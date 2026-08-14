import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    static func update(events: [CalendarEvent], now: Date = .now) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let ordered = events.sorted { $0.start < $1.start }
        guard let event = ordered.first(where: { $0.end > now }) else {
            for activity in Activity<CourslyActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .after(now.addingTimeInterval(900)))
            }
            return
        }
        let next = ordered.first { $0.start >= event.end }
        let status = now < event.start ? (event == ordered.first ? "PREMIER COURS" : "PROCHAIN COURS") : (next == nil ? "DERNIER COURS" : "EN COURS")
        let state = CourslyActivityAttributes.ContentState(status: status, title: event.title, room: event.room, type: event.type?.rawValue, start: event.start, end: event.end, nextTitle: now >= event.start ? next?.title : nil)
        let content = ActivityContent(state: state, staleDate: event.end)
        if let activity = Activity<CourslyActivityAttributes>.activities.first { await activity.update(content) }
        else { _ = try? Activity<CourslyActivityAttributes>.request(attributes: CourslyActivityAttributes(eventID: event.id), content: content, pushType: nil) }
    }
}
