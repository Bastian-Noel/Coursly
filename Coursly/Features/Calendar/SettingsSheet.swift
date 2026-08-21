import SwiftUI

struct SettingsSheet: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Calendrier") {
                    Picker("Week-ends", selection: Binding(get: { store.weekendPolicy }, set: { store.weekendPolicy = $0 })) { ForEach(WeekendDisplayPolicy.allCases) { policy in Text(policy.frenchTitle).tag(policy) } }
                    VStack(alignment: .leading, spacing: 8) { HStack { Text("Densité de la timeline"); Spacer(); Text("\(Int(store.hourHeight)) pt/h").foregroundStyle(.secondary) }; Slider(value: Binding(get: { store.hourHeight }, set: { store.hourHeight = $0 }), in: 64...120, step: 4) }
                }
                Section { 
                    Toggle("Me prévenir des changements", isOn: Binding(get: { store.notificationsEnabled }, set: { enabled in Task { await store.setNotificationsEnabled(enabled) } }))
                    Picker("Surveiller les prochains", selection: Binding(get: { store.notificationHorizonDays }, set: { store.notificationHorizonDays = $0 })) { ForEach([1, 3, 7, 14, 30], id: \.self) { value in Text("\(value) jour\(value > 1 ? "s" : "")").tag(value) } }
                    NavigationLink("Historique des changements") { ChangeHistorySettingsView().environment(store) }
                } header: { Text("Changements d’emploi du temps") } footer: { Text("Coursly compare uniquement deux snapshots POST CELCAT fiables. Un fallback iCal n’est jamais utilisé pour annoncer une suppression ou un déplacement.") }
                Section("Activité en direct") {
                    Toggle("Activer globalement", isOn: Binding(get: { store.liveActivityEnabled }, set: { enabled in Task { await store.setLiveActivityEnabled(enabled) } }))
                    LabeledContent("Autorisation iOS", value: store.liveActivitiesAuthorized ? "Autorisée" : "Désactivée")
                    LabeledContent("État", value: store.liveActivityIsActive ? "Active" : "Aucune activité")
                    Button { Task { await store.restartLiveActivity() } } label: { Label("Réafficher l’activité", systemImage: "rectangle.stack.badge.play") }.disabled(!store.liveActivityEnabled || !store.liveActivitiesAuthorized)
                    if store.liveActivityIsActive { Button(role: .destructive) { Task { await store.endLiveActivity() } } label: { Label("Terminer l’activité actuelle", systemImage: "xmark.circle") } }
                }
                Section("Simulation temporelle") {
                    Toggle("Simuler une autre date et heure", isOn: Binding(get: { store.simulationEnabled }, set: { enabled in store.setSimulationEnabled(enabled); Task { await store.load(around: store.focusedDate, force: true) } }))
                    if store.simulationEnabled {
                        DatePicker("Date et heure", selection: Binding(get: { store.simulationDate }, set: { value in store.simulationDate = value; Task { await store.load(around: value, force: true) } }), displayedComponents: [.date, .hourAndMinute])
                        Button("Revenir à maintenant") { store.resetSimulation(); Task { await store.load(around: store.focusedDate, force: true) } }
                    }
                }
                Section("Interactions") { Toggle("Retours haptiques", isOn: Binding(get: { store.hapticsEnabled }, set: { store.hapticsEnabled = $0 })) }
                Section("Diagnostic") {
                    LabeledContent("Dernière synchronisation", value: store.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Jamais")
                    LabeledContent("Groupes", value: store.selectedGroupsLabel); LabeledContent("Événements chargés", value: String(store.events.count))
                    LabeledContent("Fallback iCal", value: store.fallbackGroups.isEmpty ? "Non utilisé" : store.fallbackGroups.map(\.name).joined(separator: ", "))
                    if !store.failedGroups.isEmpty { LabeledContent("Groupes en erreur", value: store.failedGroups.map(\.name).joined(separator: ", ")) }
                    if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                    Button("Vérifier maintenant") { Task { await store.refresh() } }
                }
                Section("À propos") { LabeledContent("Version", value: versionText); Text("Coursly utilise le POST CELCAT comme source de vérité et iCal uniquement comme solution de secours.").font(.caption).foregroundStyle(.secondary) }
            }.navigationTitle("Réglages").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }
    }
    private var versionText: String { let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"; let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"; return "\(version) (\(build))" }
}

struct ChangeHistorySettingsView: View {
    @Environment(CalendarStore.self) private var store
    var body: some View {
        List { ForEach(store.recentChanges) { change in VStack(alignment: .leading, spacing: 4) { Label(change.kind.frenchTitle, systemImage: change.kind.symbolName).font(.caption.weight(.semibold)); Text(change.title).font(.headline); Text(change.summary).font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical, 4) }; if store.recentChanges.isEmpty { ContentUnavailableView("Aucun changement", systemImage: "checkmark.circle") } }
            .navigationTitle("Changements").toolbar { if !store.recentChanges.isEmpty { ToolbarItem(placement: .primaryAction) { Button("Effacer", role: .destructive) { store.clearChangeHistory() } } } }
    }
}
