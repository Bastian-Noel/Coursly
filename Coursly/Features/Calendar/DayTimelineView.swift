import SwiftUI

struct DayTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var didInitialPosition = false
    @State private var pageOffset: CGFloat = 0
    @State private var isChangingDay = false
    @GestureState private var liveDragX: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        dayPager(width: viewport.size.width)
                            .overlay(alignment: .topLeading) {
                                TimelineAnchors(prefix: "day", hourHeight: CGFloat(store.hourHeight))
                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .offset(y: TimelineAxis.y(for: store.now, hourHeight: CGFloat(store.hourHeight)))
                                    .id("day-now")
                                    .allowsHitTesting(false)
                            }
                        Color.clear
                            .frame(height: TimelineMetrics.floatingDockClearance)
                            .allowsHitTesting(false)
                    }
                }
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(daySwipe(width: viewport.size.width))
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { oldValue, newValue in
                    if didInitialPosition {
                        store.recordTopMinute(
                            TimelineAxis.minute(forContentOffset: newValue, hourHeight: CGFloat(store.hourHeight)),
                            for: .day
                        )
                        scrollFeedback(oldValue, newValue)
                    }
                }
                .task {
                    await preloadDayNeighbors()
                    guard !didInitialPosition else { return }
                    await positionOnAppearance(proxy: proxy)
                    didInitialPosition = true
                }
                .onChange(of: store.dateNavigationToken) { _, _ in
                    Task { await preloadDayNeighbors() }
                }
                .onChange(of: store.timelineScrollRequest) { _, request in
                    guard let request else { return }
                    Task { @MainActor in
                        await preloadDayNeighbors()
                        await fulfill(request, proxy: proxy, animated: true)
                    }
                }
                .onChange(of: store.highlightedEventID) { _, eventID in
                    guard let eventID,
                          let event = store.events.first(where: { $0.id == eventID }) else { return }
                    Task { @MainActor in
                        await scroll(proxy, to: TimelineAxis.anchorID(prefix: "day", minute: TimelineAxis.minute(of: event.start)), anchor: .center, animated: true)
                    }
                }
                .refreshable { await store.refresh() }
            }
        }
    }

    private func dayPager(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            dayPage(store.adjacentVisibleDate(direction: -1), width: width, highlight: nil)
                .offset(x: -width + pageOffset + liveDragX)
            dayPage(store.focusedDate, width: width, highlight: store.highlightedEventID)
                .offset(x: pageOffset + liveDragX)
            dayPage(store.adjacentVisibleDate(direction: 1), width: width, highlight: nil)
                .offset(x: width + pageOffset + liveDragX)
        }
        .frame(width: width, height: CGFloat(store.hourHeight) * 24 + 1, alignment: .topLeading)
    }

    private func dayPage(_ date: Date, width: CGFloat, highlight: String?) -> some View {
        DayTimelineCanvas(
            date: date,
            events: store.events(on: date),
            hourHeight: CGFloat(store.hourHeight),
            highlightedEventID: highlight,
            onSelect: onSelect
        )
        .frame(width: width)
    }

    private func positionOnAppearance(proxy: ScrollViewProxy) async {
        if let request = store.timelineScrollRequest {
            await fulfill(request, proxy: proxy, animated: false)
            return
        }
        if let savedMinute = store.dayTopMinute {
            await scroll(proxy, to: TimelineAxis.anchorID(prefix: "day", minute: savedMinute), anchor: .top, animated: false)
            return
        }
        if courslyCalendar.isDate(store.focusedDate, inSameDayAs: store.now) {
            await scroll(proxy, to: "day-now", anchor: .center, animated: false)
            return
        }
        let minute = store.events(on: store.focusedDate).first.map { TimelineAxis.minute(of: $0.start) } ?? 8 * 60
        await scroll(proxy, to: TimelineAxis.anchorID(prefix: "day", minute: minute), anchor: .center, animated: false)
    }

    private func fulfill(_ request: TimelineScrollRequest, proxy: ScrollViewProxy, animated: Bool) async {
        let targetID: String
        switch request.target {
        case .now:
            targetID = "day-now"
        case let .minute(minute):
            targetID = TimelineAxis.anchorID(prefix: "day", minute: minute)
        }
        await scroll(proxy, to: targetID, anchor: .center, animated: animated)
        store.consumeTimelineScrollRequest(request.id)
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: String, anchor: UnitPoint, animated: Bool) async {
        await Task.yield()
        if animated {
            withAnimation(.snappy(duration: 0.34)) { proxy.scrollTo(id, anchor: anchor) }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { proxy.scrollTo(id, anchor: anchor) }
        }
    }

    private func preloadDayNeighbors() async {
        await store.ensureLoaded(around: store.focusedDate)
        await store.ensureLoaded(around: store.adjacentVisibleDate(direction: -1))
        await store.ensureLoaded(around: store.adjacentVisibleDate(direction: 1))
    }

    private func daySwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .updating($liveDragX) { value, state, _ in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) * 1.15 else { return }
                state = max(-width, min(width, horizontal))
            }
            .onEnded { value in
                guard !isChangingDay else { return }
                let horizontal = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let effective = abs(predicted) > abs(horizontal) ? predicted : horizontal
                guard abs(effective) > 58,
                      abs(horizontal) > abs(value.translation.height) * 1.15 else {
                    withAnimation(.snappy(duration: 0.18)) { pageOffset = 0 }
                    return
                }

                let direction = effective < 0 ? 1 : -1
                isChangingDay = true
                withAnimation(.snappy(duration: 0.20)) { pageOffset = direction > 0 ? -width : width }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(190))
                    store.moveDay(direction)
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { pageOffset = 0 }
                    isChangingDay = false
                    await preloadDayNeighbors()
                }
            }
    }

    private func scrollFeedback(_ oldValue: CGFloat, _ newValue: CGFloat) {
        guard store.hapticsEnabled else { return }
        let hourHeight = CGFloat(store.hourHeight)
        let old = max(0, oldValue)
        let new = max(0, newValue)
        let low = min(old, new)
        let high = max(old, new)
        if courseBoundaryOffsets(events: store.events(on: store.focusedDate), hourHeight: hourHeight)
            .contains(where: { $0 > low && $0 <= high }) {
            HapticService.fire(.scrollCourse, enabled: true)
        } else if Int(old / hourHeight) != Int(new / hourHeight) {
            HapticService.fire(.scrollHour, enabled: true)
        }
    }
}

private struct DayTimelineCanvas: View {
    @Environment(CalendarStore.self) private var store
    let date: Date
    let events: [CalendarEvent]
    let hourHeight: CGFloat
    let highlightedEventID: String?
    let onSelect: (CalendarEvent) -> Void
    private let engine = EventLayoutEngine()

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(1, proxy.size.width - TimelineMetrics.timeColumnWidth)
            let isPastDay = courslyCalendar.startOfDay(for: date) < courslyCalendar.startOfDay(for: store.now)

            ZStack(alignment: .topLeading) {
                TimelineDayBackground(isPastDay: isPastDay)

                TimelineHourGrid(hourHeight: hourHeight)
                    .padding(.leading, TimelineMetrics.timeColumnWidth)

                TimelineTimeColumn(hourHeight: hourHeight)

                ForEach(engine.placements(for: events)) { placement in
                    let gaps = TimelineMetrics.parallelCourseGap * CGFloat(max(0, placement.columnCount - 1))
                    let lane = max(1, (contentWidth - gaps) / CGFloat(placement.columnCount))
                    let x = TimelineMetrics.timeColumnWidth + CGFloat(placement.column) * (lane + TimelineMetrics.parallelCourseGap)
                    let top = TimelineAxis.y(for: placement.event.start, hourHeight: hourHeight)
                    let bottom = TimelineAxis.y(for: placement.event.end, hourHeight: hourHeight)
                    let cardHeight = max(1, bottom - top - TimelineMetrics.courseBottomGap)

                    Button { onSelect(placement.event) } label: {
                        CourseBlock(
                            event: placement.event,
                            availableWidth: lane,
                            height: cardHeight,
                            highlighted: highlightedEventID == placement.event.id,
                            isPast: placement.event.end <= store.now
                        )
                    }
                    .buttonStyle(CoursePressButtonStyle(hapticsEnabled: store.hapticsEnabled))
                    .frame(width: lane, height: cardHeight)
                    .offset(x: x, y: top)
                }

                if courslyCalendar.isDate(date, inSameDayAs: store.now) {
                    TimelineCurrentTimeIndicator(hourHeight: hourHeight, width: contentWidth)
                        .offset(x: TimelineMetrics.timeColumnWidth)
                }
            }
        }
        .frame(height: hourHeight * 24 + 1)
    }
}
