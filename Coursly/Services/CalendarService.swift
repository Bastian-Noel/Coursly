import Foundation

struct CalendarService: Sendable {
    let directClient: any DirectCalendarClient
    let iCalClient: any ICalCalendarClient
    let directParser = DirectEventParser()
    let iCalParser = ICalParser()

    init(
        directClient: any DirectCalendarClient = CelcatDirectClient(),
        iCalClient: any ICalCalendarClient = CelcatICalClient()
    ) {
        self.directClient = directClient
        self.iCalClient = iCalClient
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

    func events(for groups: [StudentGroup], interval: DateInterval) async throws -> [CalendarEvent] {
        let groups = groups.isEmpty ? [StudentGroup(name: "MMI1-A1")] : groups
        var combined: [CalendarEvent] = []
        var lastError: Error?

        for group in groups {
            do {
                combined.append(contentsOf: try await events(for: group, interval: interval))
            } catch {
                lastError = error
            }
        }

        if combined.isEmpty, let lastError {
            throw lastError
        }

        return mergeVisualDuplicates(combined)
    }

    private func mergeVisualDuplicates(_ events: [CalendarEvent]) -> [CalendarEvent] {
        struct Key: Hashable {
            let title: String
            let start: Date
            let end: Date
            let rooms: [String]
            let teachers: [String]
            let type: CourseType?
            let moduleCode: String?
            let moduleName: String?
        }

        var merged: [Key: CalendarEvent] = [:]

        for event in events {
            let key = Key(
                title: event.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
                start: event.start,
                end: event.end,
                rooms: event.rooms.sorted(),
                teachers: event.teachers.sorted(),
                type: event.type,
                moduleCode: event.moduleCode,
                moduleName: event.moduleName
            )

            if let existing = merged[key] {
                let groups = Array(Set(existing.groups + event.groups)).sorted { $0.name < $1.name }
                merged[key] = CalendarEvent(
                    id: existing.id,
                    title: existing.title,
                    type: existing.type,
                    start: existing.start,
                    end: existing.end,
                    rooms: existing.rooms,
                    teachers: existing.teachers,
                    groups: groups,
                    moduleCode: existing.moduleCode,
                    moduleName: existing.moduleName,
                    source: existing.source
                )
            } else {
                merged[key] = event
            }
        }

        return merged.values.sorted {
            if $0.start == $1.start { return $0.title < $1.title }
            return $0.start < $1.start
        }
    }
}
