import ActivityKit
import Foundation

struct OraActivityAttributes: ActivityAttributes {
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

        // Intervalle réellement représenté par le remplissage de la capsule.
        // Nil avant le premier cours et pendant l'attente jusqu'au lendemain.
        let progressStart: Date?
        let progressEnd: Date?

        // Aperçu compact uniquement : ce cours ne devient jamais le cours principal de la veille.
        let tomorrowStart: Date?

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
