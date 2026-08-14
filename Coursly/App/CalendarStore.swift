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
    private let service = CalendarService()

    func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            events = try await service.events(for: selectedGroup, interval: displayedInterval)
            await LiveActivityManager.update(events: events(on: .now))
        }
        catch { errorMessage = error.localizedDescription }
    }

    var displayedInterval: DateInterval {
        let calendar = Calendar(identifier: .iso8601)
        let base = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
        return calendar.dateInterval(of: .weekOfYear, for: base) ?? DateInterval(start: base, duration: 604_800)
    }
    func events(on date: Date) -> [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.start, inSameDayAs: date) }.sorted { $0.start < $1.start }
    }
}
