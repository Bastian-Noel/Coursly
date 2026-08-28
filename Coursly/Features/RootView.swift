import SwiftUI

enum FloatingPanel: String, Identifiable {
    case search, groups, date, more, changes
    var id: String { rawValue }
}

struct RootView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var dockNamespace
    @State private var panel: FloatingPanel?
    @State private var selectedEvent: CalendarEvent?
    @State private var searchFilters = SearchFilters()
    @State private var showSettings = false
    @State private var showNewEvent = false

    var body: some View {
        ZStack(alignment: .bottom) {
            CourslyBackdrop()
            CalendarScene(selectedEvent: $selectedEvent, panel: $panel)
                .zIndex(0)

            FloatingControlDock(activePanel: $panel, namespace: dockNamespace)
                .offset(y: 6)
                .zIndex(20)

            if panel != nil {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.28)) {
                            panel = nil
                        }
                    }
                    .accessibilityLabel("Fermer le panneau")
                    .zIndex(30)
            }

            if let panel {
                panelView(panel)
                    .transition(panelTransition(for: panel))
                    .zIndex(40)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.snappy(duration: 0.28), value: panel)
        .preferredColorScheme(preferredColorScheme)
        .sheet(item: $selectedEvent, onDismiss: {
            store.highlightedEventID = nil
        }) { event in
            CourseDetailSheet(event: event).environment(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet().environment(store)
        }
        .sheet(isPresented: $showNewEvent) {
            LocalEventSheet(defaultDate: store.focusedDate).environment(store)
        }
        .alert(
            "Réactiver l’Activité en direct ?",
            isPresented: Binding(
                get: { store.shouldPresentLiveActivityRestorePrompt },
                set: { if !$0 { store.dismissLiveActivityRestorePrompt() } }
            )
        ) {
            Button("Plus tard", role: .cancel) {
                store.dismissLiveActivityRestorePrompt()
            }
            Button("Réactiver") {
                Task { await store.restoreLiveActivityFromPrompt() }
            }
        } message: {
            Text("Elle a été fermée alors que des cours restent aujourd’hui. Ce rappel peut être désactivé dans les réglages.")
        }
        .task {
            store.prepareForForeground()
            await store.load(around: store.focusedDate, force: true)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            store.prepareForForeground()
            Task { await store.load(around: store.focusedDate) }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.appAppearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private func panelTransition(for panel: FloatingPanel) -> AnyTransition {
        switch panel {
        case .groups, .more:
            .identity
        case .search, .date, .changes:
            .move(edge: .bottom).combined(with: .opacity)
        }
    }

    @ViewBuilder
    private func panelView(_ panel: FloatingPanel) -> some View {
        switch panel {
        case .search:
            SearchPanel(
                filters: $searchFilters,
                onSelect: { event in
                    store.goTo(event: event)
                    self.panel = nil
                },
                onClose: { self.panel = nil }
            )
            .environment(store)

        case .groups:
            HierarchicalGroupPanel(onClose: { self.panel = nil })
                .environment(store)
                .matchedGeometryEffect(id: "group-surface", in: dockNamespace)

        case .date:
            DatePanel(onClose: { self.panel = nil }).environment(store)

        case .more:
            MorePanel(
                onChanges: { self.panel = .changes },
                onNewEvent: {
                    self.panel = nil
                    showNewEvent = true
                },
                onSettings: {
                    self.panel = nil
                    showSettings = true
                },
                onClose: { self.panel = nil }
            )
            .environment(store)
            .matchedGeometryEffect(id: "more-surface", in: dockNamespace)

        case .changes:
            ChangeHistoryPanel(
                onSelect: { event in
                    store.goTo(event: event)
                    self.panel = nil
                },
                onClose: { self.panel = nil }
            )
            .environment(store)
        }
    }
}

struct CourslyBackdrop: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08), Color.clear, Color.indigo.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct CalendarScene: View {
    @Environment(CalendarStore.self) private var store
    @Binding var selectedEvent: CalendarEvent?
    @Binding var panel: FloatingPanel?

    private var isOnToday: Bool {
        Calendar.current.isDate(store.focusedDate, inSameDayAs: store.now)
    }

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeader(panel: $panel)
            Group {
                switch store.displayMode {
                case .day:
                    DayTimelineView { event in
                        store.highlightedEventID = event.id
                        selectedEvent = event
                    }
                case .week:
                    WeekTimelineView { event in
                        store.highlightedEventID = event.id
                        selectedEvent = event
                    }
                }
            }
            .environment(store)
        }
        .simultaneousGesture(
            MagnifyGesture(minimumScaleDelta: 0.14).onEnded { value in
                if value.magnification < 0.88, store.displayMode == .day {
                    store.setDisplayMode(.week)
                } else if value.magnification > 1.12, store.displayMode == .week {
                    store.setDisplayMode(.day)
                }
            }
        )
        .overlay(alignment: .bottom) {
            if !isOnToday, panel == nil {
                Button {
                    store.goToToday()
                    Task { await store.ensureLoaded(around: store.focusedDate) }
                } label: {
                    Label("Aujourd’hui", systemImage: "scope")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.16)).interactive(), in: Capsule())
                .padding(.bottom, 72)
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.snappy(duration: 0.24), value: isOnToday)
    }
}

struct CalendarHeader: View {
    @Environment(CalendarStore.self) private var store
    @Binding var panel: FloatingPanel?

    var body: some View {
        HStack(spacing: 12) {
            Button {
                panel = panel == .date ? nil : .date
                HapticService.fire(.panelOpened, enabled: store.hapticsEnabled)
            } label: {
                HStack(spacing: 10) {
                    Text(store.focusedDate.formatted(.dateTime.day()))
                        .font(.title2.monospacedDigit().weight(.bold))
                        .frame(width: 42, height: 42)
                        .background(Color.primary.opacity(0.07), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.focusedDate.formatted(.dateTime.weekday(.wide)).capitalized)
                            .font(.headline.weight(.bold))
                        Text(store.focusedDate.formatted(.dateTime.month(.wide).year()))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choisir une date")

            Spacer(minLength: 8)

            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(store.effectiveNow(from: context.date), style: .time)
                    .font(.headline.monospacedDigit().weight(.semibold))
            }

            if store.isLoading {
                ProgressView().controlSize(.small).frame(width: 44, height: 44)
            } else {
                Button {
                    HapticService.fire(.selection, enabled: store.hapticsEnabled)
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Actualiser")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background {
            TimelineDayBackground(isPastDay: false)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.secondary.opacity(0.14)).frame(height: 0.5)
        }
    }
}

struct FloatingControlDock: View {
    @Environment(CalendarStore.self) private var store
    @Binding var activePanel: FloatingPanel?
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Color.clear
                    .frame(width: 50, height: 50)
                    .allowsHitTesting(false)

                if activePanel != .more {
                    Button { toggle(.more) } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 50, height: 50)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .matchedGeometryEffect(id: "more-surface", in: namespace)
                    .accessibilityLabel("Plus d’options")
                }
            }

            ZStack {
                groupLabel
                    .opacity(0)
                    .allowsHitTesting(false)

                if activePanel != .groups {
                    Button { toggle(.groups) } label: {
                        groupLabel
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .matchedGeometryEffect(id: "group-surface", in: namespace)
                    .accessibilityLabel("Choisir les groupes, sélection actuelle \(store.selectedGroupsLabel)")
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 10)

            HStack(spacing: 0) {
                Button { toggle(.search) } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 48, height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rechercher")
                .accessibilityAddTraits(activePanel == .search ? .isSelected : [])

                Button {
                    activePanel = nil
                    store.setDisplayMode(store.displayMode == .day ? .week : .day)
                } label: {
                    Image(systemName: store.displayMode == .day ? "calendar" : "rectangle.split.1x2")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 48, height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.displayMode == .day ? "Afficher la semaine" : "Afficher le jour")
            }
            .clipShape(Capsule())
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, 18)
    }

    private var groupLabel: some View {
        Text(store.compactSelectedGroupsLabel)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 15)
            .frame(minWidth: 74, minHeight: 50)
            .contentShape(Capsule())
    }

    private func toggle(_ target: FloatingPanel) {
        activePanel = activePanel == target ? nil : target
        HapticService.fire(.panelOpened, enabled: store.hapticsEnabled)
    }
}
