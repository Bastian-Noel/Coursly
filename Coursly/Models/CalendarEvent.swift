import Foundation

enum EventSource: String, Codable, Sendable { case directPOST, iCalFallback, local }

enum CourseType: String, Codable, CaseIterable, Sendable {
    case cm = "CM", td = "TD", tp = "TP", project = "PROJET"
    case integration = "INT", meeting = "RÉUNION", test = "DS", exam = "EXAM"
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
    let type: CourseType?
    let start: Date
    let end: Date
    let rooms: [String]
    let teachers: [String]
    let groups: [StudentGroup]
    let moduleCode: String?
    let moduleName: String?
    let source: EventSource

    var room: String { rooms.joined(separator: " / ") }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}
