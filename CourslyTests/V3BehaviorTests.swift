import XCTest
@testable import Coursly

final class V3BehaviorTests: XCTestCase {
    private let group = StudentGroup(name: "MMI2-A1")

    func testMovedCourseIsDetectedAsMoveNotRemovePlusAdd() throws {
        let old = event(id: "old-id", start: date("2026-09-10T08:00:00Z"), end: date("2026-09-10T10:00:00Z"))
        let new = event(id: "new-id", start: date("2026-09-10T12:00:00Z"), end: date("2026-09-10T14:00:00Z"))

        let changes = ChangeDetectionService().detect(old: [old], new: [new], group: group)

        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .moved)
    }

    func testRoomChangeIsDetectedAsModification() throws {
        let start = date("2026-09-10T08:00:00Z")
        let end = date("2026-09-10T10:00:00Z")
        let old = event(id: "same", start: start, end: end, room: "B204")
        let new = event(id: "same", start: start, end: end, room: "C310")

        let changes = ChangeDetectionService().detect(old: [old], new: [new], group: group)

        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .modified)
    }

    func testUnchangedCourseProducesNoChange() throws {
        let start = date("2026-09-10T08:00:00Z")
        let end = date("2026-09-10T10:00:00Z")
        let old = event(id: "same", start: start, end: end)
        let new = event(id: "same", start: start, end: end)

        XCTAssertTrue(ChangeDetectionService().detect(old: [old], new: [new], group: group).isEmpty)
    }

    func testSearchFacetsComeFromLoadedEvents() throws {
        let first = event(
            id: "1",
            title: "Développement iOS",
            start: date("2026-09-10T08:00:00Z"),
            end: date("2026-09-10T10:00:00Z"),
            room: "B204",
            teacher: "Mme Dupont"
        )
        let second = event(
            id: "2",
            title: "Anglais",
            start: date("2026-09-10T10:30:00Z"),
            end: date("2026-09-10T12:00:00Z"),
            room: "C105",
            teacher: "M. Martin"
        )

        let facets = SearchEngine().facets(from: [first, second])

        XCTAssertEqual(facets.teachers, ["M. Martin", "Mme Dupont"])
        XCTAssertEqual(facets.rooms, ["B204", "C105"])
        XCTAssertEqual(facets.subjects, ["Anglais", "Développement iOS"])
    }

    func testSearchCombinesTeacherAndRoomFilters() throws {
        let matching = event(
            id: "1",
            title: "Développement iOS",
            start: date("2026-09-10T08:00:00Z"),
            end: date("2026-09-10T10:00:00Z"),
            room: "B204",
            teacher: "Mme Dupont"
        )
        let otherRoom = event(
            id: "2",
            title: "Développement iOS",
            start: date("2026-09-10T10:30:00Z"),
            end: date("2026-09-10T12:00:00Z"),
            room: "C105",
            teacher: "Mme Dupont"
        )

        var filters = SearchFilters()
        filters.teachers = ["Mme Dupont"]
        filters.rooms = ["B204"]

        XCTAssertEqual(SearchEngine().results(in: [matching, otherRoom], filters: filters).map(\.id), ["1"])
    }

    private func event(
        id: String,
        title: String = "Développement iOS",
        start: Date,
        end: Date,
        room: String = "B204",
        teacher: String = "Mme Dupont"
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            type: .tp,
            start: start,
            end: end,
            rooms: [room],
            teachers: [teacher],
            groups: [group],
            moduleCode: "R4.01",
            moduleName: "Développement iOS",
            source: .directPOST
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
