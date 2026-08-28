import SwiftUI

enum TimelineMetrics {
    static let timeColumnWidth: CGFloat = 44
    static let weekHeaderHeight: CGFloat = 54
    static let courseBottomGap: CGFloat = 4
    static let parallelCourseGap: CGFloat = 2
    static let floatingDockClearance: CGFloat = 132
}

enum TimelineAxis {
    static func minute(of date: Date) -> Int {
        let components = courslyCalendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func y(for date: Date, hourHeight: CGFloat) -> CGFloat {
        let components = courslyCalendar.dateComponents([.hour, .minute, .second], from: date)
        let minutes = CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0))
            + CGFloat(components.second ?? 0) / 60
        return y(forMinute: Double(minutes), hourHeight: hourHeight)
    }

    static func y(forMinute minute: Double, hourHeight: CGFloat) -> CGFloat {
        max(0, min(CGFloat(minute) * hourHeight / 60, hourHeight * 24))
    }

    static func minute(forContentOffset offset: CGFloat, headerHeight: CGFloat = 0, hourHeight: CGFloat) -> Int {
        let timelineOffset = max(0, offset - headerHeight)
        return max(0, min(24 * 60, Int((timelineOffset / hourHeight * 60).rounded())))
    }

    static func pinnedHeaderOffset(forContentOffset offset: CGFloat) -> CGFloat {
        max(0, offset)
    }

    static func contentOffset(
        forMinute minute: Int,
        anchor: TimelineVerticalAnchor,
        headerHeight: CGFloat = 0,
        hourHeight: CGFloat,
        viewportHeight: CGFloat,
        footerHeight: CGFloat = TimelineMetrics.floatingDockClearance
    ) -> CGFloat {
        let position = headerHeight + y(forMinute: Double(minute), hourHeight: hourHeight)
        let proposed = switch anchor {
        case .top: position
        case .center: position - viewportHeight / 2
        }
        let contentHeight = headerHeight + hourHeight * 24 + 1 + footerHeight
        let maximumOffset = max(0, contentHeight - viewportHeight)
        return max(0, min(proposed, maximumOffset))
    }
}

enum TimelineVerticalAnchor: Equatable {
    case top
    case center
}

/// Empêche les mesures transitoires de SwiftUI (souvent zéro au premier layout)
/// de devenir la position verticale mémorisée de l’utilisateur.
struct TimelineVerticalScrollState: Equatable {
    private(set) var expectedOffset: CGFloat?
    private(set) var isUserControlled = false

    mutating func beginRestoration(to offset: CGFloat) {
        expectedOffset = max(0, offset)
        isUserControlled = false
    }

    mutating func observe(offset: CGFloat, tolerance: CGFloat = 2) -> Bool {
        guard let expectedOffset else { return isUserControlled }
        guard abs(max(0, offset) - expectedOffset) <= tolerance else { return false }
        self.expectedOffset = nil
        isUserControlled = true
        return true
    }
}

struct EventPlacement: Identifiable, Equatable {
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
            let columnCount = max(1, columnEnds.count)
            output.append(contentsOf: assignments.map {
                EventPlacement(event: $0.0, column: $0.1, columnCount: columnCount)
            })
            cluster.removeAll(keepingCapacity: true)
            clusterEnd = nil
        }

        for event in ordered {
            if let clusterEnd, event.start >= clusterEnd { flush() }
            cluster.append(event)
            clusterEnd = max(clusterEnd ?? event.end, event.end)
        }
        flush()
        return output
    }
}

struct TimelineHourGrid: View {
    let hourHeight: CGFloat
    var showHalfHours = true

    var body: some View {
        Canvas { context, size in
            for hour in 0...24 {
                let y = CGFloat(hour) * hourHeight
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.secondary.opacity(hour % 3 == 0 ? 0.25 : 0.16)), lineWidth: hour % 3 == 0 ? 0.8 : 0.55)

                guard showHalfHours, hour < 24 else { continue }
                var halfPath = Path()
                halfPath.move(to: CGPoint(x: 0, y: y + hourHeight / 2))
                halfPath.addLine(to: CGPoint(x: size.width, y: y + hourHeight / 2))
                context.stroke(halfPath, with: .color(.secondary.opacity(0.07)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .frame(height: hourHeight * 24 + 1)
    }
}

struct TimelineTimeColumn: View {
    let hourHeight: CGFloat
    var headerHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: headerHeight)
            ZStack(alignment: .topLeading) {
                ForEach(0...24, id: \.self) { hour in
                    Text(String(format: "%02d", hour % 24))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: TimelineMetrics.timeColumnWidth - 10, height: 16, alignment: .trailing)
                        .position(x: (TimelineMetrics.timeColumnWidth - 10) / 2, y: CGFloat(hour) * hourHeight)
                }
            }
            .frame(height: hourHeight * 24 + 1)
        }
        .frame(width: TimelineMetrics.timeColumnWidth)
    }
}

struct TimelineDayBackground: View {
    enum PastEmphasis { case day, week }

    let isPastDay: Bool
    var pastEmphasis: PastEmphasis = .week

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.82)
            if isPastDay {
                Color(.secondarySystemBackground)
                Color.black.opacity(pastEmphasis == .day ? 0.13 : 0.08)
            }
        }
            .allowsHitTesting(false)
    }
}

struct TimelineCurrentTimeIndicator: View {
    @Environment(CalendarStore.self) private var store
    let hourHeight: CGFloat
    let width: CGFloat
    var leadingDot = true
    var showsLine = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let y = TimelineAxis.y(for: store.effectiveNow(from: context.date), hourHeight: hourHeight)
            HStack(spacing: 0) {
                if leadingDot {
                    Circle().fill(.red).frame(width: 8, height: 8)
                }
                if showsLine {
                    Rectangle().fill(.red).frame(height: 1.5)
                }
            }
            .frame(width: width, alignment: .leading)
            .offset(
                x: leadingDot ? -4 : 0,
                y: y - (leadingDot ? 4 : 0.75)
            )
            .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}

let courslyCalendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.locale = Locale(identifier: "fr_FR")
    value.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
    return value
}()

func timelineDayID(_ date: Date) -> String {
    "timeline-day-\(Int(courslyCalendar.startOfDay(for: date).timeIntervalSince1970))"
}

func capitalizedWeekday(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.timeZone = courslyCalendar.timeZone
    formatter.dateFormat = "EEE"
    let value = formatter.string(from: date)
    return value.prefix(1).uppercased() + value.dropFirst()
}

func shortTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.timeZone = courslyCalendar.timeZone
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

func courseBoundaryOffsets(events: [CalendarEvent], hourHeight: CGFloat) -> [CGFloat] {
    events.flatMap {
        [TimelineAxis.y(for: $0.start, hourHeight: hourHeight), TimelineAxis.y(for: $0.end, hourHeight: hourHeight)]
    }.sorted()
}
