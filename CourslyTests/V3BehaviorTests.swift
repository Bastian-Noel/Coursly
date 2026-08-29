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

    func testWeekHeaderCompensatesVerticalScrollAndNeverMovesAboveItsOrigin() {
        XCTAssertEqual(TimelineAxis.pinnedHeaderOffset(forContentOffset: -18), 0)
        XCTAssertEqual(TimelineAxis.pinnedHeaderOffset(forContentOffset: 420), 420)
    }

    @MainActor func testReturningToDayRestoresItsDateWithoutWeekSwipe() {
        let store = CalendarStore()
        let day = date("2026-09-10T08:00:00Z")
        store.goToDate(day)
        store.setDisplayMode(.week)

        store.focusedDate = date("2026-09-07T08:00:00Z")
        store.setDisplayMode(.day)

        XCTAssertTrue(courslyCalendar.isDate(store.focusedDate, inSameDayAs: day))
    }

    @MainActor func testWeekSwipeBecomesDayReturnDate() {
        let store = CalendarStore()
        let scrolledDay = date("2026-09-14T08:00:00Z")
        store.setDisplayMode(.week)
        store.setFocusedDateFromTimeline(scrolledDay)
        store.setDisplayMode(.day)

        XCTAssertTrue(courslyCalendar.isDate(store.focusedDate, inSameDayAs: scrolledDay))
    }

    @MainActor func testCompleteCohortUsesCompactGroupLabel() throws {
        let store = CalendarStore()
        let mmi2 = StudentGroup.all.filter { $0.name.hasPrefix("MMI2-") }
        XCTAssertFalse(mmi2.isEmpty)
        store.setSelectedGroups(mmi2)
        XCTAssertEqual(store.compactSelectedGroupsLabel, "MMI2")
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

    func testDefaultTypeRulesGroupKnownVariantsWithoutRenamingThem() {
        let classifier = CourseTypeClassifier(groups: CourseTypeRulePreferences.defaultRules)
        XCTAssertNotNil(classifier.match("Cours magistral (CM)"))
        XCTAssertNotNil(classifier.match("TRAVAUX DIRIGÉS"))
        XCTAssertNotNil(classifier.match("Travaux pratiques"))
        XCTAssertEqual(
            classifier.groupingKey(for: "Cours magistral (CM)"),
            classifier.groupingKey(for: "CM")
        )

        var event = event(
            id: "type-label",
            start: date("2026-09-10T08:00:00Z"),
            end: date("2026-09-10T09:00:00Z")
        )
        event.categoryLabel = "Cours magistral (CM)"
        let reclassified = classifier.reclassify(event)
        XCTAssertNil(reclassified.type)
        XCTAssertEqual(reclassified.displayTypeLabel, "Cours magistral (CM)")
    }

    func testCustomGroupAcceptsSeveralRegexAndOptionalRename() {
        let custom = CourseTypeGroup(
            name: "Ateliers",
            patterns: [#"atelier\s+transversal"#, #"atelier\s+client"#],
            displayRename: "Atelier"
        )
        let classifier = CourseTypeClassifier(groups: [custom])

        XCTAssertEqual(custom.validPatterns.count, 2)
        XCTAssertEqual(classifier.match("Atelier transversal")?.displayRename, "Ateliers")
        XCTAssertEqual(classifier.match("ATELIER CLIENT")?.groupID, custom.id)
        XCTAssertNil(classifier.match("Cours magistral"))
    }

    func testRenamedGroupAlwaysUsesItsOwnName() {
        var group = CourseTypeGroup(name: "Ateliers", patterns: [#"atelier"#], displayRename: "Ancien libellé")
        XCTAssertEqual(CourseTypeClassifier(groups: [group]).match("Atelier client")?.displayRename, "Ateliers")

        group.name = "Séances pratiques"
        XCTAssertEqual(CourseTypeClassifier(groups: [group]).match("Atelier client")?.displayRename, "Séances pratiques")
    }

    func testInvalidOrDisabledRegexNeverClassifiesAType() {
        let invalid = CourseTypeGroup(name: "Invalide", patterns: [#"("#])
        let disabled = CourseTypeGroup(name: "TD", patterns: [#"dirige"#], isEnabled: false)
        let classifier = CourseTypeClassifier(groups: [invalid, disabled])

        XCTAssertTrue(invalid.validPatterns.isEmpty)
        XCTAssertNil(classifier.match("Travaux dirigés"))
    }

    func testColorSettingsDistinguishUnknownTypeFromEmptyRegexGroup() {
        XCTAssertEqual(
            CourseColorDetectionStatus.dynamic(variants: []).text,
            nil
        )
        XCTAssertEqual(
            CourseColorDetectionStatus.configured(matches: []).text,
            "Aucun cours correspondant dans les données chargées"
        )
        XCTAssertFalse(CourseColorDetectionStatus.dynamic(variants: []).isEmptyConfiguredGroup)
        XCTAssertTrue(CourseColorDetectionStatus.configured(matches: []).isEmptyConfiguredGroup)
    }

    func testCourseColorsAreOrderedByFrequencyThenName() {
        XCTAssertTrue(CourseColorFrequencyOrder.precedes(firstFrequency: 8, firstLabel: "TD", secondFrequency: 3, secondLabel: "CM"))
        XCTAssertTrue(CourseColorFrequencyOrder.precedes(firstFrequency: 3, firstLabel: "CM", secondFrequency: 3, secondLabel: "TD"))
        XCTAssertFalse(CourseColorFrequencyOrder.precedes(firstFrequency: 1, firstLabel: "CM", secondFrequency: 7, secondLabel: "TP"))
    }

    func testHorizontalDayGestureSuppressesCourseOpening() {
        XCTAssertTrue(CourseInteractionGate.isHorizontalNavigation(CGSize(width: 42, height: 8)))
        XCTAssertFalse(CourseInteractionGate.isHorizontalNavigation(CGSize(width: 8, height: 42)))
        XCTAssertFalse(CourseInteractionGate.isHorizontalNavigation(CGSize(width: 4, height: 1)))
    }

    func testAppearancePreferenceOffersSystemLightAndDarkModes() {
        XCTAssertEqual(AppAppearancePreference.allCases, [.system, .light, .dark])
        XCTAssertEqual(AppAppearancePreference.system.frenchTitle, "Selon l’iPhone")
        XCTAssertEqual(AppAppearancePreference.light.frenchTitle, "Clair")
        XCTAssertEqual(AppAppearancePreference.dark.frenchTitle, "Sombre")
    }

    func testLiveActivityStateCarriesNextCoursePresentation() {
        let start = date("2026-09-10T13:30:00Z")
        let end = date("2026-09-10T15:00:00Z")
        let state = CourslyActivityAttributes.ContentState(
            status: "BIENTÔT TERMINÉ",
            title: "Développement",
            room: "I22",
            teachers: "Olivier",
            groups: "MMI2-A",
            type: "Travaux dirigés",
            accentHex: "#FF5A52",
            start: start,
            end: end,
            timerStart: start,
            timerEnd: end,
            progressStart: start,
            progressEnd: end,
            tomorrowStart: nil,
            nextTitle: "Anglais",
            nextRoom: "E57",
            nextType: "CM",
            nextAccentHex: "#4A90FF",
            nextStart: end,
            nextEnd: end.addingTimeInterval(3600),
            nextTeachers: "Camille",
            nextGroups: "MMI2-A",
            nextTimerStart: end,
            nextTimerEnd: end.addingTimeInterval(3600),
            isLastCourse: false,
            nextIsLastCourse: true,
            isInProgress: true,
            dayFinished: false
        )

        XCTAssertEqual(state.nextType, "CM")
        XCTAssertEqual(state.nextAccentHex, "#4A90FF")
        XCTAssertEqual(state.nextIsLastCourse, true)
        XCTAssertEqual(state.start, start, "Les horaires réels restent inchangés")
    }

    func testLiveActivityPauseProgressStartsAfterPreviousCourse() {
        let previous = event(
            id: "previous",
            start: date("2026-09-10T08:00:00Z"),
            end: date("2026-09-10T10:00:00Z")
        )
        let upcoming = event(
            id: "upcoming",
            start: date("2026-09-10T11:00:00Z"),
            end: date("2026-09-10T12:00:00Z")
        )
        let now = date("2026-09-10T10:30:00Z")

        XCTAssertEqual(LiveActivitySchedule.upcomingStatus(previous: previous, upcoming: upcoming, now: now), "EN PAUSE")
        XCTAssertEqual(LiveActivitySchedule.pauseInterval(previous: previous, upcoming: upcoming, now: now), DateInterval(start: previous.end, end: upcoming.start))
    }

    func testLiveActivityHasNoProgressBeforeFirstCourse() {
        let upcoming = event(
            id: "first",
            start: date("2026-09-10T11:00:00Z"),
            end: date("2026-09-10T12:00:00Z")
        )
        let now = date("2026-09-10T07:00:00Z")

        XCTAssertEqual(LiveActivitySchedule.upcomingStatus(previous: nil, upcoming: upcoming, now: now), "PREMIER COURS")
        XCTAssertNil(LiveActivitySchedule.pauseInterval(previous: nil, upcoming: upcoming, now: now))
    }

    func testLiveActivityKeepsTomorrowCourseAsCompactPreviewOnly() {
        let upcoming = event(
            id: "tomorrow",
            start: date("2026-09-11T06:30:00Z"),
            end: date("2026-09-11T08:00:00Z")
        )
        let now = date("2026-09-10T16:00:00Z")

        XCTAssertEqual(LiveActivitySchedule.tomorrowEvent(from: [upcoming], now: now)?.id, "tomorrow")
        XCTAssertEqual(LiveActivitySchedule.upcomingStatus(previous: nil, upcoming: upcoming, now: now), "PREMIER COURS")
    }

    func testLiveActivityAccentRaisesDarkColorLuminance() throws {
        let adjusted = LiveActivityAccent.readableHex(from: "#5E1B86")
        let luminance = try XCTUnwrap(LiveActivityAccent.relativeLuminance(of: adjusted))
        XCTAssertGreaterThanOrEqual(luminance, 0.34)
    }

    func testLiveActivityScheduleDeduplicatesAndSkipsOverlappingCourses() {
        let first = event(
            id: "first",
            title: "Développement",
            start: date("2026-09-10T08:00:00Z"),
            end: date("2026-09-10T10:00:00Z")
        )
        let duplicate = event(
            id: "duplicate",
            title: "Développement",
            start: date("2026-09-10T08:00:00Z"),
            end: date("2026-09-10T10:00:00Z")
        )
        let overlap = event(
            id: "overlap",
            title: "Cours en conflit",
            start: date("2026-09-10T09:00:00Z"),
            end: date("2026-09-10T11:00:00Z")
        )
        let following = event(
            id: "following",
            title: "Anglais",
            start: date("2026-09-10T11:00:00Z"),
            end: date("2026-09-10T12:00:00Z")
        )

        let ordered = LiveActivitySchedule.orderedEvents(from: [following, duplicate, overlap, first])

        XCTAssertEqual(ordered.count, 3)
        XCTAssertEqual(ordered.map(\.title), ["Développement", "Cours en conflit", "Anglais"])
        XCTAssertEqual(LiveActivitySchedule.nextIndex(after: 0, in: ordered), 2)
        XCTAssertNil(LiveActivitySchedule.nextIndex(after: 2, in: ordered))
    }

    private func event(id: String, title: String = "Développement iOS", start: Date, end: Date, room: String = "B204", teacher: String = "Mme Dupont") -> CalendarEvent {
        CalendarEvent(id: id, title: title, type: .tp, start: start, end: end, rooms: [room], teachers: [teacher], groups: [group], moduleCode: "R4.01", moduleName: "Développement iOS", source: .directPOST)
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
}
