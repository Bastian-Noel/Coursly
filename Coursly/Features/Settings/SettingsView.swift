import SwiftUI

struct SettingsView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ZStack {
            CourslyBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    settingsHeader

                    SettingsGlassSection(title: "EMPLOI DU TEMPS", systemImage: "calendar") {
                        Picker("Groupe", selection: $store.selectedGroup) {
                            ForEach(StudentGroup.all) { group in
                                Text(group.name).tag(group)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: store.selectedGroup) {
                            Task { await store.load() }
                        }
                    }

                    SettingsGlassSection(title: "SIMULATION TEMPORELLE", systemImage: "clock.arrow.2.circlepath") {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle("Simuler une autre date", isOn: $store.simulationEnabled)
                                .font(.body.weight(.medium))
                                .onChange(of: store.simulationEnabled) {
                                    store.weekOffset = 0
                                    store.selectedDate = store.now
                                    Task { await store.load() }
                                }

                            if store.simulationEnabled {
                                Divider().opacity(0.35)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date et heure simulées")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

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
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .onChange(of: store.simulationOffset) {
                                        Task { await store.load() }
                                    }
                                }

                                HStack {
                                    Image(systemName: "waveform.path.ecg")
                                        .foregroundStyle(.orange)
                                    Text("L’horloge continue d’avancer normalement à partir de ce décalage.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    store.resetSimulation()
                                    Task { await store.load() }
                                } label: {
                                    Label("Revenir à maintenant", systemImage: "arrow.counterclockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }

                    SettingsGlassSection(title: "LIVE ACTIVITY", systemImage: "iphone") {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.display")
                                .font(.title3)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Écran verrouillé uniquement")
                                    .font(.body.weight(.medium))
                                Text("Pas de Dynamic Island dans la V2.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    SettingsGlassSection(title: "À PROPOS", systemImage: "info.circle") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("0.2.0")
                                .foregroundStyle(.secondary)
                        }
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

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Coursly")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Personnalise ton emploi du temps et simule n’importe quel moment pour tester l’app.")
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
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
