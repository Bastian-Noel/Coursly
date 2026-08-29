import Foundation

enum CourseTypeColorPreferences {
    private static let keyPrefix = "v3.courseTypeColor.dynamic."
    private static let palette = [
        "#007AFF", "#5856D6", "#34C759", "#FF9500",
        "#FF3B30", "#AF52DE", "#00A7B5", "#FF2D55",
        "#5AC8FA", "#8E8E93", "#A2845E", "#30B0C7"
    ]

    static func hex(for label: String) -> String {
        let defaults = UserDefaults.standard
        let groupedKey = key(for: label)
        if let grouped = defaults.string(forKey: groupedKey) {
            return grouped
        }
        if let legacy = defaults.string(forKey: legacyKey(for: label)) {
            defaults.set(legacy, forKey: groupedKey)
            return legacy
        }
        return defaultHex(for: label)
    }

    static func setHex(_ hex: String, for label: String) {
        UserDefaults.standard.set(hex.uppercased(), forKey: key(for: label))
    }

    static func reset(labels: [String]) {
        for label in labels {
            UserDefaults.standard.removeObject(forKey: key(for: label))
            UserDefaults.standard.removeObject(forKey: legacyKey(for: label))
        }
    }

    static func defaultHex(for label: String) -> String {
        let knownColors = [
            "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A01": "#007AFF",
            "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A02": "#5856D6",
            "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A03": "#34C759",
            "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A04": "#FF9500",
            "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A05": "#00A7B5",
            "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A06": "#AF52DE",
            "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A07": "#FF3B30",
            "7D1C18B5-2AF4-46E6-A6F4-A74D12D23A08": "#FF2D55"
        ]
        if let match = CourseTypeClassifier().match(label),
           let color = knownColors[match.groupID.uuidString] {
            return color
        }

        let normalized = normalize(label)
        let hash = normalized.unicodeScalars.reduce(UInt64(5381)) { value, scalar in
            ((value << 5) &+ value) &+ UInt64(scalar.value)
        }
        return palette[Int(hash % UInt64(palette.count))]
    }

    private static func key(for label: String) -> String {
        let groupingKey = CourseTypeClassifier().groupingKey(for: label)
        return keyPrefix + Data(groupingKey.utf8).base64EncodedString()
    }

    private static func legacyKey(for label: String) -> String {
        keyPrefix + Data(normalize(label).utf8).base64EncodedString()
    }

    private static func normalize(_ label: String) -> String {
        label
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}
