import Foundation

struct DirectEventParser: Sendable {
    private struct Payload: Decodable {
        let id: StringOrNumber?
        let start: String
        let end: String?
        let description: String?
        let eventCategory: String?
        let modules: [String]?
        let sites: [String]?
        let allDay: Bool?
    }
    private enum StringOrNumber: Decodable {
        case string(String)
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let string = try? value.decode(String.self) { self = .string(string) }
            else if let number = try? value.decode(Int.self) { self = .string(String(number)) }
            else { throw DecodingError.typeMismatch(String.self, .init(codingPath: decoder.codingPath, debugDescription: "ID invalide")) }
        }
        var value: String { if case let .string(value) = self { value } else { "" } }
    }

    func parse(_ data: Data, group requestedGroup: StudentGroup) throws -> [CalendarEvent] {
        let payloads = try JSONDecoder().decode([Payload].self, from: data)
        let classifier = CourseTypeClassifier()
        return try payloads.filter { $0.allDay != true }.map { payload in
            let parts = htmlLines(payload.description ?? "")
            let siteCount = payload.sites?.count ?? 0
            let module = parts.last ?? payload.modules?.first ?? "Sans titre"
            let moduleWithoutBracketCode = module.replacingOccurrences(of: #"\s*\[.*?\]\s*$"#, with: "", options: .regularExpression)
            let moduleParts = moduleWithoutBracketCode
                .components(separatedBy: " - ")
            let rawTitle = moduleParts.count > 1 ? moduleParts.dropFirst().joined(separator: " - ") : moduleParts[0]
            let title = rawTitle
                .replacingOccurrences(
                    of: #"^(?:R|SA[ÉE])\s*\d+(?:\.\d+)+\s*(?:-\s*)?"#,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // CELCAT POST description order is: teachers, actual group, rooms, module.
            // Keep the actual group label separate from the federation group used to make the request.
            let groupIndex = max(0, parts.count - siteCount - 2)
            let actualGroupLine = parts.indices.contains(groupIndex) ? parts[groupIndex] : requestedGroup.name
            let actualGroupLabels = parseGroupLabels(actualGroupLine)
            let rooms = siteCount > 0 && groupIndex + 1 + siteCount <= parts.count
                ? Array(parts[(groupIndex + 1)..<(groupIndex + 1 + siteCount)]).map(cleanRoom) : []
            let teachers = groupIndex > 0 ? Array(parts[..<groupIndex]) : []
            let categoryLabel = cleanCategory(payload.eventCategory)

            return CalendarEvent(
                id: payload.id?.value ?? UUID().uuidString,
                title: title.isEmpty ? "Sans titre" : title,
                                categoryLabel: categoryLabel,
                typeDisplayOverride: classifier.match(categoryLabel)?.displayRename,
                start: try parseDate(payload.start),
                end: try parseDate(payload.end ?? payload.start),
                rooms: rooms,
                teachers: teachers,
                groups: [requestedGroup],
                rawGroupLabels: actualGroupLabels,
                moduleCode: payload.modules?.first,
                moduleName: module,
                source: .directPOST
            )
        }
    }

    private func htmlLines(_ value: String) -> [String] {
        value.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .components(separatedBy: .newlines)
            .map(decodeHTML)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func parseGroupLabels(_ value: String) -> [String] {
        let cleaned = decodeHTML(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        let separators = CharacterSet(charactersIn: ";,/|")
        let split = cleaned.components(separatedBy: separators).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return split.isEmpty ? [cleaned] : split
    }

    private func decodeHTML(_ value: String) -> String {
        ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&nbsp;": " ", "&eacute;": "é", "&egrave;": "è", "&agrave;": "à"].reduce(value) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }
    private func cleanRoom(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+-\s+(VEL|VELIZY|VÉLIZY)$"#, with: "", options: [.regularExpression, .caseInsensitive])
    }
    private func cleanCategory(_ category: String?) -> String? {
        guard let category else { return nil }
        let value = decodeHTML(category).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    private func parseDate(_ value: String) throws -> Date {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Europe/Paris"); formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        throw CalendarClientError.invalidResponse
    }
}

struct ICalParser: Sendable {
    func parse(_ data: Data, group: StudentGroup, interval: DateInterval) throws -> [CalendarEvent] {
        guard let text = String(data: data, encoding: .utf8) else { throw CalendarClientError.invalidResponse }
        let unfolded = text.replacingOccurrences(of: #"\r?\n[ \t]"#, with: "", options: .regularExpression)
        let classifier = CourseTypeClassifier()
        return try unfolded.components(separatedBy: "BEGIN:VEVENT").dropFirst().compactMap { block in
            guard let body = block.components(separatedBy: "END:VEVENT").first else { return nil }
            var values: [String: String] = [:]
            for line in body.components(separatedBy: .newlines) {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let key = String(line[..<colon]).components(separatedBy: ";")[0].uppercased()
                values[key] = decode(String(line[line.index(after: colon)...]))
            }
            guard let startRaw = values["DTSTART"], let start = date(startRaw) else { return nil }
            let end = values["DTEND"].flatMap(date) ?? start
            guard interval.intersects(DateInterval(start: start, end: max(end, start.addingTimeInterval(1)))) else { return nil }
            let rawTitle = values["SUMMARY"] ?? "Sans titre"
            let titleParts = rawTitle.components(separatedBy: " - ")
            let title = titleParts.count > 1 ? titleParts.dropFirst().joined(separator: " - ") : rawTitle
            return CalendarEvent(id: values["UID"] ?? UUID().uuidString, title: title,                 start: start, end: end, rooms: (values["LOCATION"] ?? "").components(separatedBy: "/").filter { !$0.isEmpty },
                teachers: [], groups: [group], rawGroupLabels: nil, moduleCode: titleParts.count > 1 ? titleParts[0] : nil,
                moduleName: rawTitle, source: .iCalFallback)
        }.sorted { $0.start < $1.start }
    }
    private func decode(_ value: String) -> String { value.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\,", with: ",").replacingOccurrences(of: "\\;", with: ";").replacingOccurrences(of: "\\\\", with: "\\").trimmingCharacters(in: .whitespaces) }
    private func date(_ value: String) -> Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        formatter.dateFormat = value.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"
        if value.hasSuffix("Z") { formatter.timeZone = .gmt }; return formatter.date(from: value)
    }
}
