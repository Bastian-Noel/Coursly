import Foundation

struct CachedRemoteCalendar: Codable, Sendable {
    let groupNames: [String]
    let savedAt: Date
    let events: [CalendarEvent]
}

@MainActor
struct RemoteCalendarCache {
    private let defaults: UserDefaults
    private let key = "v3.remoteCalendarCache"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(for groups: [StudentGroup]) -> CachedRemoteCalendar? {
        guard let data = defaults.data(forKey: key),
              let cached = try? JSONDecoder().decode(CachedRemoteCalendar.self, from: data),
              cached.groupNames == normalizedNames(groups) else { return nil }
        return cached
    }

    func save(_ events: [CalendarEvent], for groups: [StudentGroup], at date: Date = .now) {
        let cached = CachedRemoteCalendar(groupNames: normalizedNames(groups), savedAt: date, events: events)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        defaults.set(data, forKey: key)
    }

    private func normalizedNames(_ groups: [StudentGroup]) -> [String] {
        groups.map(\.name).sorted()
    }
}

@MainActor
struct DirectSnapshotStore {
    private let defaults = UserDefaults.standard
    private let key = "v3.directSnapshots"

    func snapshot(for group: StudentGroup) -> [CalendarEvent]? { loadAll()[group.name] }
    func save(_ events: [CalendarEvent], for group: StudentGroup) {
        var all = loadAll(); all[group.name] = events
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: key)
    }
    private func loadAll() -> [String: [CalendarEvent]] {
        guard let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([String: [CalendarEvent]].self, from: data) else { return [:] }
        return decoded
    }
}

@MainActor
struct ChangeHistoryStore {
    private let defaults = UserDefaults.standard
    private let key = "v3.changeHistory"
    func all() -> [CalendarChange] {
        guard let data = defaults.data(forKey: key), let changes = try? JSONDecoder().decode([CalendarChange].self, from: data) else { return [] }
        return changes.sorted { $0.detectedAt > $1.detectedAt }
    }
    func prepend(_ changes: [CalendarChange], now: Date = .now) {
        guard !changes.isEmpty else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? .distantPast
        let merged = (changes + all()).filter { $0.detectedAt >= cutoff }.reduce(into: [UUID: CalendarChange]()) { $0[$1.id] = $1 }.values.sorted { $0.detectedAt > $1.detectedAt }
        guard let data = try? JSONEncoder().encode(Array(merged.prefix(200))) else { return }
        defaults.set(data, forKey: key)
    }
    func clear() { defaults.removeObject(forKey: key) }
}

@MainActor
struct LocalEventStore {
    private let defaults = UserDefaults.standard
    private let key = "v3.localEvents"
    func all() -> [CalendarEvent] {
        guard let data = defaults.data(forKey: key), let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else { return [] }
        return events.sorted { $0.start < $1.start }
    }
    func save(_ events: [CalendarEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }; defaults.set(data, forKey: key)
    }
    func add(_ event: CalendarEvent) { var events = all(); events.removeAll { $0.id == event.id }; events.append(event); save(events) }
    func delete(id: String) { save(all().filter { $0.id != id }) }
}
