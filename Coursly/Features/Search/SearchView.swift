import SwiftUI

struct SearchView: View {
    @Environment(CalendarStore.self) private var store
    @State private var query = ""

    private var results: [CalendarEvent] {
        guard !query.isEmpty else { return store.events }
        return store.events.filter { event in
            [
                event.title,
                event.room,
                event.moduleCode ?? "",
                event.teachers.joined(separator: " "),
                event.groups.map(\.name).joined(separator: " "),
                event.type?.rawValue ?? ""
            ].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ZStack {
            CourslyBackdrop()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if query.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Recherche")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("Matière, salle, enseignant, groupe ou type de cours.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    }

                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 42)
                    } else {
                        ForEach(results) { event in
                            NavigationLink(value: event) {
                                EventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Recherche")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Matière, salle, enseignant…")
        .navigationDestination(for: CalendarEvent.self) { EventDetailView(event: $0) }
    }
}
