import SwiftUI

@main
struct CourslyApp: App {
    @State private var store = CalendarStore()
    private let frenchLocale = Locale(identifier: "fr_FR")

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, frenchLocale)
        }
    }
}
