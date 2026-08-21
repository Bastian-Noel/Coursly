import UIKit

@MainActor
enum HapticService {
    enum Event {
        case selection
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

    static func fire(_ event: Event, enabled: Bool) {
        guard enabled else { return }

        switch event {
        case .selection, .scrollHour:
            UISelectionFeedbackGenerator().selectionChanged()
        case .dayChanged, .displayModeChanged, .panelOpened:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .courseOpened, .returnedToNow, .scrollCourse:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
