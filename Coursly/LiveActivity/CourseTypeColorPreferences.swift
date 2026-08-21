import Foundation

enum CourseTypeColorPreferences {
    private static let keyPrefix = "v3.courseTypeColor."

    static func hex(for type: CourseType) -> String {
        UserDefaults.standard.string(forKey: keyPrefix + type.rawValue) ?? defaultHex(for: type)
    }

    static func setHex(_ hex: String, for type: CourseType) {
        UserDefaults.standard.set(hex.uppercased(), forKey: keyPrefix + type.rawValue)
    }

    static func reset() {
        for type in CourseType.allCases {
            UserDefaults.standard.removeObject(forKey: keyPrefix + type.rawValue)
        }
    }

    static func defaultHex(for type: CourseType) -> String {
        switch type {
        case .cm: return "#0A84FF"
        case .td: return "#5E5CE6"
        case .tp: return "#30D158"
        case .project: return "#FF9F0A"
        case .integration: return "#64D2FF"
        case .meeting: return "#BF5AF2"
        case .test: return "#FF453A"
        case .exam: return "#FF375F"
        }
    }
}
