import SwiftUI

struct SettingsView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ZStack {
            CourslyBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsHeader

                    SettingsGlassSection(title: "GROUPES AFFICHÉS", systemImage: "person.3") {
                        VStack(spacing: 10) {
                            ForEach(StudentGroup.all) { group in
                                Toggle(
                                    group.name,
                                    isOn: Binding(
                                        get: { store.isGroupSelected(group) },
                                        set: { enabled in
                                            store.setGroup(group, enabled: enabled)
                                            Task { await store.load() }
                                        }
                                    )
                                )
                                .font(.subheadline.weight(.medium))
                            }
                        }

                        Text("Au moins un groupe reste toujours sélectionné. Les cours identiques sont fusionnés visuellement ; les conflits restent côte à côte dans la grille.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SettingsGlassSection(title: "AFFICHAGE DE LA GRILLE", systemImage: "calendar.day.timeline.left") {
                        VStack(spacing: 12) {
                            Stepper("Début : \(store.firstVisibleHour) h", value: $store.firstVisibleHour, in: 0...max(0, store.lastVisibleHour - 1))
                            Stepper("Fin : \(store.lastVisibleHour) h", value: $store.lastVisibleHour, in: min(24, store.firstVisibleHour + 1)...24)
                        }
                        .font(.subheadline)

                        Text("La ligne rouge indique l’heure actuelle, ou l’heure simulée lorsque la simulation est active.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SettingsGlassSection(title: "SIMULATION TEMPORELLE", systemImage: "clock.arrow.2.circlepath") {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle("Simuler une autre date et heure", isOn: $store.simulationEnabled)
                                .font(.body.weight(.medium))
                                .onChange(of: store.simulationEnabled) {
                                    store.weekOffset = 0
                                    store.selectedDate = store.now
                                    Task { await store.load() }
                                }

                            if store.simulationEnabled {
                                Divider().opacity(0.35)

                                DatePicker(
                                    "Date et heure simulées",
                                    selection: Binding(
                                        get: { store.now },
                                        set: { newValue in
                                            store.simulationDate = newValue
                                            store.weekOffset = 0
                                            store.selectedDate = newValue
                                        }
                                    ),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .onChange(of: store.simulationOffset) {
                                    Task { await store.load() }
                                }

                                Text("L’horloge simulée continue ensuite d’avancer normalement.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button {
                                    store.resetSimulation()
                                    Task { await store.load() }
                                } label: {
                                    Label("Revenir à la date et l’heure réelles", systemImage: "arrow.counterclockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }

                    SettingsGlassSection(title: "ACTIVITÉ EN DIRECT", systemImage: "iphone") {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.display")
                                .font(.title3)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Écran verrouillé uniquement")
                                    .font(.body.weight(.medium))
                                Text("Aucune Dynamic Island dans cette version.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    SettingsGlassSection(title: "À PROPOS", systemImage: "info.circle") {
                        LabeledContent("Version", value: versionLabel)
                        LabeledContent("Application", value: "Coursly")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionLabel: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—"
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Coursly")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Choisis tes groupes, ajuste la grille et simule une autre date pour tester l’emploi du temps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsGlassSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
