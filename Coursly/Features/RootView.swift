import SwiftUI

enum FloatingPanel: String, Identifiable {
    case search, groups, date, more, changes
    var id: String { rawValue }
}

struct RootView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var panel: FloatingPanel?
    @State private var selectedEvent: CalendarEvent?
    @State private var showSettings = false
    @State private var showNewEvent = false

    var body: some View {
        ZStack(alignment: .bottom) {
            CourslyBackdrop()
            CalendarScene(selectedEvent: $selectedEvent, panel: $panel)
            if let panel { panelView(panel).transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(3) }
            FloatingControlDock(activePanel: $panel, showSettings: $showSettings, showNewEvent: $showNewEvent).zIndex(4)
        }
        .animation(.snappy(duration: 0.24), value: panel)
        .sheet(item: $selectedEvent) { event in CourseDetailSheet(event: event).environment(store) }
        .sheet(isPresented: $showSettings) { SettingsSheet().environment(store) }
        .sheet(isPresented: $showNewEvent) { LocalEventSheet(defaultDate: store.focusedDate).environment(store) }
        .task { await store.load(around: store.focusedDate, force: true) }
        .onChange(of: scenePhase) { _, phase in guard phase == .active else { return }; Task { await store.load(around: store.focusedDate) } }
    }

    @ViewBuilder private func panelView(_ panel: FloatingPanel) -> some View {
        switch panel {
        case .search:
            SearchPanel(onSelect: { event in store.goTo(event: event); self.panel = nil }, onClose: { self.panel = nil }).environment(store)
        case .groups:
            GroupPanel(onClose: { self.panel = nil }).environment(store)
        case .date:
            DatePanel(onClose: { self.panel = nil }).environment(store)
        case .more:
            MorePanel(onChanges: { self.panel = .changes }, onNewEvent: { self.panel = nil; showNewEvent = true }, onSettings: { self.panel = nil; showSettings = true }, onClose: { self.panel = nil }).environment(store)
        case .changes:
            ChangeHistoryPanel(onSelect: { event in store.goTo(event: event); self.panel = nil }, onClose: { self.panel = nil }).environment(store)
        }
    }
}

struct CourslyBackdrop: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [Color.accentColor.opacity(0.12), Color.clear, Color.indigo.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }.ignoresSafeArea()
    }
}

struct CalendarScene: View {
    @Environment(CalendarStore.self) private var store
    @Binding var selectedEvent: CalendarEvent?
    @Binding var panel: FloatingPanel?

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeader(panel: $panel).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
            Group {
                switch store.displayMode {
                case .day: DayTimelineView { event in selectedEvent = event; HapticService.fire(.courseOpened, enabled: store.hapticsEnabled) }
                case .week: WeekTimelineView { event in selectedEvent = event; HapticService.fire(.courseOpened, enabled: store.hapticsEnabled) }
                }
            }.environment(store)
        }
        .safeAreaPadding(.bottom, 76)
        .overlay(alignment: .top) {
            if store.simulationEnabled {
                Button { panel = .more; HapticService.fire(.panelOpened, enabled: store.hapticsEnabled) } label: {
                    Label("Simulation · \(store.now.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock.arrow.2.circlepath").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.orange.opacity(0.16)).interactive(), in: Capsule())
                .padding(.top, 58)
            }
        }
    }
}

struct CalendarHeader: View {
    @Environment(CalendarStore.self) private var store
    @Binding var panel: FloatingPanel?
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { panel = panel == .date ? nil : .date; HapticService.fire(.panelOpened, enabled: store.hapticsEnabled) } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.focusedDate.formatted(.dateTime.weekday(.wide))).font(.title2.weight(.bold))
                    Text(store.focusedDate.formatted(.dateTime.day().month(.wide))).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                TimelineView(.periodic(from: .now, by: 30)) { context in Text(store.effectiveNow(from: context.date), style: .time).font(.headline.monospacedDigit()) }
                Text(store.selectedGroupsLabel).font(.caption).foregroundStyle(.secondary)
            }
            if store.isLoading { ProgressView().controlSize(.small) }
            else {
                Button { Task { await store.refresh() }; HapticService.fire(.selection, enabled: store.hapticsEnabled) } label: { Image(systemName: "arrow.clockwise").font(.subheadline.weight(.semibold)).frame(width: 34, height: 34) }
                    .buttonStyle(.plain).glassEffect(.regular.interactive(), in: Circle()).accessibilityLabel("Actualiser")
            }
        }
    }
}

struct FloatingControlDock: View {
    @Environment(CalendarStore.self) private var store
    @Binding var activePanel: FloatingPanel?
    @Binding var showSettings: Bool
    @Binding var showNewEvent: Bool
    var body: some View {
        HStack(spacing: 10) {
            dockButton(title: store.displayMode == .day ? "Aujourd’hui" : "Maintenant", icon: "scope") { store.goToToday(); Task { await store.ensureLoaded(around: store.focusedDate) } }
            dockButton(title: store.displayMode == .day ? "1J" : "5J", icon: store.displayMode == .day ? "rectangle.split.1x2" : "calendar") { store.setDisplayMode(store.displayMode == .day ? .week : .day) }
            dockButton(title: "Recherche", icon: "magnifyingglass", active: activePanel == .search) { toggle(.search) }
            dockButton(title: "\(store.selectedGroups.count)", icon: "person.2.fill", active: activePanel == .groups) { toggle(.groups) }
            dockButton(title: "Plus", icon: "ellipsis", active: activePanel == .more || activePanel == .changes) { toggle(.more) }
        }.padding(.horizontal, 12).padding(.bottom, 6)
    }
    private func toggle(_ panel: FloatingPanel) { activePanel = activePanel == panel ? nil : panel; HapticService.fire(.panelOpened, enabled: store.hapticsEnabled) }
    private func dockButton(title: String, icon: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) { Image(systemName: icon).font(.subheadline.weight(.semibold)); if active || title.count <= 3 { Text(title).font(.caption.weight(.semibold)).lineLimit(1) } }
                .frame(minWidth: 34, minHeight: 40).padding(.horizontal, active ? 10 : 5)
        }
        .buttonStyle(.plain)
        .glassEffect(active ? .regular.tint(Color.accentColor.opacity(0.18)).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityLabel(title)
    }
}
