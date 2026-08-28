import Foundation

struct CourseTypeRule: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var type: CourseType
    var pattern: String
    var isEnabled: Bool

    init(id: UUID = UUID(), type: CourseType, pattern: String, isEnabled: Bool = true) {
        self.id = id
        self.type = type
        self.pattern = pattern
        self.isEnabled = isEnabled
    }

    var isValid: Bool {
        let normalizedPattern = Self.normalized(pattern)
        guard !normalizedPattern.isEmpty else { return false }
        return (try? NSRegularExpression(pattern: normalizedPattern)) != nil
    }

    func matches(_ label: String) -> Bool {
        guard isEnabled, isValid else { return false }
        let normalizedLabel = Self.normalized(label)
        let normalizedPattern = Self.normalized(pattern)
        return normalizedLabel.range(
            of: normalizedPattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.diacriticInsensitive],
            locale: Locale(identifier: "fr_FR")
        )
    }
}

struct CourseTypeClassifier: Sendable {
    let rules: [CourseTypeRule]

    init(rules: [CourseTypeRule] = CourseTypeRulePreferences.load()) {
        self.rules = rules
    }

    func classify(_ label: String?) -> CourseType? {
        guard let label else { return nil }
        return rules.first(where: { $0.matches(label) })?.type
    }

    func groupingKey(for label: String) -> String {
        if let type = classify(label) {
            return "known:\(type.rawValue)"
        }
        let normalized = label
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "fr_FR")
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return "dynamic:\(normalized)"
    }

    func reclassify(_ event: CalendarEvent) -> CalendarEvent {
        guard event.source != .local else { return event }
        return CalendarEvent(
            id: event.id,
            title: event.title,
            type: classify(event.categoryLabel),
            categoryLabel: event.categoryLabel,
            start: event.start,
            end: event.end,
            rooms: event.rooms,
            teachers: event.teachers,
            groups: event.groups,
            rawGroupLabels: event.rawGroupLabels,
            moduleCode: event.moduleCode,
            moduleName: event.moduleName,
            source: event.source
        )
    }
}

enum CourseTypeRulePreferences {
    private static let storageKey = "v3.courseTypeGroupingRules"

    static func load() -> [CourseTypeRule] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CourseTypeRule].self, from: data) else {
            return defaultRules
        }
        return decoded
    }

    static func save(_ rules: [CourseTypeRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static let defaultRules: [CourseTypeRule] = [
        CourseTypeRule(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A01")!,
            type: .cm,
            pattern: #"\b(?:(?:cours|enseignement)\s+)?magistral(?:e|es|s)?\b|\bcm\b"#
        ),
        CourseTypeRule(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A02")!,
            type: .td,
            pattern: #"\b(?:travaux|travail|cours)\s+dirige(?:e|es|s)?\b|\btd\b"#
        ),
        CourseTypeRule(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A03")!,
            type: .tp,
            pattern: #"\b(?:travaux|travail|cours)\s+pratique(?:s)?\b|\btp\b"#
        ),
        CourseTypeRule(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A04")!,
            type: .project,
            pattern: #"\bprojet(?:s)?\b"#
        ),
        CourseTypeRule(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A05")!,
            type: .integration,
            pattern: #"\bintegration\b|\bint\b"#
        ),
        CourseTypeRule(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A06")!,
            type: .meeting,
            pattern: #"\breunion(?:s)?\b"#
        ),
        CourseTypeRule(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A07")!,
            type: .test,
            pattern: #"\bdevoir(?:s)?\s+surveille(?:s)?\b|\bds\b"#
        ),
        CourseTypeRule(
            id: UUID(uuidString: "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A08")!,
            type: .exam,
            pattern: #"\bexamen(?:s)?\b|\bpartiel(?:s)?\b|\bexam\b"#
        )
    ]
}
