import SwiftUI

struct DayTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var verticalPosition = ScrollPosition(edge: .top)
    @State private var verticalScrollState = TimelineVerticalScrollState()
    @State private var pendingRequestID: UUID?
    @State private var currentVerticalOffset: CGFloat = 0
    @State private var pageOffset: CGFloat = 0
    @State private var isChangingDay = false
    @State private var suppressCourseSelection = false
    @GestureState private var liveDragX: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    dayPager(width: viewport.size.width)
                    Color.clear
                        .frame(height: TimelineMetrics.floatingDockClearance)
                        .allowsHitTesting(false)
                }
            }
            .scrollPosition($verticalPosition)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(daySwipe(width: viewport.size.width))
            .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y) } action: { oldValue, newValue in
                currentVerticalOffset = newValue
                guard verticalScrollState.observe(offset: newValue) else { return }
                completeVerticalPosition(oldOffset: oldValue, newOffset: newValue)
            }
            .task {
                await preloadDayNeighbors()
                guard !verticalScrollState.isUserControlled,
                      verticalScrollState.expectedOffset == nil else { return }
                positionOnAppearance(viewportHeight: viewport.size.height)
            }
            .onChange(of: store.dateNavigationToken) { _, _ in
                Task { await preloadDayNeighbors() }
            }
            .onChange(of: store.timelineScrollRequest) { _, request in
                guard let request else { return }
                Task { @MainActor in
                    await preloadDayNeighbors()
                    fulfill(request, viewportHeight: viewport.size.height, animated: true)
                }
            }
            .refreshable { await store.refresh() }
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
            suppressCourseSelection: suppressCourseSelection,
            onSelect: onSelect
        )
        .frame(width: width)
    }

    private func positionOnAppearance(viewportHeight: CGFloat) {
        if let request = store.timelineScrollRequest {
            fulfill(request, viewportHeight: viewportHeight, animated: false)
            return
        }
        if let savedMinute = store.dayTopMinute {
            beginScroll(minute: savedMinute, anchor: .top, viewportHeight: viewportHeight, animated: false)
            return
        }
        if oraCalendar.isDate(store.focusedDate, inSameDayAs: store.now) {
            beginScroll(
                minute: TimelineAxis.minute(of: store.now),
                anchor: .center,
                viewportHeight: viewportHeight,
                animated: false
            )
            return
        }
        let minute = store.events(on: store.focusedDate).first.map { TimelineAxis.minute(of: $0.start) } ?? 8 * 60
        beginScroll(minute: minute, anchor: .center, viewportHeight: viewportHeight, animated: false)
    }

    private func fulfill(_ request: TimelineScrollRequest, viewportHeight: CGFloat, animated: Bool) {
        let minute: Int
        switch request.target {
        case .now:
            minute = TimelineAxis.minute(of: store.now)
        case let .minute(minute):
            self.pendingRequestID = request.id
            beginScroll(minute: minute, anchor: .center, viewportHeight: viewportHeight, animated: animated)
            return
        }
        pendingRequestID = request.id
        beginScroll(minute: minute, anchor: .center, viewportHeight: viewportHeight, animated: animated)
    }

    private func beginScroll(
        minute: Int,
        anchor: TimelineVerticalAnchor,
        viewportHeight: CGFloat,
        animated: Bool
    ) {
        let offset = TimelineAxis.contentOffset(
            forMinute: minute,
            anchor: anchor,
            hourHeight: CGFloat(store.hourHeight),
            viewportHeight: viewportHeight
        )
        verticalScrollState.beginRestoration(to: offset)
        if verticalScrollState.observe(offset: currentVerticalOffset) {
            completeVerticalPosition(oldOffset: currentVerticalOffset, newOffset: currentVerticalOffset)
            return
        }
        if animated {
            withAnimation(.snappy(duration: 0.34)) { verticalPosition.scrollTo(y: offset) }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { verticalPosition.scrollTo(y: offset) }
        }
    }

    private func completeVerticalPosition(oldOffset: CGFloat, newOffset: CGFloat) {
        store.recordTopMinute(
            TimelineAxis.minute(forContentOffset: newOffset, hourHeight: CGFloat(store.hourHeight)),
            for: .day
        )
        if let requestID = pendingRequestID {
            store.consumeTimelineScrollRequest(requestID)
            pendingRequestID = nil
        }
        scrollFeedback(oldOffset, newOffset)
    }

    private func preloadDayNeighbors() async {
        await store.ensureLoaded(around: store.focusedDate)
        await store.ensureLoaded(around: store.adjacentVisibleDate(direction: -1))
        await store.ensureLoaded(around: store.adjacentVisibleDate(direction: 1))
    }

    private func daySwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                if CourseInteractionGate.isHorizontalNavigation(value.translation) {
                    suppressCourseSelection = true
                }
            }
            .updating($liveDragX) { value, state, _ in
                let horizontal = value.translation.width
                guard CourseInteractionGate.isHorizontalNavigation(value.translation) else { return }
                state = max(-width, min(width, horizontal))
            }
            .onEnded { value in
                guard !isChangingDay else { return }
                let horizontal = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let effective = abs(predicted) > abs(horizontal) ? predicted : horizontal
                guard abs(effective) > 58,
                      CourseInteractionGate.isHorizontalNavigation(value.translation) else {
                    withAnimation(.snappy(duration: 0.18)) { pageOffset = 0 }
                    releaseCourseSelectionGate()
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
                    suppressCourseSelection = false
                }
            }
    }

    private func releaseCourseSelectionGate() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            suppressCourseSelection = false
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
    let suppressCourseSelection: Bool
    let onSelect: (CalendarEvent) -> Void
    private let engine = EventLayoutEngine()

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(1, proxy.size.width - TimelineMetrics.timeColumnWidth)
            let isPastDay = oraCalendar.startOfDay(for: date) < oraCalendar.startOfDay(for: store.now)

            ZStack(alignment: .topLeading) {
                TimelineDayBackground(isPastDay: isPastDay, pastEmphasis: .day)

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

                    Button {
                        guard !suppressCourseSelection else { return }
                        onSelect(placement.event)
                    } label: {
                        CourseBlock(
                            event: placement.event,
                            availableWidth: lane,
                            height: cardHeight,
                            highlighted: highlightedEventID == placement.event.id,
                            isPast: placement.event.end <= store.now
                        )
                    }
                    .buttonStyle(CoursePressButtonStyle(
                        hapticsEnabled: store.hapticsEnabled,
                        interactionEnabled: !suppressCourseSelection
                    ))
                    .frame(width: lane, height: cardHeight)
                    .offset(x: x, y: top)
                }

                if oraCalendar.isDate(date, inSameDayAs: store.now) {
                    TimelineCurrentTimeIndicator(hourHeight: hourHeight, width: contentWidth)
                        .offset(x: TimelineMetrics.timeColumnWidth)
                }
            }
        }
        .frame(height: hourHeight * 24 + 1)
    }
}
