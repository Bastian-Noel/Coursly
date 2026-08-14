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
        XCTAssertEqual(event.type, .td)
        XCTAssertEqual(event.rooms, ["A101"])
        XCTAssertEqual(event.groups.map(\.name), ["MMI1-A1"])
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
