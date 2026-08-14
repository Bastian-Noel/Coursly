import SwiftUI

struct TodayView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let virtualNow = store.now
            let events = store.events(on: virtualNow)
            let current = events.first { $0.start <= virtualNow && $0.end > virtualNow }
            let next = events.first { $0.start > virtualNow }

            ZStack {
                CourslyBackdrop()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        header(now: virtualNow)

                        if store.simulationEnabled {
                            simulationBanner(now: virtualNow)
                        }

                        if let current {
                            focusCard(label: "EN COURS", event: current, now: virtualNow)
                        } else if let next {
                            focusCard(label: "PROCHAIN COURS", event: next, now: virtualNow)
                        }

                        stateContent(events: events)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 110)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .refreshable { await store.load() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Coursly")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(store.selectedGroup.name)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .glassEffect(.regular, in: Capsule())
                }
            }
            .navigationDestination(for: CalendarEvent.self) { EventDetailView(event: $0) }
        }
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("Aujourd’hui")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .tracking(-1)

            Text(now.formatted(date: .omitted, time: .shortened))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func simulationBanner(now: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text("Simulation active")
                    .font(.subheadline.weight(.semibold))
                Text(now.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .glassEffect(
            .regular.tint(Color.orange.opacity(0.16)),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private func focusCard(label: String, event: CalendarEvent, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.tint)
                    .tracking(0.7)
                Spacer()
                temporalLabel(for: event, now: now)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            NavigationLink(value: event) {
                EventCard(event: event, emphasized: true)
            }
            .buttonStyle(.plain)

            if event.start <= now && event.end > now {
                ProgressView(value: progress(for: event, now: now))
                    .progressViewStyle(.linear)
            }
        }
    }

    @ViewBuilder
    private func stateContent(events: [CalendarEvent]) -> some View {
        if store.isLoading && events.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Actualisation de l’emploi du temps…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
        } else if let error = store.errorMessage, events.isEmpty {
            ContentUnavailableView(
                "Emploi du temps indisponible",
                systemImage: "wifi.exclamationmark",
                description: Text(error)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else if events.isEmpty {
            ContentUnavailableView(
                "Journée libre",
                systemImage: "sparkles",
                description: Text("Aucun cours prévu pour cette journée.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            Text("LA JOURNÉE")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .padding(.top, 2)

            ForEach(events) { event in
                NavigationLink(value: event) {
                    EventCard(event: event)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func progress(for event: CalendarEvent, now: Date) -> Double {
        guard event.duration > 0 else { return 0 }
        return min(max(now.timeIntervalSince(event.start) / event.duration, 0), 1)
    }

    private func temporalLabel(for event: CalendarEvent, now: Date) -> Text {
        if now < event.start {
            let minutes = max(0, Int(event.start.timeIntervalSince(now) / 60))
            return Text("dans \(minutes) min")
        }
        let minutes = max(0, Int(event.end.timeIntervalSince(now) / 60))
        return Text("\(minutes) min restantes")
    }
}
