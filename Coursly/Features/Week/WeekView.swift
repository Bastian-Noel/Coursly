import SwiftUI

struct WeekView: View {
    @Environment(CalendarStore.self) private var store
    private let calendar = Calendar(identifier: .iso8601)

    private var days: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: store.displayedInterval.start)
        }
    }

    private var selectedEvents: [CalendarEvent] {
        store.events(on: store.selectedDate).filter { event in
            let hour = calendar.component(.hour, from: event.start)
            return hour >= store.firstVisibleHour && hour < store.lastVisibleHour
        }
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            CourslyBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    weekHeader
                    dayStrip

                    if store.simulationEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.2.circlepath")
                            Text("Heure simulée : \(store.now.formatted(date: .abbreviated, time: .shortened))")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    }

                    visibleHours

                    if selectedEvents.isEmpty && !store.isLoading {
                        ContentUnavailableView(
                            "Aucun cours",
                            systemImage: "calendar.badge.checkmark",
                            description: Text("Rien de prévu sur cette plage horaire.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else {
                        ForEach(selectedEvents) { event in
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
        .navigationTitle("Semaine")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CalendarEvent.self) { EventDetailView(event: $0) }
    }

    private var weekHeader: some View {
        HStack(spacing: 12) {
            Button { changeWeek(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.glass)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.displayedInterval.start.formatted(.dateTime.month(.wide).year()))
                    .font(.title2.weight(.bold))
                Text("\(store.selectedGroup.name) · semaine \(calendar.component(.weekOfYear, from: store.displayedInterval.start))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { changeWeek(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.glass)
        }
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(days, id: \.self) { day in
                    let selected = calendar.isDate(day, inSameDayAs: store.selectedDate)
                    Button {
                        store.selectedDate = day
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption.weight(.semibold))
                            Text(day.formatted(.dateTime.day()))
                                .font(.title3.weight(.bold))
                        }
                        .frame(width: 48, height: 58)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    .glassEffect(
                        selected ? .regular.tint(Color.accentColor.opacity(0.18)).interactive() : .regular.interactive(),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var visibleHours: some View {
        HStack(spacing: 12) {
            Label("\(store.firstVisibleHour) h", systemImage: "sunrise")
            Spacer()
            Button("Aujourd’hui") {
                store.weekOffset = 0
                store.selectedDate = store.now
                Task { await store.load() }
            }
            .buttonStyle(.glass)
            Spacer()
            Label("\(store.lastVisibleHour) h", systemImage: "sunset")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func changeWeek(_ delta: Int) {
        store.weekOffset += delta
        store.selectedDate = calendar.date(byAdding: .weekOfYear, value: delta, to: store.selectedDate) ?? store.selectedDate
        Task { await store.load() }
    }
}
