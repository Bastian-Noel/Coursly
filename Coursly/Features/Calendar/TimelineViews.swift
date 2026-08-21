import SwiftUI

private let timelineTimeWidth: CGFloat = 52

private struct TimelineScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct EventPlacement: Identifiable {
    let event: CalendarEvent
    let column: Int
    let columnCount: Int

    var id: String { event.id + "-\(column)" }
}

struct EventLayoutEngine {
    func placements(for events: [CalendarEvent]) -> [EventPlacement] {
        let ordered = events.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }
        guard !ordered.isEmpty else { return [] }

        var output: [EventPlacement] = []
        var index = 0

        while index < ordered.count {
            var cluster = [ordered[index]]
            var clusterEnd = ordered[index].end
            var cursor = index + 1

            while cursor < ordered.count, ordered[cursor].start < clusterEnd {
                cluster.append(ordered[cursor])
                clusterEnd = max(clusterEnd, ordered[cursor].end)
                cursor += 1
            }

            var columnEnds: [Date] = []
            var assignments: [(CalendarEvent, Int)] = []

            for event in cluster {
                if let available = columnEnds.firstIndex(where: { $0 <= event.start }) {
                    columnEnds[available] = event.end
                    assignments.append((event, available))
                } else {
                    let column = columnEnds.count
                    columnEnds.append(event.end)
                    assignments.append((event, column))
                }
            }

            let count = max(1, columnEnds.count)
            output.append(contentsOf: assignments.map {
                EventPlacement(event: $0.0, column: $0.1, columnCount: count)
            })
            index = cursor
        }

        return output
    }
}

struct DayTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var hasCentered = false
    @State private var settledHorizontalOffset: CGFloat = 0
    @State private var isChangingDay = false
    @State private var lastScrollOffset: CGFloat?
    @GestureState private var liveHorizontalDrag: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    DayTimelineCanvas(
                        date: store.focusedDate,
                        events: store.events(on: store.focusedDate),
                        hourHeight: CGFloat(store.hourHeight),
                        highlightedEventID: store.highlightedEventID,
                        onSelect: onSelect
                    )
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: TimelineScrollOffsetKey.self,
                                value: geometry.frame(in: .named("day-timeline-scroll")).minY
                            )
                        }
                    }
                }
                .coordinateSpace(name: "day-timeline-scroll")
                .scrollBounceBehavior(.basedOnSize)
                .contentShape(Rectangle())
                .offset(x: settledHorizontalOffset + liveHorizontalDrag)
                .simultaneousGesture(daySwipeGesture(width: viewport.size.width))
                .onPreferenceChange(TimelineScrollOffsetKey.self) { minY in
                    handleScrollFeedback(offset: max(0, -minY))
                }
                .onAppear {
                    guard !hasCentered else { return }
                    hasCentered = true
                    scrollToRelevantHour(proxy: proxy, animated: false)
                }
                .onChange(of: store.highlightedEventID) { _, newValue in
                    guard newValue != nil else { return }
                    scrollToRelevantHour(proxy: proxy, animated: true)
                }
                .refreshable { await store.refresh() }
            }
        }
    }

    private func daySwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($liveHorizontalDrag) { value, state, _ in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.05 else { return }
                state = horizontal
            }
            .onEnded { value in
                guard !isChangingDay else { return }

                let horizontal = value.translation.width
                let vertical = value.translation.height
                let predicted = value.predictedEndTranslation.width
                let effective = abs(predicted) > abs(horizontal) ? predicted : horizontal

                guard abs(effective) > 58, abs(horizontal) > abs(vertical) * 1.05 else {
                    withAnimation(.snappy(duration: 0.18)) {
                        settledHorizontalOffset = 0
                    }
                    return
                }

                let direction = effective < 0 ? 1 : -1
                isChangingDay = true

                withAnimation(.snappy(duration: 0.16)) {
                    settledHorizontalOffset = direction > 0 ? -width : width
                }

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(155))
                    store.moveDay(direction)
                    await store.ensureLoaded(around: store.focusedDate)
                    lastScrollOffset = nil

                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        settledHorizontalOffset = direction > 0 ? width : -width
                    }

                    withAnimation(.snappy(duration: 0.22)) {
                        settledHorizontalOffset = 0
                    }
                    try? await Task.sleep(for: .milliseconds(220))
                    isChangingDay = false
                }
            }
    }

    private func handleScrollFeedback(offset: CGFloat) {
        guard let previous = lastScrollOffset else {
            lastScrollOffset = offset
            return
        }
        guard abs(offset - previous) > 1 else { return }

        let hourHeight = CGFloat(store.hourHeight)
        let oldHour = Int(previous / hourHeight)
        let newHour = Int(offset / hourHeight)
        let crossedCourse = crossedCourseBoundary(
            from: previous,
            to: offset,
            events: store.events(on: store.focusedDate),
            hourHeight: hourHeight
        )

        if crossedCourse {
            HapticService.fire(.scrollCourse, enabled: store.hapticsEnabled)
        } else if oldHour != newHour {
            HapticService.fire(.scrollHour, enabled: store.hapticsEnabled)
        }

        lastScrollOffset = offset
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

    private func scrollToRelevantHour(proxy: ScrollViewProxy, animated: Bool) {
        let event = store.highlightedEventID.flatMap { id in
            store.events.first(where: { $0.id == id })
        }
        let targetDate = event?.start ?? store.now
        let shouldUseNow = event != nil || Calendar.current.isDate(store.focusedDate, inSameDayAs: store.now)
        let hour = shouldUseNow ? max(0, Calendar.current.component(.hour, from: targetDate) - 1) : 8

        if animated {
            withAnimation(.snappy(duration: 0.35)) {
                proxy.scrollTo("day-hour-\(hour)", anchor: .top)
            }
        } else {
            proxy.scrollTo("day-hour-\(hour)", anchor: .top)
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
            let contentWidth = max(1, proxy.size.width - timelineTimeWidth - 8)

            ZStack(alignment: .topLeading) {
                hourGrid

                ForEach(placements) { placement in
                    let width = contentWidth / CGFloat(placement.columnCount)
                    let x = CGFloat(placement.column) * width + 2
                    let y = yPosition(for: placement.event.start)
                    let exactHeight = yPosition(for: placement.event.end) - y
                    let height = max(1, exactHeight)

                    CourseBlock(
                        event: placement.event,
                        availableWidth: max(36, width - 4),
                        height: height,
                        highlighted: highlightedEventID == placement.event.id
                    )
                    .frame(width: max(36, width - 4), height: height)
                    .offset(x: x, y: y)
                    .onTapGesture { onSelect(placement.event) }
                }

                if Calendar.current.isDate(date, inSameDayAs: store.now) {
                    CurrentTimeIndicator(hourHeight: hourHeight, x: 0, width: contentWidth)
                }
            }
            .frame(height: hourHeight * 24 + 28, alignment: .top)
        }
        .frame(height: hourHeight * 24 + 28)
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HourRow(hour: hour, height: hourHeight)
                    .id("day-hour-\(hour)")
            }

            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 0.5)
                Text("00:00")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: timelineTimeWidth - 7, alignment: .leading)
            }
            .frame(height: 28, alignment: .top)
        }
    }

    private func yPosition(for value: Date) -> CGFloat {
        let start = Calendar.current.startOfDay(for: date)
        let minutes = value.timeIntervalSince(start) / 60
        return max(0, min(CGFloat(minutes) * hourHeight / 60, hourHeight * 24))
    }
}

struct WeekTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void

    @State private var hasCentered = false
    @State private var lastScrollOffset: CGFloat?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                GeometryReader { geometry in
                    let days = store.visibleWeekDays(containing: store.focusedDate)
                    let naturalWidth = max(
                        geometry.size.width,
                        CGFloat(days.count) * 104 + timelineTimeWidth + 8
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        WeekTimelineCanvas(
                            days: days,
                            events: store.events,
                            now: store.now,
                            hourHeight: CGFloat(store.hourHeight),
                            width: naturalWidth,
                            onSelect: onSelect
                        )
                        .frame(width: naturalWidth)
                    }
                }
                .frame(height: CGFloat(store.hourHeight) * 24 + 76)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: TimelineScrollOffsetKey.self,
                            value: geometry.frame(in: .named("week-timeline-scroll")).minY
                        )
                    }
                }
            }
            .coordinateSpace(name: "week-timeline-scroll")
            .onPreferenceChange(TimelineScrollOffsetKey.self) { minY in
                handleScrollFeedback(offset: max(0, -minY))
            }
            .onAppear {
                guard !hasCentered else { return }
                hasCentered = true
                let hour = max(0, Calendar.current.component(.hour, from: store.now) - 1)
                proxy.scrollTo("week-hour-\(hour)", anchor: .top)
            }
            .refreshable { await store.refresh() }
        }
    }

    private func handleScrollFeedback(offset: CGFloat) {
        guard let previous = lastScrollOffset else {
            lastScrollOffset = offset
            return
        }
        guard abs(offset - previous) > 1 else { return }

        let hourHeight = CGFloat(store.hourHeight)
        let oldHour = Int(previous / hourHeight)
        let newHour = Int(offset / hourHeight)
        let lower = min(previous, offset)
        let upper = max(previous, offset)
        let boundaries = courseBoundaryOffsets(events: store.events, hourHeight: hourHeight)
        let crossedCourse = upper - lower < hourHeight * 2.5 && boundaries.contains { $0 > lower && $0 <= upper }

        if crossedCourse {
            HapticService.fire(.scrollCourse, enabled: store.hapticsEnabled)
        } else if oldHour != newHour {
            HapticService.fire(.scrollHour, enabled: store.hapticsEnabled)
        }

        lastScrollOffset = offset
    }
}

struct WeekTimelineCanvas: View {
    @Environment(CalendarStore.self) private var store

    let days: [Date]
    let events: [CalendarEvent]
    let now: Date
    let hourHeight: CGFloat
    let width: CGFloat
    let onSelect: (CalendarEvent) -> Void

    private let headerHeight: CGFloat = 48
    private let engine = EventLayoutEngine()

    var body: some View {
        let dayWidth = max(92, (width - timelineTimeWidth - 8) / CGFloat(max(days.count, 1)))

        ZStack(alignment: .topLeading) {
            weekGrid(dayWidth: dayWidth)

            ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
                let dayEvents = events.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
                let placements = engine.placements(for: dayEvents)

                ForEach(placements) { placement in
                    let laneWidth = dayWidth / CGFloat(placement.columnCount)
                    let x = CGFloat(dayIndex) * dayWidth + CGFloat(placement.column) * laneWidth + 2
                    let y = headerHeight + yPosition(for: placement.event.start, day: day)
                    let exactHeight = yPosition(for: placement.event.end, day: day)
                        - yPosition(for: placement.event.start, day: day)
                    let height = max(1, exactHeight)

                    CourseBlock(
                        event: placement.event,
                        availableWidth: max(36, laneWidth - 4),
                        height: height,
                        highlighted: store.highlightedEventID == placement.event.id,
                        forceCompact: true
                    )
                    .frame(width: max(36, laneWidth - 4), height: height)
                    .offset(x: x, y: y)
                    .onTapGesture { onSelect(placement.event) }
                }

                if Calendar.current.isDate(day, inSameDayAs: now) {
                    WeekCurrentTimeIndicator(
                        y: headerHeight + yPosition(for: now, day: day),
                        x: CGFloat(dayIndex) * dayWidth,
                        width: dayWidth
                    )
                }
            }
        }
        .frame(width: width, height: headerHeight + hourHeight * 24 + 28, alignment: .topLeading)
    }

    private func weekGrid(dayWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    Button {
                        store.focusedDate = Calendar.current.startOfDay(for: day)
                        store.setDisplayMode(.day)
                    } label: {
                        VStack(spacing: 2) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                            Text(day.formatted(.dateTime.day()))
                                .font(.headline.monospacedDigit())
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(
                            Calendar.current.isDate(day, inSameDayAs: now)
                                ? Color.accentColor
                                : Color.primary
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: dayWidth, height: headerHeight)
                }

                Color.clear.frame(width: timelineTimeWidth, height: headerHeight)
            }

            ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 6) {
                    ZStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.18))
                            .frame(height: 0.5)

                        HStack(spacing: 0) {
                            ForEach(days.indices, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.10))
                                    .frame(width: 0.5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Text(String(format: "%02d:00", hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: timelineTimeWidth - 6, alignment: .leading)
                }
                .frame(height: hourHeight, alignment: .top)
                .id("week-hour-\(hour)")
            }
        }
    }

    private func yPosition(for value: Date, day: Date) -> CGFloat {
        let start = Calendar.current.startOfDay(for: day)
        let minutes = value.timeIntervalSince(start) / 60
        return max(0, min(CGFloat(minutes) * hourHeight / 60, hourHeight * 24))
    }
}

struct HourRow: View {
    let hour: Int
    let height: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 0.5)

            Text(String(format: "%02d:00", hour))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: timelineTimeWidth - 7, alignment: .leading)
        }
        .frame(height: height, alignment: .top)
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
            let start = Calendar.current.startOfDay(for: now)
            let minutes = now.timeIntervalSince(start) / 60
            let y = max(0, min(CGFloat(minutes) * hourHeight / 60, hourHeight * 24))

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

struct WeekCurrentTimeIndicator: View {
    let y: CGFloat
    let x: CGFloat
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(Color.red).frame(width: 7, height: 7)
            Rectangle().fill(Color.red).frame(height: 1.5)
        }
        .frame(width: width, alignment: .leading)
        .offset(x: x - 3, y: y - 3)
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
        HStack(spacing: 5) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(event.start, style: .time)
                Spacer(minLength: 0)
                Text(event.end, style: .time)
            }
            .font(
                .system(
                    size: availableWidth < 115 ? 8 : 9,
                    weight: .semibold,
                    design: .rounded
                )
                .monospacedDigit()
            )
            .foregroundStyle(.secondary)
            .frame(width: availableWidth < 105 ? 28 : 35, alignment: .trailing)
            .padding(.vertical, min(6, max(1, height * 0.08)))

            Rectangle()
                .fill(eventColor.opacity(0.58))
                .frame(width: 2)
                .padding(.vertical, min(5, max(1, height * 0.08)))

            VStack(alignment: .leading, spacing: availableWidth > 190 ? 4 : 2) {
                HStack(spacing: 4) {
                    if let label = event.displayTypeLabel, !label.isEmpty {
                        Text(label)
                            .font(.system(size: forceCompact ? 8 : 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(eventColor.opacity(0.17), in: Capsule())
                    } else if event.source == .local {
                        Image(systemName: "person.crop.circle")
                            .font(.caption2)
                    }
                    Spacer(minLength: 0)
                }

                Text(event.title)
                    .font(titleFont)
                    .lineLimit(forceCompact || availableWidth < 130 ? 2 : 3)
                    .minimumScaleFactor(0.72)

                if height > 48, !event.room.isEmpty {
                    Label(event.room, systemImage: "mappin")
                        .font(metadataFont)
                        .lineLimit(1)
                }

                if !forceCompact, availableWidth >= 150, height > 70, !event.teachers.isEmpty {
                    Label(event.teachers.joined(separator: ", "), systemImage: "person")
                        .font(metadataFont)
                        .lineLimit(1)
                }

                if !forceCompact, availableWidth >= 180, height > 88, !event.groups.isEmpty {
                    Text(event.groups.map(\.name).joined(separator: " · "))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !forceCompact, availableWidth >= 210, height > 106, let module = event.moduleCode {
                    Text(module)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, min(6, max(1, height * 0.08)))
            .padding(.trailing, 6)
        }
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(eventColor.opacity(event.source == .local ? 0.10 : 0.13))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    highlighted ? Color.accentColor : eventColor.opacity(0.38),
                    lineWidth: highlighted ? 2.5 : 0.8
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var titleFont: Font {
        if forceCompact || availableWidth < 120 { return .caption2.weight(.bold) }
        if availableWidth < 180 { return .caption.weight(.bold) }
        return .subheadline.weight(.bold)
    }

    private var metadataFont: Font {
        forceCompact || availableWidth < 140 ? .caption2 : .caption
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

private extension Color {
    init(courslyHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        } else {
            red = 0
            green = 122.0 / 255.0
            blue = 1
        }

        self.init(red: red, green: green, blue: blue)
    }
}

private func courseBoundaryOffsets(events: [CalendarEvent], hourHeight: CGFloat) -> [CGFloat] {
    events.flatMap { event -> [CGFloat] in
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: event.start)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: event.end)

        func offset(_ components: DateComponents) -> CGFloat {
            let minutes = CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0))
                + CGFloat(components.second ?? 0) / 60
            return minutes * hourHeight / 60
        }

        return [offset(startComponents), offset(endComponents)]
    }
    .sorted()
}
