import SwiftUI

struct LocalEventSheet: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var room = ""; @State private var start: Date; @State private var end: Date
    init(defaultDate: Date) {
        let calendar = Calendar.current; let base = calendar.date(bySettingHour: max(8, calendar.component(.hour, from: Date())), minute: 0, second: 0, of: defaultDate) ?? defaultDate
        _start = State(initialValue: base); _end = State(initialValue: base.addingTimeInterval(60 * 60))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Événement") { TextField("Titre", text: $title); TextField("Salle ou lieu (optionnel)", text: $room) }
                Section("Horaire") { DatePicker("Début", selection: $start, displayedComponents: [.date, .hourAndMinute]); DatePicker("Fin", selection: $end, in: start..., displayedComponents: [.date, .hourAndMinute]) }
            }
            .navigationTitle("Nouvel événement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Créer") { store.addLocalEvent(title: title, start: start, end: end, room: room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : room); dismiss() }.fontWeight(.semibold) }
            }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
