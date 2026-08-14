import SwiftUI

struct RootView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        TabView {
            NavigationStack { TodayView() }.tabItem { Label("Aujourd’hui", systemImage: "sun.max") }
            NavigationStack { WeekView() }.tabItem { Label("Semaine", systemImage: "calendar") }
            NavigationStack { SearchView() }.tabItem { Label("Recherche", systemImage: "magnifyingglass") }
            NavigationStack { SettingsView() }.tabItem { Label("Réglages", systemImage: "gearshape") }
        }
        .task { await store.load() }
    }
}

struct EventCard: View {
    let event: CalendarEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(event.title).font(.headline); Spacer(); if let type = event.type { Text(type.rawValue).font(.caption.bold()).padding(.horizontal, 7).padding(.vertical, 4).background(.tint.opacity(0.14), in: Capsule()) } }
            Label(event.start.formatted(date: .omitted, time: .shortened) + " – " + event.end.formatted(date: .omitted, time: .shortened), systemImage: "clock")
            if !event.room.isEmpty { Label(event.room, systemImage: "mappin.and.ellipse") }
            Text(event.groups.map(\.name).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
            if !event.teachers.isEmpty { Text(event.teachers.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
        }.padding().background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }
}
