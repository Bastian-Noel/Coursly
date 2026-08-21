import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    static var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    static var hasActiveActivity: Bool { !Activity<CourslyActivityAttributes>.activities.isEmpty }

    static func update(events: [CalendarEvent], now: Date = .now, enabled: Bool) async {
        guard enabled else { await endAll(now: now); return }
        guard areActivitiesEnabled else { return }
        let ordered = events.filter { $0.source != .local || $0.end > now }.sorted { $0.start < $1.start }
        guard let currentOrNext = ordered.first(where: { $0.end > now }) else { await finishDay(now: now); return }
        let isInProgress = currentOrNext.start <= now && now < currentOrNext.end
        let currentIndex = ordered.firstIndex(of: currentOrNext) ?? 0
        let next = ordered.dropFirst(currentIndex + 1).first
        let isFirst = currentIndex == 0; let isLast = next == nil; let remaining = currentOrNext.end.timeIntervalSince(now)
        let status: String
        if !isInProgress { status = isFirst ? "PREMIER COURS" : "PROCHAIN COURS" }
        else if isLast { status = "DERNIER COURS" }
        else if remaining <= 20 * 60 { status = "BIENTÔT TERMINÉ" }
        else { status = "EN COURS" }
        let state = CourslyActivityAttributes.ContentState(status: status, title: currentOrNext.title, room: currentOrNext.room, type: currentOrNext.type?.rawValue, start: currentOrNext.start, end: currentOrNext.end, nextTitle: isInProgress ? next?.title : nil, nextRoom: isInProgress ? next?.room : nil, nextStart: isInProgress ? next?.start : nil, isInProgress: isInProgress, dayFinished: false)
        let content = ActivityContent(state: state, staleDate: isInProgress ? currentOrNext.end : currentOrNext.start)
        if let activity = Activity<CourslyActivityAttributes>.activities.first {
            await activity.update(content)
            for extra in Activity<CourslyActivityAttributes>.activities.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
        } else {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = TimeZone(identifier: "Europe/Paris")
            _ = try? Activity<CourslyActivityAttributes>.request(attributes: CourslyActivityAttributes(dayID: formatter.string(from: currentOrNext.start)), content: content, pushType: nil)
        }
    }

    static func restart(events: [CalendarEvent], now: Date = .now) async { await endAll(now: now, immediate: true); await update(events: events, now: now, enabled: true) }
    static func endAll(now: Date = .now, immediate: Bool = false) async {
        let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .after(now.addingTimeInterval(60))
        for activity in Activity<CourslyActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: policy) }
    }
    private static func finishDay(now: Date) async {
        guard !Activity<CourslyActivityAttributes>.activities.isEmpty else { return }
        let state = CourslyActivityAttributes.ContentState(status: "JOURNÉE TERMINÉE", title: "Cours terminés", room: "", type: nil, start: now, end: now, nextTitle: nil, nextRoom: nil, nextStart: nil, isInProgress: false, dayFinished: true)
        let content = ActivityContent(state: state, staleDate: now)
        for activity in Activity<CourslyActivityAttributes>.activities { await activity.end(content, dismissalPolicy: .after(now.addingTimeInterval(15 * 60))) }
    }
}
