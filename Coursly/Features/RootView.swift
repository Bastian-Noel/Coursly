import SwiftUI

enum FloatingPanel: String, Identifiable { case search, groups, date, more, changes; var id: String { rawValue } }

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
            CalendarScene(selectedEvent: $selectedEvent, panel: $panel).zIndex(0)
            if let panel { panelView(panel).transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(10) }
            FloatingControlDock(activePanel: $panel, showSettings: $showSettings, showNewEvent: $showNewEvent)
                .padding(.bottom, 8).zIndex(20)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.snappy(duration: 0.24), value: panel)
        .sheet(item: $selectedEvent) { event in CourseDetailSheet(event: event).environment(store) }
        .sheet(isPresented: $showSettings) { SettingsSheet().environment(store) }
        .sheet(isPresented: $showNewEvent) { LocalEventSheet(defaultDate: store.focusedDate).environment(store) }
        .task { await store.load(around: store.focusedDate, force: true) }
        .onChange(of: scenePhase) { _, phase in guard phase == .active else { return }; Task { await store.load(around: store.focusedDate) } }
    }

    @ViewBuilder private func panelView(_ panel: FloatingPanel) -> some View {
        switch panel {
        case .search: SearchPanel(onSelect: { event in store.goTo(event: event); self.panel = nil }, onClose: { self.panel = nil }).environment(store)
        case .groups: HierarchicalGroupPanel(onClose: { self.panel = nil }).environment(store)
        case .date: DatePanel(onClose: { self.panel = nil }).environment(store)
        case .more: MorePanel(onChanges: { self.panel = .changes }, onNewEvent: { self.panel = nil; showNewEvent = true }, onSettings: { self.panel = nil; showSettings = true }, onClose: { self.panel = nil }).environment(store)
        case .changes: ChangeHistoryPanel(onSelect: { event in store.goTo(event: event); self.panel = nil }, onClose: { self.panel = nil }).environment(store)
        }
    }
}

struct CourslyBackdrop: View {
    var body: some View { ZStack { Color(.systemBackground); LinearGradient(colors: [Color.accentColor.opacity(0.12), Color.clear, Color.indigo.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing) }.ignoresSafeArea() }
}

struct CalendarScene: View {
    @Environment(CalendarStore.self) private var store
    @Binding var selectedEvent: CalendarEvent?
    @Binding var panel: FloatingPanel?
    private var isOnToday: Bool { Calendar.current.isDate(store.focusedDate, inSameDayAs: store.now) }

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
        .simultaneousGesture(MagnifyGesture(minimumScaleDelta: 0.14).onEnded { value in
            if value.magnification < 0.88, store.displayMode == .day { store.setDisplayMode(.week) }
            else if value.magnification > 1.12, store.displayMode == .week { store.setDisplayMode(.day) }
        })
        .overlay(alignment: .top) {
            if store.simulationEnabled {
                Button { panel = .more; HapticService.fire(.panelOpened, enabled: store.hapticsEnabled) } label: {
                    Label("Simulation · \(store.now.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock.arrow.2.circlepath")
                        .font(.caption.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44).contentShape(Capsule())
                }.buttonStyle(.plain).glassEffect(.regular.tint(.orange.opacity(0.16)).interactive(), in: Capsule()).padding(.top, 58)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !isOnToday, panel == nil {
                Button { store.goToToday(); Task { await store.ensureLoaded(around: store.focusedDate) } } label: {
                    Label("Aujourd’hui", systemImage: "scope").font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 48).contentShape(Capsule())
                }.buttonStyle(.plain).glassEffect(.regular.tint(Color.accentColor.opacity(0.16)).interactive(), in: Capsule()).padding(.leading, 14).padding(.bottom, 84)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
            }
        }.animation(.snappy(duration: 0.24), value: isOnToday)
    }
}

struct CalendarHeader: View {
    @Environment(CalendarStore.self) private var store
    @Binding var panel: FloatingPanel?
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { panel = panel == .date ? nil : .date; HapticService.fire(.panelOpened, enabled: store.hapticsEnabled) } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.focusedDate.formatted(.dateTime.weekday(.wide)).capitalized).font(.title2.weight(.bold))
                    Text(store.focusedDate.formatted(.dateTime.day().month(.wide))).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                }.frame(minHeight: 48, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Choisir une date")
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                TimelineView(.periodic(from: .now, by: 30)) { context in Text(store.effectiveNow(from: context.date), style: .time).font(.headline.monospacedDigit()) }
                Text(store.selectedGroupsLabel).font(.caption).foregroundStyle(.secondary)
            }
            if store.isLoading { ProgressView().controlSize(.small).frame(width: 48, height: 48) }
            else {
                Button { HapticService.fire(.selection, enabled: store.hapticsEnabled); Task { await store.refresh() } } label: {
                    Image(systemName: "arrow.clockwise").font(.subheadline.weight(.semibold)).frame(width: 48, height: 48).contentShape(Circle())
                }.buttonStyle(.plain).glassEffect(.regular.interactive(), in: Circle()).accessibilityLabel("Actualiser")
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
        HStack(spacing: 8) {
            dockButton(title: store.displayMode == .day ? "Semaine" : "Jour", icon: store.displayMode == .day ? "calendar" : "rectangle.split.1x2") { activePanel = nil; store.setDisplayMode(store.displayMode == .day ? .week : .day) }
            dockButton(title: "Chercher", icon: "magnifyingglass", active: activePanel == .search) { toggle(.search) }
            dockButton(title: "Groupes", icon: "person.2.fill", active: activePanel == .groups, badge: store.selectedGroups.count) { toggle(.groups) }
            dockButton(title: "Plus", icon: "ellipsis", active: activePanel == .more || activePanel == .changes) { toggle(.more) }
        }.padding(.horizontal, 10).padding(.vertical, 7)
    }
    private func toggle(_ panel: FloatingPanel) { activePanel = activePanel == panel ? nil : panel; HapticService.fire(.panelOpened, enabled: store.hapticsEnabled) }
    private func dockButton(title: String, icon: String, active: Bool = false, badge: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon).font(.system(size: 16, weight: .semibold)).frame(width: 24, height: 22)
                    if let badge, badge > 0 { Text(String(badge)).font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(minWidth: 14, minHeight: 14).background(Color.accentColor, in: Circle()).offset(x: 7, y: -5) }
                }
                Text(title).font(.system(size: 9.5, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
            }.frame(minWidth: 62, minHeight: 52).padding(.horizontal, 4).contentShape(Rectangle())
        }.buttonStyle(.plain).glassEffect(active ? .regular.tint(Color.accentColor.opacity(0.18)).interactive() : .regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous)).accessibilityLabel(title).accessibilityAddTraits(active ? .isSelected : [])
    }
}
