import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent
    var body: some View {
        List {
            Section { Text(event.title).font(.title2.bold()); if let type = event.type { Label(type.rawValue, systemImage: "tag") } }
            Section("Horaire") { LabeledContent("Date", value: event.start.formatted(date: .complete, time: .omitted)); LabeledContent("Début", value: event.start.formatted(date: .omitted, time: .shortened)); LabeledContent("Fin", value: event.end.formatted(date: .omitted, time: .shortened)) }
            if !event.rooms.isEmpty { Section("Salle") { Text(event.room) } }
            Section("Groupe") { Text(event.groups.map(\.name).joined(separator: ", ")) }
            if !event.teachers.isEmpty { Section("Enseignant") { Text(event.teachers.joined(separator: ", ")) } }
            if let code = event.moduleCode, !code.isEmpty { Section("Module") { Text(code) } }
        }.navigationTitle("Cours").navigationBarTitleDisplayMode(.inline)
    }
}
