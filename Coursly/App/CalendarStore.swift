import Foundation
import Observation

@MainActor @Observable
final class CalendarStore {
    var selectedGroup = StudentGroup(name: UserDefaults.standard.string(forKey: "selectedGroup") ?? "MMI1-A1") {
        didSet { UserDefaults.standard.set(selectedGroup.name, forKey: "selectedGroup") }
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

    /// Horloge métier de l'app. En mode simulation, elle continue d'avancer en temps réel
    /// à partir du décalage choisi dans Réglages.
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
            events = try await service.events(for: selectedGroup, interval: displayedInterval)
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
}
