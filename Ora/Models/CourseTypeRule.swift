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
            id: event.id, title: event.title, categoryLabel: event.categoryLabel,
            typeDisplayOverride: result?.displayRename, start: event.start, end: event.end,
            rooms: event.rooms, teachers: event.teachers, groups: event.groups,
            rawGroupLabels: event.rawGroupLabels, moduleCode: event.moduleCode,
            moduleName: event.moduleName, notes: event.notes, source: event.source
        )
    }
}

enum CourseTypeRulePreferences {
    private static let storageKey = "v6.courseTypeGroups"
    private static let previousStorageKey = "v5.courseTypeGroups"
    private static let olderStorageKey = "v4.courseTypeGroups"
    private static let legacyStorageKey = "v3.courseTypeGroupingRules"

    /// Loads the exact saved configuration, including an intentionally empty list.
    /// Defaults are written once so deleting every group can never recreate them.
    static func load(from defaults: UserDefaults = .standard) -> [CourseTypeGroup] {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CourseTypeGroup].self, from: data) {
            return decoded
        }

        if let data = defaults.data(forKey: previousStorageKey),
           let previous = try? JSONDecoder().decode([CourseTypeGroup].self, from: data) {
            let migrated = migrateV5Groups(previous)
            save(migrated, to: defaults)
            return migrated
        }

        if let data = defaults.data(forKey: olderStorageKey),
           let older = try? JSONDecoder().decode([CourseTypeGroup].self, from: data) {
            let migrated = migratePreviousGroups(older)
            save(migrated, to: defaults)
            return migrated
        }

        save(defaultRules, to: defaults)
        return defaultRules
    }

    static func save(_ groups: [CourseTypeGroup], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: previousStorageKey)
        defaults.removeObject(forKey: olderStorageKey)
        defaults.removeObject(forKey: legacyStorageKey)
    }

    /// These are editable starter expressions, not a closed list of course types.
    /// Every other CELCAT label remains available dynamically.
    static let defaultRules: [CourseTypeGroup] = [
        CourseTypeGroup(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A03")!,
            name: "TP",
            patterns: [#"\btp\b"#, #"\b(?:travail|travaux)\s+pratique(?:s)?\b"#]
        ),
        CourseTypeGroup(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A02")!,
            name: "TD",
            patterns: [#"\btd\b"#, #"\b(?:travail|travaux)\s+dirige(?:e|es|s)?\b"#]
        ),
        CourseTypeGroup(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A01")!,
            name: "CM",
            patterns: [#"\bcm\b"#, #"\bcours\s+magistr(?:al(?:e|es|s)?|aux)\b"#]
        ),
        CourseTypeGroup(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A04")!,
            name: "Projet tutoré",
            patterns: [#"\bprojet(?:s)?\s+tutore(?:e|es|s)?\b"#],
            displayRename: "Projet tutoré"
        )
    ]

    /// v5 shipped TP, TD and CM with renaming enabled by default.
    /// Disable only that untouched default while preserving deletions and user-created groups.
    private static func migrateV5Groups(_ previous: [CourseTypeGroup]) -> [CourseTypeGroup] {
        let formerlyRenamedDefaults: [UUID: String] = [
            UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A03")!: "TP",
            UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A02")!: "TD",
            UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A01")!: "CM"
        ]

        return previous.map { group in
            guard let defaultName = formerlyRenamedDefaults[group.id],
                  group.name == defaultName,
                  group.trimmedRename == defaultName else { return group }
            var migrated = group
            migrated.displayRename = nil
            return migrated
        }
    }

    private static let previousBuiltInIDs = Set([
        "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A01",
        "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A02",
        "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A03",
        "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A04",
        "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A05",
        "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A06",
        "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A07",
        "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A08"
    ])

    private static func migratePreviousGroups(_ previous: [CourseTypeGroup]) -> [CourseTypeGroup] {
        let existingIDs = Set(previous.map { $0.id.uuidString })
        let retainedDefaults = defaultRules.filter { existingIDs.contains($0.id.uuidString) }
        let customGroups = previous.filter { !previousBuiltInIDs.contains($0.id.uuidString) }
        return retainedDefaults + customGroups
    }
}
