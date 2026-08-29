import XCTest
@testable import Coursly

final class ParserTests: XCTestCase {
    func testEmptyDirectResponseIsAValidSuccess() throws {
        XCTAssertEqual(try DirectEventParser().parse(Data("[]".utf8), group: .init(name: "MMI1-A1")), [])
    }

    func testDirectParserPreservesReadableGroupAndMetadata() throws {
        let json = #"[{"id":"42","start":"2026-08-13T08:00:00+02:00","end":"2026-08-13T10:00:00+02:00","description":"Mme Prof<br />MMI1-A1<br />A101 - VELIZY<br />R101 - Développement web [R101]","eventCategory":"Travaux dirigés","modules":["R101"],"sites":["VELIZY"]}]"#
        let event = try XCTUnwrap(DirectEventParser().parse(Data(json.utf8), group: .init(name: "MMI1-A1")).first)
        XCTAssertEqual(event.title, "Développement web")
        XCTAssertNil(event.type, "Le regroupement ne transforme plus le type CELCAT")
        XCTAssertEqual(event.displayTypeLabel, "Travaux dirigés")
        XCTAssertEqual(event.rooms, ["A101"])
        XCTAssertEqual(event.groups.map(\.name), ["MMI1-A1"])
    }

    func testDirectParserUsesActualBroadGroupAndRemovesVisibleModulePrefix() throws {
        let json = #"[{"id":"42","start":"2026-09-11T13:00:00","end":"2026-09-11T14:30:00","description":"HAUTBOIS Xavier\r\n\r\n<br />\r\n\r\nMMI2-B\r\n\r\n<br />\r\n\r\nI22 - VEL\r\n\r\n<br />\r\n\r\nR 3.19 Environnement de developpement interactif [MM3R19]\r\n","eventCategory":"Travaux Dirigés (TD)","modules":["MM3R19"],"sites":["Bat. BASTIE - VEL"]}]"#
        let event = try XCTUnwrap(DirectEventParser().parse(Data(json.utf8), group: .init(name: "MMI2-B2")).first)
        XCTAssertEqual(event.displayGroupLabels, ["MMI2-B"])
        XCTAssertEqual(event.title, "Environnement de developpement interactif")
        XCTAssertFalse(event.title.contains("MM3R19"))
        XCTAssertFalse(event.title.hasPrefix("R 3.19"))
    }

    func testDirectParserKeepsMultipleTeachersOnSeparateValues() throws {
        let json = #"[{"id":"42","start":"2026-09-11T13:00:00","end":"2026-09-11T14:30:00","description":"Mme Dupont\r\nM. Martin<br />MMI2-B<br />I22 - VEL<br />R 3.19 - Atelier [MM3R19]","eventCategory":"Atelier transversal","modules":["MM3R19"],"sites":["Bat. BASTIE - VEL"]}]"#
        let event = try XCTUnwrap(DirectEventParser().parse(Data(json.utf8), group: .init(name: "MMI2-B2")).first)
        XCTAssertEqual(event.teachers, ["Mme Dupont", "M. Martin"])
        XCTAssertEqual(event.displayTypeLabel, "Atelier transversal")
    }

    func testICalUnfoldsLinesAndFiltersInterval() throws {
        let ics = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:abc\r\nSUMMARY:R101 - Développe\r\n ment web\r\nLOCATION:A101 / A102\r\nDTSTART:20260813T080000\r\nDTEND:20260813T100000\r\nEND:VEVENT\r\nEND:VCALENDAR"
        let formatter = ISO8601DateFormatter()
        let interval = DateInterval(start: formatter.date(from: "2026-08-12T00:00:00Z")!, end: formatter.date(from: "2026-08-15T00:00:00Z")!)
        let event = try XCTUnwrap(ICalParser().parse(Data(ics.utf8), group: .init(name: "MMI1-A1"), interval: interval).first)
        XCTAssertEqual(event.title, "Développement web")
        XCTAssertEqual(event.source, .iCalFallback)
    }
}

private actor DirectStub: DirectCalendarClient {
    let data: Data?
    init(data: Data?) { self.data = data }
    func fetch(group: StudentGroup, interval: DateInterval) async throws -> Data {
        guard let data else { throw URLError(.timedOut) }
        return data
    }
}

private actor ICalSpy: ICalCalendarClient {
    private(set) var calls = 0
    let data: Data
    init(data: Data = Data("BEGIN:VCALENDAR\nEND:VCALENDAR".utf8)) { self.data = data }
    func fetch(group: StudentGroup) async throws -> Data { calls += 1; return data }
}

final class CalendarServiceTests: XCTestCase {
    func testEmptyPOSTNeverTriggersICalFallback() async throws {
        let fallback = ICalSpy()
        let service = CalendarService(directClient: DirectStub(data: Data("[]".utf8)), iCalClient: fallback)
        let result = try await service.events(for: .init(name: "MMI1-A1"), interval: .init(start: .now, duration: 86_400))
        XCTAssertTrue(result.isEmpty)
        let calls = await fallback.calls
        XCTAssertEqual(calls, 0)
    }

    func testPOSTFailureTriggersICalFallback() async throws {
        let fallback = ICalSpy()
        let service = CalendarService(directClient: DirectStub(data: nil), iCalClient: fallback)
        _ = try await service.events(for: .init(name: "MMI1-A1"), interval: .init(start: .now, duration: 86_400))
        let calls = await fallback.calls
        XCTAssertEqual(calls, 1)
    }
}

final class CelcatClientContractTests: XCTestCase {
    func testDirectRequestMatchesCurrentCELCATFormContract() throws {
        let interval = DateInterval(
            start: ISO8601DateFormatter().date(from: "2026-09-01T00:00:00Z")!,
            end: ISO8601DateFormatter().date(from: "2026-10-15T00:00:00Z")!
        )
        let request = try CelcatDirectClient().makeRequest(group: .init(name: "MMI2-B2"), interval: interval)
        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        let items = try XCTUnwrap(URLComponents(string: "https://coursly.invalid/?\(body)")?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: items.compactMap { item in item.value.map { (item.name, $0) } })

        XCTAssertEqual(request.url?.absoluteString, "https://edt.iut-velizy.uvsq.fr/Home/GetCalendarData")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(values["resType"], "103")
        XCTAssertEqual(values["calView"], "agendaWeek")
        XCTAssertEqual(values["federationIds[]"], "MMI2-B2")
        XCTAssertEqual(values["colourScheme"], "3")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Requested-With"), "XMLHttpRequest")
    }

    func testICalFallbackTriesStaticFederationFeedsBeforeLegacyRoute() throws {
        let urls = try CelcatICalClient().candidateURLs(for: .init(name: "MMI2-B2"))

        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(urls[0].host, "celcat.iut-velizy.uvsq.fr")
        XCTAssertEqual(urls[0].path, "/cal/ical/G1-TM2VJCBU5998/schedule.ics")
        XCTAssertEqual(urls[1].host, "celcat.rambouillet.iut-velizy.uvsq.fr")
        XCTAssertEqual(urls[2].host, "edt.iut-velizy.uvsq.fr")
        XCTAssertEqual(urls[2].path, "/Calendar/iCalendar")
    }

    @MainActor func testRemoteCalendarCacheIsScopedToSelectedGroups() throws {
        let suiteName = "CourslyTests.RemoteCalendarCache.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cache = RemoteCalendarCache(defaults: defaults)
        let group = StudentGroup(name: "MMI2-B2")
        let start = ISO8601DateFormatter().date(from: "2026-09-10T08:00:00Z")!
        let event = CalendarEvent(
            id: "cached", title: "Réseau", type: .tp,
            start: start, end: start.addingTimeInterval(3_600),
            rooms: ["B204"], teachers: ["Mme Dupont"], groups: [group],
            moduleCode: "R2", moduleName: "Réseau", source: .directPOST
        )

        cache.save([event], for: [group], at: start)

        XCTAssertEqual(cache.load(for: [group])?.events, [event])
        XCTAssertNil(cache.load(for: [.init(name: "MMI1-A1")]))
    }
}
