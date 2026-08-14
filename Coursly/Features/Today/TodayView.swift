import SwiftUI

struct TodayView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let virtualNow = store.now
            let day = Calendar.current.startOfDay(for: virtualNow)
            let events = store.events(on: virtualNow)
            let current = events.first { $0.start <= virtualNow && $0.end > virtualNow }
            let next = events.first { $0.start > virtualNow }

            ZStack {
                CourslyBackdrop()

                VStack(spacing: 10) {
                    header(now: virtualNow, current: current, next: next)

                    if store.simulationEnabled {
                        simulationBanner(now: virtualNow)
                    }

                    if store.isLoading && events.isEmpty {
                        loadingState
                    } else if let error = store.errorMessage, events.isEmpty {
                        ContentUnavailableView(
                            "Emploi du temps indisponible",
                            systemImage: "wifi.exclamationmark",
                            description: Text(error)
                        )
                        .frame(maxHeight: .infinity)
                    } else if events.isEmpty {
                        ContentUnavailableView(
                            "Journée libre",
                            systemImage: "sparkles",
                            description: Text("Aucun cours prévu pour cette journée.")
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        TimetableGrid(
                            days: [day],
                            events: events,
                            now: virtualNow,
                            startHour: store.firstVisibleHour,
                            endHour: store.lastVisibleHour
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Coursly")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(store.selectedGroupsLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: Capsule())
                }
            }
            .navigationDestination(for: CalendarEvent.self) { EventDetailView(event: $0) }
            .refreshable { await store.load() }
        }
    }

    private func header(now: Date, current: CalendarEvent?, next: CalendarEvent?) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("Aujourd’hui")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
            }

            Spacer(minLength: 8)

            if let current {
                statusPill(title: "En cours", detail: current.room.isEmpty ? current.title : current.room)
            } else if let next {
                statusPill(title: "Prochain", detail: next.start.formatted(date: .omitted, time: .shortened))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusPill(title: String, detail: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: Capsule())
    }

    private func simulationBanner(now: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.2.circlepath")
            Text("Simulation : \(now.formatted(date: .abbreviated, time: .shortened))")
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)
        .padding(.horizontal, 10)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Actualisation de l’emploi du temps…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
