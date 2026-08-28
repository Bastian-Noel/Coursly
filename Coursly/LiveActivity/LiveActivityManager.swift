import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    static var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    static var hasActiveActivity: Bool { !Activity<CourslyActivityAttributes>.activities.isEmpty }

    static func update(
        events: [CalendarEvent],
        now: Date = .now,
        enabled: Bool,
        typeColors: [String: String] = [:]
    ) async {
        guard enabled else {
            await endAll(now: now)
            return
        }
        guard areActivitiesEnabled else { return }

        let ordered = events
            .filter { $0.end > $0.start }
            .sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }

        guard !ordered.isEmpty else {
            await endAll(now: now, immediate: true)
            return
        }

        let systemNow = Date()
        let timerOffset = systemNow.timeIntervalSince(now)
        func timerDate(_ date: Date) -> Date { date.addingTimeInterval(timerOffset) }
        func accentHex(for event: CalendarEvent) -> String {
            guard let label = event.displayTypeLabel else { return "#6E6E73" }
            return typeColors[label] ?? CourseTypeColorPreferences.hex(for: label)
        }
        func teachers(for event: CalendarEvent) -> String {
            event.teachers.joined(separator: " · ")
        }
        func groups(for event: CalendarEvent) -> String {
            event.displayGroupsText
        }

        if let currentIndex = ordered.firstIndex(where: { $0.start <= now && now < $0.end }) {
            let current = ordered[currentIndex]
            let next = ordered.dropFirst(currentIndex + 1).first
            let isLast = next == nil
            let remaining = current.end.timeIntervalSince(now)
            let showNext = remaining <= 30 * 60
            let status = isLast ? "DERNIER COURS" : (remaining <= 20 * 60 ? "BIENTÔT TERMINÉ" : "EN COURS")
            let timerStart = timerDate(current.start)
            let timerEnd = timerDate(current.end)

            let state = CourslyActivityAttributes.ContentState(
                status: status,
                title: current.title,
                room: current.room,
                teachers: teachers(for: current),
                groups: groups(for: current),
                type: current.displayTypeLabel,
                accentHex: accentHex(for: current),
                start: current.start,
                end: current.end,
                timerStart: timerStart,
                timerEnd: timerEnd,
                nextTitle: showNext ? next?.title : nil,
                nextRoom: showNext ? next?.room : nil,
                nextType: showNext ? next?.displayTypeLabel : nil,
                nextAccentHex: showNext ? next.map { accentHex(for: $0) } : nil,
                nextStart: showNext ? next?.start : nil,
                isInProgress: true,
                dayFinished: false
            )
            await publish(state: state, dayDate: current.start, staleDate: timerEnd)
            return
        }

        if let upcomingIndex = ordered.firstIndex(where: { $0.start > now }) {
            let upcoming = ordered[upcomingIndex]
            let hasCompletedCourseBefore = ordered[..<upcomingIndex].contains { $0.end <= now }
            let timerStart = timerDate(upcoming.start)
            let timerEnd = timerDate(upcoming.end)
            let state = CourslyActivityAttributes.ContentState(
                status: hasCompletedCourseBefore ? "PAUSE" : "PREMIER COURS",
                title: upcoming.title,
                room: upcoming.room,
                teachers: teachers(for: upcoming),
                groups: groups(for: upcoming),
                type: upcoming.displayTypeLabel,
                accentHex: accentHex(for: upcoming),
                start: upcoming.start,
                end: upcoming.end,
                timerStart: timerStart,
                timerEnd: timerEnd,
                nextTitle: nil,
                nextRoom: nil,
                nextType: nil,
                nextAccentHex: nil,
                nextStart: nil,
                isInProgress: false,
                dayFinished: false
            )
            await publish(state: state, dayDate: upcoming.start, staleDate: timerStart)
            return
        }

        await finishDay(now: now)
    }

    static func restart(
        events: [CalendarEvent],
        now: Date = .now,
        typeColors: [String: String] = [:]
    ) async {
        await endAll(now: now, immediate: true)
        await update(events: events, now: now, enabled: true, typeColors: typeColors)
    }

    static func endAll(now: Date = .now, immediate: Bool = false) async {
        let systemNow = Date()
        let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .after(systemNow.addingTimeInterval(60))
        for activity in Activity<CourslyActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: policy)
        }
    }

    private static func publish(
        state: CourslyActivityAttributes.ContentState,
        dayDate: Date,
        staleDate: Date
    ) async {
        let content = ActivityContent(state: state, staleDate: staleDate)

        if let activity = Activity<CourslyActivityAttributes>.activities.first {
            await activity.update(content)
            for extra in Activity<CourslyActivityAttributes>.activities.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        _ = try? Activity<CourslyActivityAttributes>.request(
            attributes: CourslyActivityAttributes(dayID: formatter.string(from: dayDate)),
            content: content,
            pushType: nil
        )
    }

    private static func finishDay(now: Date) async {
        guard !Activity<CourslyActivityAttributes>.activities.isEmpty else { return }
        let systemNow = Date()
        let state = CourslyActivityAttributes.ContentState(
            status: "JOURNÉE TERMINÉE",
            title: "Cours terminés",
            room: "",
            teachers: "",
            groups: "",
            type: nil,
            accentHex: "#34C759",
            start: now,
            end: now,
            timerStart: systemNow,
            timerEnd: systemNow,
            nextTitle: nil,
            nextRoom: nil,
            nextType: nil,
            nextAccentHex: nil,
            nextStart: nil,
            isInProgress: false,
            dayFinished: true
        )
        let content = ActivityContent(state: state, staleDate: systemNow)
        for activity in Activity<CourslyActivityAttributes>.activities {
            await activity.end(content, dismissalPolicy: .after(systemNow.addingTimeInterval(15 * 60)))
        }
    }
}
