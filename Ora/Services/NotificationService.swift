import Foundation
import UserNotifications

@MainActor
struct NotificationService {
    func requestAuthorization() async -> Bool {
        do { return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) }
        catch { return false }
    }
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
    func notify(changes: [CalendarChange]) async {
        guard !changes.isEmpty, await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        if changes.count == 1, let change = changes.first {
            content.title = change.kind.frenchTitle
            content.body = "\(change.title) · \(change.summary)"
        } else {
            content.title = "\(changes.count) changements dans ton emploi du temps"
            content.body = changes.prefix(4).map { "• \($0.title) — \($0.kind.frenchTitle.lowercased())" }.joined(separator: "\n")
        }
        content.sound = .default
        content.threadIdentifier = "ora-calendar-changes"
        content.userInfo = ["destination": "changes"]
        let request = UNNotificationRequest(identifier: "ora-changes-\(UUID().uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
