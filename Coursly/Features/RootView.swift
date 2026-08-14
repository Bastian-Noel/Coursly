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
        .tint(Color.accentColor)
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
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(event.start.formatted(date: .omitted, time: .shortened))
                    .font(.caption.weight(.bold).monospacedDigit())
                Text(event.end.formatted(date: .omitted, time: .shortened))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46)

            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(emphasized ? .headline : .subheadline.weight(.semibold))
                        .lineLimit(2)

                    if let type = event.type {
                        Text(type.rawValue)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.tint)
                    }
                }

                if !event.room.isEmpty {
                    Label(event.room, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !event.groups.isEmpty {
                    Text(event.groups.map(\.name).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}
