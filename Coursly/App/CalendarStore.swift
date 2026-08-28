import Foundation
import Observation

enum TimelineScrollTarget: Equatable, Sendable {
    case now
    case minute(Int)
}

struct TimelineScrollRequest: Equatable, Sendable {
    let id: UUID
    let target: TimelineScrollTarget
}

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
    var isUsingCachedEvents = false
    var focusedDate: Date = Calendar.current.startOfDay(for: Date())
    var dayFocusedDate: Date = Calendar.current.startOfDay(for: Date())
    var displayMode: CalendarDisplayMode = .day
    private(set) var didNavigateWeekHorizontally = false
    var highlightedEventID: String?
    /// La navigation de date et la position verticale sont volontairement séparées.
    /// Un swipe horizontal ne produit jamais de requête de recentrage.
    var dateNavigationToken = UUID()
    var timelineScrollRequest: TimelineScrollRequest?
    var dayTopMinute: Int?
    var weekTopMinute: Int?
    var weekendPolicy: WeekendDisplayPolicy { didSet { UserDefaults.standard.set(weekendPolicy.rawValue, forKey: "v3.weekendPolicy") } }
    var hourHeight: Double { didSet { UserDefaults.standard.set(hourHeight, forKey: "v3.hourHeight") } }
    var simulationEnabled: Bool { didSet { UserDefaults.standard.set(simulationEnabled, forKey: "simulationEnabled") } }
    var simulationOffset: TimeInterval { didSet { UserDefaults.standard.set(simulationOffset, forKey: "simulationOffset") } }
    var notificationsEnabled: Bool { didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "v3.notificationsEnabled") } }
    var notificationHorizonDays: Int { didSet { UserDefaults.standard.set(notificationHorizonDays, forKey: "v3.notificationHorizonDays") } }
    var notificationChangeKinds: Set<CalendarChangeKind> { didSet { UserDefaults.standard.set(notificationChangeKinds.map(\.rawValue).sorted(), forKey: "v3.notificationChangeKinds") } }
    var liveActivityEnabled: Bool { didSet { UserDefaults.standard.set(liveActivityEnabled, forKey: "v3.liveActivityEnabled") } }
    var liveActivityRestorePromptEnabled: Bool { didSet { UserDefaults.standard.set(liveActivityRestorePromptEnabled, forKey: "v3.liveActivityRestorePromptEnabled") } }
    private(set) var shouldPresentLiveActivityRestorePrompt = false
    var hapticsEnabled: Bool { didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "v3.hapticsEnabled") } }
    var recentChanges: [CalendarChange] = []
    var courseColorRevision = UUID()

    private let service = CalendarService()
    private let changeDetector = ChangeDetectionService()
    private let searchEngine = SearchEngine()
    private let snapshotStore = DirectSnapshotStore()
    private let calendarCache = RemoteCalendarCache()
    private let historyStore = ChangeHistoryStore()
    private let localEventStore = LocalEventStore()
    private let notificationService = NotificationService()
    private static let observedTypesKey = "v3.observedCourseTypeLabels"
    private static let liveActivityWasActiveKey = "v3.liveActivityWasActive"
    private var liveActivityWasActive: Bool
    private var suppressLiveActivityAutoStart = false
    private var loadedIntervals: [DateInterval] = []
    private var activeLoadTask: Task<Void, Never>?
    private var activeLoadID: UUID?

    init() {
        let defaults = UserDefaults.standard
        selectedGroups = CalendarStore.loadSelectedGroups()
        simulationEnabled = defaults.bool(forKey: "simulationEnabled")
        simulationOffset = defaults.double(forKey: "simulationOffset")
        notificationsEnabled = defaults.object(forKey: "v3.notificationsEnabled") as? Bool ?? true
        notificationHorizonDays = max(1, defaults.integer(forKey: "v3.notificationHorizonDays") == 0 ? 7 : defaults.integer(forKey: "v3.notificationHorizonDays"))
        if let storedKinds = defaults.stringArray(forKey: "v3.notificationChangeKinds") { notificationChangeKinds = Set(storedKinds.compactMap(CalendarChangeKind.init(rawValue:))) } else { notificationChangeKinds = Set(CalendarChangeKind.allCases) }
        liveActivityEnabled = defaults.object(forKey: "v3.liveActivityEnabled") as? Bool ?? true
        liveActivityRestorePromptEnabled = defaults.object(forKey: "v3.liveActivityRestorePromptEnabled") as? Bool ?? true
        liveActivityWasActive = defaults.bool(forKey: Self.liveActivityWasActiveKey)
        hapticsEnabled = defaults.object(forKey: "v3.hapticsEnabled") as? Bool ?? true
        hourHeight = defaults.double(forKey: "v3.hourHeight") == 0 ? 88 : defaults.double(forKey: "v3.hourHeight")
        weekendPolicy = WeekendDisplayPolicy(rawValue: defaults.string(forKey: "v3.weekendPolicy") ?? "") ?? .smart
        let effectiveNow = simulationEnabled ? Date().addingTimeInterval(simulationOffset) : Date()
        focusedDate = Calendar.current.startOfDay(for: effectiveNow)
        dayFocusedDate = focusedDate
        recentChanges = historyStore.all()
        if let cached = calendarCache.load(for: selectedGroups) {
            remoteEvents = cached.events
            lastSyncDate = cached.savedAt
            isUsingCachedEvents = true
        }
        refreshCombinedEvents()
    }

    var now: Date { effectiveNow(from: Date()) }
    func effectiveNow(from systemDate: Date) -> Date { simulationEnabled ? systemDate.addingTimeInterval(simulationOffset) : systemDate }
    var simulationDate: Date {
        get { now }
        set {
            simulationOffset = newValue.timeIntervalSinceNow
            simulationEnabled = true
            navigate(to: newValue, scrollTarget: .now)
        }
    }
    var selectedGroupsLabel: String { switch selectedGroups.count { case 0: "Aucun groupe"; case 1: selectedGroups[0].name; default: "\(selectedGroups.count) groupes" } }
    var compactSelectedGroupsLabel: String {
        guard !selectedGroups.isEmpty else { return "Groupes" }
        let cohorts = Set(selectedGroups.compactMap { $0.name.split(separator: "-").first.map(String.init) })
        if cohorts.count == 1, let cohort = cohorts.first {
            let allInCohort = StudentGroup.all.filter { $0.name.hasPrefix(cohort + "-") }
            if !allInCohort.isEmpty, Set(allInCohort) == Set(selectedGroups) { return cohort }
        }
        return selectedGroups.count == 1 ? selectedGroups[0].name : "\(selectedGroups.count) groupes"
    }
    var searchFacets: SearchFacets { searchEngine.facets(from: events) }
    var liveActivityIsActive: Bool { LiveActivityManager.hasActiveActivity }
    var liveActivitiesAuthorized: Bool { LiveActivityManager.areActivitiesEnabled }
    var observedCourseTypeLabels: [String] {
        let stored = UserDefaults.standard.stringArray(forKey: Self.observedTypesKey) ?? []
        let current = remoteEvents.compactMap(\.displayTypeLabel).map(Self.cleanTypeLabel).filter { !$0.isEmpty }
        return Array(Set(stored + current)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    func search(_ filters: SearchFilters) -> [CalendarEvent] { searchEngine.results(in: events, filters: filters) }
    func isGroupSelected(_ group: StudentGroup) -> Bool { selectedGroups.contains(group) }
    func isNotificationKindEnabled(_ kind: CalendarChangeKind) -> Bool { notificationChangeKinds.contains(kind) }

    func setGroup(_ group: StudentGroup, enabled: Bool) {
        var updated = selectedGroups
        if enabled {
            if !updated.contains(group) { updated.append(group) }
        } else {
            guard updated.count > 1 else { return }
            updated.removeAll { $0 == group }
        }
        setSelectedGroups(updated)
    }

    func setSelectedGroups(_ groups: [StudentGroup]) {
        let valid = Array(Set(groups.filter { StudentGroup.all.contains($0) })).sorted { $0.name < $1.name }
        guard !valid.isEmpty, valid != selectedGroups else { return }
        selectedGroups = valid
        restoreCachedCalendarForSelection()
        HapticService.fire(.selection, enabled: hapticsEnabled)
    }

    func setNotificationKind(_ kind: CalendarChangeKind, enabled: Bool) { if enabled { notificationChangeKinds.insert(kind) } else { notificationChangeKinds.remove(kind) }; HapticService.fire(.selection, enabled: hapticsEnabled) }
    func resetSimulation() {
        simulationEnabled = false
        simulationOffset = 0
        navigate(to: Date(), scrollTarget: .now)
    }

    func setSimulationEnabled(_ enabled: Bool) {
        simulationEnabled = enabled
        if !enabled { simulationOffset = 0 }
        navigate(to: now, scrollTarget: .now)
    }

    func load(around date: Date? = nil, force: Bool = false) async {
        let center = date ?? focusedDate
        let interval = makeLoadInterval(around: center)
        if !force, loadedIntervals.contains(where: { $0.contains(center) }) { refreshCombinedEvents(); return }

        if let activeLoadTask {
            await activeLoadTask.value
            if !force, loadedIntervals.contains(where: { $0.contains(center) }) { return }
        }

        let loadID = UUID()
        activeLoadID = loadID
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performLoad(interval: interval, force: force)
        }
        activeLoadTask = task
        await task.value
        if activeLoadID == loadID {
            activeLoadTask = nil
            activeLoadID = nil
        }
    }

    private func performLoad(interval: DateInterval, force: Bool) async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do {
            let result = try await service.load(groups: selectedGroups, interval: interval)
            if force {
                remoteEvents = result.events
                loadedIntervals = [interval]
            } else {
                remoteEvents = service.mergeVisualDuplicates(remoteEvents + result.events)
                loadedIntervals.append(interval)
            }
            persistObservedCourseTypes(from: result.events)
            loadedInterval = encompassingLoadedInterval()
            fallbackGroups = Array(Set(fallbackGroups + result.fallbackGroups)).sorted { $0.name < $1.name }
            failedGroups = result.failedGroups
            lastSyncDate = Date()
            isUsingCachedEvents = false

            let newChanges = force ? processDirectSnapshots(result.directEventsByGroup, interval: interval) : []
            refreshCombinedEvents()
            if result.failedGroups.isEmpty {
                calendarCache.save(remoteEvents, for: selectedGroups, at: lastSyncDate ?? Date())
            }
            if !newChanges.isEmpty {
                historyStore.prepend(newChanges, now: now)
                recentChanges = historyStore.all()
                let notifyChanges = changesWithinNotificationHorizon(newChanges)
                if notificationsEnabled, !notifyChanges.isEmpty { await notificationService.notify(changes: notifyChanges) }
            } else { recentChanges = historyStore.all() }
            if liveActivityEnabled, !suppressLiveActivityAutoStart {
                await LiveActivityManager.update(events: events(on: now), now: now, enabled: true)
                recordLiveActivityIfActive()
            } else if !liveActivityEnabled {
                await LiveActivityManager.endAll(now: now)
            }
        } catch {
            errorMessage = error.localizedDescription
            failedGroups = selectedGroups
            isUsingCachedEvents = !remoteEvents.isEmpty
            HapticService.fire(.error, enabled: hapticsEnabled)
        }
    }

    func refresh() async { await load(around: focusedDate, force: true) }
    func ensureLoaded(around date: Date) async {
        if loadedIntervals.contains(where: { $0.contains(date) }) { return }
        await load(around: date, force: false)
    }
    func events(on date: Date) -> [CalendarEvent] { events.filter { Calendar.current.isDate($0.start, inSameDayAs: date) }.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start } }
    func hasEvents(on date: Date) -> Bool { !events(on: date).isEmpty }
    func adjacentVisibleDate(from date: Date? = nil, direction: Int) -> Date { nextVisibleDate(from: date ?? focusedDate, direction: direction) }
    func moveDay(_ direction: Int) {
        guard direction != 0 else { return }
        focusedDate = Calendar.current.startOfDay(for: nextVisibleDate(from: focusedDate, direction: direction))
        dayFocusedDate = focusedDate
        highlightedEventID = nil
        HapticService.fire(.dayChanged, enabled: hapticsEnabled)
    }

    func setFocusedDateFromTimeline(_ date: Date) {
        focusedDate = Calendar.current.startOfDay(for: date)
        didNavigateWeekHorizontally = true
        highlightedEventID = nil
    }

    func goToDate(_ date: Date) {
        navigate(to: date, scrollTarget: nil)
        HapticService.fire(.selection, enabled: hapticsEnabled)
    }

    func goToToday() {
        highlightedEventID = nil
        navigate(to: now, scrollTarget: .now)
        HapticService.fire(.returnedToNow, enabled: hapticsEnabled)
    }

    func goTo(event: CalendarEvent) {
        displayMode = .day
        highlightedEventID = event.id
        navigate(to: event.start, scrollTarget: .minute(timelineMinute(for: event.start)))
        HapticService.fire(.selection, enabled: hapticsEnabled)
    }

    func setDisplayMode(_ mode: CalendarDisplayMode) {
        guard displayMode != mode else { return }
        if mode == .week {
            dayFocusedDate = focusedDate
            didNavigateWeekHorizontally = false
        } else if !didNavigateWeekHorizontally {
            focusedDate = dayFocusedDate
            dateNavigationToken = UUID()
        } else {
            dayFocusedDate = focusedDate
        }
        displayMode = mode
        HapticService.fire(.displayModeChanged, enabled: hapticsEnabled)
    }

    func consumeTimelineScrollRequest(_ id: UUID) {
        guard timelineScrollRequest?.id == id else { return }
        timelineScrollRequest = nil
    }

    func recordTopMinute(_ minute: Int, for mode: CalendarDisplayMode) {
        let clamped = max(0, min(24 * 60, minute))
        switch mode {
        case .day: dayTopMinute = clamped
        case .week: weekTopMinute = clamped
        }
    }

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
    func setLiveActivityEnabled(_ enabled: Bool) async {
        liveActivityEnabled = enabled
        shouldPresentLiveActivityRestorePrompt = false
        suppressLiveActivityAutoStart = false
        if enabled {
            await restartLiveActivity()
        } else {
            liveActivityWasActive = false
            UserDefaults.standard.set(false, forKey: Self.liveActivityWasActiveKey)
            await LiveActivityManager.endAll(now: now)
        }
    }
    func prepareForForeground() {
        let hasRemainingCourse = events(on: now).contains { $0.end > now }
        let shouldPrompt = liveActivityRestorePromptEnabled
            && liveActivityEnabled
            && liveActivitiesAuthorized
            && liveActivityWasActive
            && hasRemainingCourse
            && !liveActivityIsActive
        shouldPresentLiveActivityRestorePrompt = shouldPrompt
        suppressLiveActivityAutoStart = shouldPrompt
    }
    func dismissLiveActivityRestorePrompt() {
        shouldPresentLiveActivityRestorePrompt = false
    }
    func restoreLiveActivityFromPrompt() async {
        shouldPresentLiveActivityRestorePrompt = false
        suppressLiveActivityAutoStart = false
        await restartLiveActivity()
    }
    func restartLiveActivity() async {
        guard liveActivityEnabled else { return }
        suppressLiveActivityAutoStart = false
        await LiveActivityManager.restart(events: events(on: now), now: now)
        recordLiveActivityIfActive()
        HapticService.fire(.success, enabled: hapticsEnabled)
    }
    func endLiveActivity() async {
        suppressLiveActivityAutoStart = true
        liveActivityWasActive = false
        UserDefaults.standard.set(false, forKey: Self.liveActivityWasActiveKey)
        await LiveActivityManager.endAll(now: now)
    }
    func clearChangeHistory() { historyStore.clear(); recentChanges = [] }
    func courseColorsDidChange() { courseColorRevision = UUID() }
    func recentChangeKind(for event: CalendarEvent) -> CalendarChangeKind? { let cutoff = now.addingTimeInterval(-48 * 60 * 60); return recentChanges.first(where: { $0.detectedAt >= cutoff && ($0.newEvent?.id == event.id || $0.oldEvent?.id == event.id) })?.kind }

    private func recordLiveActivityIfActive() {
        guard liveActivityIsActive else { return }
        liveActivityWasActive = true
        UserDefaults.standard.set(true, forKey: Self.liveActivityWasActiveKey)
    }

    private func encompassingLoadedInterval() -> DateInterval? {
        guard let first = loadedIntervals.first else { return nil }
        let start = loadedIntervals.dropFirst().reduce(first.start) { min($0, $1.start) }
        let end = loadedIntervals.dropFirst().reduce(first.end) { max($0, $1.end) }
        return DateInterval(start: start, end: end)
    }
    private func persistObservedCourseTypes(from loadedEvents: [CalendarEvent]) {
        let defaults = UserDefaults.standard
        let previous = defaults.stringArray(forKey: Self.observedTypesKey) ?? []
        let discovered = loadedEvents.filter { $0.source != .local }.compactMap(\.displayTypeLabel).map(Self.cleanTypeLabel).filter { !$0.isEmpty }
        defaults.set(Array(Set(previous + discovered)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, forKey: Self.observedTypesKey)
    }
    private static func cleanTypeLabel(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func processDirectSnapshots(_ snapshots: [StudentGroup: [CalendarEvent]], interval: DateInterval) -> [CalendarChange] {
        var changes: [CalendarChange] = []
        for (group, newEvents) in snapshots {
            let scopedNew = newEvents.filter { interval.contains($0.start) }
            if let oldEvents = snapshotStore.snapshot(for: group) { changes.append(contentsOf: changeDetector.detect(old: oldEvents.filter { interval.contains($0.start) }, new: scopedNew, group: group, detectedAt: Date())) }
            snapshotStore.save(scopedNew, for: group)
        }
        return changeDetector.deduplicate(changes)
    }
    private func changesWithinNotificationHorizon(_ changes: [CalendarChange]) -> [CalendarChange] { let lower = now; let upper = Calendar.current.date(byAdding: .day, value: notificationHorizonDays, to: lower) ?? lower; return changes.filter { guard notificationChangeKinds.contains($0.kind), let date = $0.relevantDate else { return false }; return date >= lower && date <= upper } }
    private func refreshCombinedEvents() { events = (remoteEvents + localEventStore.all()).sorted { $0.start == $1.start ? $0.title < $1.title : $0.start < $1.start } }
    private func restoreCachedCalendarForSelection() {
        let cached = calendarCache.load(for: selectedGroups)
        remoteEvents = cached?.events ?? []
        lastSyncDate = cached?.savedAt
        isUsingCachedEvents = cached != nil
        loadedIntervals.removeAll()
        loadedInterval = nil
        fallbackGroups = []
        failedGroups = []
        errorMessage = nil
        refreshCombinedEvents()
    }
    private func makeLoadInterval(around date: Date) -> DateInterval { let calendar = Calendar.current; let day = calendar.startOfDay(for: date); let start = calendar.date(byAdding: .day, value: -7, to: day) ?? day; let horizon = max(35, notificationHorizonDays + 14); let end = calendar.date(byAdding: .day, value: horizon, to: day) ?? day.addingTimeInterval(Double(horizon) * 86_400); return DateInterval(start: start, end: end) }
    private func navigate(to date: Date, scrollTarget: TimelineScrollTarget?) {
        focusedDate = Calendar.current.startOfDay(for: date)
        dayFocusedDate = focusedDate
        highlightedEventID = scrollTarget == nil ? nil : highlightedEventID
        dateNavigationToken = UUID()
        if let scrollTarget {
            timelineScrollRequest = TimelineScrollRequest(id: UUID(), target: scrollTarget)
        } else {
            timelineScrollRequest = nil
        }
    }
    private func timelineMinute(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    private func nextVisibleDate(from date: Date, direction: Int) -> Date {
        let calendar = Calendar.current; var candidate = date
        for _ in 0..<10 { candidate = calendar.date(byAdding: .day, value: direction > 0 ? 1 : -1, to: candidate) ?? candidate; let weekday = calendar.component(.weekday, from: candidate); let weekend = weekday == 1 || weekday == 7; guard weekend else { return candidate }; switch weekendPolicy { case .always: return candidate; case .hidden: continue; case .smart: if hasEvents(on: candidate) { return candidate } } }
        return candidate
    }
    private static func loadSelectedGroups() -> [StudentGroup] {
        let defaults = UserDefaults.standard
        if let names = defaults.stringArray(forKey: "selectedGroups"), !names.isEmpty { let valid = names.map(StudentGroup.init(name:)).filter { StudentGroup.all.contains($0) }; if !valid.isEmpty { return valid } }
        if let legacy = defaults.string(forKey: "selectedGroup") { let group = StudentGroup(name: legacy); if StudentGroup.all.contains(group) { return [group] } }
        return [StudentGroup(name: "MMI1-A1")]
    }
    private func persistSelectedGroups() { if selectedGroups.isEmpty { selectedGroups = [StudentGroup(name: "MMI1-A1")]; return }; UserDefaults.standard.set(selectedGroups.map(\.name), forKey: "selectedGroups"); UserDefaults.standard.set(selectedGroups.first?.name, forKey: "selectedGroup") }
}
