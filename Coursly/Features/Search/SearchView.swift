import SwiftUI

struct SearchView: View {
    @Environment(CalendarStore.self) private var store
    @State private var query = ""
    private var results: [CalendarEvent] { guard !query.isEmpty else { return store.events }; return store.events.filter { event in [event.title, event.room, event.moduleCode ?? "", event.teachers.joined(separator: " "), event.groups.map(\.name).joined(separator: " "), event.type?.rawValue ?? ""].contains { $0.localizedCaseInsensitiveContains(query) } } }
    var body: some View { List(results) { event in NavigationLink(value: event) { EventCard(event: event) }.listRowSeparator(.hidden) }.listStyle(.plain).navigationTitle("Recherche").searchable(text: $query, prompt: "Matière, salle, enseignant…").navigationDestination(for: CalendarEvent.self) { EventDetailView(event: $0) } }
}
