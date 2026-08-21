import Foundation
import Observation

@MainActor @Observable
final class CalendarStore {
    var selectedGroups: [StudentGroup] { didSet { persistSelectedGroups() } }
    var remoteEvents: [CalendarEvent] = []
    var events: [CalendarEvent] = []
    var isLoading = false
    var errorMessage: String?
    var fallbackGroups: [StudentGroup] = []
    var failedGroups: [StudentGroup] = []
    var loadedInterval: DateInterval?
    var lastSyncDate: Date?
    var focusedDate: Date = Calendar.current.startOfDay(for: Date())
    var displayMode: CalendarDisplayMode = .day
    var highlightedEventID: String?
    var weekendPolicy: WeekendDisplayPolicy { didSet { UserDefaults.standard.set(weekendPolicy.rawValue, forKey: "v3.weekendPolicy") } }
    var hourHeight: Double { didSet { UserDefaults.standard.set(hourHeight, forKey: "v3.hourHeight") } }
    var simulationEnabled: Bool { didSet { UserDefaults.standard.set(simulationEnabled, forKey: "simulationEnabled") } }
    var simulationOffset: TimeInterval { didSet { UserDefaults.standard.set(simulationOffset, forKey: "simulationOffset") } }
    var notificationsEnabled: Bool { didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "v3.notificationsEnabled") } }
    var notificationHorizonDays: Int { didSet { UserDefaults.standard.set(notificationHorizonDays, forKey: "v3.notificationHorizonDays") } }
    var notificationChangeKinds: Set<CalendarChangeKind> {
        didSet { UserDefaults.standard.set(notificationChangeKinds.map(\.rawValue).sorted(), forKey: "v3.notificationChangeKinds") }
    }
    var liveActivityEnabled: Bool { didSet { UserDefaults.standard.set(liveActivityEnabled, forKey: "v3.liveActivityEnabled") } }
    var hapticsEnabled: Bool { didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "v3.hapticsEnabled") } }
    var recentChanges: [CalendarChange] = []

    private let service = CalendarService()
    private let changeDetector = ChangeDetectionService()
    private let searchEngine = SearchEngine()
    private let snapshotStore = DirectSnapshotStore()
    private let historyStore = ChangeHistoryStore()
    private let localEventStore = LocalEventStore()
    private let notificationService = NotificationService()

    init() {
        let defaults = UserDefaults.standard
        selectedGroups = CalendarStore.loadSelectedGroups()
        simulationEnabled = defaults.bool(forKey: "simulationEnabled")
        simulationOffset = defaults.double(forKey: "simulationOffset")
        notificationsEnabled = defaults.object(forKey: "v3.notificationsEnabled") as? Bool ?? true
        notificationHorizonDays = max(1, defaults.integer(forKey: "v3.notificationHorizonDays") == 0 ? 7 : defaults.integer(forKey: "v3.notificationHorizonDays"))
        if let storedKinds = defaults.stringArray(forKey: "v3.notificationChangeKinds") {
            notificationChangeKinds = Set(storedKinds.compactMap(CalendarChangeKind.init(rawValue:)))
        } else {
            notificationChangeKinds = Set(CalendarChangeKind.allCases)
        }
        liveActivityEnabled = defaults.object(forKey: "v3.liveActivityEnabled") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "v3.hapticsEnabled") as? Bool ?? true
        hourHeight = defaults.double(forKey: "v3.hourHeight") == 0 ? 88 : defaults.double(forKey: "v3.hourHeight")
        weekendPolicy = WeekendDisplayPolicy(rawValue: defaults.string(forKey: "v3.weekendPolicy") ?? "") ?? .smart
        let effectiveNow = simulationEnabled ? Date().addingTimeInterval(simulationOffset) : Date()
        focusedDate = Calendar.current.startOfDay(for: effectiveNow)
        recentChanges = historyStore.all()
    }

    var now: Date { effectiveNow(from: Date()) }
    func effectiveNow(from systemDate: Date) -> Date { simulationEnabled ? systemDate.addingTimeInterval(simulationOffset) : systemDate }
    var simulationDate: Date {
        get { now }
        set { simulationOffset = newValue.timeIntervalSinceNow; simulationEnabled = true; focusedDate = Calendar.current.startOfDay(for: newValue) }
    }
    var selectedGroupsLabel: String {
        switch selectedGroups.count { case 0: "Aucun groupe"; case 1: selectedGroups[0].name; default: "\(selectedGroups.count) groupes" }
    }
    var searchFacets: SearchFacets { searchEngine.facets(from: events) }
    var liveActivityIsActive: Bool { LiveActivityManager.hasActiveActivity }
    var liveActivitiesAuthorized: Bool { LiveActivityManager.areActivitiesEnabled }
    func search(_ filters: SearchFilters) -> [CalendarEvent] { searchEngine.results(in: events, filters: filters) }
    func isGroupSelected(_ group: StudentGroup) -> Bool { selectedGroups.contains(group) }
    func isNotificationKindEnabled(_ kind: CalendarChangeKind) -> Bool { notificationChangeKinds.contains(kind) }

    func setGroup(_ group: StudentGroup, enabled: Bool) {
        if enabled {
            if !selectedGroups.contains(group) { selectedGroups.append(group); selectedGroups.sort { $0.name < $1.name } }
        } else {
            guard selectedGroups.count > 1 else { return }; selectedGroups.removeAll { $0 == group }
        }
        HapticService.fire(.selection, enabled: hapticsEnabled)
    }

    func setNotificationKind(_ kind: CalendarChangeKind, enabled: Bool) {
        if enabled { notificationChangeKinds.insert(kind) }
        else { notificationChangeKinds.remove(kind) }
        HapticService.fire(.selection, enabled: hapticsEnabled)
    }

    func resetSimulation() { simulationEnabled = false; simulationOffset = 0; focusedDate = Calendar.current.startOfDay(for: Date()) }
    func setSimulationEnabled(_ enabled: Bool) {
        simulationEnabled = enabled
        if !enabled { simulationOffset = 0; focusedDate = Calendar.current.startOfDay(for: Date()) }
        else { focusedDate = Calendar.current.startOfDay(for: now) }
    }

    func load(around date: Date? = nil, force: Bool = false) async {
        let center = date ?? focusedDate
        let interval = makeLoadInterval(around: center)
        if !force, let loadedInterval, loadedInterval.contains(center) { refreshCombinedEvents(); return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.load(groups: selectedGroups, interval: interval)
            remoteEvents = result.events; loadedInterval = interval; fallbackGroups = result.fallbackGroups; failedGroups = result.failedGroups; lastSyncDate = Date()
            let newChanges = processDirectSnapshots(result.directEventsByGroup, interval: interval)
            refreshCombinedEvents()
            if !newChanges.isEmpty {
                historyStore.prepend(newChanges, now: now); recentChanges = historyStore.all()
                let notifyChanges = changesWithinNotificationHorizon(newChanges)
                if notificationsEnabled, !notifyChanges.isEmpty { await notificationService.notify(changes: notifyChanges) }
            } else { recentChanges = historyStore.all() }
            if liveActivityEnabled { await LiveActivityManager.update(events: events(on: now), now: now, enabled: true) }
            else { await LiveActivityManager.endAll(now: now) }
        } catch { errorMessage = error.localizedDescription; HapticService.fire(.error, enabled: hapticsEnabled) }
    }

    func refresh() async { await load(around: focusedDate, force: true) }
    func ensureLoaded(around date: Date) async { if let loadedInterval, loadedInterval.contains(date) { return }; await load(around: date, force: true) }
    func events(on date: Date) -> [CalendarEvent] { events.filter { Calendar.current.isDate($0.start, inSameDayAs: date) }.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start } }
    func hasEvents(on date: Date) -> Bool { !events(on: date).isEmpty }
    func moveDay(_ direction: Int) { guard direction != 0 else { return }; focusedDate = Calendar.current.startOfDay(for: nextVisibleDate(from: focusedDate, direction: direction)); highlightedEventID = nil; HapticService.fire(.dayChanged, enabled: hapticsEnabled) }
    func goToToday() { focusedDate = Calendar.current.startOfDay(for: now); displayMode = .day; highlightedEventID = nil; HapticService.fire(.returnedToNow, enabled: hapticsEnabled) }
    func goTo(event: CalendarEvent) { focusedDate = Calendar.current.startOfDay(for: event.start); displayMode = .day; highlightedEventID = event.id; HapticService.fire(.selection, enabled: hapticsEnabled) }
    func setDisplayMode(_ mode: CalendarDisplayMode) { guard displayMode != mode else { return }; displayMode = mode; HapticService.fire(.displayModeChanged, enabled: hapticsEnabled) }

    func visibleWeekDays(containing date: Date) -> [Date] {
        let iso = Calendar(identifier: .iso8601)
        guard let week = iso.dateInterval(of: .weekOfYear, for: date) else { return [date] }
        return (0..<7).compactMap { iso.date(byAdding: .day, value: $0, to: week.start) }.filter { day in
            let weekday = Calendar.current.component(.weekday, from: day); let isWeekend = weekday == 1 || weekday == 7
            guard isWeekend else { return true }
            switch weekendPolicy { case .always: return true; case .hidden: return false; case .smart: return hasEvents(on: day) }
        }
    }

    func addLocalEvent(title: String, start: Date, end: Date, room: String?) {
        let event = CalendarEvent(id: "local-\(UUID().uuidString)", title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Événement personnel" : title, type: nil, start: start, end: max(end, start.addingTimeInterval(15 * 60)), rooms: room.map { [$0] } ?? [], teachers: [], groups: [], moduleCode: nil, moduleName: nil, source: .local)
        localEventStore.add(event); refreshCombinedEvents(); HapticService.fire(.success, enabled: hapticsEnabled)
    }
    func deleteLocalEvent(_ event: CalendarEvent) { guard event.source == .local else { return }; localEventStore.delete(id: event.id); refreshCombinedEvents(); HapticService.fire(.success, enabled: hapticsEnabled) }
    func setNotificationsEnabled(_ enabled: Bool) async { notificationsEnabled = enabled ? await notificationService.requestAuthorization() : false }
    func setLiveActivityEnabled(_ enabled: Bool) async { liveActivityEnabled = enabled; if enabled { await restartLiveActivity() } else { await LiveActivityManager.endAll(now: now) } }
    func restartLiveActivity() async { guard liveActivityEnabled else { return }; await LiveActivityManager.restart(events: events(on: now), now: now); HapticService.fire(.success, enabled: hapticsEnabled) }
    func endLiveActivity() async { await LiveActivityManager.endAll(now: now) }
    func clearChangeHistory() { historyStore.clear(); recentChanges = [] }

    func recentChangeKind(for event: CalendarEvent) -> CalendarChangeKind? {
        let cutoff = now.addingTimeInterval(-48 * 60 * 60)
        return recentChanges.first(where: { change in
            change.detectedAt >= cutoff && (change.newEvent?.id == event.id || change.oldEvent?.id == event.id)
        })?.kind
    }

    private func processDirectSnapshots(_ snapshots: [StudentGroup: [CalendarEvent]], interval: DateInterval) -> [CalendarChange] {
        var changes: [CalendarChange] = []
        for (group, newEvents) in snapshots {
            let scopedNew = newEvents.filter { interval.contains($0.start) }
            if let oldEvents = snapshotStore.snapshot(for: group) { changes.append(contentsOf: changeDetector.detect(old: oldEvents.filter { interval.contains($0.start) }, new: scopedNew, group: group, detectedAt: Date())) }
            snapshotStore.save(scopedNew, for: group)
        }
        return changeDetector.deduplicate(changes)
    }
    private func changesWithinNotificationHorizon(_ changes: [CalendarChange]) -> [CalendarChange] {
        let lower = now; let upper = Calendar.current.date(byAdding: .day, value: notificationHorizonDays, to: lower) ?? lower
        return changes.filter { change in
            guard notificationChangeKinds.contains(change.kind), let date = change.relevantDate else { return false }
            return date >= lower && date <= upper
        }
    }
    private func refreshCombinedEvents() { events = (remoteEvents + localEventStore.all()).sorted { $0.start == $1.start ? $0.title < $1.title : $0.start < $1.start } }
    private func makeLoadInterval(around date: Date) -> DateInterval {
        let calendar = Calendar.current; let day = calendar.startOfDay(for: date); let start = calendar.date(byAdding: .day, value: -7, to: day) ?? day; let horizon = max(35, notificationHorizonDays + 14); let end = calendar.date(byAdding: .day, value: horizon, to: day) ?? day.addingTimeInterval(Double(horizon) * 86_400); return DateInterval(start: start, end: end)
    }
    private func nextVisibleDate(from date: Date, direction: Int) -> Date {
        let calendar = Calendar.current; var candidate = date
        for _ in 0..<10 {
            candidate = calendar.date(byAdding: .day, value: direction > 0 ? 1 : -1, to: candidate) ?? candidate
            let weekday = calendar.component(.weekday, from: candidate); let weekend = weekday == 1 || weekday == 7
            guard weekend else { return candidate }
            switch weekendPolicy { case .always: return candidate; case .hidden: continue; case .smart: if hasEvents(on: candidate) { return candidate } }
        }
        return candidate
    }
    private static func loadSelectedGroups() -> [StudentGroup] {
        let defaults = UserDefaults.standard
        if let names = defaults.stringArray(forKey: "selectedGroups"), !names.isEmpty { let valid = names.map(StudentGroup.init(name:)).filter { StudentGroup.all.contains($0) }; if !valid.isEmpty { return valid } }
        if let legacy = defaults.string(forKey: "selectedGroup") { let group = StudentGroup(name: legacy); if StudentGroup.all.contains(group) { return [group] } }
        return [StudentGroup(name: "MMI1-A1")]
    }
    private func persistSelectedGroups() {
        if selectedGroups.isEmpty { selectedGroups = [StudentGroup(name: "MMI1-A1")]; return }
        UserDefaults.standard.set(selectedGroups.map(\.name), forKey: "selectedGroups"); UserDefaults.standard.set(selectedGroups.first?.name, forKey: "selectedGroup")
    }
}
