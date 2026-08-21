import Foundation

extension CalendarStore {
    var observedCourseTypeLabels: [String] {
        Array(Set(events.compactMap(\.displayTypeLabel)))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
