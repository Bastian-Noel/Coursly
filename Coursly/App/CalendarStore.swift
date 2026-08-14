import Foundation
import Observation

@MainActor @Observable
final class CalendarStore {
    var selectedGroups: [StudentGroup] = Self.loadSelectedGroups() {
        didSet { persistSelectedGroups() }
    }

    var events: [CalendarEvent] = []
    var isLoading = false
    var errorMessage: String?
    var selectedDate = Date()
    var weekOffset = 0
    var firstVisibleHour = 8
    var lastVisibleHour = 19

    var simulationEnabled = UserDefaults.standard.bool(forKey: "simulationEnabled") {
        didSet { UserDefaults.standard.set(simulationEnabled, forKey: "simulationEnabled") }
    }

    var simulationOffset: TimeInterval = UserDefaults.standard.double(forKey: "simulationOffset") {
        didSet { UserDefaults.standard.set(simulationOffset, forKey: "simulationOffset") }
    }

    private let service = CalendarService()

    var now: Date {
        simulationEnabled ? Date().addingTimeInterval(simulationOffset) : Date()
    }

    var simulationDate: Date {
        get { now }
        set {
            simulationOffset = newValue.timeIntervalSinceNow
            simulationEnabled = true
        }
    }

    var selectedGroupsLabel: String {
        switch selectedGroups.count {
        case 0: return "Aucun groupe"
        case 1: return selectedGroups[0].name
        default: return "\(selectedGroups.count) groupes"
        }
    }

    func isGroupSelected(_ group: StudentGroup) -> Bool {
        selectedGroups.contains(group)
    }

    func setGroup(_ group: StudentGroup, enabled: Bool) {
        if enabled {
            if !selectedGroups.contains(group) {
                selectedGroups.append(group)
                selectedGroups.sort { $0.name < $1.name }
            }
        } else {
            guard selectedGroups.count > 1 else { return }
            selectedGroups.removeAll { $0 == group }
        }
    }

    func resetSimulation() {
        simulationEnabled = false
        simulationOffset = 0
        weekOffset = 0
        selectedDate = Date()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            events = try await service.events(for: selectedGroups, interval: displayedInterval)
            await LiveActivityManager.update(events: events(on: now))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var displayedInterval: DateInterval {
        let calendar = Calendar(identifier: .iso8601)
        let base = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now) ?? now
        return calendar.dateInterval(of: .weekOfYear, for: base)
            ?? DateInterval(start: base, duration: 604_800)
    }

    func events(on date: Date) -> [CalendarEvent] {
        events
            .filter { Calendar.current.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }

    private static func loadSelectedGroups() -> [StudentGroup] {
        let defaults = UserDefaults.standard

        if let names = defaults.stringArray(forKey: "selectedGroups"), !names.isEmpty {
            let groups = names.map(StudentGroup.init(name:))
            let valid = groups.filter { StudentGroup.all.contains($0) }
            if !valid.isEmpty { return valid }
        }

        if let legacy = defaults.string(forKey: "selectedGroup") {
            let group = StudentGroup(name: legacy)
            if StudentGroup.all.contains(group) { return [group] }
        }

        return [StudentGroup(name: "MMI1-A1")]
    }

    private func persistSelectedGroups() {
        let normalized = selectedGroups.isEmpty ? [StudentGroup(name: "MMI1-A1")] : selectedGroups
        if selectedGroups.isEmpty { selectedGroups = normalized; return }
        UserDefaults.standard.set(normalized.map(\.name), forKey: "selectedGroups")
        UserDefaults.standard.set(normalized.first?.name, forKey: "selectedGroup")
    }
}
