import SwiftUI

@main
struct OraApp: App {
    @State private var store = CalendarStore()
    private let frenchLocale = Locale(identifier: "fr_FR")
    private let parisTimeZone = TimeZone(identifier: "Europe/Paris")!

    private var parisCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = frenchLocale
        calendar.timeZone = parisTimeZone
        return calendar
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, frenchLocale)
                .environment(\.timeZone, parisTimeZone)
                .environment(\.calendar, parisCalendar)
        }
    }
}
