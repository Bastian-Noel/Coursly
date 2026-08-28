import Foundation

enum CourseTypeColorPreferences {
    private static let keyPrefix = "v3.courseTypeColor.dynamic."
    private static let palette = [
        "#007AFF", "#5856D6", "#34C759", "#FF9500",
        "#FF3B30", "#AF52DE", "#00A7B5", "#FF2D55",
        "#5AC8FA", "#8E8E93", "#A2845E", "#30B0C7"
    ]

    static func hex(for label: String) -> String {
        UserDefaults.standard.string(forKey: key(for: label)) ?? defaultHex(for: label)
    }

    static func setHex(_ hex: String, for label: String) {
        UserDefaults.standard.set(hex.uppercased(), forKey: key(for: label))
    }

    static func reset(labels: [String]) {
        for label in labels {
            UserDefaults.standard.removeObject(forKey: key(for: label))
        }
    }

    static func defaultHex(for label: String) -> String {
        let knownColors: [CourseType: String] = [
            .cm: "#007AFF",
            .td: "#5856D6",
            .tp: "#34C759",
            .project: "#FF9500",
            .integration: "#00A7B5",
            .meeting: "#AF52DE",
            .test: "#FF3B30",
            .exam: "#FF2D55"
        ]
        if let type = CourseTypeClassifier().classify(label),
           let color = knownColors[type] {
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

    private static func normalize(_ label: String) -> String {
        label
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}
