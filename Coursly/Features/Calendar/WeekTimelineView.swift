import SwiftUI

struct WeekTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var days: [Date] = []
    @State private var horizontalDayID: String?
    @State private var programmaticHorizontalDayID: String?
    @State private var verticalPosition = ScrollPosition(edge: .top)
    @State private var verticalScrollState = TimelineVerticalScrollState()
    @State private var pendingRequestID: UUID?
    @State private var currentVerticalOffset: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            let dayWidth = max(1, (viewport.size.width - TimelineMetrics.timeColumnWidth) / 5)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        TimelineTimeColumn(
                            hourHeight: CGFloat(store.hourHeight),
                            headerHeight: TimelineMetrics.weekHeaderHeight
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    WeekDayColumn(
                                        day: day,
                                        events: store.events(on: day),
                                        now: store.now,
                                        hourHeight: CGFloat(store.hourHeight),
                                        width: dayWidth,
                                        stickyHeaderOffset: TimelineAxis.pinnedHeaderOffset(forContentOffset: currentVerticalOffset),
                                        highlightedEventID: store.highlightedEventID,
                                        onSelect: onSelect
                                    )
                                    .frame(width: dayWidth)
                                    .id(timelineDayID(day))
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollPosition(id: $horizontalDayID, anchor: .leading)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .onChange(of: horizontalDayID) { _, newID in
                            guard let newID,
                                  let day = days.first(where: { timelineDayID($0) == newID }) else { return }
                            if programmaticHorizontalDayID == newID {
                                programmaticHorizontalDayID = nil
                            } else {
                                store.setFocusedDateFromTimeline(day)
                            }
                            extendWindowIfNeeded(around: day)
                            Task { await preloadFiveDays(startingAt: day) }
                        }
                    }
                    .frame(height: TimelineMetrics.weekHeaderHeight + CGFloat(store.hourHeight) * 24 + 1)
                    .overlay(alignment: .topLeading) {
                        TimelineCurrentTimeIndicator(
                            hourHeight: CGFloat(store.hourHeight),
                            width: viewport.size.width,
                            leadingDot: false
                        )
                        .offset(y: TimelineMetrics.weekHeaderHeight)
                        .zIndex(30)
                    }

                    Color.clear
                        .frame(height: TimelineMetrics.floatingDockClearance)
                        .allowsHitTesting(false)
                }
            }
            .scrollPosition($verticalPosition)
            .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y) } action: { oldValue, newValue in
                currentVerticalOffset = newValue
                guard verticalScrollState.observe(offset: newValue) else { return }
                completeVerticalPosition(oldOffset: oldValue, newOffset: newValue)
            }
            .task {
                await configureInitialWindow(viewportHeight: viewport.size.height)
            }
            .onChange(of: store.dateNavigationToken) { _, _ in
                Task { @MainActor in
                    await navigateHorizontally(to: store.focusedDate)
                }
            }
            .onChange(of: store.timelineScrollRequest) { _, request in
                guard let request else { return }
                fulfill(request, viewportHeight: viewport.size.height, animated: true)
            }
            .refreshable { await store.refresh() }
        }
    }

    private func configureInitialWindow(viewportHeight: CGFloat) async {
        guard days.isEmpty else { return }
        let first = firstVisibleDay(containing: store.focusedDate)
        days = makeWindow(around: first, radius: 120)
        let initialID = timelineDayID(first)
        programmaticHorizontalDayID = initialID
        horizontalDayID = initialID
        await preloadFiveDays(startingAt: first)

        guard !verticalScrollState.isUserControlled,
              verticalScrollState.expectedOffset == nil else { return }
        if let request = store.timelineScrollRequest {
            fulfill(request, viewportHeight: viewportHeight, animated: false)
        } else if let savedMinute = store.weekTopMinute {
            beginScroll(minute: savedMinute, anchor: .top, viewportHeight: viewportHeight, animated: false)
        } else {
            let visibleDays = fiveVisibleDays(startingAt: first)
            let firstCourseMinute = visibleDays
                .flatMap { store.events(on: $0) }
                .map { TimelineAxis.minute(of: $0.start) }
                .min() ?? 8 * 60
            beginScroll(minute: firstCourseMinute, anchor: .top, viewportHeight: viewportHeight, animated: false)
        }
    }

    private func navigateHorizontally(to date: Date) async {
        let first = firstVisibleDay(containing: date)
        if !days.contains(where: { courslyCalendar.isDate($0, inSameDayAs: first) }) {
            days = makeWindow(around: first, radius: 120)
        }
        await preloadFiveDays(startingAt: first)
        let targetID = timelineDayID(first)
        programmaticHorizontalDayID = targetID
        withAnimation(.snappy(duration: 0.32)) {
            horizontalDayID = targetID
        }
    }

    private func fulfill(_ request: TimelineScrollRequest, viewportHeight: CGFloat, animated: Bool) {
        let minute: Int
        switch request.target {
        case .now: minute = TimelineAxis.minute(of: store.now)
        case let .minute(value): minute = value
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
            headerHeight: TimelineMetrics.weekHeaderHeight,
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
            TimelineAxis.minute(
                forContentOffset: newOffset,
                headerHeight: TimelineMetrics.weekHeaderHeight,
                hourHeight: CGFloat(store.hourHeight)
            ),
            for: .week
        )
        if let requestID = pendingRequestID {
            store.consumeTimelineScrollRequest(requestID)
            pendingRequestID = nil
        }
        weekScrollFeedback(oldOffset, newOffset)
    }

    private func preloadFiveDays(startingAt start: Date) async {
        await store.ensureLoaded(around: start)
        await store.ensureLoaded(around: advanceVisibleDay(from: start, count: 4))
    }

    private func extendWindowIfNeeded(around day: Date) {
        guard let index = days.firstIndex(where: { courslyCalendar.isDate($0, inSameDayAs: day) }) else { return }
        if index < 24, let first = days.first {
            var cursor = first
            var prefix: [Date] = []
            for _ in 0..<90 {
                cursor = store.adjacentVisibleDate(from: cursor, direction: -1)
                prefix.append(cursor)
            }
            days.insert(contentsOf: prefix.reversed(), at: 0)
        } else if index > days.count - 25, let last = days.last {
            var cursor = last
            var suffix: [Date] = []
            for _ in 0..<90 {
                cursor = store.adjacentVisibleDate(from: cursor, direction: 1)
                suffix.append(cursor)
            }
            days.append(contentsOf: suffix)
        }
    }

    private func makeWindow(around center: Date, radius: Int) -> [Date] {
        var before: [Date] = []
        var after: [Date] = []
        var left = courslyCalendar.startOfDay(for: center)
        var right = left
        for _ in 0..<radius {
            left = store.adjacentVisibleDate(from: left, direction: -1)
            right = store.adjacentVisibleDate(from: right, direction: 1)
            before.append(left)
            after.append(right)
        }
        return Array(before.reversed()) + [courslyCalendar.startOfDay(for: center)] + after
    }

    private func firstVisibleDay(containing date: Date) -> Date {
        store.visibleWeekDays(containing: date).first ?? courslyCalendar.startOfDay(for: date)
    }

    private func advanceVisibleDay(from date: Date, count: Int) -> Date {
        var result = date
        for _ in 0..<count { result = store.adjacentVisibleDate(from: result, direction: 1) }
        return result
    }

    private func fiveVisibleDays(startingAt start: Date) -> [Date] {
        var result = [start]
        var cursor = start
        while result.count < 5 {
            cursor = store.adjacentVisibleDate(from: cursor, direction: 1)
            result.append(cursor)
        }
        return result
    }

    private func weekScrollFeedback(_ oldValue: CGFloat, _ newValue: CGFloat) {
        guard store.hapticsEnabled else { return }
        let hourHeight = CGFloat(store.hourHeight)
        let old = max(0, oldValue - TimelineMetrics.weekHeaderHeight)
        let new = max(0, newValue - TimelineMetrics.weekHeaderHeight)
        if Int(old / hourHeight) != Int(new / hourHeight) {
            HapticService.fire(.scrollHour, enabled: true)
        }
    }
}

private struct WeekDayColumn: View {
    @Environment(CalendarStore.self) private var store
    let day: Date
    let events: [CalendarEvent]
    let now: Date
    let hourHeight: CGFloat
    let width: CGFloat
    let stickyHeaderOffset: CGFloat
    let highlightedEventID: String?
    let onSelect: (CalendarEvent) -> Void
    private let engine = EventLayoutEngine()

    var body: some View {
        let isPastDay = courslyCalendar.startOfDay(for: day) < courslyCalendar.startOfDay(for: now)
        let isToday = courslyCalendar.isDate(day, inSameDayAs: now)

        VStack(spacing: 0) {
            WeekDayHeader(
                day: day,
                isPastDay: isPastDay,
                isToday: isToday,
                isPinned: stickyHeaderOffset > 1
            )
            .offset(y: stickyHeaderOffset)
            .zIndex(20)

            ZStack(alignment: .topLeading) {
                TimelineDayBackground(isPastDay: isPastDay)
                TimelineHourGrid(hourHeight: hourHeight)

                ForEach(engine.placements(for: events)) { placement in
                    let gaps = TimelineMetrics.parallelCourseGap * CGFloat(max(0, placement.columnCount - 1))
                    let lane = max(1, (width - gaps) / CGFloat(placement.columnCount))
                    let x = CGFloat(placement.column) * (lane + TimelineMetrics.parallelCourseGap)
                    let top = TimelineAxis.y(for: placement.event.start, hourHeight: hourHeight)
                    let bottom = TimelineAxis.y(for: placement.event.end, hourHeight: hourHeight)
                    let cardHeight = max(1, bottom - top - TimelineMetrics.weekCourseBottomGap)

                    Button { onSelect(placement.event) } label: {
                        CourseBlock(
                            event: placement.event,
                            availableWidth: lane,
                            height: cardHeight,
                            highlighted: highlightedEventID == placement.event.id,
                            weekLayout: true,
                            isPast: placement.event.end <= now
                        )
                    }
                    .buttonStyle(CoursePressButtonStyle(hapticsEnabled: store.hapticsEnabled))
                    .frame(width: lane, height: cardHeight)
                    .offset(x: x, y: top)
                }

                if isToday {
                    TimelineCurrentTimeIndicator(
                        hourHeight: hourHeight,
                        width: width,
                        leadingDot: true,
                        showsLine: false
                    )
                }
            }
            .frame(height: hourHeight * 24 + 1)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.secondary.opacity(0.14)).frame(width: 0.5).allowsHitTesting(false)
        }
    }
}

private struct WeekDayHeader: View {
    let day: Date
    let isPastDay: Bool
    let isToday: Bool
    let isPinned: Bool

    var body: some View {
        VStack(spacing: 1) {
            Text(capitalizedWeekday(day).uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(day.formatted(.dateTime.day()))
                .font(.title3.monospacedDigit().weight(.bold))
                .frame(minWidth: 30, minHeight: 30)
                .background(isToday ? Color.primary.opacity(0.08) : Color.clear, in: Circle())
        }
        .frame(maxWidth: .infinity, minHeight: TimelineMetrics.weekHeaderHeight, maxHeight: TimelineMetrics.weekHeaderHeight)
        .foregroundStyle(isPastDay ? Color.secondary : Color.primary)
        .background {
            TimelineDayBackground(isPastDay: isPastDay)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isToday ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.16))
                .frame(height: isToday ? 2 : 0.5)
        }
        .shadow(color: .black.opacity(isPinned ? 0.07 : 0), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
    }
}
