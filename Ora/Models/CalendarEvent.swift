import Foundation

enum EventSource: String, Codable, Sendable {
    case directPOST
    case iCalFallback
    case local
}

struct StudentGroup: Identifiable, Hashable, Codable, Sendable {
    let name: String
    var id: String { name }

    static let all: [StudentGroup] = [
        "MMI1-A1", "MMI1-A2", "MMI1-B1", "MMI1-B2",
        "MMI2-A1", "MMI2-A2", "MMI2-B1", "MMI2-B2",
        "MMI3-FA-DW-A1", "MMI3-FA-DW-A2", "MMI3-FI-CN-A1",
        "MMI3-FI-CN-A2", "MMI3-FA-CN-A1", "MMI3-FA-CN-A2"
    ].map(StudentGroup.init(name:))
}

struct CalendarEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    var categoryLabel: String? = nil
    var typeDisplayOverride: String? = nil
    let start: Date
    let end: Date
    let rooms: [String]
    let teachers: [String]
    let groups: [StudentGroup]
    var rawGroupLabels: [String]? = nil
    let moduleCode: String?
    let moduleName: String?
    var notes: String? = nil
    let source: EventSource

    var room: String { rooms.joined(separator: " / ") }
    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    var displayTypeLabel: String? {
        let renamed = typeDisplayOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let renamed, !renamed.isEmpty { return renamed }
        let raw = categoryLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty { return raw }
        return nil
    }
    var colorTypeLabel: String? {
        let raw = categoryLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty { return raw }
        return displayTypeLabel
    }
    var displayGroupLabels: [String] {
        let actual = (rawGroupLabels ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return actual.isEmpty ? groups.map(\.name) : Array(Set(actual)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    var displayGroupsText: String { displayGroupLabels.joined(separator: " · ") }

    var searchableText: String {
        [
            title,
            displayTypeLabel ?? "",
            rooms.joined(separator: " "),
            teachers.joined(separator: " "),
            displayGroupLabels.joined(separator: " "),
            moduleCode ?? "",
            moduleName ?? "",
            notes ?? ""
        ]
        .joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    func isSameVisualCourse(as other: CalendarEvent) -> Bool {
        normalized(title) == normalized(other.title)
            && start == other.start
            && end == other.end
            && rooms.sorted() == other.rooms.sorted()
            && teachers.sorted() == other.teachers.sorted()
            && normalized(displayTypeLabel ?? "") == normalized(other.displayTypeLabel ?? "")
            && moduleCode == other.moduleCode
            && moduleName == other.moduleName
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
