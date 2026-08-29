import Foundation

struct CourseTypeGroup: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var patterns: [String]
    var displayRename: String?
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, patterns: [String] = [], displayRename: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.patterns = patterns
        self.displayRename = displayRename
        self.isEnabled = isEnabled
    }

    var validPatterns: [String] {
        patterns.map(Self.normalized).filter { !$0.isEmpty && (try? NSRegularExpression(pattern: $0)) != nil }
    }

    var trimmedRename: String? {
        guard let value = displayRename?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    var displayLabel: String? {
        guard trimmedRename != nil else { return nil }
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func matches(_ label: String) -> Bool {
        guard isEnabled else { return false }
        let value = Self.normalized(label)
        return validPatterns.contains { value.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    static func isValid(pattern: String) -> Bool {
        let value = normalized(pattern)
        return !value.isEmpty && (try? NSRegularExpression(pattern: value)) != nil
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }
}

struct CourseTypeMatch: Hashable, Sendable {
    let groupID: UUID
    let displayRename: String?
}

struct CourseTypeClassifier: Sendable {
    let groups: [CourseTypeGroup]

    init(groups: [CourseTypeGroup] = CourseTypeRulePreferences.load()) { self.groups = groups }

    func match(_ label: String?) -> CourseTypeMatch? {
        guard let label, let group = groups.first(where: { $0.matches(label) }) else { return nil }
        return CourseTypeMatch(groupID: group.id, displayRename: group.displayLabel)
    }

    func groupingKey(for label: String) -> String {
        if let match = match(label) { return "group:\(match.groupID.uuidString)" }
        let normalized = label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return "dynamic:\(normalized)"
    }

    func reclassify(_ event: CalendarEvent) -> CalendarEvent {
        guard event.source != .local else { return event }
        let result = match(event.categoryLabel)
        return CalendarEvent(
            id: event.id, title: event.title, type: nil, categoryLabel: event.categoryLabel,
            typeDisplayOverride: result?.displayRename, start: event.start, end: event.end,
            rooms: event.rooms, teachers: event.teachers, groups: event.groups,
            rawGroupLabels: event.rawGroupLabels, moduleCode: event.moduleCode,
            moduleName: event.moduleName, notes: event.notes, source: event.source
        )
    }
}

enum CourseTypeRulePreferences {
    private static let storageKey = "v4.courseTypeGroups"
    private static let legacyStorageKey = "v3.courseTypeGroupingRules"

    static func load() -> [CourseTypeGroup] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CourseTypeGroup].self, from: data) {
            return decoded
        }
        if let migrated = migrateLegacyRules() {
            save(migrated)
            return migrated
        }
        return defaultRules
    }

    static func save(_ groups: [CourseTypeGroup]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: legacyStorageKey)
    }

    static let defaultRules: [CourseTypeGroup] = [
        CourseTypeGroup(id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A01")!, name: "Cours magistraux", patterns: [#"\bcm\b"#, #"\bcours\s+magistral(?:e|es|s)?\b"#]),
        CourseTypeGroup(id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A02")!, name: "Travaux dirigés", patterns: [#"\btd\b"#, #"\btravaux\s+dirige(?:e|es|s)?\b"#]),
        CourseTypeGroup(id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A03")!, name: "Travaux pratiques", patterns: [#"\btp\b"#, #"\btravaux\s+pratique(?:s)?\b"#]),
        CourseTypeGroup(id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A04")!, name: "Projets", patterns: [#"\bprojet(?:s)?\b"#]),
        CourseTypeGroup(id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A05")!, name: "Intégration", patterns: [#"\bintegration\b"#, #"\bint\b"#]),
        CourseTypeGroup(id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A06")!, name: "Réunions", patterns: [#"\breunion(?:s)?\b"#]),
        CourseTypeGroup(id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A07")!, name: "Contrôles", patterns: [#"\bds\b"#, #"\bcontrole(?:s)?\b"#]),
        CourseTypeGroup(id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A08")!, name: "Examens", patterns: [#"\bexam(?:en|ens)?\b"#])
    ]

    private struct LegacyRule: Codable {
        let type: CourseType
        let pattern: String
        let isEnabled: Bool
    }

    private static func migrateLegacyRules() -> [CourseTypeGroup]? {
        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey),
              let legacy = try? JSONDecoder().decode([LegacyRule].self, from: data),
              !legacy.isEmpty else { return nil }
        let names: [CourseType: String] = [
            .cm: "Cours magistraux", .td: "Travaux dirigés", .tp: "Travaux pratiques",
            .project: "Projets", .integration: "Intégration", .meeting: "Réunions",
            .test: "Contrôles", .exam: "Examens"
        ]
        return CourseType.allCases.compactMap { type in
            let rules = legacy.filter { $0.type == type }
            guard !rules.isEmpty else { return nil }
            return CourseTypeGroup(
                name: names[type] ?? type.rawValue,
                patterns: rules.map(\.pattern),
                isEnabled: rules.contains(where: \.isEnabled)
            )
        }
    }
}
