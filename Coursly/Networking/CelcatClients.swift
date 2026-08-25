import Foundation

enum CalendarClientError: LocalizedError {
    case invalidResponse, invalidGroup, invalidURL
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Réponse CELCAT invalide"
        case .invalidGroup: "Groupe inconnu"
        case .invalidURL: "URL CELCAT invalide"
        }
    }
}

protocol DirectCalendarClient: Sendable {
    func fetch(group: StudentGroup, interval: DateInterval) async throws -> Data
}

protocol ICalCalendarClient: Sendable {
    func fetch(group: StudentGroup) async throws -> Data
}

struct CelcatDirectClient: DirectCalendarClient {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func fetch(group: StudentGroup, interval: DateInterval) async throws -> Data {
        let request = try makeRequest(group: group, interval: interval)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalendarClientError.invalidResponse
        }
        return data
    }

    func makeRequest(group: StudentGroup, interval: DateInterval) throws -> URLRequest {
        guard let url = URL(string: "https://edt.iut-velizy.uvsq.fr/Home/GetCalendarData") else {
            throw CalendarClientError.invalidURL
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        formatter.dateFormat = "yyyy-MM-dd"
        let values = [
            "start": formatter.string(from: interval.start),
            "end": formatter.string(from: interval.end),
            "resType": "103", "calView": "agendaWeek", "federationIds[]": group.name,
            "colourScheme": "3"
        ]
        var components = URLComponents()
        components.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.httpMethod = "POST"
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://edt.iut-velizy.uvsq.fr", forHTTPHeaderField: "Origin")
        request.setValue("https://edt.iut-velizy.uvsq.fr/", forHTTPHeaderField: "Referer")
        request.setValue("Coursly/0.3 (iOS)", forHTTPHeaderField: "User-Agent")
        return request
    }
}

struct CelcatICalClient: ICalCalendarClient {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    private static let identifiers = [
        "MMI1-A1": "G1-QJ2DMFYC5987", "MMI1-A2": "G1-PW2GUKMM5988",
        "MMI1-B1": "G1-HN2CHYNX5990", "MMI1-B2": "G1-QW2SJTJH5991",
        "MMI2-A1": "G1-QS2QEJVB5994", "MMI2-A2": "G1-EG2LDXAM5995",
        "MMI2-B1": "G1-AE2BGJHX5997", "MMI2-B2": "G1-TM2VJCBU5998",
        "MMI3-FA-DW-A1": "G1-TS2PGRAD6003", "MMI3-FA-DW-A2": "G1-KL2GMWYW6004",
        "MMI3-FI-CN-A1": "G1-EB2URAPF6006", "MMI3-FI-CN-A2": "G1-JP2NSAYC6007",
        "MMI3-FA-CN-A1": "G1-CC2LTGMX6000", "MMI3-FA-CN-A2": "G1-HW2LKCBM6001"
    ]

    func fetch(group: StudentGroup) async throws -> Data {
        let candidates = try candidateURLs(for: group)
        var lastError: Error = CalendarClientError.invalidResponse
        for url in candidates {
            do {
                var request = URLRequest(url: url, timeoutInterval: 12)
                request.setValue("text/calendar, text/plain, */*", forHTTPHeaderField: "Accept")
                request.setValue("Coursly/0.3 (iOS)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      String(decoding: data.prefix(256), as: UTF8.self).contains("BEGIN:VCALENDAR") else {
                    lastError = CalendarClientError.invalidResponse
                    continue
                }
                return data
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func candidateURLs(for group: StudentGroup) throws -> [URL] {
        guard let internalID = Self.identifiers[group.name] else { throw CalendarClientError.invalidGroup }
        let staticPaths = [
            "https://celcat.iut-velizy.uvsq.fr/cal/ical/\(internalID)/schedule.ics",
            "https://celcat.rambouillet.iut-velizy.uvsq.fr/cal/ical/\(internalID)/schedule.ics"
        ]
        var candidates = staticPaths.compactMap(URL.init(string:))
        var legacy = URLComponents(string: "https://edt.iut-velizy.uvsq.fr/Calendar/iCalendar")
        legacy?.queryItems = [
            URLQueryItem(name: "resType", value: "103"),
            URLQueryItem(name: "federationIds[]", value: internalID)
        ]
        if let legacyURL = legacy?.url { candidates.append(legacyURL) }
        return candidates
    }
}
