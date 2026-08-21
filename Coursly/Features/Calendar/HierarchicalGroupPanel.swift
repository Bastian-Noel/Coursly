import SwiftUI

struct HierarchicalGroupPanel: View {
    @Environment(CalendarStore.self) private var store
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
            title: "Choisir un groupe",
            systemImage: "person.2.fill",
            onClose: onClose
        ) {
            if !path.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        path.removeLast()
                        HapticService.fire(.selection, enabled: store.hapticsEnabled)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())

                    Text(path.joined(separator: "  ›  "))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer()
                }
            }

            if path.isEmpty {
                Text("Choisis d’abord la promotion, puis les sous-groupes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Choisis le sous-groupe suivant, ou « Tous » pour afficher toutes les variantes de ce niveau.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                if !path.isEmpty, descendants.count > 1 {
                    choiceButton(
                        title: "Tous",
                        subtitle: "\(descendants.count) groupes",
                        selected: Set(store.selectedGroups) == Set(descendants)
                    ) {
                        select(descendants)
                    }
                }

                ForEach(nextChoices, id: \.self) { choice in
                    let candidatePath = path + [choice]
                    let matching = StudentGroup.all.filter { tokens(for: $0).starts(with: candidatePath) }
                    let exact = matching.filter { tokens(for: $0).count == candidatePath.count }
                    let isTerminal = !exact.isEmpty && matching.count == exact.count
                    let selected = isTerminal && Set(store.selectedGroups) == Set(exact)

                    choiceButton(
                        title: displayName(choice, depth: path.count),
                        subtitle: isTerminal ? exact.first?.name : "\(matching.count) choix",
                        selected: selected
                    ) {
                        if isTerminal {
                            select(exact)
                        } else {
                            path.append(choice)
                            HapticService.fire(.selection, enabled: store.hapticsEnabled)
                        }
                    }
                }
            }

            Divider().opacity(0.35)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Affichage actuel")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.selectedGroups.map(\.name).joined(separator: " · "))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
            }

            Text("Un groupe final remplace la sélection précédente. « Tous » conserve le multi-groupes et les cours identiques restent fusionnés.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func choiceButton(
        title: String,
        subtitle: String?,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(title)
                        .font(.subheadline.weight(.bold))
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            selected
                ? .regular.tint(Color.accentColor.opacity(0.18)).interactive()
                : .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func select(_ groups: [StudentGroup]) {
        guard !groups.isEmpty else { return }
        store.setSelectedGroups(groups)
        Task { await store.load(around: store.focusedDate, force: true) }
    }

    private func displayName(_ component: String, depth: Int) -> String {
        if depth == 0 { return component }
        if component.count == 1, component.allSatisfy(\.isNumber) { return "Sous-groupe \(component)" }
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
        return zip(self, prefix).allSatisfy(==)
    }
}
