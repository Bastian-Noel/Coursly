import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    private static var revision = 0

    static var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    static var hasActiveActivity: Bool { !Activity<CourslyActivityAttributes>.activities.isEmpty }

    static func update(
        events: [CalendarEvent],
        now: Date = .now,
        enabled: Bool,
        typeColors: [String: String] = [:]
    ) async {
        revision += 1
        let updateRevision = revision

        guard enabled else {
            await endActivities(now: now, immediate: false)
            return
        }
        guard areActivitiesEnabled else { return }

        let ordered = events.filter { $0.end > $0.start }
            .sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }

        guard !ordered.isEmpty else {
            await endActivities(now: now, immediate: true)
            return
        }

        let systemNow = Date()
        let timerOffset = systemNow.timeIntervalSince(now)
        func timerDate(_ date: Date) -> Date { date.addingTimeInterval(timerOffset) }
        func accentHex(for event: CalendarEvent) -> String {
            guard let label = event.colorTypeLabel else { return "#6E6E73" }
            return typeColors[label] ?? CourseTypeColorPreferences.hex(for: label)
        }
        func teachers(for event: CalendarEvent) -> String { event.teachers.joined(separator: " · ") }
        func groups(for event: CalendarEvent) -> String { event.displayGroupsText }

        let primaryIndex: Int
        let initiallyInProgress: Bool
        let initialStatus: String

        if let current = ordered.firstIndex(where: { $0.start <= now && now < $0.end }) {
            primaryIndex = current
            initiallyInProgress = true
            let remaining = ordered[current].end.timeIntervalSince(now)
            initialStatus = current == ordered.index(before: ordered.endIndex)
                ? "DERNIER COURS"
                : (remaining <= 20 * 60 ? "BIENTÔT TERMINÉ" : "EN COURS")
        } else if let upcoming = ordered.firstIndex(where: { $0.start > now }) {
            primaryIndex = upcoming
            initiallyInProgress = false
            initialStatus = ordered[..<upcoming].contains(where: { $0.end <= now }) ? "PAUSE" : "PREMIER COURS"
        } else {
            await finishDay(now: now, revision: updateRevision)
            return
        }

        let primary = ordered[primaryIndex]
        let nextIndex = ordered.index(after: primaryIndex)
        let next = nextIndex < ordered.endIndex ? ordered[nextIndex] : nil
        let timerStart = timerDate(primary.start)
        let timerEnd = timerDate(primary.end)
        let nextTimerStart = next.map { timerDate($0.start) }
        let nextTimerEnd = next.map { timerDate($0.end) }

        let state = CourslyActivityAttributes.ContentState(
            status: initialStatus,
            title: primary.title,
            room: primary.room,
            teachers: teachers(for: primary),
            groups: groups(for: primary),
            type: primary.displayTypeLabel,
            accentHex: accentHex(for: primary),
            start: primary.start,
            end: primary.end,
            timerStart: timerStart,
            timerEnd: timerEnd,
            nextTitle: next?.title,
            nextRoom: next?.room,
            nextType: next?.displayTypeLabel,
            nextAccentHex: next.map(accentHex),
            nextStart: next?.start,
            nextEnd: next?.end,
            nextTeachers: next.map(teachers),
            nextGroups: next.map(groups),
            nextTimerStart: nextTimerStart,
            nextTimerEnd: nextTimerEnd,
            isLastCourse: next == nil,
            nextIsLastCourse: next.map { _ in nextIndex == ordered.index(before: ordered.endIndex) },
            isInProgress: initiallyInProgress,
            dayFinished: false
        )

        let lifecycleEnd = nextTimerEnd ?? timerEnd
        await publish(
            state: state,
            dayDate: primary.start,
            staleDate: lifecycleEnd.addingTimeInterval(15 * 60),
            revision: updateRevision
        )
    }

    static func restart(
        events: [CalendarEvent],
        now: Date = .now,
        typeColors: [String: String] = [:]
    ) async {
        revision += 1
        await endActivities(now: now, immediate: true)
        await update(events: events, now: now, enabled: true, typeColors: typeColors)
    }

    static func endAll(now: Date = .now, immediate: Bool = false) async {
        revision += 1
        await endActivities(now: now, immediate: immediate)
    }

    private static func endActivities(now: Date, immediate: Bool) async {
        let systemNow = Date()
        let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .after(systemNow.addingTimeInterval(60))
        for activity in Activity<CourslyActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: policy)
        }
    }

    private static func publish(
        state: CourslyActivityAttributes.ContentState,
        dayDate: Date,
        staleDate: Date,
        revision updateRevision: Int
    ) async {
        guard updateRevision == revision else { return }
        let content = ActivityContent(state: state, staleDate: staleDate, relevanceScore: 90)

        if let activity = Activity<CourslyActivityAttributes>.activities.first {
            await activity.update(content)
            guard updateRevision == revision else { return }
            for extra in Activity<CourslyActivityAttributes>.activities.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        guard updateRevision == revision else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        _ = try? Activity<CourslyActivityAttributes>.request(
            attributes: CourslyActivityAttributes(dayID: formatter.string(from: dayDate)),
            content: content,
            pushType: nil
        )
    }

    private static func finishDay(now: Date, revision updateRevision: Int) async {
        guard updateRevision == revision, !Activity<CourslyActivityAttributes>.activities.isEmpty else { return }
        let systemNow = Date()
        let state = CourslyActivityAttributes.ContentState(
            status: "JOURNÉE TERMINÉE", title: "Cours terminés", room: "", teachers: "", groups: "",
            type: nil, accentHex: "#34C759", start: now, end: now, timerStart: systemNow, timerEnd: systemNow,
            nextTitle: nil, nextRoom: nil, nextType: nil, nextAccentHex: nil, nextStart: nil, nextEnd: nil,
            nextTeachers: nil, nextGroups: nil, nextTimerStart: nil, nextTimerEnd: nil,
            isLastCourse: true, nextIsLastCourse: nil, isInProgress: false, dayFinished: true
        )
        let content = ActivityContent(state: state, staleDate: systemNow.addingTimeInterval(15 * 60), relevanceScore: 10)
        for activity in Activity<CourslyActivityAttributes>.activities {
            await activity.end(content, dismissalPolicy: .after(systemNow.addingTimeInterval(15 * 60)))
        }
    }
}
