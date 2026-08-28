import SwiftUI

struct CourseTypeRuleSettingsView: View {
    @Environment(CalendarStore.self) private var store
    @State private var rules = CourseTypeRulePreferences.load()

    var body: some View {
        List {
            Section {
                ForEach(rules) { rule in
                    NavigationLink {
                        CourseTypeRuleEditor(rule: rule) { updated in
                            save(updated)
                        }
                    } label: {
                        ruleRow(rule)
                    }
                    .swipeActions {
                        Button("Supprimer", role: .destructive) {
                            remove(rule)
                        }
                    }
                }
                .onMove { source, destination in
                    rules.move(fromOffsets: source, toOffset: destination)
                    persist()
                }

                NavigationLink {
                    CourseTypeRuleEditor(
                        rule: CourseTypeRule(
                            type: .cm,
                            pattern: ""
                        )
                    ) { created in
                        rules.append(created)
                        persist()
                    }
                } label: {
                    Label("Ajouter une règle regex", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Règles de regroupement")
            } footer: {
                Text("La première regex active qui correspond choisit le groupe interne. Le nom CELCAT affiché n’est jamais remplacé.")
            }

            Section {
                Button("Rétablir les règles par défaut") {
                    CourseTypeRulePreferences.reset()
                    rules = CourseTypeRulePreferences.defaultRules
                    applyChanges()
                }
            }
        }
        .navigationTitle("Regroupement des types")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
    }

    private func ruleRow(_ rule: CourseTypeRule) -> some View {
        HStack(spacing: 12) {
            Text(rule.type.rawValue)
                .font(.caption.weight(.heavy))
                .foregroundStyle(rule.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 54, height: 32)
                .background(Color.accentColor.opacity(rule.isEnabled ? 0.12 : 0.04), in: Capsule())

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.pattern)
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .foregroundStyle(rule.isEnabled ? Color.primary : Color.secondary)
                Text(rule.isEnabled ? "Active" : "Désactivée")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func save(_ updated: CourseTypeRule) {
        if let index = rules.firstIndex(where: { $0.id == updated.id }) {
            rules[index] = updated
        } else {
            rules.append(updated)
        }
        persist()
    }

    private func remove(_ rule: CourseTypeRule) {
        rules.removeAll { $0.id == rule.id }
        persist()
    }

    private func persist() {
        CourseTypeRulePreferences.save(rules)
        applyChanges()
    }

    private func applyChanges() {
        store.courseTypeRulesDidChange()
        HapticService.fire(.selection, enabled: store.hapticsEnabled)
        Task { await store.restartLiveActivity() }
    }
}

private struct CourseTypeRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CourseTypeRule
    let onSave: (CourseTypeRule) -> Void

    init(rule: CourseTypeRule, onSave: @escaping (CourseTypeRule) -> Void) {
        _draft = State(initialValue: rule)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Groupe interne") {
                Picker("Type", selection: $draft.type) {
                    ForEach(CourseType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Toggle("Règle active", isOn: $draft.isEnabled)
            }

            Section {
                TextField(
                    "Expression régulière",
                    text: $draft.pattern,
                    axis: .vertical
                )
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(3...7)

                if !draft.pattern.isEmpty, !draft.isValid {
                    Label("Expression régulière invalide", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Regex")
            } footer: {
                Text("La casse et les accents sont ignorés. Exemples : \\bcm\\b ou cours\\s+magistral.")
            }

            Section {
                LabeledContent("Effet visible", value: "Aucun renommage")
                Text("La règle sert uniquement à regrouper les variantes pour leur classification et leur couleur.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Règle de type")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    onSave(draft)
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!draft.isValid)
            }
        }
    }
}
