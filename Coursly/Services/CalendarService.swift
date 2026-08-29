import Foundation

struct GroupCalendarResult: Sendable {
    let group: StudentGroup
    let events: [CalendarEvent]
    let source: EventSource
}

struct CalendarLoadResult: Sendable {
    let events: [CalendarEvent]
    let directEventsByGroup: [StudentGroup: [CalendarEvent]]
    let fallbackGroups: [StudentGroup]
    let failedGroups: [StudentGroup]
}

struct CalendarService: Sendable {
    let directClient: any DirectCalendarClient
    let iCalClient: any ICalCalendarClient
    let directParser = DirectEventParser()
    let iCalParser = ICalParser()

    init(directClient: any DirectCalendarClient = CelcatDirectClient(), iCalClient: any ICalCalendarClient = CelcatICalClient()) {
        self.directClient = directClient
        self.iCalClient = iCalClient
    }

    func fetch(group: StudentGroup, interval: DateInterval) async throws -> GroupCalendarResult {
        do {
            let data = try await directClient.fetch(group: group, interval: interval)
            return GroupCalendarResult(group: group, events: try directParser.parse(data, group: group), source: .directPOST)
        } catch {
            let data = try await iCalClient.fetch(group: group)
            return GroupCalendarResult(group: group, events: try iCalParser.parse(data, group: group, interval: interval), source: .iCalFallback)
        }
    }

    func events(for group: StudentGroup, interval: DateInterval) async throws -> [CalendarEvent] { try await fetch(group: group, interval: interval).events }

    func load(groups: [StudentGroup], interval: DateInterval) async throws -> CalendarLoadResult {
        let requestedGroups = groups.isEmpty ? [StudentGroup(name: "MMI1-A1")] : groups
        var combined: [CalendarEvent] = [], directByGroup: [StudentGroup: [CalendarEvent]] = [:]
        var fallbackGroups: [StudentGroup] = [], failedGroups: [StudentGroup] = []
        var lastError: Error?, successfulGroupCount = 0
        for group in requestedGroups {
            do {
                let result = try await fetch(group: group, interval: interval)
                successfulGroupCount += 1
                combined.append(contentsOf: result.events)
                if result.source == .directPOST { directByGroup[group] = result.events }
                else if result.source == .iCalFallback { fallbackGroups.append(group) }
            } catch { failedGroups.append(group); lastError = error }
        }
        if successfulGroupCount == 0, let lastError { throw lastError }
        return CalendarLoadResult(events: mergeVisualDuplicates(combined), directEventsByGroup: directByGroup, fallbackGroups: fallbackGroups.sorted { $0.name < $1.name }, failedGroups: failedGroups.sorted { $0.name < $1.name })
    }

    func events(for groups: [StudentGroup], interval: DateInterval) async throws -> [CalendarEvent] { try await load(groups: groups, interval: interval).events }

    func mergeVisualDuplicates(_ events: [CalendarEvent]) -> [CalendarEvent] {
        struct Key: Hashable {
            let title: String; let start: Date; let end: Date; let rooms: [String]; let teachers: [String]
            let category: String; let moduleCode: String?; let moduleName: String?
        }
        var merged: [Key: CalendarEvent] = [:]
        for event in events {
            guard event.source != .local else {
                let key = Key(title: "local:\(event.id)", start: event.start, end: event.end, rooms: event.rooms, teachers: event.teachers, category: event.displayTypeLabel ?? "", moduleCode: event.moduleCode, moduleName: event.moduleName)
                merged[key] = event
                continue
            }
            let key = Key(
                title: event.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
                start: event.start,
                end: event.end,
                rooms: event.rooms.sorted(),
                teachers: event.teachers.sorted(),
                category: event.displayTypeLabel?.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) ?? "",
                moduleCode: event.moduleCode,
                moduleName: event.moduleName
            )
            if let existing = merged[key] {
                let requestedGroups = Array(Set(existing.groups + event.groups)).sorted { $0.name < $1.name }
                let actualLabels = Array(Set((existing.rawGroupLabels ?? []) + (event.rawGroupLabels ?? []))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                let source: EventSource = existing.source == .directPOST || event.source == .directPOST ? .directPOST : existing.source
                merged[key] = CalendarEvent(
                    id: existing.id,
                    title: existing.title,
                    categoryLabel: existing.categoryLabel ?? event.categoryLabel,
                    typeDisplayOverride: existing.typeDisplayOverride ?? event.typeDisplayOverride,
                    start: existing.start,
                    end: existing.end,
                    rooms: existing.rooms,
                    teachers: existing.teachers,
                    groups: requestedGroups,
                    rawGroupLabels: actualLabels.isEmpty ? nil : actualLabels,
                    moduleCode: existing.moduleCode,
                    moduleName: existing.moduleName,
                    source: source
                )
            } else { merged[key] = event }
        }
        return merged.values.sorted { $0.start == $1.start ? $0.title < $1.title : $0.start < $1.start }
    }
}
