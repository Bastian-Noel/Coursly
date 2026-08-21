import SwiftUI

private let timelineTimeWidth: CGFloat = 52
private let eventGap: CGFloat = 2
private let eventVerticalInset: CGFloat = 2
private let weekHeaderHeight: CGFloat = 50

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
            .sorted { lhs, rhs in
                lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
            }
        guard !ordered.isEmpty else { return [] }

        var output: [EventPlacement] = []
        var cluster: [CalendarEvent] = []
        var clusterEnd: Date?

        func flushCluster() {
            guard !cluster.isEmpty else { return }

            var columnEnds: [Date] = []
            var assignments: [(CalendarEvent, Int)] = []

            for event in cluster {
                if let reusableColumn = columnEnds.firstIndex(where: { $0 <= event.start }) {
                    columnEnds[reusableColumn] = event.end
                    assignments.append((event, reusableColumn))
                } else {
                    let column = columnEnds.count
                    columnEnds.append(event.end)
                    assignments.append((event, column))
                }
            }

            let columnCount = max(1, columnEnds.count)
            output.append(contentsOf: assignments.map {
                EventPlacement(event: $0.0, column: $0.1, columnCount: columnCount)
            })
            cluster.removeAll(keepingCapacity: true)
            clusterEnd = nil
        }

        for event in ordered {
            if let end = clusterEnd, event.start >= end {
                flushCluster()
            }
            cluster.append(event)
            clusterEnd = max(clusterEnd ?? event.end, event.end)
        }
        flushCluster()

        return output
    }
}

struct DayTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var hasCentered = false
    @State private var pageOffset: CGFloat = 0
    @State private var isChangingDay = false
    @GestureState private var liveHorizontalDrag: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    let previousDate = store.adjacentVisibleDate(direction: -1)
                    let nextDate = store.adjacentVisibleDate(direction: 1)

                    HStack(spacing: 0) {
                        timelinePage(for: previousDate, width: viewport.size.width)
                        timelinePage(for: store.focusedDate, width: viewport.size.width)
                        timelinePage(for: nextDate, width: viewport.size.width)
                    }
                    .frame(width: viewport.size.width * 3, alignment: .leading)
                    .offset(x: -viewport.size.width + pageOffset + liveHorizontalDrag)
                }
                .scrollBounceBehavior(.basedOnSize)
                .contentShape(Rectangle())
                .clipped()
                .simultaneousGesture(daySwipeGesture(width: viewport.size.width))
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { oldValue, newValue in
                    handleScrollFeedback(from: oldValue, to: newValue)
                }
                .onAppear {
                    guard !hasCentered else { return }
                    hasCentered = true
                    scrollToRelevantTime(proxy: proxy, animated: false)
                    Task {
                        await store.ensureLoaded(around: previousDate)
                        await store.ensureLoaded(around: nextDate)
                    }
                }
                .onChange(of: store.timelineRecenterToken) { _, _ in
                    scrollToRelevantTime(proxy: proxy, animated: true, forceNow: true)
                }
                .onChange(of: store.highlightedEventID) { _, newValue in
                    guard newValue != nil else { return }
                    scrollToRelevantTime(proxy: proxy, animated: true)
                }
                .refreshable { await store.refresh() }
            }
        }
    }

    private func timelinePage(for date: Date, width: CGFloat) -> some View {
        DayTimelineCanvas(
            date: date,
            events: store.events(on: date),
            hourHeight: CGFloat(store.hourHeight),
            highlightedEventID: calendar.isDate(date, inSameDayAs: store.focusedDate)
                ? store.highlightedEventID
                : nil,
            onSelect: onSelect
        )
        .frame(width: width)
    }

    private func daySwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($liveHorizontalDrag) { value, state, _ in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.08 else { return }
                state = max(-width, min(width, horizontal))
            }
            .onEnded { value in
                guard !isChangingDay else { return }

                let horizontal = value.translation.width
                let vertical = value.translation.height
                let predicted = value.predictedEndTranslation.width
                let effective = abs(predicted) > abs(horizontal) ? predicted : horizontal

                guard abs(effective) > 58, abs(horizontal) > abs(vertical) * 1.08 else {
                    withAnimation(.snappy(duration: 0.18)) { pageOffset = 0 }
                    return
                }

                let direction = effective < 0 ? 1 : -1
                isChangingDay = true

                var capture = Transaction()
                capture.disablesAnimations = true
                withTransaction(capture) {
                    pageOffset = max(-width, min(width, horizontal))
                }

                withAnimation(.snappy(duration: 0.20)) {
                    pageOffset = direction > 0 ? -width : width
                }

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(190))
                    store.moveDay(direction)

                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { pageOffset = 0 }

                    isChangingDay = false
                    let preloadDate = store.adjacentVisibleDate(direction: direction)
                    await store.ensureLoaded(around: preloadDate)
                }
            }
    }

    private func handleScrollFeedback(from oldValue: CGFloat, to newValue: CGFloat) {
        guard store.hapticsEnabled else { return }
        let oldOffset = max(0, oldValue)
        let newOffset = max(0, newValue)
        guard abs(newOffset - oldOffset) > 0.75 else { return }

        let hourHeight = CGFloat(store.hourHeight)
        let oldHour = Int(oldOffset / hourHeight)
        let newHour = Int(newOffset / hourHeight)
        let crossedCourse = crossedCourseBoundary(
            from: oldOffset,
            to: newOffset,
            events: store.events(on: store.focusedDate),
            hourHeight: hourHeight
        )

        if crossedCourse {
            HapticService.fire(.scrollCourse, enabled: true)
        } else if oldHour != newHour {
            HapticService.fire(.scrollHour, enabled: true)
        }
    }

    private func crossedCourseBoundary(
        from oldValue: CGFloat,
        to newValue: CGFloat,
        events: [CalendarEvent],
        hourHeight: CGFloat
    ) -> Bool {
        let lower = min(oldValue, newValue)
        let upper = max(oldValue, newValue)
        guard upper - lower < hourHeight * 2.5 else { return false }

        return courseBoundaryOffsets(events: events, hourHeight: hourHeight).contains { boundary in
            boundary > lower && boundary <= upper
        }
    }

    private func scrollToRelevantTime(
        proxy: ScrollViewProxy,
        animated: Bool,
        forceNow: Bool = false
    ) {
        let event = forceNow ? nil : store.highlightedEventID.flatMap { id in
            store.events.first(where: { $0.id == id })
        }
        let targetDate = event?.start ?? store.now
        let useTarget = forceNow || event != nil || calendar.isDate(store.focusedDate, inSameDayAs: store.now)
        let minutes = useTarget ? minutesSinceMidnight(targetDate) : 8 * 60
        let quarter = max(0, min(95, Int(round(Double(minutes) / 15.0))))
        let target = "day-quarter-\(quarter)"

        if animated {
            withAnimation(.snappy(duration: 0.38)) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            proxy.scrollTo(target, anchor: .center)
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
            let placements = engine.placements(for: events)
            let contentWidth = max(1, proxy.size.width - timelineTimeWidth)

            ZStack(alignment: .topLeading) {
                DayHourGrid(hourHeight: hourHeight)

                ForEach(placements) { placement in
                    let totalGaps = eventGap * CGFloat(max(0, placement.columnCount - 1))
                    let laneWidth = max(1, (contentWidth - 4 - totalGaps) / CGFloat(placement.columnCount))
                    let x = timelineTimeWidth + 2 + CGFloat(placement.column) * (laneWidth + eventGap)
                    let exactTop = yPosition(for: placement.event.start, hourHeight: hourHeight)
                    let exactBottom = yPosition(for: placement.event.end, hourHeight: hourHeight)
                    let exactHeight = max(1, exactBottom - exactTop)
                    let cardHeight = max(1, exactHeight - eventVerticalInset * 2)

                    CourseBlock(
                        event: placement.event,
                        availableWidth: laneWidth,
                        height: cardHeight,
                        highlighted: highlightedEventID == placement.event.id
                    )
                    .frame(width: laneWidth, height: cardHeight)
                    .offset(x: x, y: exactTop + eventVerticalInset)
                    .onTapGesture { onSelect(placement.event) }
                }

                if calendar.isDate(date, inSameDayAs: store.now) {
                    CurrentTimeIndicator(
                        hourHeight: hourHeight,
                        x: timelineTimeWidth,
                        width: contentWidth
                    )
                }
            }
            .frame(height: hourHeight * 24 + 2, alignment: .top)
        }
        .frame(height: hourHeight * 24 + 2)
    }
}

private struct DayHourGrid: View {
    let hourHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                let y = CGFloat(hour) * hourHeight
                Rectangle()
                    .fill(Color.secondary.opacity(hour % 3 == 0 ? 0.24 : 0.15))
                    .frame(height: hour % 3 == 0 ? 0.8 : 0.5)
                    .offset(x: timelineTimeWidth, y: y)

                Text(String(format: "%02d:00", hour % 24))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: timelineTimeWidth - 8, alignment: .trailing)
                    .offset(x: 0, y: y - 7)
            }

            ForEach(0..<96, id: \.self) { quarter in
                Color.clear
                    .frame(width: 1, height: 1)
                    .offset(y: CGFloat(quarter) * hourHeight / 4)
                    .id("day-quarter-\(quarter)")
            }
        }
        .frame(height: hourHeight * 24 + 2, alignment: .top)
    }
}

struct WeekTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var hasPositioned = false

    var body: some View {
        GeometryReader { viewport in
            let dayWidth = max(1, (viewport.size.width - timelineTimeWidth) / 5)
            let initialStart = initialWeekStart
            let days = extendedVisibleDays(centeredAround: initialStart)
            let initialFive = fiveDays(startingAt: initialStart)

            ScrollViewReader { verticalProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        WeekTimeColumn(hourHeight: CGFloat(store.hourHeight))
                            .frame(width: timelineTimeWidth)

                        ScrollViewReader { horizontalProxy in
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
                                        .id(day)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                            .defaultScrollAnchor(.leading)
                            .onAppear {
                                horizontalProxy.scrollTo(initialStart, anchor: .leading)
                            }
                            .onChange(of: store.focusedDate) { _, _ in
                                let newStart = initialWeekStart
                                withAnimation(.snappy(duration: 0.28)) {
                                    horizontalProxy.scrollTo(newStart, anchor: .leading)
                                }
                            }
                        }
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { oldValue, newValue in
                    handleWeekScrollFeedback(from: oldValue, to: newValue)
                }
                .onAppear {
                    guard !hasPositioned else { return }
                    hasPositioned = true
                    scrollToEarliestCourse(in: initialFive, proxy: verticalProxy, animated: false)
                    Task {
                        if let first = days.first { await store.ensureLoaded(around: first) }
                        if let last = days.last { await store.ensureLoaded(around: last) }
                    }
                }
                .onChange(of: store.timelineRecenterToken) { _, _ in
                    if calendar.isDate(store.focusedDate, inSameDayAs: store.now) {
                        scrollToMinute(minutesSinceMidnight(store.now), proxy: verticalProxy, animated: true)
                    } else {
                        scrollToEarliestCourse(in: fiveDays(startingAt: initialWeekStart), proxy: verticalProxy, animated: true)
                    }
                }
                .refreshable { await store.refresh() }
            }
        }
    }

    private var initialWeekStart: Date {
        store.visibleWeekDays(containing: store.focusedDate).first ?? store.focusedDate
    }

    private func extendedVisibleDays(centeredAround center: Date) -> [Date] {
        var previous: [Date] = []
        var cursor = center
        for _ in 0..<15 {
            cursor = store.adjacentVisibleDate(from: cursor, direction: -1)
            previous.append(cursor)
        }

        var following: [Date] = []
        cursor = center
        for _ in 0..<25 {
            cursor = store.adjacentVisibleDate(from: cursor, direction: 1)
            following.append(cursor)
        }

        return previous.reversed() + [center] + following
    }

    private func fiveDays(startingAt start: Date) -> [Date] {
        var output = [start]
        var cursor = start
        while output.count < 5 {
            cursor = store.adjacentVisibleDate(from: cursor, direction: 1)
            output.append(cursor)
        }
        return output
    }

    private func scrollToEarliestCourse(
        in days: [Date],
        proxy: ScrollViewProxy,
        animated: Bool
    ) {
        let dayKeys = Set(days.map { calendar.startOfDay(for: $0) })
        let earliest = store.events
            .filter { dayKeys.contains(calendar.startOfDay(for: $0.start)) }
            .map(\.start)
            .min()

        let targetMinutes = earliest.map(minutesSinceMidnight) ?? 8 * 60
        scrollToMinute(targetMinutes, proxy: proxy, animated: animated)
    }

    private func scrollToMinute(_ minutes: Int, proxy: ScrollViewProxy, animated: Bool) {
        let quarter = max(0, min(95, Int(floor(Double(minutes) / 15.0))))
        let target = "week-quarter-\(quarter)"
        if animated {
            withAnimation(.snappy(duration: 0.38)) {
                proxy.scrollTo(target, anchor: .top)
            }
        } else {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    private func handleWeekScrollFeedback(from oldValue: CGFloat, to newValue: CGFloat) {
        guard store.hapticsEnabled else { return }
        let oldOffset = max(0, oldValue)
        let newOffset = max(0, newValue)
        guard abs(newOffset - oldOffset) > 0.75 else { return }

        let hourHeight = CGFloat(store.hourHeight)
        let oldHour = Int(max(0, oldOffset - weekHeaderHeight) / hourHeight)
        let newHour = Int(max(0, newOffset - weekHeaderHeight) / hourHeight)

        if oldHour != newHour {
            HapticService.fire(.scrollHour, enabled: true)
        }
    }
}

private struct WeekTimeColumn: View {
    let hourHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: weekHeaderHeight)

            ZStack(alignment: .topLeading) {
                ForEach(0...24, id: \.self) { hour in
                    let y = CGFloat(hour) * hourHeight
                    Text(String(format: "%02d:00", hour % 24))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: timelineTimeWidth - 8, alignment: .trailing)
                        .offset(y: y - 7)
                }

                ForEach(0..<96, id: \.self) { quarter in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .offset(y: CGFloat(quarter) * hourHeight / 4)
                        .id("week-quarter-\(quarter)")
                }
            }
            .frame(height: hourHeight * 24 + 2, alignment: .top)
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
        VStack(spacing: 0) {
            Button {
                store.focusedDate = calendar.startOfDay(for: day)
                store.setDisplayMode(.day)
            } label: {
                VStack(spacing: 1) {
                    Text(capitalizedWeekday(day))
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Text(day.formatted(.dateTime.day()))
                        .font(.subheadline.monospacedDigit().weight(.bold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(calendar.isDate(day, inSameDayAs: now) ? Color.accentColor : Color.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: weekHeaderHeight)

            ZStack(alignment: .topLeading) {
                WeekDayGrid(hourHeight: hourHeight)

                let placements = engine.placements(for: events)
                ForEach(placements) { placement in
                    let totalGaps = eventGap * CGFloat(max(0, placement.columnCount - 1))
                    let laneWidth = max(1, (width - 4 - totalGaps) / CGFloat(placement.columnCount))
                    let x = 2 + CGFloat(placement.column) * (laneWidth + eventGap)
                    let exactTop = yPosition(for: placement.event.start, hourHeight: hourHeight)
                    let exactBottom = yPosition(for: placement.event.end, hourHeight: hourHeight)
                    let exactHeight = max(1, exactBottom - exactTop)
                    let cardHeight = max(1, exactHeight - eventVerticalInset * 2)

                    CourseBlock(
                        event: placement.event,
                        availableWidth: laneWidth,
                        height: cardHeight,
                        highlighted: highlightedEventID == placement.event.id,
                        forceCompact: true
                    )
                    .frame(width: laneWidth, height: cardHeight)
                    .offset(x: x, y: exactTop + eventVerticalInset)
                    .onTapGesture { onSelect(placement.event) }
                }

                if calendar.isDate(day, inSameDayAs: now) {
                    WeekCurrentTimeIndicator(
                        y: yPosition(for: now, hourHeight: hourHeight),
                        width: width
                    )
                }
            }
            .frame(height: hourHeight * 24 + 2, alignment: .top)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 0.5)
        }
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
        .frame(height: hourHeight * 24 + 2, alignment: .top)
    }
}

struct CurrentTimeIndicator: View {
    @Environment(CalendarStore.self) private var store

    let hourHeight: CGFloat
    let x: CGFloat
    let width: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = store.effectiveNow(from: context.date)
            let y = yPosition(for: now, hourHeight: hourHeight)

            HStack(spacing: 0) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Rectangle().fill(Color.red).frame(height: 1.5)
            }
            .frame(width: width, alignment: .leading)
            .offset(x: x - 4, y: y - 4)
            .accessibilityHidden(true)
        }
    }
}

private struct WeekCurrentTimeIndicator: View {
    let y: CGFloat
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(Color.red).frame(width: 7, height: 7)
            Rectangle().fill(Color.red).frame(height: 1.5)
        }
        .frame(width: width, alignment: .leading)
        .offset(x: -3, y: y - 3)
        .accessibilityHidden(true)
    }
}

struct CourseBlock: View {
    let event: CalendarEvent
    let availableWidth: CGFloat
    let height: CGFloat
    let highlighted: Bool
    var forceCompact = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(eventColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: availableWidth > 190 ? 4 : 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    if let label = event.displayTypeLabel, !label.isEmpty {
                        Text(label)
                            .font(.system(size: forceCompact ? 7 : 9, weight: .bold))
                            .foregroundStyle(eventColor)
                            .lineLimit(1)
                    } else if event.source == .local {
                        Image(systemName: "person.crop.circle")
                            .font(.caption2)
                    }

                    Spacer(minLength: 2)

                    Text(event.start, style: .time)
                        .font(timeFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(event.title)
                    .font(titleFont)
                    .lineLimit(forceCompact || availableWidth < 130 ? 2 : 3)
                    .minimumScaleFactor(0.68)

                if height > 48, !event.room.isEmpty {
                    Text(event.room)
                        .font(metadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !forceCompact, availableWidth >= 145, height > 68, !event.teachers.isEmpty {
                    Text(event.teachers.joined(separator: ", "))
                        .font(metadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !forceCompact, availableWidth >= 170, height > 84, !event.groups.isEmpty {
                    Text(event.groups.map(\.name).joined(separator: " · "))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)
                    Text(event.end, style: .time)
                        .font(timeFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, forceCompact ? 3 : 6)
            .padding(.trailing, forceCompact ? 2 : 5)
            .padding(.vertical, min(5, max(1, height * 0.05)))
        }
        .clipped()
        .background(Rectangle().fill(eventColor.opacity(event.source == .local ? 0.09 : 0.12)))
        .overlay {
            if highlighted {
                Rectangle().stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var titleFont: Font {
        if forceCompact || availableWidth < 90 { return .system(size: 8, weight: .bold) }
        if availableWidth < 140 { return .caption2.weight(.bold) }
        if availableWidth < 180 { return .caption.weight(.bold) }
        return .subheadline.weight(.bold)
    }

    private var metadataFont: Font {
        forceCompact || availableWidth < 140 ? .system(size: 7.5) : .caption
    }

    private var timeFont: Font {
        .system(
            size: forceCompact || availableWidth < 100 ? 7 : 9,
            weight: .semibold,
            design: .rounded
        )
        .monospacedDigit()
    }

    private var eventColor: Color {
        if event.source == .local { return Color.purple }
        guard let label = event.displayTypeLabel, !label.isEmpty else { return Color.accentColor }
        return Color(courslyHex: CourseTypeColorPreferences.hex(for: label))
    }

    private var accessibilityText: String {
        var parts = [event.displayTypeLabel, event.title].compactMap { $0 }
        parts.append(
            "de \(event.start.formatted(date: .omitted, time: .shortened)) à \(event.end.formatted(date: .omitted, time: .shortened))"
        )
        if !event.room.isEmpty { parts.append("salle \(event.room)") }
        if !event.teachers.isEmpty { parts.append(event.teachers.joined(separator: ", ")) }
        if !event.groups.isEmpty { parts.append(event.groups.map(\.name).joined(separator: ", ")) }
        return parts.joined(separator: ", ")
    }
}

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
    let minutes = CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0))
        + CGFloat(components.second ?? 0) / 60
    return max(0, min(minutes * hourHeight / 60, hourHeight * 24))
}

private func capitalizedWeekday(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.timeZone = TimeZone(identifier: "Europe/Paris")
    formatter.dateFormat = "EEE"
    let value = formatter.string(from: date)
    return value.prefix(1).uppercased() + value.dropFirst()
}

private extension Color {
    init(courslyHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        if cleaned.count == 6 {
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        } else {
            self.init(red: 0, green: 122.0 / 255.0, blue: 1)
        }
    }
}

private func courseBoundaryOffsets(events: [CalendarEvent], hourHeight: CGFloat) -> [CGFloat] {
    events.flatMap { event in
        [
            yPosition(for: event.start, hourHeight: hourHeight),
            yPosition(for: event.end, hourHeight: hourHeight)
        ]
    }
    .sorted()
}
