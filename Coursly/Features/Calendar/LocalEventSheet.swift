import SwiftUI

struct LocalEventSheet: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var typeLabel = ""
    @State private var room = ""
    @State private var teacherDraft = ""
    @State private var teachers: [String] = []
    @State private var notes = ""
    @State private var start: Date
    @State private var end: Date

    init(defaultDate: Date) {
        let calendar = Calendar.current
        let base = calendar.date(bySettingHour: max(8, calendar.component(.hour, from: Date())), minute: 0, second: 0, of: defaultDate) ?? defaultDate
        _start = State(initialValue: base)
        _end = State(initialValue: base.addingTimeInterval(60 * 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Événement") {
                    SuggestedTextField(title: "Titre", text: $title, suggestions: store.knownTitles)
                    SuggestedTextField(title: "Type (optionnel)", text: $typeLabel, suggestions: store.knownTypeLabels)
                }

                Section("Lieu") {
                    SuggestedTextField(title: "Salle ou lieu", text: $room, suggestions: store.knownRooms)
                }

                Section {
                    if !teachers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(teachers, id: \.self) { teacher in
                                    Button { teachers.removeAll { $0 == teacher } } label: {
                                        HStack(spacing: 5) {
                                            Text(teacher).lineLimit(1)
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                        }
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 10).frame(minHeight: 34)
                                        .background(Color.accentColor.opacity(0.10), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    TextField("Ajouter un enseignant", text: $teacherDraft)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { addTeacher(teacherDraft) }

                    SuggestionStrip(values: filtered(store.knownTeachers, for: teacherDraft)) { addTeacher($0) }
                } header: {
                    Text("Enseignants")
                } footer: {
                    Text("Écris un nom puis valide, ou touche une proposition connue.")
                }

                Section("Horaire") {
                    DatePicker("Début", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Fin", selection: $end, in: start..., displayedComponents: [.date, .hourAndMinute])
                }

                Section("Notes") {
                    TextField("Informations complémentaires", text: $notes, axis: .vertical)
                        .lineLimit(3...7)
                }
            }
            .navigationTitle("Nouvel événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        if !teacherDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { addTeacher(teacherDraft) }
                        store.addLocalEvent(
                            title: title, typeLabel: typeLabel, start: start, end: end,
                            room: room, teachers: teachers, notes: notes
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func addTeacher(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if !teachers.contains(where: { $0.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) { teachers.append(cleaned) }
        teacherDraft = ""
    }

    private func filtered(_ values: [String], for query: String) -> [String] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        return Array(values.filter { $0.localizedCaseInsensitiveContains(cleaned) && !teachers.contains($0) }.prefix(8))
    }
}

private struct SuggestedTextField: View {
    let title: String
    @Binding var text: String
    let suggestions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField(title, text: $text)
                .textInputAutocapitalization(.sentences)
            SuggestionStrip(values: filtered) { text = $0 }
        }
    }

    private var filtered: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(suggestions.filter {
            $0.localizedCaseInsensitiveContains(query) && $0.localizedCaseInsensitiveCompare(query) != .orderedSame
        }.prefix(8))
    }
}

private struct SuggestionStrip: View {
    let values: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !values.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(values, id: \.self) { value in
                        Button(value) { onSelect(value) }
                            .font(.caption.weight(.medium))
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                    }
                }
            }
        }
    }
}

