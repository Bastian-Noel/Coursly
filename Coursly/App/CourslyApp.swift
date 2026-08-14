import SwiftUI

@main
struct CourslyApp: App {
    @State private var store = CalendarStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
