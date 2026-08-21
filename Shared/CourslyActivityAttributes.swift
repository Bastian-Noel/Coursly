import ActivityKit
import Foundation

struct CourslyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let title: String
        let room: String
        let type: String?
        let start: Date
        let end: Date
        let nextTitle: String?
        let nextRoom: String?
        let nextStart: Date?
        let isInProgress: Bool
        let dayFinished: Bool
    }
    let dayID: String
}
