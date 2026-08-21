import UIKit

@MainActor
enum HapticService {
    enum Event { case selection, dayChanged, displayModeChanged, panelOpened, courseOpened, returnedToNow, success, warning, error }
    static func fire(_ event: Event, enabled: Bool) {
        guard enabled else { return }
        switch event {
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .dayChanged, .displayModeChanged, .panelOpened: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .courseOpened, .returnedToNow: UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
