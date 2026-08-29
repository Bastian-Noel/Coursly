import ActivityKit
import Foundation

enum LiveActivitySchedule {
    private static var parisCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    static func orderedEvents(from events: [CalendarEvent]) -> [CalendarEvent] {
        let sorted = events.filter { $0.end > $0.start }
            .sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
        return sorted.reduce(into: [CalendarEvent]()) { unique, event in
            guard !unique.contains(where: { $0.isSameVisualCourse(as: event) }) else { return }
            unique.append(event)
        }
    }

    static func nextIndex(after index: Int, in events: [CalendarEvent]) -> Int? {
        guard events.indices.contains(index) else { return nil }
        return events.indices.dropFirst(index + 1).first {
            events[$0].start >= events[index].end
        }
    }

    static func relevantEvents(from events: [CalendarEvent], now: Date) -> [CalendarEvent] {
        let start = parisCalendar.startOfDay(for: now)
        let end = parisCalendar.date(byAdding: .day, value: 2, to: start)!
        return events.filter { $0.end > start && $0.start < end }
    }

    static func upcomingStatus(previous: CalendarEvent?, upcoming: CalendarEvent, now: Date) -> String {
        let today = parisCalendar.startOfDay(for: now)
        let upcomingDay = parisCalendar.startOfDay(for: upcoming.start)
        if upcomingDay > today {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.timeZone = parisCalendar.timeZone
            formatter.dateFormat = "HH'h'mm"
            return "PROCHAIN COURS DEMAIN À \(formatter.string(from: upcoming.start))"
        }
        guard let previous,
              parisCalendar.isDate(previous.end, inSameDayAs: upcoming.start) else {
            return "PREMIER COURS"
        }
        return "EN PAUSE"
    }

    static func pauseInterval(previous: CalendarEvent?, upcoming: CalendarEvent, now: Date) -> DateInterval? {
        guard upcomingStatus(previous: previous, upcoming: upcoming, now: now) == "EN PAUSE",
              let previous,
              previous.end < upcoming.start else { return nil }
        return DateInterval(start: previous.end, end: upcoming.start)
    }
}

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

        let ordered = LiveActivitySchedule.orderedEvents(
            from: LiveActivitySchedule.relevantEvents(from: events, now: now)
        )

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

        if let current = ordered.firstIndex(where: { $0.start <= now && now < $0.end }) {
            primaryIndex = current
            initiallyInProgress = true
        } else if let upcoming = ordered.firstIndex(where: { $0.start > now }) {
            primaryIndex = upcoming
            initiallyInProgress = false
        } else {
            await finishDay(now: now, revision: updateRevision)
            return
        }

        let primary = ordered[primaryIndex]
        let previous = ordered[..<primaryIndex].last(where: { $0.end <= now })
        let nextIndex = LiveActivitySchedule.nextIndex(after: primaryIndex, in: ordered)
        let next = nextIndex.map { ordered[$0] }
        let initialStatus: String
        if initiallyInProgress {
            let remaining = primary.end.timeIntervalSince(now)
            initialStatus = next == nil ? "DERNIER COURS" : (remaining <= 20 * 60 ? "BIENTÔT TERMINÉ" : "EN COURS")
        } else {
            initialStatus = LiveActivitySchedule.upcomingStatus(previous: previous, upcoming: primary, now: now)
        }
        let timerStart = timerDate(primary.start)
        let timerEnd = timerDate(primary.end)
        let pauseInterval = initiallyInProgress ? nil : LiveActivitySchedule.pauseInterval(previous: previous, upcoming: primary, now: now)
        let progressStart = initiallyInProgress ? timerStart : pauseInterval.map { timerDate($0.start) }
        let progressEnd = initiallyInProgress ? timerEnd : pauseInterval.map { timerDate($0.end) }
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
            progressStart: progressStart,
            progressEnd: progressEnd,
            nextTitle: next?.title,
            nextRoom: next?.room,
            nextType: next?.displayTypeLabel,
            nextAccentHex: next.map { accentHex(for: $0) },
            nextStart: next?.start,
            nextEnd: next?.end,
            nextTeachers: next.map { teachers(for: $0) },
            nextGroups: next.map { groups(for: $0) },
            nextTimerStart: nextTimerStart,
            nextTimerEnd: nextTimerEnd,
            isLastCourse: next == nil,
            nextIsLastCourse: nextIndex.map { index in
                LiveActivitySchedule.nextIndex(after: index, in: ordered) == nil
            },
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
            progressStart: nil, progressEnd: nil,
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
