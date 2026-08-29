import SwiftUI

struct CourseDetailSheet: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let event: CalendarEvent
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) { if let type = event.displayTypeLabel, !type.isEmpty { Text(type).font(.caption.bold()).padding(.horizontal, 9).padding(.vertical, 5).background(Color.accentColor.opacity(0.14), in: Capsule()) }; if event.source == .local { Label("Personnel", systemImage: "person.crop.circle").font(.caption.weight(.semibold)).foregroundStyle(.secondary) } }
                        Text(event.title).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                        Text(event.start.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.headline).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) { detailPill(icon: "clock", title: "\(event.start.formatted(date: .omitted, time: .shortened)) → \(event.end.formatted(date: .omitted, time: .shortened))"); detailPill(icon: "hourglass", title: durationText) }
                    VStack(spacing: 0) {
                        if !event.room.isEmpty { DetailRow(icon: "mappin.and.ellipse", title: "Salle", value: event.room) }
                        if !event.teachers.isEmpty { DetailRow(icon: "person", title: "Enseignant", value: event.teachers.joined(separator: ", ")) }
                        if !event.displayGroupLabels.isEmpty { DetailRow(icon: "person.2", title: "Groupes", value: event.displayGroupsText) }
                        if let moduleCode = event.moduleCode, !moduleCode.isEmpty { DetailRow(icon: "number", title: "Code module", value: moduleCode) }
                        if let moduleName = event.moduleName, !moduleName.isEmpty, moduleName != event.title { DetailRow(icon: "book.closed", title: "Module", value: moduleName) }
                        if let notes = event.notes, !notes.isEmpty { DetailRow(icon: "note.text", title: "Notes", value: notes) }
                    }.background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    if event.source == .local { Button(role: .destructive) { store.deleteLocalEvent(event); dismiss() } label: { Label("Supprimer l’événement", systemImage: "trash").frame(maxWidth: .infinity) }.buttonStyle(.bordered) }
                }.padding(20)
            }.navigationTitle("Cours").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    private func detailPill(icon: String, title: String) -> some View { Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 9).background(Color.secondary.opacity(0.08), in: Capsule()) }
    private var durationText: String { let minutes = Int(event.duration / 60); let hours = minutes / 60; let remaining = minutes % 60; if hours > 0, remaining > 0 { return "\(hours) h \(remaining)" }; if hours > 0 { return "\(hours) h" }; return "\(remaining) min" }
}

struct DetailRow: View {
    let icon: String; let title: String; let value: String
    var body: some View { HStack(alignment: .top, spacing: 12) { Image(systemName: icon).frame(width: 22).foregroundStyle(Color.accentColor); VStack(alignment: .leading, spacing: 2) { Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary); Text(value).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true) }; Spacer() }.padding(14) }
}
