import SwiftUI

struct TimetableGrid: View {
    let days: [Date]
    let events: [CalendarEvent]
    let now: Date
    let startHour: Int
    let endHour: Int

    private let calendar = Calendar.current
    private let timeColumnWidth: CGFloat = 48
    private let headerHeight: CGFloat = 42
    private let hourHeight: CGFloat = 78

    var body: some View {
        GeometryReader { proxy in
            let dayWidth = resolvedDayWidth(availableWidth: proxy.size.width)
            let contentWidth = timeColumnWidth + dayWidth * CGFloat(days.count)
            let contentHeight = headerHeight + CGFloat(max(endHour - startHour, 1)) * hourHeight

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    gridBackground(dayWidth: dayWidth, contentWidth: contentWidth, contentHeight: contentHeight)
                    hourLabels(contentHeight: contentHeight)
                    dayHeaders(dayWidth: dayWidth)
                    eventLayers(dayWidth: dayWidth)
                    currentTimeLayer(dayWidth: dayWidth)
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func resolvedDayWidth(availableWidth: CGFloat) -> CGFloat {
        if days.count == 1 {
            return max(availableWidth - timeColumnWidth, 260)
        }
        return 142
    }

    @ViewBuilder
    private func gridBackground(dayWidth: CGFloat, contentWidth: CGFloat, contentHeight: CGFloat) -> some View {
        Canvas { context, _ in
            var path = Path()

            for hour in startHour...endHour {
                let y = headerHeight + CGFloat(hour - startHour) * hourHeight
                path.move(to: CGPoint(x: timeColumnWidth, y: y))
                path.addLine(to: CGPoint(x: contentWidth, y: y))
            }

            for index in 0...days.count {
                let x = timeColumnWidth + CGFloat(index) * dayWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: contentHeight))
            }

            context.stroke(path, with: .color(Color.secondary.opacity(0.18)), lineWidth: 0.7)
        }
    }

    @ViewBuilder
    private func hourLabels(contentHeight: CGFloat) -> some View {
        ForEach(startHour..<endHour, id: \.self) { hour in
            Text(String(format: "%02d:00", hour))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth - 7, alignment: .trailing)
                .position(
                    x: (timeColumnWidth - 7) / 2,
                    y: headerHeight + CGFloat(hour - startHour) * hourHeight + 7
                )
        }
    }

    @ViewBuilder
    private func dayHeaders(dayWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
            VStack(spacing: 1) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                Text(day.formatted(.dateTime.day()))
                    .font(.headline.monospacedDigit())
            }
            .foregroundStyle(calendar.isDate(day, inSameDayAs: now) ? Color.accentColor : Color.primary)
            .frame(width: dayWidth, height: headerHeight)
            .position(
                x: timeColumnWidth + CGFloat(index) * dayWidth + dayWidth / 2,
                y: headerHeight / 2
            )
        }
    }

    @ViewBuilder
    private func eventLayers(dayWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            let placements = placements(for: events.filter { calendar.isDate($0.start, inSameDayAs: day) })

            ForEach(placements) { placement in
                let startMinute = minutesFromMidnight(placement.event.start)
                let endMinute = minutesFromMidnight(placement.event.end)
                let visibleStart = max(startMinute, startHour * 60)
                let visibleEnd = min(endMinute, endHour * 60)

                if visibleEnd > visibleStart {
                    let top = headerHeight + CGFloat(visibleStart - startHour * 60) / 60 * hourHeight
                    let height = max(CGFloat(visibleEnd - visibleStart) / 60 * hourHeight, 26)
                    let laneWidth = (dayWidth - 8) / CGFloat(max(placement.laneCount, 1))
                    let width = max(laneWidth - 4, 34)
                    let left = timeColumnWidth
                        + CGFloat(dayIndex) * dayWidth
                        + 4
                        + CGFloat(placement.lane) * laneWidth

                    NavigationLink(value: placement.event) {
                        TimetableEventCell(event: placement.event, compact: placement.laneCount > 1)
                    }
                    .buttonStyle(.plain)
                    .frame(width: width, height: height)
                    .position(x: left + width / 2, y: top + height / 2)
                }
            }
        }
    }

    @ViewBuilder
    private func currentTimeLayer(dayWidth: CGFloat) -> some View {
        let minute = minutesFromMidnight(now)

        if minute >= startHour * 60,
           minute <= endHour * 60,
           let dayIndex = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: now) }) {
            let y = headerHeight + CGFloat(minute - startHour * 60) / 60 * hourHeight
            let x = timeColumnWidth + CGFloat(dayIndex) * dayWidth

            Rectangle()
                .fill(Color.red)
                .frame(width: dayWidth, height: 1.5)
                .position(x: x + dayWidth / 2, y: y)

            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .position(x: x + 3.5, y: y)
        }
    }

    private func minutesFromMidnight(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func placements(for input: [CalendarEvent]) -> [Placement] {
        let sorted = input.sorted {
            if $0.start == $1.start { return $0.end < $1.end }
            return $0.start < $1.start
        }

        var result: [Placement] = []
        var cluster: [CalendarEvent] = []
        var clusterEnd: Date?

        func appendCluster(_ events: [CalendarEvent], to result: inout [Placement]) {
            guard !events.isEmpty else { return }
            var laneEnds: [Date] = []
            var raw: [(CalendarEvent, Int)] = []

            for event in events {
                if let lane = laneEnds.firstIndex(where: { $0 <= event.start }) {
                    laneEnds[lane] = event.end
                    raw.append((event, lane))
                } else {
                    laneEnds.append(event.end)
                    raw.append((event, laneEnds.count - 1))
                }
            }

            let count = max(laneEnds.count, 1)
            result.append(contentsOf: raw.map { Placement(event: $0.0, lane: $0.1, laneCount: count) })
        }

        for event in sorted {
            if let end = clusterEnd, event.start >= end {
                appendCluster(cluster, to: &result)
                cluster = [event]
                clusterEnd = event.end
            } else {
                cluster.append(event)
                clusterEnd = max(clusterEnd ?? event.end, event.end)
            }
        }

        appendCluster(cluster, to: &result)
        return result
    }
}

private struct Placement: Identifiable {
    let event: CalendarEvent
    let lane: Int
    let laneCount: Int
    var id: String { "\(event.id)-\(lane)" }
}

private struct TimetableEventCell: View {
    let event: CalendarEvent
    let compact: Bool

    private var tint: Color {
        switch event.type {
        case .cm: .blue
        case .td: .indigo
        case .tp: .mint
        case .project: .orange
        case .integration: .cyan
        case .meeting: .purple
        case .test, .exam: .red
        case nil: .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            HStack(spacing: 4) {
                if let type = event.type {
                    Text(type.rawValue)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                }
                Spacer(minLength: 0)
                Text(event.start.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
            }
            .foregroundStyle(tint)

            Text(event.title)
                .font(.system(size: compact ? 10 : 12, weight: .bold, design: .rounded))
                .lineLimit(compact ? 2 : 3)
                .minimumScaleFactor(0.78)

            if !event.room.isEmpty {
                Label(event.room, systemImage: "mappin")
                    .font(.system(size: compact ? 8 : 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !compact, event.groups.count > 1 {
                Text(event.groups.map(\.name).joined(separator: " · "))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(compact ? 5 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .glassEffect(.regular.tint(tint.opacity(0.10)).interactive(), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule()
                .fill(tint)
                .frame(width: 3)
                .padding(.vertical, 5)
        }
        .contentShape(Rectangle())
    }
}
