import SwiftUI

struct CourseTypeRuleSettingsView: View {
    @Environment(CalendarStore.self) private var store
    @State private var groups = CourseTypeRulePreferences.load()

    var body: some View {
        List {
            Section {
                ForEach(groups) { group in
                    NavigationLink {
                        CourseTypeGroupEditor(group: group) { save($0) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: group.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                                .font(.title3)
                                .foregroundStyle(group.isEnabled ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.name).font(.body.weight(.semibold))
                                Text(summary(for: group)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button("Supprimer", role: .destructive) {
                            guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
                            delete(at: IndexSet(integer: index))
                        }
                    }
                }
                .onDelete(perform: delete)
                .onMove { groups.move(fromOffsets: $0, toOffset: $1); persist() }

                NavigationLink {
                    CourseTypeGroupEditor(group: CourseTypeGroup(name: "", patterns: [])) { created in
                        groups.append(created); persist()
                    }
                } label: {
                    Label("Créer un regroupement", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Regroupements")
            } footer: {
                Text("Le nom identifie le regroupement dans les réglages et les couleurs. Si le renommage est activé, ce même nom remplace aussi le libellé CELCAT sur les cours.")
            }

            Section {
                Button("Rétablir les regroupements par défaut") {
                    CourseTypeRulePreferences.reset()
                    groups = CourseTypeRulePreferences.defaultRules
                    CourseTypeRulePreferences.save(groups)
                    applyChanges()
                }
            }
        }
        .navigationTitle("Regroupement des types")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func summary(for group: CourseTypeGroup) -> String {
        let count = group.patterns.count
        if group.displayLabel != nil { return "\(count) expression\(count > 1 ? "s" : "") · affiche le nom du regroupement" }
        return "\(count) expression\(count > 1 ? "s" : "") · aucun renommage"
    }

    private func delete(at offsets: IndexSet) {
        groups.remove(atOffsets: offsets)
        persist()
    }

    private func save(_ group: CourseTypeGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) { groups[index] = group }
        else { groups.append(group) }
        persist()
    }

    private func persist() {
        CourseTypeRulePreferences.save(groups)
        applyChanges()
    }

    private func applyChanges() {
        store.courseTypeRulesDidChange()
        HapticService.fire(.selection, enabled: store.hapticsEnabled)
        Task { await store.restartLiveActivity() }
    }
}

private enum PatternBuilderMode: String, CaseIterable, Identifiable {
    case contains = "Contient"
    case word = "Mot exact"
    case starts = "Commence"
    case ends = "Se termine"
    case regex = "Regex libre"
    var id: String { rawValue }

    func pattern(for value: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: value.trimmingCharacters(in: .whitespacesAndNewlines))
        return switch self {
        case .contains: escaped
        case .word: #"\b"# + escaped + #"\b"#
        case .starts: "^" + escaped
        case .ends: escaped + "$"
        case .regex: value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

private struct CourseTypeGroupEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CourseTypeGroup
    @State private var mode: PatternBuilderMode = .contains
    @State private var builderText = ""
    @State private var testText = ""
    @State private var renameEnabled: Bool
    let onSave: (CourseTypeGroup) -> Void

    init(group: CourseTypeGroup, onSave: @escaping (CourseTypeGroup) -> Void) {
        _draft = State(initialValue: group)
        _renameEnabled = State(initialValue: group.trimmedRename != nil)
        self.onSave = onSave
    }

    private var builtPattern: String { mode.pattern(for: builderText) }
    private var canAdd: Bool { !builderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && CourseTypeGroup.isValid(pattern: builtPattern) }
    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.patterns.isEmpty
            && draft.patterns.allSatisfy { CourseTypeGroup.isValid(pattern: $0) }
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $draft.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Regroupement actif").font(.headline)
                        Text(draft.isEnabled ? "Les expressions sont utilisées" : "Aucune expression n’est appliquée").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tint(.accentColor)

                TextField("Nom du regroupement", text: $draft.name)
            } header: {
                Text("Organisation")
            }

            Section {
                if draft.patterns.isEmpty {
                    ContentUnavailableView("Aucune expression", systemImage: "text.magnifyingglass", description: Text("Ajoute les formulations qui doivent être regroupées."))
                } else {
                    ForEach(Array(draft.patterns.enumerated()), id: \.offset) { index, pattern in
                        HStack(spacing: 10) {
                            Image(systemName: "text.magnifyingglass").foregroundStyle(.secondary)
                            Text(pattern).font(.caption.monospaced()).textSelection(.enabled)
                            Spacer()
                            Button(role: .destructive) { draft.patterns.remove(at: index) } label: {
                                Image(systemName: "minus.circle.fill").frame(width: 34, height: 34)
                            }.buttonStyle(.plain)
                        }
                    }
                    .onMove { draft.patterns.move(fromOffsets: $0, toOffset: $1) }
                }
            } header: {
                HStack { Text("Expressions reconnues"); Spacer(); Text("\(draft.patterns.count)").foregroundStyle(.secondary) }
            }

            Section {
                Picker("Façon de reconnaître", selection: $mode) {
                    ForEach(PatternBuilderMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)

                TextField(mode == .regex ? "Expression régulière" : "Texte à reconnaître", text: $builderText, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(mode == .regex ? .body.monospaced() : .body)

                if !builderText.isEmpty {
                    LabeledContent("Expression créée") {
                        Text(builtPattern).font(.caption.monospaced()).foregroundStyle(canAdd ? Color.secondary : Color.red).lineLimit(2)
                    }
                }

                Button {
                    draft.patterns.append(builtPattern)
                    builderText = ""
                } label: {
                    Label("Ajouter cette expression", systemImage: "plus.circle.fill")
                }
                .disabled(!canAdd)
            } header: {
                Text("Ajouter sans écrire de regex")
            } footer: {
                Text("Choisis une règle simple et Coursly construit l’expression. « Regex libre » reste disponible pour les cas avancés.")
            }

            Section {
                Toggle("Utiliser ce nom sur les cours", isOn: $renameEnabled)
                    .onChange(of: renameEnabled) { _, enabled in if !enabled { draft.displayRename = nil } }
            } header: {
                Text("Renommage optionnel")
            } footer: {
                Text("Activé, le nom du regroupement ci-dessus devient le libellé affiché. Désactivé, le texte CELCAT reste inchangé.")
            }

            Section("Essayer la règle") {
                TextField("Exemple de type reçu", text: $testText)
                if !testText.isEmpty {
                    Label(
                        draft.matches(testText) ? "Cet exemple correspond" : "Aucune correspondance",
                        systemImage: draft.matches(testText) ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .foregroundStyle(draft.matches(testText) ? Color.green : Color.secondary)
                }
            }
        }
        .navigationTitle(draft.name.isEmpty ? "Nouveau regroupement" : draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.displayRename = renameEnabled ? draft.name : nil
                    onSave(draft); dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
    }
}
