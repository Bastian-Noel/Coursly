import SwiftUI

struct HierarchicalGroupPanel: View {
    @Environment(CalendarStore.self) private var store
    let namespace: Namespace.ID
    let onClose: () -> Void
    @State private var path: [String] = []

    private var descendants: [StudentGroup] {
        StudentGroup.all.filter { tokens(for: $0).starts(with: path) }
    }

    private var nextChoices: [String] {
        Array(Set(descendants.compactMap { group in
            let components = tokens(for: group)
            return components.indices.contains(path.count) ? components[path.count] : nil
        }))
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        FloatingPanelShell(
            title: "",
            systemImage: "person.2.fill",
            onClose: onClose,
            showsHeader: false,
            bottomInset: 8,
            matchedSurfaceID: "group-surface",
            matchedNamespace: namespace
        ) {
            if !path.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        path.removeLast()
                        HapticService.fire(.selection, enabled: store.hapticsEnabled)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Niveau précédent")

                    Text(path.joined(separator: " › "))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer()
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                if !path.isEmpty, descendants.count > 1 {
                    choiceButton(
                        title: "Tous",
                        selected: Set(store.selectedGroups) == Set(descendants)
                    ) {
                        selectAndClose(descendants)
                    }
                }

                ForEach(nextChoices, id: \.self) { choice in
                    let candidatePath = path + [choice]
                    let matching = StudentGroup.all.filter { tokens(for: $0).starts(with: candidatePath) }
                    let exact = matching.filter { tokens(for: $0).count == candidatePath.count }
                    let terminal = !exact.isEmpty && matching.count == exact.count

                    choiceButton(
                        title: displayName(choice, depth: path.count),
                        selected: terminal && Set(store.selectedGroups) == Set(exact)
                    ) {
                        if terminal {
                            selectAndClose(exact)
                        } else {
                            path.append(choice)
                            HapticService.fire(.selection, enabled: store.hapticsEnabled)
                        }
                    }
                }
            }
        }
    }

    private func choiceButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            selected
                ? .regular.tint(Color.accentColor.opacity(0.18)).interactive()
                : .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
    }

    private func selectAndClose(_ groups: [StudentGroup]) {
        guard !groups.isEmpty else { return }
        store.setSelectedGroups(groups)
        Task { await store.load(around: store.focusedDate, force: true) }
        onClose()
    }

    private func displayName(_ component: String, depth: Int) -> String {
        if depth == 0 { return component }
        if component.count == 1 { return "Groupe \(component)" }
        return component
    }

    private func tokens(for group: StudentGroup) -> [String] {
        var parts = group.name.split(separator: "-").map(String.init)
        guard let last = parts.last else { return [] }
        let letters = last.prefix { $0.isLetter }
        let digits = last.dropFirst(letters.count)
        if !letters.isEmpty,
           !digits.isEmpty,
           digits.allSatisfy(\.isNumber),
           parts.count > 1 {
            parts.removeLast()
            parts.append(String(letters))
            parts.append(String(digits))
        }
        return parts
    }
}

private extension Array where Element == String {
    func starts(with prefix: [String]) -> Bool {
        guard prefix.count <= count else { return false }
        return zip(self, prefix).allSatisfy { $0.0 == $0.1 }
    }
}
