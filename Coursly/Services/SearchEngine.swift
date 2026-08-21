import Foundation

struct SearchFacets: Sendable {
    let subjects: [String]
    let teachers: [String]
    let rooms: [String]
    let groups: [String]
    let types: [CourseType]
    let modules: [String]
}

struct SearchFilters: Sendable {
    var query = ""
    var subjects: Set<String> = []
    var teachers: Set<String> = []
    var rooms: Set<String> = []
    var groups: Set<String> = []
    var types: Set<CourseType> = []
    var modules: Set<String> = []

    var hasFacets: Bool {
        !subjects.isEmpty || !teachers.isEmpty || !rooms.isEmpty || !groups.isEmpty || !types.isEmpty || !modules.isEmpty
    }
}

struct SearchEngine: Sendable {
    func facets(from events: [CalendarEvent]) -> SearchFacets {
        SearchFacets(subjects: unique(events.map(\.title)), teachers: unique(events.flatMap(\.teachers)), rooms: unique(events.flatMap(\.rooms)), groups: unique(events.flatMap { $0.groups.map(\.name) }), types: Array(Set(events.compactMap(\.type))).sorted { $0.rawValue < $1.rawValue }, modules: unique(events.compactMap { $0.moduleCode ?? $0.moduleName }))
    }

    func results(in events: [CalendarEvent], filters: SearchFilters) -> [CalendarEvent] {
        let normalizedQuery = normalize(filters.query)
        return events.filter { event in
            if !normalizedQuery.isEmpty, !normalize(event.searchableText).contains(normalizedQuery) { return false }
            if !filters.subjects.isEmpty, !filters.subjects.contains(event.title) { return false }
            if !filters.teachers.isEmpty, filters.teachers.isDisjoint(with: Set(event.teachers)) { return false }
            if !filters.rooms.isEmpty, filters.rooms.isDisjoint(with: Set(event.rooms)) { return false }
            if !filters.groups.isEmpty, filters.groups.isDisjoint(with: Set(event.groups.map(\.name))) { return false }
            if !filters.types.isEmpty, event.type.map({ filters.types.contains($0) }) != true { return false }
            if !filters.modules.isEmpty {
                let values = Set([event.moduleCode, event.moduleName].compactMap { $0 })
                if filters.modules.isDisjoint(with: values) { return false }
            }
            return true
        }.sorted {
            if $0.start == $1.start { return $0.title < $1.title }
            return $0.start < $1.start
        }
    }

    private func unique(_ values: [String]) -> [String] {
        Array(Set(values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
