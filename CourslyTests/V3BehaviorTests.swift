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
        let start = date("2026-09-10T08:00:00Z"), end = date("2026-09-10T10:00:00Z")
        let old = event(id: "same", start: start, end: end, room: "B204")
        let new = event(id: "same", start: start, end: end, room: "C310")
        let changes = ChangeDetectionService().detect(old: [old], new: [new], group: group)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .modified)
    }

    func testUnchangedCourseProducesNoChange() throws {
        let start = date("2026-09-10T08:00:00Z"), end = date("2026-09-10T10:00:00Z")
        XCTAssertTrue(ChangeDetectionService().detect(old: [event(id: "same", start: start, end: end)], new: [event(id: "same", start: start, end: end)], group: group).isEmpty)
    }

    func testSearchFacetsComeFromLoadedEvents() throws {
        let first = event(id: "1", title: "Développement iOS", start: date("2026-09-10T08:00:00Z"), end: date("2026-09-10T10:00:00Z"), room: "B204", teacher: "Mme Dupont")
        let second = event(id: "2", title: "Anglais", start: date("2026-09-10T10:30:00Z"), end: date("2026-09-10T12:00:00Z"), room: "C105", teacher: "M. Martin")
        let facets = SearchEngine().facets(from: [first, second])
        XCTAssertEqual(facets.teachers, ["M. Martin", "Mme Dupont"])
        XCTAssertEqual(facets.rooms, ["B204", "C105"])
        XCTAssertEqual(facets.subjects, ["Anglais", "Développement iOS"])
    }

    func testSearchCombinesTeacherAndRoomFilters() throws {
        let matching = event(id: "1", title: "Développement iOS", start: date("2026-09-10T08:00:00Z"), end: date("2026-09-10T10:00:00Z"), room: "B204", teacher: "Mme Dupont")
        let otherRoom = event(id: "2", title: "Développement iOS", start: date("2026-09-10T10:30:00Z"), end: date("2026-09-10T12:00:00Z"), room: "C105", teacher: "Mme Dupont")
        var filters = SearchFilters(); filters.teachers = ["Mme Dupont"]; filters.rooms = ["B204"]
        XCTAssertEqual(SearchEngine().results(in: [matching, otherRoom], filters: filters).map(\.id), ["1"])
    }

    func testSearchUsesDynamicCELCATTypeAndActualGroup() throws {
        var custom = event(
            id: "dynamic",
            start: date("2026-09-10T08:00:00Z"),
            end: date("2026-09-10T10:00:00Z")
        )
        custom.categoryLabel = "Atelier transversal"
        custom.rawGroupLabels = ["MMI2-B"]

        let facets = SearchEngine().facets(from: [custom])
        XCTAssertEqual(facets.types, ["Atelier transversal"])
        XCTAssertEqual(facets.groups, ["MMI2-B"])

        var filters = SearchFilters()
        filters.types = ["Atelier transversal"]
        filters.groups = ["MMI2-B"]
        XCTAssertEqual(SearchEngine().results(in: [custom], filters: filters).map(\.id), ["dynamic"])
    }

    func testDirectParserKeepsActualBroadCELCATGroup() throws {
        let payload = """
        [{"id":"evt-1","start":"2026-09-10T08:00:00","end":"2026-09-10T09:00:00","description":"Mme Dupont<br />MMI2-B<br />B204 - VEL<br />R218 - Développement iOS [MM2R18]","eventCategory":"Travaux pratiques","modules":["MM2R18"],"sites":["B204"],"allDay":false}]
        """.data(using: .utf8)!
        let event = try XCTUnwrap(DirectEventParser().parse(payload, group: StudentGroup(name: "MMI2-B2")).first)
        XCTAssertEqual(event.groups.map(\.name), ["MMI2-B2"], "Le groupe de requête reste disponible pour la provenance")
        XCTAssertEqual(event.displayGroupLabels, ["MMI2-B"], "L'UI doit afficher le groupe réellement annoncé par CELCAT")
    }

    func testVisualMergePreservesActualGroupInsteadOfSelectedSubgroups() {
        let start = date("2026-09-10T08:00:00Z"), end = date("2026-09-10T09:00:00Z")
        let b1 = CalendarEvent(id: "1", title: "Réseau", type: .tp, categoryLabel: "Travaux pratiques", start: start, end: end, rooms: ["B204"], teachers: ["Mme Dupont"], groups: [StudentGroup(name: "MMI2-B1")], rawGroupLabels: ["MMI2-B"], moduleCode: "R2", moduleName: "Réseau", source: .directPOST)
        let b2 = CalendarEvent(id: "2", title: "Réseau", type: .tp, categoryLabel: "Travaux pratiques", start: start, end: end, rooms: ["B204"], teachers: ["Mme Dupont"], groups: [StudentGroup(name: "MMI2-B2")], rawGroupLabels: ["MMI2-B"], moduleCode: "R2", moduleName: "Réseau", source: .directPOST)
        let merged = CalendarService().mergeVisualDuplicates([b1, b2])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].displayGroupLabels, ["MMI2-B"])
        XCTAssertEqual(Set(merged[0].groups.map(\.name)), Set(["MMI2-B1", "MMI2-B2"]))
    }

    func testBackToBackCoursesDoNotCreateParallelColumns() {
        let first = event(id: "1", start: date("2026-09-10T08:00:00Z"), end: date("2026-09-10T09:00:00Z"))
        let second = event(id: "2", start: date("2026-09-10T09:00:00Z"), end: date("2026-09-10T10:00:00Z"))
        let placements = EventLayoutEngine().placements(for: [first, second])
        XCTAssertEqual(placements.map(\.columnCount), [1, 1])
        XCTAssertEqual(placements.map(\.column), [0, 0])
    }

    func testTimelineCoordinatesUseRealParisClockTime() throws {
        let date = try XCTUnwrap(courslyCalendar.date(from: DateComponents(
            timeZone: TimeZone(identifier: "Europe/Paris"),
            year: 2026,
            month: 9,
            day: 10,
            hour: 13,
            minute: 30
        )))
        XCTAssertEqual(TimelineAxis.minute(of: date), 13 * 60 + 30)
        XCTAssertEqual(TimelineAxis.y(for: date, hourHeight: 80), 1_080, accuracy: 0.01)
    }

    func testWeekOffsetRemovesHeaderBeforeConvertingToMinute() {
        let offset = TimelineMetrics.weekHeaderHeight + 6 * 80
        XCTAssertEqual(
            TimelineAxis.minute(forContentOffset: offset, headerHeight: TimelineMetrics.weekHeaderHeight, hourHeight: 80),
            6 * 60
        )
    }

    func testTimelineComputesExactCenteredOffsetInsteadOfMidnightAnchor() {
        XCTAssertEqual(
            TimelineAxis.contentOffset(
                forMinute: 8 * 60,
                anchor: .center,
                hourHeight: 80,
                viewportHeight: 400
            ),
            440,
            accuracy: 0.01
        )
    }

    func testWeekTopOffsetIncludesScrollingHeader() {
        XCTAssertEqual(
            TimelineAxis.contentOffset(
                forMinute: 8 * 60,
                anchor: .top,
                headerHeight: TimelineMetrics.weekHeaderHeight,
                hourHeight: 80,
                viewportHeight: 400
            ),
            TimelineMetrics.weekHeaderHeight + 640,
            accuracy: 0.01
        )
    }

    func testInitialZeroGeometryCannotOverwritePendingRestoration() {
        var state = TimelineVerticalScrollState()
        state.beginRestoration(to: 440)

        XCTAssertFalse(state.observe(offset: 0))
        XCTAssertEqual(state.expectedOffset, 440)
        XCTAssertFalse(state.isUserControlled)

        XCTAssertTrue(state.observe(offset: 441))
        XCTAssertNil(state.expectedOffset)
        XCTAssertTrue(state.isUserControlled)
    }

    @MainActor func testGoToTodayKeepsCurrentDisplayMode() {
        let store = CalendarStore()
        store.displayMode = .week
        store.goToToday()
        XCTAssertEqual(store.displayMode, .week)
        XCTAssertEqual(store.timelineScrollRequest?.target, .now)
    }

    @MainActor func testHorizontalDayMoveDoesNotRequestVerticalRecentering() {
        let store = CalendarStore()
        store.timelineScrollRequest = nil
        store.dayTopMinute = 9 * 60 + 15
        store.moveDay(1)
        XCTAssertNil(store.timelineScrollRequest)
        XCTAssertEqual(store.dayTopMinute, 9 * 60 + 15)
    }

    @MainActor func testDisplayModeChangePreservesIndependentVerticalPositions() {
        let store = CalendarStore()
        store.dayTopMinute = 8 * 60
        store.weekTopMinute = 10 * 60
        store.timelineScrollRequest = nil
        store.setDisplayMode(.week)
        XCTAssertNil(store.timelineScrollRequest)
        XCTAssertEqual(store.dayTopMinute, 8 * 60)
        XCTAssertEqual(store.weekTopMinute, 10 * 60)
    }

    private func event(id: String, title: String = "Développement iOS", start: Date, end: Date, room: String = "B204", teacher: String = "Mme Dupont") -> CalendarEvent {
        CalendarEvent(id: id, title: title, type: .tp, start: start, end: end, rooms: [room], teachers: [teacher], groups: [group], moduleCode: "R4.01", moduleName: "Développement iOS", source: .directPOST)
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
}
