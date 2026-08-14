import SwiftUI

struct WeekView: View {
    @Environment(CalendarStore.self) private var store
    private let calendar = Calendar(identifier: .iso8601)
    private var days: [Date] { (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: store.displayedInterval.start) } }

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            HStack {
                Button { changeWeek(-1) } label: { Image(systemName: "chevron.left") }
                Spacer(); Button("Aujourd’hui") { store.weekOffset = 0; store.selectedDate = .now; Task { await store.load() } }.font(.subheadline.bold())
                Spacer(); Button { changeWeek(1) } label: { Image(systemName: "chevron.right") }
            }.padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        Button { store.selectedDate = day } label: {
                            VStack { Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption); Text(day.formatted(.dateTime.day())).font(.title3.bold()) }
                                .frame(width: 48, height: 58).background(calendar.isDate(day, inSameDayAs: store.selectedDate) ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(calendar.isDate(day, inSameDayAs: store.selectedDate) ? .white : .primary)
                        }
                    }
                }.padding()
            }
            HStack {
                Stepper("Début \(store.firstVisibleHour) h", value: $store.firstVisibleHour, in: 0...max(0, store.lastVisibleHour - 1))
                Stepper("Fin \(store.lastVisibleHour) h", value: $store.lastVisibleHour, in: min(24, store.firstVisibleHour + 1)...24)
            }.font(.caption).padding(.horizontal)
            List(store.events(on: store.selectedDate).filter { event in
                let hour = calendar.component(.hour, from: event.start)
                return hour >= store.firstVisibleHour && hour < store.lastVisibleHour
            }) { event in
                NavigationLink(value: event) { EventCard(event: event) }.listRowSeparator(.hidden)
            }.listStyle(.plain).overlay { if store.events(on: store.selectedDate).isEmpty && !store.isLoading { ContentUnavailableView("Aucun cours", systemImage: "calendar.badge.checkmark") } }
        }
        .navigationTitle(store.displayedInterval.start.formatted(.dateTime.month(.wide).year()))
        .navigationDestination(for: CalendarEvent.self) { EventDetailView(event: $0) }
    }
    private func changeWeek(_ delta: Int) { store.weekOffset += delta; store.selectedDate = calendar.date(byAdding: .weekOfYear, value: delta, to: store.selectedDate) ?? store.selectedDate; Task { await store.load() } }
}
