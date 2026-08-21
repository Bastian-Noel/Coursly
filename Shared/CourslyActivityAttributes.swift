import ActivityKit
import Foundation

struct CourslyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let title: String
        let room: String
        let teachers: String
        let group: String
        let type: String?
        let accentHex: String

        // Horaires réels du cours, toujours affichés en heure Europe/Paris.
        let start: Date
        let end: Date

        // Dates translatées uniquement pour permettre aux timers ActivityKit
        // de fonctionner avec l'horloge système, notamment en simulation.
        let timerStart: Date
        let timerEnd: Date

        let nextTitle: String?
        let nextRoom: String?
        let nextStart: Date?
        let isInProgress: Bool
        let dayFinished: Bool
    }
    let dayID: String
}
