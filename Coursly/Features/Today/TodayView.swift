import SwiftUI

struct TodayView: View {
    @Environment(CalendarStore.self) private var store
    private var events: [CalendarEvent] { store.events(on: .now) }
    private var current: CalendarEvent? { events.first { $0.start <= .now && $0.end > .now } }
    private var next: CalendarEvent? { events.first { $0.start > .now } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let current { section("EN COURS", current) }
                else if let next { section("PROCHAIN COURS", next) }
                if store.isLoading { ProgressView("Actualisation…").frame(maxWidth: .infinity).padding() }
                else if let error = store.errorMessage { ContentUnavailableView("Emploi du temps indisponible", systemImage: "wifi.exclamationmark", description: Text(error)) }
                else if events.isEmpty { ContentUnavailableView("Journée libre", systemImage: "sparkles", description: Text("Aucun cours prévu aujourd’hui.")) }
                ForEach(events) { event in NavigationLink(value: event) { EventCard(event: event) }.buttonStyle(.plain) }
            }.padding()
        }
        .navigationTitle("Aujourd’hui")
        .navigationDestination(for: CalendarEvent.self) { EventDetailView(event: $0) }
        .refreshable { await store.load() }
    }
    @ViewBuilder private func section(_ label: String, _ event: CalendarEvent) -> some View {
        Text(label).font(.caption.bold()).foregroundStyle(.tint); EventCard(event: event)
    }
}
