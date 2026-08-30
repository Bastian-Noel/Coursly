import UIKit

@MainActor
enum HapticService {
    enum Event {
        case selection
        case refreshStarted
        case dayChanged
        case displayModeChanged
        case panelOpened
        case courseOpened
        case returnedToNow
        case scrollHour
        case scrollCourse
        case success
        case warning
        case error
    }

    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static var lastScrollFeedbackTime: TimeInterval = 0

    static func prepare(_ event: Event, enabled: Bool) {
        guard enabled else { return }
        switch event {
        case .selection, .scrollHour:
            selectionGenerator.prepare()
        case .refreshStarted, .panelOpened, .courseOpened:
            softImpact.prepare()
        case .dayChanged, .displayModeChanged, .scrollCourse:
            rigidImpact.prepare()
        case .returnedToNow:
            mediumImpact.prepare()
        case .success, .warning, .error:
            notificationGenerator.prepare()
        }
    }

    static func fire(_ event: Event, enabled: Bool) {
        guard enabled else { return }

        switch event {
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .refreshStarted:
            softImpact.impactOccurred(intensity: 0.34)
        case .scrollHour:
            guard canPlayScrollFeedback(after: 0.085) else { return }
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .scrollCourse:
            guard canPlayScrollFeedback(after: 0.12) else { return }
            rigidImpact.impactOccurred(intensity: 0.52)
            rigidImpact.prepare()
        case .dayChanged, .displayModeChanged:
            rigidImpact.impactOccurred(intensity: 0.62)
            rigidImpact.prepare()
        case .panelOpened, .courseOpened:
            softImpact.impactOccurred(intensity: 0.58)
            softImpact.prepare()
        case .returnedToNow:
            mediumImpact.impactOccurred(intensity: 0.72)
            mediumImpact.prepare()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }

    private static func canPlayScrollFeedback(after minimumInterval: TimeInterval) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastScrollFeedbackTime >= minimumInterval else { return false }
        lastScrollFeedbackTime = now
        return true
    }
}
