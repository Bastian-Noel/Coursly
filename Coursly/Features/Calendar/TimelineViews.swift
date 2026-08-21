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
        let sorted = events.sorted {
            if $0.startDate == $1.startDate { return $0.endDate < $1.endDate }
            return $0.startDate < $1.startDate
        }
        var active: [(event: CalendarEvent, column: Int)] = []
        var result: [EventPlacement] = []
        var clusterIndices: [Int] = []
        var clusterMaxColumns = 1

        func closeCluster() {
            for index in clusterIndices {
                let item = result[index]
                result[index] = EventPlacement(event: item.event, column: item.column, columnCount: clusterMaxColumns)
            }
            clusterIndices.removeAll()
            clusterMaxColumns = 1
        }

        for event in sorted {
            active.removeAll { $0.event.endDate <= event.startDate }
            if active.isEmpty, !clusterIndices.isEmpty { closeCluster() }
            let used = Set(active.map(\.column))
            let column = (0...).first { !used.contains($0) } ?? 0
            active.append((event, column))
            clusterMaxColumns = max(clusterMaxColumns, active.count, column + 1)
            result.append(EventPlacement(event: event, column: column, columnCount: clusterMaxColumns))
            clusterIndices.append(result.count - 1)
        }
        if !clusterIndices.isEmpty { closeCluster() }
        return result
    }
}

struct DayTimelineView: View {
    let date: Date
    let events: [CalendarEvent]
    let now: Date
    let hourHeight: CGFloat
    var hapticsEnabled = true
    var horizontalOffset: CGFloat = 0
    var onSelect: (CalendarEvent) -> Void
    var onSwipeDay: (Int) -> Void

    @State private var lastHapticHour: Int?
    @State private var crossedBoundaries = Set<String>()

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        timelineGrid
                        eventLayer(width: viewport.size.width)
                        currentTimeLine(width: viewport.size.width)
                    }
                    .frame(height: hourHeight * 24)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: TimelineScrollOffsetKey.self,
                                value: geometry.frame(in: .named("day-timeline-scroll")).minY
                            )
                        }
                    )
                    .id("timeline")
                }
                .coordinateSpace(name: "day-timeline-scroll")
                .scrollIndicators(.hidden)
                .onPreferenceChange(TimelineScrollOffsetKey.self) { offset in
                    handleScrollHaptics(offset: offset)
                }
                .onAppear {
                    scrollToRelevantTime(proxy: proxy)
                }
            }
        }
        .offset(x: horizontalOffset)
        .contentShape(Rectangle())
        .simultaneousGesture(daySwipeGesture)
    }

    private var timelineGrid: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - timelineTimeWidth)
            ZStack(alignment: .topLeading) {
                ForEach(0...24, id: \.self) { hour in
                    let y = CGFloat(hour) * hourHeight
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: contentWidth, y: y))
                    }
                    .stroke(.secondary.opacity(hour % 3 == 0 ? 0.30 : 0.16), lineWidth: hour % 3 == 0 ? 1 : 0.6)

                    Text(String(format: "%02d:00", hour % 24))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: timelineTimeWidth - 8, alignment: .leading)
                        .position(x: contentWidth + (timelineTimeWidth / 2), y: min(max(9, y), hourHeight * 24 - 9))
                }
            }
        }
    }

    private func eventLayer(width: CGFloat) -> some View {
        let placements = EventLayoutEngine().placements(for: events)
        let contentWidth = max(1, width - timelineTimeWidth)
        return ZStack(alignment: .topLeading) {
            ForEach(placements) { placement in
                let top = yPosition(for: placement.event.startDate)
                let bottom = yPosition(for: placement.event.endDate)
                let height = max(1, bottom - top)
                let gutter: CGFloat = 4
                let columnWidth = max(1, (contentWidth - gutter * CGFloat(max(0, placement.columnCount - 1))) / CGFloat(placement.columnCount))
                EventCard(event: placement.event, compact: placement.columnCount > 1)
                    .frame(width: columnWidth, height: height)
                    .offset(x: CGFloat(placement.column) * (columnWidth + gutter), y: top)
                    .onTapGesture { onSelect(placement.event) }
            }
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    @ViewBuilder
    private func currentTimeLine(width: CGFloat) -> some View {
        if calendar.isDate(date, inSameDayAs: now) {
            let y = yPosition(for: now)
            let contentWidth = max(1, width - timelineTimeWidth)
            HStack(spacing: 0) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Rectangle().fill(.red).frame(height: 1.5)
            }
            .frame(width: contentWidth)
            .offset(y: y - 4)
            .allowsHitTesting(false)
        }
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.15,
                      abs(value.translation.width) > 64 else { return }
                onSwipeDay(value.translation.width < 0 ? 1 : -1)
            }
    }

    private func yPosition(for date: Date) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = CGFloat((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
        return seconds / 3600 * hourHeight
    }

    private func scrollToRelevantTime(proxy: ScrollViewProxy) {
        guard calendar.isDate(date, inSameDayAs: now) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.35)) {
                proxy.scrollTo("timeline", anchor: UnitPoint(x: 0.5, y: min(1, max(0, yPosition(for: now) / (hourHeight * 24)))))
            }
        }
    }

    private func handleScrollHaptics(offset: CGFloat) {
        guard hapticsEnabled else { return }
        let visibleY = max(0, -offset)
        let hour = Int(visibleY / hourHeight)
        if lastHapticHour != hour {
            if lastHapticHour != nil { HapticService.selection(enabled: true) }
            lastHapticHour = hour
        }

        let threshold: CGFloat = 8
        for event in events {
            for (suffix, boundary) in [("start", yPosition(for: event.startDate)), ("end", yPosition(for: event.endDate))] {
                let key = "\(event.id)-\(suffix)"
                if abs(boundary - visibleY) <= threshold {
                    if !crossedBoundaries.contains(key) {
                        crossedBoundaries.insert(key)
                        HapticService.soft(enabled: true)
                    }
                } else if abs(boundary - visibleY) > threshold * 2 {
                    crossedBoundaries.remove(key)
                }
            }
        }
    }
}

struct EventCard: View {
    let event: CalendarEvent
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(event.startDate, format: .dateTime.hour().minute())
                .font(.caption2.monospacedDigit().weight(.semibold))
            Text(event.title)
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(compact ? 2 : 3)
            if !compact {
                if let type = event.displayTypeLabel, !type.isEmpty {
                    Text(type).font(.caption2.weight(.bold))
                }
                if let room = event.room, !room.isEmpty {
                    Text(room).font(.caption).lineLimit(1)
                }
                if let teacher = event.teacher, !teacher.isEmpty {
                    Text(teacher).font(.caption2).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(event.endDate, format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit().weight(.semibold))
            }
        }
        .padding(compact ? 5 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(eventColor.opacity(0.20), in: RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous)
                .stroke(eventColor.opacity(0.72), lineWidth: 1)
        }
        .clipped()
        .contentShape(Rectangle())
    }

    private var eventColor: Color {
        if event.source == .local { return Color.purple }
        guard let type = event.type else { return Color.accentColor }
        switch type {
        case .cm: return Color.blue
        case .td: return Color.indigo
        case .tp: return Color.green
        case .project: return Color.orange
        case .integration: return Color.teal
        case .meeting: return Color.purple
        case .test, .exam: return Color.red
        }
    }
}
