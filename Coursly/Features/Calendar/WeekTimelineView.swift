import SwiftUI

struct WeekTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var days: [Date] = []
    @State private var horizontalDayID: String?
    @State private var didInitialPosition = false

    var body: some View {
        GeometryReader { viewport in
            let dayWidth = max(1, (viewport.size.width - TimelineMetrics.timeColumnWidth) / 5)

            ScrollViewReader { verticalProxy in
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
                                store.setFocusedDateFromTimeline(day)
                                extendWindowIfNeeded(around: day)
                                Task { await preloadFiveDays(startingAt: day) }
                            }
                        }
                        .frame(height: TimelineMetrics.weekHeaderHeight + CGFloat(store.hourHeight) * 24 + 1)
                        .overlay(alignment: .topLeading) {
                            TimelineAnchors(
                                prefix: "week",
                                hourHeight: CGFloat(store.hourHeight),
                                headerHeight: TimelineMetrics.weekHeaderHeight
                            )
                        }

                        Color.clear
                            .frame(height: TimelineMetrics.floatingDockClearance)
                            .allowsHitTesting(false)
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { oldValue, newValue in
                    if didInitialPosition {
                        store.recordTopMinute(
                            TimelineAxis.minute(
                                forContentOffset: newValue,
                                headerHeight: TimelineMetrics.weekHeaderHeight,
                                hourHeight: CGFloat(store.hourHeight)
                            ),
                            for: .week
                        )
                        weekScrollFeedback(oldValue, newValue)
                    }
                }
                .task {
                    await configureInitialWindow(proxy: verticalProxy)
                }
                .onChange(of: store.dateNavigationToken) { _, _ in
                    Task { @MainActor in
                        await navigateHorizontally(to: store.focusedDate)
                    }
                }
                .onChange(of: store.timelineScrollRequest) { _, request in
                    guard let request else { return }
                    Task { @MainActor in
                        await fulfill(request, proxy: verticalProxy, animated: true)
                    }
                }
                .refreshable { await store.refresh() }
            }
        }
    }

    private func configureInitialWindow(proxy: ScrollViewProxy) async {
        guard days.isEmpty else { return }
        let first = firstVisibleDay(containing: store.focusedDate)
        days = makeWindow(around: first, radius: 120)
        horizontalDayID = timelineDayID(first)
        await preloadFiveDays(startingAt: first)

        guard !didInitialPosition else { return }
        if let request = store.timelineScrollRequest {
            await fulfill(request, proxy: proxy, animated: false)
        } else if let savedMinute = store.weekTopMinute {
            await scroll(proxy, minute: savedMinute, anchor: .top, animated: false)
        } else {
            let visibleDays = fiveVisibleDays(startingAt: first)
            let firstCourseMinute = visibleDays
                .flatMap { store.events(on: $0) }
                .map { TimelineAxis.minute(of: $0.start) }
                .min() ?? 8 * 60
            await scroll(proxy, minute: firstCourseMinute, anchor: .top, animated: false)
        }
        didInitialPosition = true
    }

    private func navigateHorizontally(to date: Date) async {
        let first = firstVisibleDay(containing: date)
        if !days.contains(where: { courslyCalendar.isDate($0, inSameDayAs: first) }) {
            days = makeWindow(around: first, radius: 120)
        }
        await preloadFiveDays(startingAt: first)
        withAnimation(.snappy(duration: 0.32)) {
            horizontalDayID = timelineDayID(first)
        }
    }

    private func fulfill(_ request: TimelineScrollRequest, proxy: ScrollViewProxy, animated: Bool) async {
        let minute: Int
        switch request.target {
        case .now: minute = TimelineAxis.minute(of: store.now)
        case let .minute(value): minute = value
        }
        await scroll(proxy, minute: minute, anchor: .center, animated: animated)
        store.consumeTimelineScrollRequest(request.id)
    }

    private func scroll(_ proxy: ScrollViewProxy, minute: Int, anchor: UnitPoint, animated: Bool) async {
        await Task.yield()
        let id = TimelineAxis.anchorID(prefix: "week", minute: minute)
        if animated {
            withAnimation(.snappy(duration: 0.34)) { proxy.scrollTo(id, anchor: anchor) }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { proxy.scrollTo(id, anchor: anchor) }
        }
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
    let highlightedEventID: String?
    let onSelect: (CalendarEvent) -> Void
    private let engine = EventLayoutEngine()

    var body: some View {
        let isPastDay = courslyCalendar.startOfDay(for: day) < courslyCalendar.startOfDay(for: now)
        let isToday = courslyCalendar.isDate(day, inSameDayAs: now)

        VStack(spacing: 0) {
            WeekDayHeader(day: day, isPastDay: isPastDay, isToday: isToday)

            ZStack(alignment: .topLeading) {
                TimelineDayBackground(isPastDay: isPastDay)
                TimelineHourGrid(hourHeight: hourHeight)

                ForEach(engine.placements(for: events)) { placement in
                    let gaps = TimelineMetrics.parallelCourseGap * CGFloat(max(0, placement.columnCount - 1))
                    let lane = max(1, (width - gaps) / CGFloat(placement.columnCount))
                    let x = CGFloat(placement.column) * (lane + TimelineMetrics.parallelCourseGap)
                    let top = TimelineAxis.y(for: placement.event.start, hourHeight: hourHeight)
                    let bottom = TimelineAxis.y(for: placement.event.end, hourHeight: hourHeight)
                    let cardHeight = max(1, bottom - top - TimelineMetrics.courseBottomGap)

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
                    TimelineCurrentTimeIndicator(hourHeight: hourHeight, width: width)
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

    var body: some View {
        VStack(spacing: 2) {
            Text(capitalizedWeekday(day))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Text(day.formatted(.dateTime.day()))
                .font(.subheadline.monospacedDigit().bold())
                .frame(minWidth: 28, minHeight: 28)
                .background(isToday ? Color(.systemGray5) : Color.clear, in: Circle())
        }
        .frame(maxWidth: .infinity, minHeight: TimelineMetrics.weekHeaderHeight, maxHeight: TimelineMetrics.weekHeaderHeight)
        .foregroundStyle(isPastDay ? Color.secondary : Color.primary)
        .background(isPastDay ? Color(.systemGray6) : Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.secondary.opacity(0.16)).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}
