import Foundation

enum CalendarChangeKind: String, Codable, CaseIterable, Sendable {
    case added
    case removed
    case moved
    case modified

    var frenchTitle: String {
        switch self {
        case .added: "Cours ajouté"
        case .removed: "Cours supprimé"
        case .moved: "Cours déplacé"
        case .modified: "Cours modifié"
        }
    }

    var symbolName: String {
        switch self {
        case .added: "plus.circle.fill"
        case .removed: "minus.circle.fill"
        case .moved: "arrow.left.arrow.right.circle.fill"
        case .modified: "pencil.circle.fill"
        }
    }
}

struct CalendarChange: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let kind: CalendarChangeKind
    let detectedAt: Date
    let group: StudentGroup
    let oldEvent: CalendarEvent?
    let newEvent: CalendarEvent?

    init(
        id: UUID = UUID(),
        kind: CalendarChangeKind,
        detectedAt: Date = .now,
        group: StudentGroup,
        oldEvent: CalendarEvent? = nil,
        newEvent: CalendarEvent? = nil
    ) {
        self.id = id
        self.kind = kind
        self.detectedAt = detectedAt
        self.group = group
        self.oldEvent = oldEvent
        self.newEvent = newEvent
    }

    var event: CalendarEvent? { newEvent ?? oldEvent }
    var title: String { event?.title ?? "Cours" }

    var relevantDate: Date? {
        switch kind {
        case .added, .moved, .modified:
            newEvent?.start ?? oldEvent?.start
        case .removed:
            oldEvent?.start
        }
    }

    var summary: String {
        switch kind {
        case .added:
            guard let event = newEvent else { return "Nouveau cours" }
            return "Ajouté le \(event.start.formatted(date: .abbreviated, time: .shortened))"
        case .removed:
            guard let event = oldEvent else { return "Cours supprimé" }
            return "Supprimé le \(event.start.formatted(date: .abbreviated, time: .shortened))"
        case .moved:
            guard let oldEvent, let newEvent else { return "Horaire modifié" }
            return "\(oldEvent.start.formatted(date: .omitted, time: .shortened)) → \(newEvent.start.formatted(date: .omitted, time: .shortened))"
        case .modified:
            guard let oldEvent, let newEvent else { return "Informations modifiées" }
            if oldEvent.rooms != newEvent.rooms {
                return "Salle : \(oldEvent.room.isEmpty ? "—" : oldEvent.room) → \(newEvent.room.isEmpty ? "—" : newEvent.room)"
            }
            if oldEvent.teachers != newEvent.teachers {
                let before = oldEvent.teachers.joined(separator: ", ")
                let after = newEvent.teachers.joined(separator: ", ")
                return "Prof : \(before.isEmpty ? "—" : before) → \(after.isEmpty ? "—" : after)"
            }
            return "Informations du cours mises à jour"
        }
    }
}

enum CalendarDisplayMode: String, Codable, CaseIterable, Sendable {
    case day
    case week
}

enum WeekendDisplayPolicy: String, Codable, CaseIterable, Sendable, Identifiable {
    case smart
    case always
    case hidden

    var id: String { rawValue }

    var frenchTitle: String {
        switch self {
        case .smart: "Intelligent"
        case .always: "Toujours afficher"
        case .hidden: "Toujours masquer"
        }
    }
}
