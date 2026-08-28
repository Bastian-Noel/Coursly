import SwiftUI

struct FloatingPanelShell<Content: View>: View {
    let title: String
    let systemImage: String
    let onClose: () -> Void
    var showsHeader = true
    var widthFraction: CGFloat = 1
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                HStack {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .accessibilityLabel("Fermer")
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: 620)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .modifier(FloatingPanelWidth(fraction: widthFraction))
        .padding(.horizontal, 12)
        .padding(.bottom, 82)
    }
}

struct GroupPanel: View {
    @Environment(CalendarStore.self) private var store
    let onClose: () -> Void

    var body: some View {
        FloatingPanelShell(title: "Groupes affichés", systemImage: "person.2.fill", onClose: onClose) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(StudentGroup.all) { group in
                        Button {
                            let enabled = !store.isGroupSelected(group)
                            store.setGroup(group, enabled: enabled)
                            Task { await store.load(around: store.focusedDate, force: true) }
                        } label: {
                            HStack {
                                Image(systemName: store.isGroupSelected(group) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(store.isGroupSelected(group) ? Color.accentColor : Color.secondary)
                                Text(group.name).font(.subheadline.weight(.medium))
                                Spacer()
                            }
                            .frame(minHeight: 48)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 360)

            Text("Les cours identiques sont fusionnés. Les conflits restent côte à côte dans la timeline.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SearchPanel: View {
    @Environment(CalendarStore.self) private var store
    @Binding var filters: SearchFilters
    let onSelect: (CalendarEvent) -> Void
    let onClose: () -> Void

    private var results: [CalendarEvent] { store.search(filters) }
    private var facets: SearchFacets { store.searchFacets }

    var body: some View {
        FloatingPanelShell(title: "Recherche", systemImage: "magnifyingglass", onClose: onClose) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Matière, prof, salle, module…", text: $filters.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !filters.query.isEmpty {
                    Button {
                        filters.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Effacer la recherche")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    facetMenu(title: "Matières", icon: "book.closed", values: facets.subjects, selection: $filters.subjects)
                    facetMenu(title: "Profs", icon: "person", values: facets.teachers, selection: $filters.teachers)
                    facetMenu(title: "Salles", icon: "mappin.and.ellipse", values: facets.rooms, selection: $filters.rooms)
                    facetMenu(title: "Groupes", icon: "person.2", values: facets.groups, selection: $filters.groups)
                    typeMenu
                    facetMenu(title: "Modules", icon: "number", values: facets.modules, selection: $filters.modules)
                }
            }

            HStack {
                Text("\(results.count) résultat\(results.count > 1 ? "s" : "")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if filters.hasFacets || !filters.query.isEmpty {
                    Button("Effacer") { filters = SearchFilters() }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(results.prefix(40)) { event in
                        Button { onSelect(event) } label: {
                            SearchResultRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                    if results.isEmpty {
                        ContentUnavailableView(
                            "Aucun cours",
                            systemImage: "magnifyingglass",
                            description: Text("Essaie de retirer un filtre ou de modifier la recherche.")
                        )
                        .frame(height: 170)
                    }
                }
            }
            .frame(maxHeight: 310)
        }
    }

    private func facetMenu(title: String, icon: String, values: [String], selection: Binding<Set<String>>) -> some View {
        Menu {
            if values.isEmpty {
                Text("Aucune valeur disponible")
            } else {
                ForEach(values, id: \.self) { value in
                    Button {
                        var current = selection.wrappedValue
                        if current.contains(value) { current.remove(value) }
                        else { current.insert(value) }
                        selection.wrappedValue = current
                        HapticService.fire(.selection, enabled: store.hapticsEnabled)
                    } label: {
                        Label(value, systemImage: selection.wrappedValue.contains(value) ? "checkmark.circle.fill" : "circle")
                    }
                }
                if !selection.wrappedValue.isEmpty {
                    Divider()
                    Button("Tout décocher") { selection.wrappedValue = [] }
                }
            }
        } label: {
            Label(selection.wrappedValue.isEmpty ? title : "\(title) · \(selection.wrappedValue.count)", systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .frame(minHeight: 44)
                .background(selection.wrappedValue.isEmpty ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.14), in: Capsule())
                .contentShape(Capsule())
        }
    }

    private var typeMenu: some View {
        Menu {
            ForEach(facets.types, id: \.self) { type in
                Button {
                    if filters.types.contains(type) { filters.types.remove(type) }
                    else { filters.types.insert(type) }
                    HapticService.fire(.selection, enabled: store.hapticsEnabled)
                } label: {
                    Label(type, systemImage: filters.types.contains(type) ? "checkmark.circle.fill" : "circle")
                }
            }
            if !filters.types.isEmpty {
                Divider()
                Button("Tout décocher") { filters.types = [] }
            }
        } label: {
            Label(filters.types.isEmpty ? "Types" : "Types · \(filters.types.count)", systemImage: "tag")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .frame(minHeight: 44)
                .background(filters.types.isEmpty ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.14), in: Capsule())
                .contentShape(Capsule())
        }
    }
}

struct SearchResultRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let type = event.type {
                        Text(type.rawValue).font(.caption2.bold()).foregroundStyle(.secondary)
                    }
                    Text(event.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                Text(event.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !event.room.isEmpty {
                Text(event.room).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
            }
            Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct DatePanel: View {
    @Environment(CalendarStore.self) private var store
    let onClose: () -> Void

    var body: some View {
        FloatingPanelShell(title: "Choisir une date", systemImage: "calendar", onClose: onClose) {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { store.focusedDate },
                    set: { newDate in
                        store.goToDate(newDate)
                        Task { await store.ensureLoaded(around: newDate) }
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            Button {
                store.goToToday()
                onClose()
            } label: {
                Label("Revenir à aujourd’hui", systemImage: "scope")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct MorePanel: View {
    @Environment(CalendarStore.self) private var store
    let onChanges: () -> Void
    let onNewEvent: () -> Void
    let onSettings: () -> Void
    let onClose: () -> Void

    var body: some View {
        FloatingPanelShell(
            title: "",
            systemImage: "line.3.horizontal",
            onClose: onClose,
            showsHeader: false,
            widthFraction: 0.70
        ) {
            Button(action: onClose) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 36, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Replier les options")

            VStack(spacing: 2) {
                actionRow("Nouvel événement", icon: "plus.circle.fill", action: onNewEvent)
                actionRow("Changements", icon: "arrow.triangle.2.circlepath", action: onChanges)
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.16))
                .frame(height: 0.5)

            VStack(spacing: 2) {
                quickToggle(
                    "Activité en direct",
                    icon: "rectangle.stack.badge.play",
                    isOn: Binding(
                        get: { store.liveActivityEnabled },
                        set: { enabled in Task { await store.setLiveActivityEnabled(enabled) } }
                    )
                )
                quickToggle(
                    "Retours haptiques",
                    icon: "hand.tap",
                    isOn: Binding(
                        get: { store.hapticsEnabled },
                        set: { store.hapticsEnabled = $0 }
                    )
                )
                if store.simulationEnabled {
                    actionRow("Heure réelle", icon: "clock.arrow.circlepath") {
                        store.resetSimulation()
                        Task { await store.load(around: store.focusedDate, force: true) }
                        HapticService.fire(.returnedToNow, enabled: store.hapticsEnabled)
                    }
                }
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.16))
                .frame(height: 0.5)

            actionRow("Tous les réglages", icon: "gearshape.fill", action: onSettings)

            if !store.fallbackGroups.isEmpty {
                Label("Données de secours actives", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func actionRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 22)
                Text(title).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func quickToggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
        }
        .frame(minHeight: 46)
        .tint(.accentColor)
    }
}

struct ChangeHistoryPanel: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void
    let onClose: () -> Void

    var body: some View {
        FloatingPanelShell(title: "Changements récents", systemImage: "arrow.triangle.2.circlepath", onClose: onClose) {
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(store.recentChanges.prefix(60)) { change in
                        Button {
                            if let event = change.event { onSelect(event) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: change.kind.symbolName)
                                    .foregroundStyle(color(for: change.kind))
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(change.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(change.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                    Text(change.detectedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 4)
                            }
                            .frame(minHeight: 52)
                            .padding(.horizontal, 10)
                            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if store.recentChanges.isEmpty {
                        ContentUnavailableView(
                            "Aucun changement détecté",
                            systemImage: "checkmark.circle",
                            description: Text("Coursly compare les snapshots POST CELCAT fiables.")
                        )
                        .frame(height: 190)
                    }
                }
            }
            .frame(maxHeight: 360)

            if !store.recentChanges.isEmpty {
                Button(role: .destructive) { store.clearChangeHistory() } label: {
                    Text("Effacer l’historique").frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func color(for kind: CalendarChangeKind) -> Color {
        switch kind {
        case .added: return Color.green
        case .removed: return Color.red
        case .moved: return Color.orange
        case .modified: return Color.blue
        }
    }
}

private struct FloatingPanelWidth: ViewModifier {
    let fraction: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if fraction < 0.99 {
            content
                .containerRelativeFrame(.horizontal) { length, _ in
                    min(420, length * fraction)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content
                .frame(maxWidth: .infinity)
        }
    }
}
