import Foundation

struct CalendarService: Sendable {
    let directClient: any DirectCalendarClient
    let iCalClient: any ICalCalendarClient
    let directParser = DirectEventParser()
    let iCalParser = ICalParser()

    init(directClient: any DirectCalendarClient = CelcatDirectClient(), iCalClient: any ICalCalendarClient = CelcatICalClient()) {
        self.directClient = directClient; self.iCalClient = iCalClient
    }

    func events(for group: StudentGroup, interval: DateInterval) async throws -> [CalendarEvent] {
        do {
            let data = try await directClient.fetch(group: group, interval: interval)
            return try directParser.parse(data, group: group) // [] reste un succès.
        } catch {
            let data = try await iCalClient.fetch(group: group)
            return try iCalParser.parse(data, group: group, interval: interval)
        }
    }
}
