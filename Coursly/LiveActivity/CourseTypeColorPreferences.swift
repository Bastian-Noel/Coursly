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
        let normalized = normalize(label)
        let known: [String: String] = [
            "CM": "#007AFF",
            "COURS MAGISTRAL": "#007AFF",
            "TD": "#5856D6",
            "TRAVAUX DIRIGES": "#5856D6",
            "TP": "#34C759",
            "TRAVAUX PRATIQUES": "#34C759",
            "PROJET": "#FF9500",
            "INT": "#00A7B5",
            "INTEGRATION": "#00A7B5",
            "REUNION": "#AF52DE",
            "DS": "#FF3B30",
            "DEVOIR SURVEILLE": "#FF3B30",
            "EXAM": "#FF2D55",
            "EXAMEN": "#FF2D55"
        ]
        if let exact = known[normalized] { return exact }

        let hash = normalized.unicodeScalars.reduce(UInt64(5381)) { value, scalar in
            ((value << 5) &+ value) &+ UInt64(scalar.value)
        }
        return palette[Int(hash % UInt64(palette.count))]
    }

    private static func key(for label: String) -> String {
        keyPrefix + Data(normalize(label).utf8).base64EncodedString()
    }

    private static func normalize(_ label: String) -> String {
        label
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}
