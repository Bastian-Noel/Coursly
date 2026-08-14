import SwiftUI

struct WeekView: View {
    @Environment(CalendarStore.self) private var store
    private let calendar = Calendar(identifier: .iso8601)

    private var days: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: store.displayedInterval.start)
        }
    }

    var body: some View {
        ZStack {
            CourslyBackdrop()

            VStack(spacing: 10) {
                weekHeader

                if store.simulationEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.2.circlepath")
                        Text("Simulation : \(store.now.formatted(date: .abbreviated, time: .shortened))")
                        Spacer()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                }

                if store.isLoading && store.events.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Actualisation de la semaine…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = store.errorMessage, store.events.isEmpty {
                    ContentUnavailableView(
                        "Emploi du temps indisponible",
                        systemImage: "wifi.exclamationmark",
                        description: Text(error)
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    TimetableGrid(
                        days: days,
                        events: store.events,
                        now: store.now,
                        startHour: store.firstVisibleHour,
                        endHour: store.lastVisibleHour
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .navigationTitle("Semaine")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CalendarEvent.self) { EventDetailView(event: $0) }
    }

    private var weekHeader: some View {
        HStack(spacing: 10) {
            Button { changeWeek(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.glass)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.displayedInterval.start.formatted(.dateTime.month(.wide).year()))
                    .font(.headline.weight(.bold))
                Text("Semaine \(calendar.component(.weekOfYear, from: store.displayedInterval.start)) · \(store.selectedGroupsLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Aujourd’hui") {
                store.weekOffset = 0
                store.selectedDate = store.now
                Task { await store.load() }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.glass)

            Button { changeWeek(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.glass)
        }
    }

    private func changeWeek(_ delta: Int) {
        store.weekOffset += delta
        store.selectedDate = calendar.date(byAdding: .weekOfYear, value: delta, to: store.selectedDate) ?? store.selectedDate
        Task { await store.load() }
    }
}
