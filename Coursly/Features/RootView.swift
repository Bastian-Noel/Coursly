import SwiftUI

struct RootView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Aujourd’hui", systemImage: "sun.max.fill") }

            NavigationStack { WeekView() }
                .tabItem { Label("Semaine", systemImage: "calendar") }

            NavigationStack { SearchView() }
                .tabItem { Label("Recherche", systemImage: "magnifyingglass") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
        .task { await store.load() }
    }
}

struct CourslyBackdrop: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.20),
                    Color.clear,
                    Color.indigo.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.cyan.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

struct EventCard: View {
    let event: CalendarEvent
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(event.title)
                    .font(emphasized ? .title3.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                if let type = event.type {
                    Text(type.rawValue)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .glassEffect(.regular.tint(Color.accentColor.opacity(0.20)), in: Capsule())
                }
            }

            HStack(spacing: 14) {
                Label(
                    event.start.formatted(date: .omitted, time: .shortened)
                    + " – "
                    + event.end.formatted(date: .omitted, time: .shortened),
                    systemImage: "clock"
                )

                if !event.room.isEmpty {
                    Label(event.room, systemImage: "location.fill")
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if !event.groups.isEmpty || !event.teachers.isEmpty {
                HStack(spacing: 8) {
                    if !event.groups.isEmpty {
                        Label(event.groups.map(\.name).joined(separator: " · "), systemImage: "person.2.fill")
                    }
                    if !event.teachers.isEmpty {
                        Text("•")
                        Text(event.teachers.joined(separator: ", "))
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(
            emphasized ? .regular.tint(Color.accentColor.opacity(0.10)).interactive() : .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
