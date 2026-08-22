import SwiftUI

private let timelineTimeWidth: CGFloat = 44
private let weekHeaderHeight: CGFloat = 52
private let weekPreloadRadius = 90
private let courseBottomGap: CGFloat = 3
private let parallelCourseGap: CGFloat = 2
private let floatingDockClearance: CGFloat = 92

struct EventPlacement: Identifiable {
    let event: CalendarEvent
    let column: Int
    let columnCount: Int
    var id: String { event.id + "-\(column)" }
}

struct EventLayoutEngine {
    func placements(for events: [CalendarEvent]) -> [EventPlacement] {
        let ordered = events
            .filter { $0.end > $0.start }
            .sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
        var output: [EventPlacement] = []
        var cluster: [CalendarEvent] = []
        var clusterEnd: Date?

        func flush() {
            guard !cluster.isEmpty else { return }
            var columnEnds: [Date] = []
            var assignments: [(CalendarEvent, Int)] = []
            for event in cluster {
                if let reusable = columnEnds.firstIndex(where: { $0 <= event.start }) {
                    columnEnds[reusable] = event.end
                    assignments.append((event, reusable))
                } else {
                    assignments.append((event, columnEnds.count))
                    columnEnds.append(event.end)
                }
            }
            let count = max(1, columnEnds.count)
            output.append(contentsOf: assignments.map { EventPlacement(event: $0.0, column: $0.1, columnCount: count) })
            cluster.removeAll(keepingCapacity: true)
            clusterEnd = nil
        }

        for event in ordered {
            if let end = clusterEnd, event.start >= end { flush() }
            cluster.append(event)
            clusterEnd = max(clusterEnd ?? event.end, event.end)
        }
        flush()
        return output
    }
}

// MARK: - Day

struct DayTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var didInitialScroll = false
    @State private var pageOffset: CGFloat = 0
    @State private var isChangingDay = false
    @GestureState private var liveDragX: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        dayPage(store.adjacentVisibleDate(direction: -1), width: viewport.size.width, highlight: nil)
                            .offset(x: -viewport.size.width + pageOffset + liveDragX)
                        dayPage(store.focusedDate, width: viewport.size.width, highlight: store.highlightedEventID)
                            .offset(x: pageOffset + liveDragX)
                        dayPage(store.adjacentVisibleDate(direction: 1), width: viewport.size.width, highlight: nil)
                            .offset(x: viewport.size.width + pageOffset + liveDragX)
                    }
                    .frame(width: viewport.size.width, height: CGFloat(store.hourHeight) * 24 + 1, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { dayAnchors }
                }
                .contentMargins(.bottom, floatingDockClearance, for: .scrollContent)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(daySwipe(width: viewport.size.width))
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { oldValue, newValue in
                    scrollFeedback(oldValue, newValue)
                }
                .task {
                    await preloadDayNeighbors()
                    guard !didInitialScroll else { return }
                    await scrollForInitialAppearance(proxy: proxy)
                    didInitialScroll = true
                }
                .onChange(of: store.timelineRecenterToken) { _, _ in
                    Task { @MainActor in await scrollForExplicitNavigation(proxy: proxy) }
                }
                .onChange(of: store.highlightedEventID) { _, newValue in
                    guard newValue != nil else { return }
                    Task { @MainActor in await scrollForExplicitNavigation(proxy: proxy) }
                }
                .refreshable { await store.refresh() }
            }
        }
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

    private var dayAnchors: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<96, id: \.self) { quarter in
                Color.clear.frame(width: 1, height: 1)
                    .offset(y: CGFloat(quarter) * CGFloat(store.hourHeight) / 4)
                    .id("day-quarter-\(quarter)")
            }
            Color.clear.frame(width: 1, height: 1)
                .offset(y: yPosition(for: store.now, hourHeight: CGFloat(store.hourHeight)))
                .id("day-now")
        }
    }

    private func preloadDayNeighbors() async {
        await store.ensureLoaded(around: store.focusedDate)
        await store.ensureLoaded(around: store.adjacentVisibleDate(direction: -1))
        await store.ensureLoaded(around: store.adjacentVisibleDate(direction: 1))
    }

    private func scrollForInitialAppearance(proxy: ScrollViewProxy) async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(90))
        if calendar.isDate(store.focusedDate, inSameDayAs: store.now) {
            scroll(proxy, to: "day-now", anchor: .center, animated: false)
        } else {
            let minute = store.events(on: store.focusedDate).first.map { minutesSinceMidnight($0.start) } ?? 8 * 60
            scroll(proxy, to: quarterID(prefix: "day", minute: minute), anchor: .center, animated: false)
        }
    }

    private func scrollForExplicitNavigation(proxy: ScrollViewProxy) async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(90))
        if let id = store.highlightedEventID, let event = store.events.first(where: { $0.id == id }) {
            scroll(proxy, to: quarterID(prefix: "day", minute: minutesSinceMidnight(event.start)), anchor: .center, animated: true)
            return
        }
        if calendar.isDate(store.focusedDate, inSameDayAs: store.now) {
            scroll(proxy, to: "day-now", anchor: .center, animated: true)
            return
        }
        let minute = store.events(on: store.focusedDate).first.map { minutesSinceMidnight($0.start) } ?? 8 * 60
        scroll(proxy, to: quarterID(prefix: "day", minute: minute), anchor: .center, animated: true)
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: String, anchor: UnitPoint, animated: Bool) {
        if animated { withAnimation(.snappy(duration: 0.34)) { proxy.scrollTo(id, anchor: anchor) } }
        else { proxy.scrollTo(id, anchor: anchor) }
    }

    private func daySwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($liveDragX) { value, state, _ in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) * 1.08 else { return }
                state = max(-width, min(width, horizontal))
            }
            .onEnded { value in
                guard !isChangingDay else { return }
                let horizontal = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let effective = abs(predicted) > abs(horizontal) ? predicted : horizontal
                guard abs(effective) > 58, abs(horizontal) > abs(value.translation.height) * 1.08 else {
                    withAnimation(.snappy(duration: 0.18)) { pageOffset = 0 }
                    return
                }
                let direction = effective < 0 ? 1 : -1
                isChangingDay = true
                withAnimation(.snappy(duration: 0.20)) { pageOffset = direction > 0 ? -width : width }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(190))
                    store.moveDay(direction)
                    var reset = Transaction(); reset.disablesAnimations = true
                    withTransaction(reset) { pageOffset = 0 }
                    isChangingDay = false
                    await preloadDayNeighbors()
                }
            }
    }

    private func scrollFeedback(_ oldValue: CGFloat, _ newValue: CGFloat) {
        guard store.hapticsEnabled else { return }
        let h = CGFloat(store.hourHeight)
        let old = max(0, oldValue), new = max(0, newValue), low = min(old, new), high = max(old, new)
        if courseBoundaryOffsets(events: store.events(on: store.focusedDate), hourHeight: h).contains(where: { $0 > low && $0 <= high }) {
            HapticService.fire(.scrollCourse, enabled: true)
        } else if Int(old / h) != Int(new / h) {
            HapticService.fire(.scrollHour, enabled: true)
        }
    }
}

struct DayTimelineCanvas: View {
    @Environment(CalendarStore.self) private var store
    let date: Date
    let events: [CalendarEvent]
    let hourHeight: CGFloat
    let highlightedEventID: String?
    let onSelect: (CalendarEvent) -> Void
    private let engine = EventLayoutEngine()

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(1, proxy.size.width - timelineTimeWidth)
            let pastDay = calendar.startOfDay(for: date) < calendar.startOfDay(for: store.now)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(pastDay ? Color(.secondarySystemBackground).opacity(0.72) : Color.clear)
                DayHourGrid(hourHeight: hourHeight)

                ForEach(engine.placements(for: events)) { placement in
                    let gaps = parallelCourseGap * CGFloat(max(0, placement.columnCount - 1))
                    let lane = max(1, (contentWidth - gaps) / CGFloat(placement.columnCount))
                    let x = timelineTimeWidth + CGFloat(placement.column) * (lane + parallelCourseGap)
                    let top = yPosition(for: placement.event.start, hourHeight: hourHeight)
                    let bottom = yPosition(for: placement.event.end, hourHeight: hourHeight)
                    let cardHeight = max(1, bottom - top - courseBottomGap)

                    Button { onSelect(placement.event) } label: {
                        CourseBlock(
                            event: placement.event,
                            availableWidth: lane,
                            height: cardHeight,
                            highlighted: highlightedEventID == placement.event.id,
                            forceCompact: false,
                            isPast: placement.event.end <= store.now
                        )
                    }
                    .buttonStyle(CoursePressButtonStyle())
                    .frame(width: lane, height: cardHeight)
                    .offset(x: x, y: top)
                }

                if calendar.isDate(date, inSameDayAs: store.now) {
                    CurrentTimeIndicator(hourHeight: hourHeight, x: timelineTimeWidth, width: contentWidth)
                }
            }
        }
        .frame(height: hourHeight * 24 + 1)
    }
}

private struct DayHourGrid: View {
    let hourHeight: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                let y = CGFloat(hour) * hourHeight
                Text(String(format: "%02d", hour % 24))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: timelineTimeWidth - 10, height: 16, alignment: .trailing)
                    .position(x: (timelineTimeWidth - 10) / 2, y: y)
                Rectangle()
                    .fill(Color.secondary.opacity(hour % 3 == 0 ? 0.24 : 0.14))
                    .frame(height: hour % 3 == 0 ? 0.8 : 0.5)
                    .padding(.leading, timelineTimeWidth)
                    .offset(y: y)
            }
        }
        .frame(height: hourHeight * 24 + 1)
    }
}

// MARK: - Week

struct WeekTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var rangeCenter = Date()
    @State private var horizontalDayID: String?
    @State private var didInitialPosition = false

    var body: some View {
        GeometryReader { viewport in
            let dayWidth = max(1, (viewport.size.width - timelineTimeWidth) / 5)
            let days = loadedDays(around: rangeCenter)

            ScrollViewReader { verticalProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        WeekTimeColumn(hourHeight: CGFloat(store.hourHeight))
                            .frame(width: timelineTimeWidth)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 0) {
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
                                    .id(weekDayID(day))
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollPosition(id: $horizontalDayID, anchor: .leading)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .onChange(of: horizontalDayID) { _, newID in
                            guard let newID, let day = days.first(where: { weekDayID($0) == newID }) else { return }
                            store.focusedDate = calendar.startOfDay(for: day)
                            Task {
                                await store.ensureLoaded(around: day)
                                let fifth = advanceVisibleDay(from: day, count: 4)
                                await store.ensureLoaded(around: fifth)
                            }
                        }
                    }
                    .overlay(alignment: .topLeading) { weekAnchors }
                }
                .contentMargins(.bottom, floatingDockClearance, for: .scrollContent)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { oldValue, newValue in
                    weekScrollFeedback(oldValue, newValue)
                }
                .task {
                    rangeCenter = calendar.startOfDay(for: store.focusedDate)
                    let first = firstVisibleDay(containing: store.focusedDate)
                    horizontalDayID = weekDayID(first)
                    await store.ensureLoaded(around: first)
                    await store.ensureLoaded(around: advanceVisibleDay(from: first, count: 4))
                    guard !didInitialPosition else { return }
                    await scrollWeekToEarliest(proxy: verticalProxy, startingAt: first, animated: false)
                    didInitialPosition = true
                }
                .onChange(of: store.timelineRecenterToken) { _, _ in
                    Task { @MainActor in
                        let first = firstVisibleDay(containing: store.focusedDate)
                        if abs(first.timeIntervalSince(rangeCenter)) > 60 * 24 * 60 * 60 { rangeCenter = first }
                        horizontalDayID = weekDayID(first)
                        await store.ensureLoaded(around: first)
                        await store.ensureLoaded(around: advanceVisibleDay(from: first, count: 4))
                        await scrollWeekToEarliest(proxy: verticalProxy, startingAt: first, animated: true)
                    }
                }
                .refreshable { await store.refresh() }
            }
        }
    }

    private var weekAnchors: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<96, id: \.self) { quarter in
                Color.clear.frame(width: 1, height: 1)
                    .offset(y: weekHeaderHeight + CGFloat(quarter) * CGFloat(store.hourHeight) / 4)
                    .id("week-quarter-\(quarter)")
            }
        }
    }

    private func loadedDays(around center: Date) -> [Date] {
        var before: [Date] = [], after: [Date] = []
        var left = calendar.startOfDay(for: center), right = left
        for _ in 0..<weekPreloadRadius {
            left = store.adjacentVisibleDate(from: left, direction: -1)
            right = store.adjacentVisibleDate(from: right, direction: 1)
            before.append(left); after.append(right)
        }
        return Array(before.reversed()) + [calendar.startOfDay(for: center)] + after
    }

    private func firstVisibleDay(containing date: Date) -> Date {
        store.visibleWeekDays(containing: date).first ?? calendar.startOfDay(for: date)
    }

    private func advanceVisibleDay(from date: Date, count: Int) -> Date {
        var result = date
        for _ in 0..<count { result = store.adjacentVisibleDate(from: result, direction: 1) }
        return result
    }

    private func fiveVisibleDays(startingAt start: Date) -> [Date] {
        var days = [start], cursor = start
        while days.count < 5 { cursor = store.adjacentVisibleDate(from: cursor, direction: 1); days.append(cursor) }
        return days
    }

    private func scrollWeekToEarliest(proxy: ScrollViewProxy, startingAt first: Date, animated: Bool) async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(120))
        let days = fiveVisibleDays(startingAt: first)
        let minute = days.flatMap { store.events(on: $0) }.map(\.start).min().map(minutesSinceMidnight) ?? 8 * 60
        let id = quarterID(prefix: "week", minute: minute)
        if animated { withAnimation(.snappy(duration: 0.34)) { proxy.scrollTo(id, anchor: .top) } }
        else { proxy.scrollTo(id, anchor: .top) }
    }

    private func weekScrollFeedback(_ oldValue: CGFloat, _ newValue: CGFloat) {
        guard store.hapticsEnabled else { return }
        let h = CGFloat(store.hourHeight)
        let old = max(0, oldValue - weekHeaderHeight), new = max(0, newValue - weekHeaderHeight)
        if Int(old / h) != Int(new / h) { HapticService.fire(.scrollHour, enabled: true) }
    }
}

private struct WeekTimeColumn: View {
    let hourHeight: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: weekHeaderHeight)
            ZStack(alignment: .topLeading) {
                ForEach(0...24, id: \.self) { hour in
                    Text(String(format: "%02d", hour % 24))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: timelineTimeWidth - 10, height: 16, alignment: .trailing)
                        .position(x: (timelineTimeWidth - 10) / 2, y: CGFloat(hour) * hourHeight)
                }
            }
            .frame(height: hourHeight * 24 + 1)
        }
    }
}

private struct WeekDayColumn: View {
    let day: Date
    let events: [CalendarEvent]
    let now: Date
    let hourHeight: CGFloat
    let width: CGFloat
    let highlightedEventID: String?
    let onSelect: (CalendarEvent) -> Void
    private let engine = EventLayoutEngine()

    var body: some View {
        let pastDay = calendar.startOfDay(for: day) < calendar.startOfDay(for: now)
        VStack(spacing: 0) {
            Button(action: onHeaderTap) {
                VStack(spacing: 1) {
                    Text(capitalizedWeekday(day)).font(.caption2.weight(.semibold)).lineLimit(1)
                    Text(day.formatted(.dateTime.day())).font(.subheadline.monospacedDigit().bold())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(calendar.isDate(day, inSameDayAs: now) ? Color.accentColor : Color.primary)
                .background(pastDay ? Color(.secondarySystemBackground) : Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: weekHeaderHeight)

            ZStack(alignment: .topLeading) {
                Rectangle().fill(pastDay ? Color(.secondarySystemBackground).opacity(0.78) : Color.clear)
                WeekDayGrid(hourHeight: hourHeight)

                ForEach(engine.placements(for: events)) { placement in
                    let gaps = parallelCourseGap * CGFloat(max(0, placement.columnCount - 1))
                    let lane = max(1, (width - gaps) / CGFloat(placement.columnCount))
                    let x = CGFloat(placement.column) * (lane + parallelCourseGap)
                    let top = yPosition(for: placement.event.start, hourHeight: hourHeight)
                    let bottom = yPosition(for: placement.event.end, hourHeight: hourHeight)
                    let cardHeight = max(1, bottom - top - courseBottomGap)

                    Button { onSelect(placement.event) } label: {
                        CourseBlock(
                            event: placement.event,
                            availableWidth: lane,
                            height: cardHeight,
                            highlighted: highlightedEventID == placement.event.id,
                            forceCompact: true,
                            isPast: placement.event.end <= now
                        )
                    }
                    .buttonStyle(CoursePressButtonStyle())
                    .frame(width: lane, height: cardHeight)
                    .offset(x: x, y: top)
                }

                if calendar.isDate(day, inSameDayAs: now) {
                    WeekCurrentTimeIndicator(hourHeight: hourHeight, width: width)
                }
            }
            .frame(height: hourHeight * 24 + 1)
        }
        .overlay(alignment: .leading) { Rectangle().fill(Color.secondary.opacity(0.12)).frame(width: 0.5) }
    }

    private func onHeaderTap() {
        // Header navigation is intentionally handled by the parent date state through the day itself.
        // A visible button keeps clear tap affordance without introducing a second scroll state.
    }
}

private struct WeekDayGrid: View {
    let hourHeight: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(Color.secondary.opacity(hour % 3 == 0 ? 0.24 : 0.14))
                    .frame(height: hour % 3 == 0 ? 0.8 : 0.5)
                    .offset(y: CGFloat(hour) * hourHeight)
            }
        }
        .frame(height: hourHeight * 24 + 1)
    }
}

// MARK: - Indicators and cards

struct CurrentTimeIndicator: View {
    @Environment(CalendarStore.self) private var store
    let hourHeight: CGFloat
    let x: CGFloat
    let width: CGFloat
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let y = yPosition(for: store.effectiveNow(from: context.date), hourHeight: hourHeight)
            HStack(spacing: 0) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Rectangle().fill(.red).frame(height: 1.5)
            }
            .frame(width: width, alignment: .leading)
            .offset(x: x - 4, y: y - 4)
            .accessibilityHidden(true)
        }
    }
}

private struct WeekCurrentTimeIndicator: View {
    @Environment(CalendarStore.self) private var store
    let hourHeight: CGFloat
    let width: CGFloat
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let y = yPosition(for: store.effectiveNow(from: context.date), hourHeight: hourHeight)
            HStack(spacing: 0) {
                Circle().fill(.red).frame(width: 7, height: 7)
                Rectangle().fill(.red).frame(height: 1.5)
            }
            .frame(width: width, alignment: .leading)
            .offset(x: -3, y: y - 3)
            .accessibilityHidden(true)
        }
    }
}

private struct CoursePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

struct CourseBlock: View {
    let event: CalendarEvent
    let availableWidth: CGFloat
    let height: CGFloat
    let highlighted: Bool
    var forceCompact = false
    var isPast = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(stripeColor).frame(width: 3).frame(maxHeight: .infinity)
            cardContent
                .padding(.leading, forceCompact ? 3 : 6)
                .padding(.trailing, forceCompact ? 2 : 5)
                .padding(.vertical, compactHeight ? 2 : 4)
        }
        .background(Rectangle().fill(cardFill))
        .overlay { if highlighted { Rectangle().stroke(Color.accentColor, lineWidth: 2) } }
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var cardContent: some View {
        if compactHeight {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(event.title)
                        .font(compactTitleFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                    Spacer(minLength: 2)
                    Text(timeRange)
                        .font(compactTimeFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                HStack(spacing: 3) {
                    if let label = event.displayTypeLabel, !label.isEmpty { Text(label).foregroundStyle(stripeColor).fontWeight(.bold) }
                    if !event.room.isEmpty { metadataSeparator; Text(event.room) }
                    if !event.teachers.isEmpty { metadataSeparator; Text(event.teachers.joined(separator: ", ")) }
                    if !event.displayGroupsText.isEmpty { metadataSeparator; Text(event.displayGroupsText) }
                }
                .font(compactMetadataFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.40)
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: availableWidth > 190 ? 4 : 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    if let label = event.displayTypeLabel, !label.isEmpty {
                        Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(stripeColor).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    Text(event.start, style: .time).font(timeFont).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(event.title).font(titleFont).lineLimit(availableWidth < 130 ? 2 : 3).minimumScaleFactor(0.62)
                HStack(spacing: 4) {
                    if !event.room.isEmpty { Text(event.room) }
                    if !event.teachers.isEmpty { metadataSeparator; Text(event.teachers.joined(separator: ", ")) }
                    if !event.displayGroupsText.isEmpty { metadataSeparator; Text(event.displayGroupsText) }
                }
                .font(metadataFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                Spacer(minLength: 0)
                HStack { Spacer(minLength: 0); Text(event.end, style: .time).font(timeFont).foregroundStyle(.secondary).lineLimit(1) }
            }
        }
    }

    private var metadataSeparator: some View { Text("·").foregroundStyle(.tertiary) }
    private var compactHeight: Bool { forceCompact || height <= 92 }
    private var compactTitleFont: Font { .system(size: height < 50 ? 7.5 : (height < 68 ? 8.5 : 10), weight: .bold) }
    private var compactMetadataFont: Font { .system(size: height < 55 ? 5.8 : (height < 75 ? 6.5 : 7.5), weight: .medium) }
    private var compactTimeFont: Font { .system(size: height < 55 ? 6 : 7.5, weight: .semibold, design: .rounded).monospacedDigit() }
    private var titleFont: Font { if availableWidth < 140 { return .caption2.weight(.bold) }; if availableWidth < 180 { return .caption.weight(.bold) }; return .subheadline.weight(.bold) }
    private var metadataFont: Font { availableWidth < 140 ? .system(size: 7.5) : .caption }
    private var timeFont: Font { .system(size: availableWidth < 100 ? 7 : 9, weight: .semibold, design: .rounded).monospacedDigit() }
    private var timeRange: String { "\(shortTime(event.start))–\(shortTime(event.end))" }
    private var baseHex: String {
        if event.source == .local { return "#AF52DE" }
        guard let label = event.displayTypeLabel, !label.isEmpty else { return "#0A84FF" }
        return CourseTypeColorPreferences.hex(for: label)
    }
    private var baseColor: Color { Color(courslyHex: baseHex) }
    private var stripeColor: Color { isPast ? Color(courslyHex: baseHex, brightnessScale: 0.70) : baseColor }
    private var cardFill: Color {
        if isPast { return Color(courslyHex: baseHex, brightnessScale: 0.42).opacity(0.86) }
        return baseColor.opacity(event.source == .local ? 0.10 : 0.13)
    }
    private var accessibilityText: String {
        var parts = [event.displayTypeLabel, event.title].compactMap { $0 }
        parts.append("de \(event.start.formatted(date: .omitted, time: .shortened)) à \(event.end.formatted(date: .omitted, time: .shortened))")
        if !event.room.isEmpty { parts.append("salle \(event.room)") }
        if !event.teachers.isEmpty { parts.append(event.teachers.joined(separator: ", ")) }
        if !event.displayGroupsText.isEmpty { parts.append(event.displayGroupsText) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Helpers

private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.locale = Locale(identifier: "fr_FR")
    value.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
    return value
}

private func minutesSinceMidnight(_ date: Date) -> Int {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    return (components.hour ?? 0) * 60 + (components.minute ?? 0)
}

private func yPosition(for date: Date, hourHeight: CGFloat) -> CGFloat {
    let components = calendar.dateComponents([.hour, .minute, .second], from: date)
    let minutes = CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0)) + CGFloat(components.second ?? 0) / 60
    return max(0, min(minutes * hourHeight / 60, hourHeight * 24))
}

private func quarterID(prefix: String, minute: Int) -> String {
    "\(prefix)-quarter-\(max(0, min(95, minute / 15)))"
}

private func weekDayID(_ date: Date) -> String {
    "week-day-\(Int(calendar.startOfDay(for: date).timeIntervalSince1970))"
}

private func capitalizedWeekday(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "EEE"
    let value = formatter.string(from: date)
    return value.prefix(1).uppercased() + value.dropFirst()
}

private func shortTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private extension Color {
    init(courslyHex hex: String, brightnessScale: Double = 1) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        if cleaned.count == 6 {
            let scale = max(0, min(1, brightnessScale))
            self.init(
                red: Double((value >> 16) & 0xFF) / 255 * scale,
                green: Double((value >> 8) & 0xFF) / 255 * scale,
                blue: Double(value & 0xFF) / 255 * scale
            )
        } else {
            self = .accentColor
        }
    }
}

private func courseBoundaryOffsets(events: [CalendarEvent], hourHeight: CGFloat) -> [CGFloat] {
    events.flatMap { [yPosition(for: $0.start, hourHeight: hourHeight), yPosition(for: $0.end, hourHeight: hourHeight)] }.sorted()
}
