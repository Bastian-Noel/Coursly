import SwiftUI

struct SettingsSheet: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Emploi du temps") {
                    LabeledContent("Groupes affichés", value: store.compactSelectedGroupsLabel)
                    NavigationLink {
                        CalendarAppearanceSettingsView().environment(store)
                    } label: {
                        Label("Affichage et jours", systemImage: "calendar.day.timeline.left")
                    }
                    NavigationLink {
                        LiveActivityColorSettingsView().environment(store)
                    } label: {
                        Label("Couleurs des cours", systemImage: "paintpalette.fill")
                    }
                }

                Section("Alertes") {
                    NavigationLink {
                        ChangeTrackingSettingsView().environment(store)
                    } label: {
                        Label("Changements et statuts", systemImage: "bell.badge")
                    }
                    NavigationLink {
                        LiveActivitySettingsView().environment(store)
                    } label: {
                        Label("Activité en direct", systemImage: "rectangle.stack.badge.play")
                    }
                }

                Section("Apparence et interactions") {
                    Picker("Apparence", selection: Binding(
                        get: { store.appAppearance },
                        set: { store.appAppearance = $0 }
                    )) {
                        ForEach(AppAppearancePreference.allCases) { preference in
                            Text(preference.frenchTitle).tag(preference)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Toggle("Retours haptiques", isOn: Binding(
                        get: { store.hapticsEnabled },
                        set: { store.hapticsEnabled = $0 }
                    ))
                }

                Section("Avancé") {
                    NavigationLink {
                        SimulationSettingsView().environment(store)
                    } label: {
                        Label("Date et heure simulées", systemImage: "clock.arrow.2.circlepath")
                    }
                    NavigationLink {
                        CourseTypeRuleSettingsView().environment(store)
                    } label: {
                        Label("Regroupement des types", systemImage: "text.badge.checkmark")
                    }
                    NavigationLink {
                        DiagnosticSettingsView().environment(store)
                    } label: {
                        Label("Données et diagnostic", systemImage: "wrench.and.screwdriver")
                    }
                }

                Section("À propos") {
                    LabeledContent("Version", value: versionText)
                }
            }
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}

private struct CalendarAppearanceSettingsView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        Form {
            Section("Jours affichés") {
                Picker("Week-ends", selection: Binding(
                    get: { store.weekendPolicy },
                    set: { store.weekendPolicy = $0 }
                )) {
                    ForEach(WeekendDisplayPolicy.allCases) { policy in
                        Text(policy.frenchTitle).tag(policy)
                    }
                }
            }

            Section("Densité") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hauteur d’une heure")
                        Spacer()
                        Text("\(Int(store.hourHeight)) pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { store.hourHeight },
                            set: { store.hourHeight = $0 }
                        ),
                        in: 64...120,
                        step: 4
                    )
                }
            }

        }
        .navigationTitle("Affichage et jours")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChangeTrackingSettingsView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        Form {
            Section("Surveillance") {
                Toggle("Me prévenir des changements", isOn: Binding(
                    get: { store.notificationsEnabled },
                    set: { enabled in Task { await store.setNotificationsEnabled(enabled) } }
                ))
                Picker("Période surveillée", selection: Binding(
                    get: { store.notificationHorizonDays },
                    set: { store.notificationHorizonDays = $0 }
                )) {
                    ForEach([1, 3, 7, 14, 30], id: \.self) { value in
                        Text("\(value) jour\(value > 1 ? "s" : "")").tag(value)
                    }
                }
            }

            Section("Statuts notifiés") {
                ForEach(CalendarChangeKind.allCases, id: \.self) { kind in
                    Toggle(kind.frenchTitle, isOn: Binding(
                        get: { store.isNotificationKindEnabled(kind) },
                        set: { store.setNotificationKind(kind, enabled: $0) }
                    ))
                }
            }

            Section {
                NavigationLink("Historique") {
                    ChangeHistorySettingsView().environment(store)
                }
            } footer: {
                Text("Les changements reposent uniquement sur deux snapshots POST CELCAT fiables.")
            }
        }
        .navigationTitle("Changements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LiveActivitySettingsView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        Form {
            Section("Activation") {
                Toggle("Activité en direct", isOn: Binding(
                    get: { store.liveActivityEnabled },
                    set: { enabled in Task { await store.setLiveActivityEnabled(enabled) } }
                ))
                Toggle("Proposer de la réactiver si fermée", isOn: Binding(
                    get: { store.liveActivityRestorePromptEnabled },
                    set: { store.liveActivityRestorePromptEnabled = $0 }
                ))
                .disabled(!store.liveActivityEnabled)
            }

            Section("État") {
                LabeledContent("Autorisation iOS", value: store.liveActivitiesAuthorized ? "Autorisée" : "Désactivée")
                LabeledContent("Activité", value: store.liveActivityIsActive ? "Active" : "Aucune")
            }

            Section {
                Button {
                    Task { await store.restartLiveActivity() }
                } label: {
                    Label("Réafficher maintenant", systemImage: "rectangle.stack.badge.play")
                }
                .disabled(!store.liveActivityEnabled || !store.liveActivitiesAuthorized)

                if store.liveActivityIsActive {
                    Button(role: .destructive) {
                        Task { await store.endLiveActivity() }
                    } label: {
                        Label("Terminer l’activité actuelle", systemImage: "xmark.circle")
                    }
                }
            } footer: {
                Text("Si l’activité est fermée alors qu’un cours reste aujourd’hui, Coursly peut proposer sa réactivation à la prochaine ouverture.")
            }
        }
        .navigationTitle("Activité en direct")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SimulationSettingsView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        Form {
            Section {
                Toggle("Simuler une autre date et heure", isOn: Binding(
                    get: { store.simulationEnabled },
                    set: { enabled in
                        store.setSimulationEnabled(enabled)
                        Task { await store.load(around: store.focusedDate, force: true) }
                    }
                ))

                if store.simulationEnabled {
                    DatePicker("Date et heure", selection: Binding(
                        get: { store.simulationDate },
                        set: { value in
                            store.simulationDate = value
                            Task { await store.load(around: value, force: true) }
                        }
                    ), displayedComponents: [.date, .hourAndMinute])

                    Button("Revenir à maintenant") {
                        store.resetSimulation()
                        Task { await store.load(around: store.focusedDate, force: true) }
                    }
                }
            } footer: {
                Text("La simulation modifie la logique temporelle, jamais les horaires CELCAT affichés.")
            }
        }
        .navigationTitle("Simulation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DiagnosticSettingsView: View {
    @Environment(CalendarStore.self) private var store
    @State private var isChecking = false
    @State private var checkFinishedAt: Date?

    var body: some View {
        Form {
            Section("Synchronisation") {
                LabeledContent("Dernière", value: store.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Jamais")
                LabeledContent("Groupes", value: store.selectedGroupsLabel)
                LabeledContent("Cours chargés", value: String(store.events.count))
                LabeledContent("Source affichée", value: store.isUsingCachedEvents ? "Dernière copie locale" : "CELCAT à jour")
                LabeledContent("Fallback iCal", value: store.fallbackGroups.isEmpty ? "Non utilisé" : store.fallbackGroups.map(\.name).joined(separator: ", "))
            }

            if !store.failedGroups.isEmpty || store.errorMessage != nil {
                Section("Erreurs") {
                    if !store.failedGroups.isEmpty {
                        LabeledContent("Groupes", value: store.failedGroups.map(\.name).joined(separator: ", "))
                    }
                    if let error = store.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }

            Section {
                Button {
                    guard !isChecking else { return }
                    isChecking = true
                    Task {
                        await store.load(around: store.focusedDate, force: true)
                        checkFinishedAt = Date()
                        isChecking = false
                        HapticService.fire(store.errorMessage == nil ? .success : .error, enabled: store.hapticsEnabled)
                    }
                } label: {
                    HStack {
                        Label(isChecking ? "Vérification…" : "Vérifier maintenant", systemImage: "arrow.clockwise")
                        Spacer()
                        if isChecking { ProgressView().controlSize(.small) }
                    }
                }
                .disabled(isChecking)

                if let date = checkFinishedAt {
                    Label(
                        store.errorMessage == nil ? "Vérifié à \(date.formatted(date: .omitted, time: .shortened))" : "Vérification terminée avec une erreur",
                        systemImage: store.errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(store.errorMessage == nil ? Color.green : Color.red)
                }
            }
        }
        .navigationTitle("Diagnostic")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChangeHistorySettingsView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        List {
            ForEach(store.recentChanges) { change in
                VStack(alignment: .leading, spacing: 4) {
                    Label(change.kind.frenchTitle, systemImage: change.kind.symbolName)
                        .font(.caption.weight(.semibold))
                    Text(change.title).font(.headline)
                    Text(change.summary).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            if store.recentChanges.isEmpty {
                ContentUnavailableView("Aucun changement", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("Changements")
        .toolbar {
            if !store.recentChanges.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Effacer", role: .destructive) { store.clearChangeHistory() }
                }
            }
        }
    }
}
