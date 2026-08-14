import SwiftUI

struct SettingsView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Emploi du temps") {
                Picker("Groupe", selection: $store.selectedGroup) {
                    ForEach(StudentGroup.all) { group in
                        Text(group.name).tag(group)
                    }
                }
                .onChange(of: store.selectedGroup) {
                    Task { await store.load() }
                }
            }
            Section("Live Activity") {
                Label("Écran verrouillé uniquement", systemImage: "iphone")
            }
        }
        .navigationTitle("Réglages")
    }
}
