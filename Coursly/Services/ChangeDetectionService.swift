import Foundation

struct ChangeDetectionService: Sendable {
    func detect(old oldEvents: [CalendarEvent], new newEvents: [CalendarEvent], group: StudentGroup, detectedAt: Date = .now) -> [CalendarChange] {
        let old = oldEvents.sorted { $0.start < $1.start }
        let new = newEvents.sorted { $0.start < $1.start }
        var unmatchedNew = Set(new.indices)
        var changes: [CalendarChange] = []

        for oldEvent in old {
            let matchIndex = bestMatchIndex(for: oldEvent, in: new, available: unmatchedNew)
            guard let matchIndex else {
                changes.append(CalendarChange(kind: .removed, detectedAt: detectedAt, group: group, oldEvent: oldEvent))
                continue
            }
            unmatchedNew.remove(matchIndex)
            let newEvent = new[matchIndex]
            if oldEvent.start != newEvent.start || oldEvent.end != newEvent.end {
                changes.append(CalendarChange(kind: .moved, detectedAt: detectedAt, group: group, oldEvent: oldEvent, newEvent: newEvent))
            } else if materiallyDifferent(oldEvent, newEvent) {
                changes.append(CalendarChange(kind: .modified, detectedAt: detectedAt, group: group, oldEvent: oldEvent, newEvent: newEvent))
            }
        }

        for index in unmatchedNew.sorted() {
            changes.append(CalendarChange(kind: .added, detectedAt: detectedAt, group: group, newEvent: new[index]))
        }
        return changes.sorted { ($0.relevantDate ?? .distantFuture) < ($1.relevantDate ?? .distantFuture) }
    }

    func deduplicate(_ changes: [CalendarChange]) -> [CalendarChange] {
        struct Key: Hashable {
            let kind: CalendarChangeKind
            let title: String
            let oldStart: Date?
            let newStart: Date?
            let oldEnd: Date?
            let newEnd: Date?
            let oldRooms: [String]
            let newRooms: [String]
        }
        var seen = Set<Key>()
        var output: [CalendarChange] = []
        for change in changes {
            let key = Key(kind: change.kind, title: normalize(change.title), oldStart: change.oldEvent?.start, newStart: change.newEvent?.start, oldEnd: change.oldEvent?.end, newEnd: change.newEvent?.end, oldRooms: change.oldEvent?.rooms.sorted() ?? [], newRooms: change.newEvent?.rooms.sorted() ?? [])
            if seen.insert(key).inserted { output.append(change) }
        }
        return output
    }

    private func bestMatchIndex(for oldEvent: CalendarEvent, in candidates: [CalendarEvent], available: Set<Int>) -> Int? {
        if let exact = available.first(where: { candidates[$0].id == oldEvent.id }) { return exact }
        var best: (index: Int, score: Int)?
        for index in available {
            let score = similarity(oldEvent, candidates[index])
            if score >= 55, best == nil || score > best!.score { best = (index, score) }
        }
        return best?.index
    }

    private func similarity(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Int {
        var score = 0
        let lhsTitle = normalize(lhs.title)
        let rhsTitle = normalize(rhs.title)
        let lhsModule = normalize(lhs.moduleCode ?? lhs.moduleName ?? "")
        let rhsModule = normalize(rhs.moduleCode ?? rhs.moduleName ?? "")
        if !lhsModule.isEmpty, lhsModule == rhsModule { score += 40 }
        if lhsTitle == rhsTitle { score += 35 }
        let lhsCategory = normalize(lhs.categoryLabel ?? "")
        let rhsCategory = normalize(rhs.categoryLabel ?? "")
        if !lhsCategory.isEmpty, lhsCategory == rhsCategory { score += 10 }
        if overlaps(lhs.groups.map(\.name), rhs.groups.map(\.name)) { score += 10 }
        if overlaps(lhs.teachers, rhs.teachers) { score += 10 }
        if abs(lhs.duration - rhs.duration) <= 15 * 60 { score += 10 }
        if Calendar.current.isDate(lhs.start, inSameDayAs: rhs.start) { score += 5 }
        return score
    }

    private func materiallyDifferent(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Bool {
        normalize(lhs.title) != normalize(rhs.title)
            || normalize(lhs.categoryLabel ?? "") != normalize(rhs.categoryLabel ?? "")
            || lhs.rooms.sorted() != rhs.rooms.sorted()
            || lhs.teachers.sorted() != rhs.teachers.sorted()
            || lhs.moduleCode != rhs.moduleCode
            || lhs.moduleName != rhs.moduleName
    }

    private func overlaps(_ lhs: [String], _ rhs: [String]) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return !Set(lhs.map(normalize)).isDisjoint(with: Set(rhs.map(normalize)))
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
