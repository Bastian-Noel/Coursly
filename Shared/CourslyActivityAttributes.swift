import ActivityKit
import Foundation

struct CourslyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let title: String
        let room: String
        let teachers: String
        let groups: String
        let type: String?
        let accentHex: String

        // Horaires réels du cours, toujours affichés en heure Europe/Paris.
        let start: Date
        let end: Date

        // Dates translatées uniquement pour les timers ActivityKit.
        let timerStart: Date
        let timerEnd: Date

        let nextTitle: String?
        let nextRoom: String?
        let nextType: String?
        let nextAccentHex: String?
        let nextStart: Date?
        let nextEnd: Date?
        let nextTeachers: String?
        let nextGroups: String?
        let nextTimerStart: Date?
        let nextTimerEnd: Date?
        let isLastCourse: Bool
        let nextIsLastCourse: Bool?
        let isInProgress: Bool
        let dayFinished: Bool
    }
    let dayID: String
}
