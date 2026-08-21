import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    static var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    static var hasActiveActivity: Bool { !Activity<CourslyActivityAttributes>.activities.isEmpty }

    static func update(events: [CalendarEvent], now: Date = .now, enabled: Bool) async {
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

        if let currentIndex = ordered.firstIndex(where: { $0.start <= now && now < $0.end }) {
            let current = ordered[currentIndex]
            let next = ordered.dropFirst(currentIndex + 1).first
            let isLast = next == nil
            let remaining = current.end.timeIntervalSince(now)
            let showNext = remaining <= 30 * 60

            let state = CourslyActivityAttributes.ContentState(
                status: isLast ? "DERNIER COURS" : "EN COURS",
                title: current.title,
                room: current.room,
                type: current.type?.rawValue,
                start: current.start,
                end: current.end,
                nextTitle: showNext ? next?.title : nil,
                nextRoom: showNext ? next?.room : nil,
                nextStart: showNext ? next?.start : nil,
                isInProgress: true,
                dayFinished: false
            )
            await publish(state: state, dayDate: current.start, staleDate: current.end)
            return
        }

        if let upcomingIndex = ordered.firstIndex(where: { $0.start > now }) {
            let upcoming = ordered[upcomingIndex]
            let hasCompletedCourseBefore = ordered[..<upcomingIndex].contains { $0.end <= now }
            let state = CourslyActivityAttributes.ContentState(
                status: hasCompletedCourseBefore ? "PAUSE" : "PREMIER COURS",
                title: upcoming.title,
                room: upcoming.room,
                type: upcoming.type?.rawValue,
                start: upcoming.start,
                end: upcoming.end,
                nextTitle: nil,
                nextRoom: nil,
                nextStart: nil,
                isInProgress: false,
                dayFinished: false
            )
            await publish(state: state, dayDate: upcoming.start, staleDate: upcoming.start)
            return
        }

        await finishDay(now: now)
    }

    static func restart(events: [CalendarEvent], now: Date = .now) async {
        await endAll(now: now, immediate: true)
        await update(events: events, now: now, enabled: true)
    }

    static func endAll(now: Date = .now, immediate: Bool = false) async {
        let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .after(now.addingTimeInterval(60))
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
        let state = CourslyActivityAttributes.ContentState(
            status: "JOURNÉE TERMINÉE",
            title: "Cours terminés",
            room: "",
            type: nil,
            start: now,
            end: now,
            nextTitle: nil,
            nextRoom: nil,
            nextStart: nil,
            isInProgress: false,
            dayFinished: true
        )
        let content = ActivityContent(state: state, staleDate: now)
        for activity in Activity<CourslyActivityAttributes>.activities {
            await activity.end(content, dismissalPolicy: .after(now.addingTimeInterval(15 * 60)))
        }
    }
}
