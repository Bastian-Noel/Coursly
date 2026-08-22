import SwiftUI

private let timelineTimeWidth: CGFloat = 44
private let weekHeaderHeight: CGFloat = 52
private let weekPreloadRadius = 90
private let courseBottomGap: CGFloat = 3

struct EventPlacement: Identifiable { let event: CalendarEvent; let column: Int; let columnCount: Int; var id: String { event.id + "-\(column)" } }

struct EventLayoutEngine {
    func placements(for events: [CalendarEvent]) -> [EventPlacement] {
        let ordered = events.filter { $0.end > $0.start }.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
        var output: [EventPlacement] = [], cluster: [CalendarEvent] = []; var clusterEnd: Date?
        func flush() {
            guard !cluster.isEmpty else { return }; var ends: [Date] = []; var assigned: [(CalendarEvent, Int)] = []
            for event in cluster { if let index = ends.firstIndex(where: { $0 <= event.start }) { ends[index] = event.end; assigned.append((event, index)) } else { assigned.append((event, ends.count)); ends.append(event.end) } }
            let count = max(1, ends.count); output.append(contentsOf: assigned.map { EventPlacement(event: $0.0, column: $0.1, columnCount: count) }); cluster.removeAll(keepingCapacity: true); clusterEnd = nil
        }
        for event in ordered { if let end = clusterEnd, event.start >= end { flush() }; cluster.append(event); clusterEnd = max(clusterEnd ?? event.end, event.end) }; flush(); return output
    }
}

struct DayTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void
    @State private var didInitialScroll = false
    @State private var pageOffset: CGFloat = 0
    @State private var isChangingDay = false
    @GestureState private var dragX: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    let previous = store.adjacentVisibleDate(direction: -1), next = store.adjacentVisibleDate(direction: 1)
                    HStack(spacing: 0) { page(previous, viewport.size.width, nil); page(store.focusedDate, viewport.size.width, store.highlightedEventID); page(next, viewport.size.width, nil) }
                        .frame(width: viewport.size.width * 3, alignment: .leading).offset(x: -viewport.size.width + pageOffset + dragX).overlay(alignment: .topLeading) { dayAnchors }
                }
                .clipped().contentShape(Rectangle()).simultaneousGesture(daySwipe(width: viewport.size.width))
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { oldValue, newValue in scrollFeedback(oldValue, newValue) }
                .task {
                    await store.ensureLoaded(around: store.focusedDate)
                    guard !didInitialScroll else { return }; await scrollAfterLayout(proxy: proxy, animated: false, initial: true); didInitialScroll = true
                }
                .onChange(of: store.timelineRecenterToken) { _, _ in Task { @MainActor in await scrollAfterLayout(proxy: proxy, animated: true, forceNow: true) } }
                .onChange(of: store.highlightedEventID) { _, value in guard value != nil else { return }; Task { @MainActor in await scrollAfterLayout(proxy: proxy, animated: true) } }
                .refreshable { await store.refresh() }
            }
        }
    }

    private func page(_ date: Date, _ width: CGFloat, _ highlight: String?) -> some View { DayTimelineCanvas(date: date, events: store.events(on: date), hourHeight: CGFloat(store.hourHeight), highlightedEventID: highlight, onSelect: onSelect).frame(width: width) }
    private var dayAnchors: some View { ZStack(alignment: .topLeading) { ForEach(0..<96, id: \.self) { q in Color.clear.frame(width: 1, height: 1).offset(y: CGFloat(q) * CGFloat(store.hourHeight) / 4).id("day-quarter-\(q)") }; Color.clear.frame(width: 1, height: 1).offset(y: yPosition(for: store.now, hourHeight: CGFloat(store.hourHeight))).id("day-now") } }

    private func scrollAfterLayout(proxy: ScrollViewProxy, animated: Bool, forceNow: Bool = false, initial: Bool = false) async {
        await Task.yield(); try? await Task.sleep(for: .milliseconds(100)); let isToday = calendar.isDate(store.focusedDate, inSameDayAs: store.now)
        if forceNow || (initial && isToday) { scroll(proxy, "day-now", .center, animated); return }
        if let id = store.highlightedEventID, let event = store.events.first(where: { $0.id == id }) { scroll(proxy, "day-quarter-\(max(0, min(95, minutesSinceMidnight(event.start) / 15)))", .center, animated) }
    }
    private func scroll(_ proxy: ScrollViewProxy, _ id: String, _ anchor: UnitPoint, _ animated: Bool) { if animated { withAnimation(.snappy(duration: 0.38)) { proxy.scrollTo(id, anchor: anchor) } } else { proxy.scrollTo(id, anchor: anchor) } }
    private func daySwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12).updating($dragX) { value, state, _ in guard abs(value.translation.width) > abs(value.translation.height) * 1.08 else { return }; state = max(-width, min(width, value.translation.width)) }.onEnded { value in
            guard !isChangingDay else { return }; let horizontal = value.translation.width, vertical = value.translation.height, predicted = value.predictedEndTranslation.width, effective = abs(predicted) > abs(horizontal) ? predicted : horizontal
            guard abs(effective) > 58, abs(horizontal) > abs(vertical) * 1.08 else { withAnimation(.snappy(duration: 0.18)) { pageOffset = 0 }; return }
            let direction = effective < 0 ? 1 : -1; isChangingDay = true; withAnimation(.snappy(duration: 0.2)) { pageOffset = direction > 0 ? -width : width }
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(190)); store.moveDay(direction); var transaction = Transaction(); transaction.disablesAnimations = true; withTransaction(transaction) { pageOffset = 0 }; isChangingDay = false; await store.ensureLoaded(around: store.focusedDate) }
        }
    }
    private func scrollFeedback(_ oldValue: CGFloat, _ newValue: CGFloat) { guard store.hapticsEnabled else { return }; let h = CGFloat(store.hourHeight), old = max(0, oldValue), new = max(0, newValue), low = min(old, new), high = max(old, new); if courseBoundaryOffsets(events: store.events(on: store.focusedDate), hourHeight: h).contains(where: { $0 > low && $0 <= high }) { HapticService.fire(.scrollCourse, enabled: true) } else if Int(old / h) != Int(new / h) { HapticService.fire(.scrollHour, enabled: true) } }
}

struct DayTimelineCanvas: View {
    @Environment(CalendarStore.self) private var store
    let date: Date; let events: [CalendarEvent]; let hourHeight: CGFloat; let highlightedEventID: String?; let onSelect: (CalendarEvent) -> Void
    private let engine = EventLayoutEngine()
    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(1, proxy.size.width - timelineTimeWidth)
            ZStack(alignment: .topLeading) {
                DayHourGrid(hourHeight: hourHeight)
                ForEach(engine.placements(for: events)) { placement in
                    let lane = max(1, contentWidth / CGFloat(placement.columnCount)), top = yPosition(for: placement.event.start, hourHeight: hourHeight), bottom = yPosition(for: placement.event.end, hourHeight: hourHeight), cardHeight = max(1, bottom - top - courseBottomGap)
                    CourseBlock(event: placement.event, availableWidth: lane, height: cardHeight, highlighted: highlightedEventID == placement.event.id, isPast: placement.event.end <= store.now)
                        .frame(width: lane, height: cardHeight, alignment: .top).offset(x: timelineTimeWidth + CGFloat(placement.column) * lane, y: top).onTapGesture { onSelect(placement.event) }
                }
                if calendar.isDate(date, inSameDayAs: store.now) { CurrentTimeIndicator(hourHeight: hourHeight, x: timelineTimeWidth, width: contentWidth) }
            }
        }.frame(height: hourHeight * 24 + 1)
    }
}

private struct DayHourGrid: View {
    let hourHeight: CGFloat
    var body: some View { ZStack(alignment: .topLeading) { ForEach(0...24, id: \.self) { hour in let y = CGFloat(hour) * hourHeight; Text(String(format: "%02d", hour % 24)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: timelineTimeWidth - 10, height: 16, alignment: .trailing).position(x: (timelineTimeWidth - 10) / 2, y: y); Rectangle().fill(Color.secondary.opacity(hour % 3 == 0 ? 0.24 : 0.14)).frame(height: hour % 3 == 0 ? 0.8 : 0.5).padding(.leading, timelineTimeWidth).offset(y: y) } }.frame(height: hourHeight * 24 + 1) }
}

struct WeekTimelineView: View {
    @Environment(CalendarStore.self) private var store
    let onSelect: (CalendarEvent) -> Void
    @State private var centerDate = Date()
    @State private var didInitialScroll = false
    @State private var horizontalPosition: String?

    var body: some View {
        GeometryReader { viewport in
            let dayWidth = max(1, (viewport.size.width - timelineTimeWidth) / 5), days = loadedDays(around: centerDate)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: timelineTimeWidth, height: weekHeaderHeight)
                    ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 0) { ForEach(days, id: \.self) { day in weekHeader(day, width: dayWidth).id(weekDayID(day)) } }.scrollTargetLayout() }
                        .scrollPosition(id: $horizontalPosition, anchor: .leading).scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                }.background(.ultraThinMaterial).overlay(alignment: .bottom) { Rectangle().fill(Color.secondary.opacity(0.16)).frame(height: 0.5) }
                ScrollViewReader { verticalProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            WeekTimeColumn(hourHeight: CGFloat(store.hourHeight)).frame(width: timelineTimeWidth)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 0) { ForEach(days, id: \.self) { day in WeekDayColumn(day: day, events: store.events(on: day), now: store.now, hourHeight: CGFloat(store.hourHeight), width: dayWidth, highlightedEventID: store.highlightedEventID, onSelect: onSelect).frame(width: dayWidth).id(weekDayID(day)) } }.scrollTargetLayout()
                            }.scrollPosition(id: $horizontalPosition, anchor: .leading).scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        }.overlay(alignment: .topLeading) { weekAnchors }
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { old, new in let h = CGFloat(store.hourHeight); if store.hapticsEnabled, Int(max(0, old) / h) != Int(max(0, new) / h) { HapticService.fire(.scrollHour, enabled: true) } }
                    .task {
                        centerDate = calendar.startOfDay(for: store.focusedDate); await store.ensureLoaded(around: store.focusedDate)
                        guard !didInitialScroll else { return }; horizontalPosition = weekDayID(visibleFive(from: store.focusedDate).first ?? store.focusedDate); await scrollWeekVertically(proxy: verticalProxy, days: visibleFive(from: store.focusedDate), animated: false); didInitialScroll = true
                    }
                    .onChange(of: store.timelineRecenterToken) { _, _ in Task { @MainActor in centerDate = calendar.startOfDay(for: store.focusedDate); horizontalPosition = weekDayID(visibleFive(from: store.focusedDate).first ?? store.focusedDate); await scrollWeekVertically(proxy: verticalProxy, days: visibleFive(from: store.focusedDate), animated: true) } }
                    .refreshable { await store.refresh() }
                }
            }
        }
    }

    private func weekHeader(_ day: Date, width: CGFloat) -> some View {
        Button { store.focusedDate = calendar.startOfDay(for: day); store.setDisplayMode(.day) } label: {
            VStack(spacing: 1) { Text(capitalizedWeekday(day)).font(.caption2.weight(.semibold)).lineLimit(1); Text(day.formatted(.dateTime.day())).font(.subheadline.monospacedDigit().bold()) }
                .frame(width: width, height: weekHeaderHeight).foregroundStyle(calendar.isDate(day, inSameDayAs: store.now) ? Color.accentColor : Color.primary).background(day < calendar.startOfDay(for: store.now) ? Color.black.opacity(0.13) : Color.clear)
        }.buttonStyle(.plain)
    }
    private var weekAnchors: some View { ZStack(alignment: .topLeading) { ForEach(0..<96, id: \.self) { q in Color.clear.frame(width: 1, height: 1).offset(y: CGFloat(q) * CGFloat(store.hourHeight) / 4).id("week-quarter-\(q)") } } }
    private func loadedDays(around center: Date) -> [Date] { var before: [Date] = [], after: [Date] = [], left = calendar.startOfDay(for: center), right = calendar.startOfDay(for: center); for _ in 0..<weekPreloadRadius { left = store.adjacentVisibleDate(from: left, direction: -1); right = store.adjacentVisibleDate(from: right, direction: 1); before.append(left); after.append(right) }; return Array(before.reversed()) + [calendar.startOfDay(for: center)] + after }
    private func visibleFive(from date: Date) -> [Date] { let start = store.visibleWeekDays(containing: date).first ?? calendar.startOfDay(for: date); var result = [start], cursor = start; while result.count < 5 { cursor = store.adjacentVisibleDate(from: cursor, direction: 1); result.append(cursor) }; return result }
    private func scrollWeekVertically(proxy: ScrollViewProxy, days: [Date], animated: Bool) async { await Task.yield(); try? await Task.sleep(for: .milliseconds(120)); let minute = days.flatMap { store.events(on: $0) }.map(\.start).min().map(minutesSinceMidnight) ?? 8 * 60, target = "week-quarter-\(max(0, min(95, minute / 15)))"; if animated { withAnimation(.snappy(duration: 0.35)) { proxy.scrollTo(target, anchor: .top) } } else { proxy.scrollTo(target, anchor: .top) } }
}

private func weekDayID(_ date: Date) -> String { "week-day-\(Int(calendar.startOfDay(for: date).timeIntervalSince1970))" }
private struct WeekTimeColumn: View { let hourHeight: CGFloat; var body: some View { ZStack(alignment: .topLeading) { ForEach(0...24, id: \.self) { hour in Text(String(format: "%02d", hour % 24)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: timelineTimeWidth - 10, height: 16, alignment: .trailing).position(x: (timelineTimeWidth - 10) / 2, y: CGFloat(hour) * hourHeight) } }.frame(height: hourHeight * 24 + 1) } }

private struct WeekDayColumn: View {
    let day: Date; let events: [CalendarEvent]; let now: Date; let hourHeight: CGFloat; let width: CGFloat; let highlightedEventID: String?; let onSelect: (CalendarEvent) -> Void
    private let engine = EventLayoutEngine()
    var body: some View {
        ZStack(alignment: .topLeading) {
            if day < calendar.startOfDay(for: now) { Color.black.opacity(0.10) }
            ForEach(0...24, id: \.self) { hour in Rectangle().fill(Color.secondary.opacity(hour % 3 == 0 ? 0.24 : 0.14)).frame(height: hour % 3 == 0 ? 0.8 : 0.5).offset(y: CGFloat(hour) * hourHeight) }
            ForEach(engine.placements(for: events)) { placement in
                let lane = max(1, width / CGFloat(placement.columnCount)), top = yPosition(for: placement.event.start, hourHeight: hourHeight), bottom = yPosition(for: placement.event.end, hourHeight: hourHeight), cardHeight = max(1, bottom - top - courseBottomGap)
                CourseBlock(event: placement.event, availableWidth: lane, height: cardHeight, highlighted: highlightedEventID == placement.event.id, forceCompact: true, isPast: placement.event.end <= now)
                    .frame(width: lane, height: cardHeight, alignment: .top).offset(x: CGFloat(placement.column) * lane, y: top).onTapGesture { onSelect(placement.event) }
            }
            if calendar.isDate(day, inSameDayAs: now) { WeekCurrentTimeIndicator(hourHeight: hourHeight, width: width) }
        }.frame(height: hourHeight * 24 + 1).overlay(alignment: .leading) { Rectangle().fill(Color.secondary.opacity(0.12)).frame(width: 0.5) }
    }
}

struct CurrentTimeIndicator: View { @Environment(CalendarStore.self) private var store; let hourHeight: CGFloat; let x: CGFloat; let width: CGFloat; var body: some View { TimelineView(.periodic(from: .now, by: 30)) { context in let y = yPosition(for: store.effectiveNow(from: context.date), hourHeight: hourHeight); HStack(spacing: 0) { Circle().fill(.red).frame(width: 8, height: 8); Rectangle().fill(.red).frame(height: 1.5) }.frame(width: width, alignment: .leading).offset(x: x - 4, y: y - 4).accessibilityHidden(true) } } }
private struct WeekCurrentTimeIndicator: View { @Environment(CalendarStore.self) private var store; let hourHeight: CGFloat; let width: CGFloat; var body: some View { TimelineView(.periodic(from: .now, by: 30)) { context in let y = yPosition(for: store.effectiveNow(from: context.date), hourHeight: hourHeight); HStack(spacing: 0) { Circle().fill(.red).frame(width: 7, height: 7); Rectangle().fill(.red).frame(height: 1.5) }.frame(width: width, alignment: .leading).offset(x: -3, y: y - 3).accessibilityHidden(true) } } }

struct CourseBlock: View {
    let event: CalendarEvent; let availableWidth: CGFloat; let height: CGFloat; let highlighted: Bool; var forceCompact = false; var isPast = false
    @GestureState private var pressed = false
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(eventColor).frame(width: 3).frame(maxHeight: .infinity)
            content.padding(.leading, forceCompact ? 3 : 6).padding(.trailing, forceCompact ? 2 : 5).padding(.vertical, compactHeight ? 2 : 4)
        }
        .background(Rectangle().fill(isPast ? Color.black.opacity(0.22) : eventColor.opacity(event.source == .local ? 0.09 : 0.12)))
        .overlay { if highlighted { Rectangle().stroke(Color.accentColor, lineWidth: 2) } }.clipped().contentShape(Rectangle())
        .scaleEffect(pressed ? 0.975 : 1).brightness(pressed ? -0.06 : 0).animation(.snappy(duration: 0.12), value: pressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in state = true })
        .accessibilityElement(children: .ignore).accessibilityLabel(accessibilityText)
    }
    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: compactHeight ? 1 : (availableWidth > 190 ? 4 : 2)) {
            HStack(alignment: .firstTextBaseline, spacing: 3) { if let label = event.displayTypeLabel, !label.isEmpty { Text(label).font(.system(size: forceCompact ? 7 : 9, weight: .bold)).foregroundStyle(eventColor).lineLimit(1) }; Spacer(minLength: 2); Text(event.start, style: .time).font(timeFont).foregroundStyle(.secondary).lineLimit(1) }
            Text(event.title).font(titleFont).lineLimit(compactHeight ? 1 : (forceCompact || availableWidth < 130 ? 2 : 3)).minimumScaleFactor(0.55)
            if compactHeight {
                HStack(spacing: 4) { if !event.room.isEmpty { Text(event.room) }; if !event.teachers.isEmpty { Text(event.teachers.joined(separator: ", ")) }; if !event.groups.isEmpty { Text(event.groups.map(\.name).joined(separator: " · ")) } }.font(metadataFont).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.45)
            } else {
                if height > 48, !event.room.isEmpty { Text(event.room).font(metadataFont).foregroundStyle(.secondary).lineLimit(1) }
                if !forceCompact, availableWidth >= 145, height > 68, !event.teachers.isEmpty { Text(event.teachers.joined(separator: ", ")).font(metadataFont).foregroundStyle(.secondary).lineLimit(1) }
                if !forceCompact, availableWidth >= 150, height > 76, !event.groups.isEmpty { Text(event.groups.map(\.name).joined(separator: " · ")).font(.caption2.weight(.medium)).foregroundStyle(.tertiary).lineLimit(1) }
            }
            Spacer(minLength: 0); HStack { Spacer(minLength: 0); Text(event.end, style: .time).font(timeFont).foregroundStyle(.secondary).lineLimit(1) }
        }
    }
    private var compactHeight: Bool { height <= 88 || forceCompact }
    private var titleFont: Font { if compactHeight { return .system(size: height < 55 ? 7.5 : 9, weight: .bold) }; if availableWidth < 140 { return .caption2.weight(.bold) }; if availableWidth < 180 { return .caption.weight(.bold) }; return .subheadline.weight(.bold) }
    private var metadataFont: Font { .system(size: compactHeight ? 6.5 : (availableWidth < 140 ? 7.5 : 10)) }
    private var timeFont: Font { .system(size: forceCompact || availableWidth < 100 || height < 60 ? 7 : 9, weight: .semibold, design: .rounded).monospacedDigit() }
    private var eventColor: Color { if event.source == .local { return .purple }; guard let label = event.displayTypeLabel, !label.isEmpty else { return .accentColor }; return Color(courslyHex: CourseTypeColorPreferences.hex(for: label)) }
    private var accessibilityText: String { var parts = [event.displayTypeLabel, event.title].compactMap { $0 }; parts.append("de \(event.start.formatted(date: .omitted, time: .shortened)) à \(event.end.formatted(date: .omitted, time: .shortened))"); if !event.room.isEmpty { parts.append("salle \(event.room)") }; if !event.teachers.isEmpty { parts.append(event.teachers.joined(separator: ", ")) }; if !event.groups.isEmpty { parts.append(event.groups.map(\.name).joined(separator: ", ")) }; return parts.joined(separator: ", ") }
}

private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.locale = Locale(identifier: "fr_FR"); value.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current; return value }
private func minutesSinceMidnight(_ date: Date) -> Int { let c = calendar.dateComponents([.hour, .minute], from: date); return (c.hour ?? 0) * 60 + (c.minute ?? 0) }
private func yPosition(for date: Date, hourHeight: CGFloat) -> CGFloat { let c = calendar.dateComponents([.hour, .minute, .second], from: date); let minutes = CGFloat((c.hour ?? 0) * 60 + (c.minute ?? 0)) + CGFloat(c.second ?? 0) / 60; return max(0, min(minutes * hourHeight / 60, hourHeight * 24)) }
private func capitalizedWeekday(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.timeZone = calendar.timeZone; f.dateFormat = "EEE"; let value = f.string(from: date); return value.prefix(1).uppercased() + value.dropFirst() }
private extension Color { init(courslyHex hex: String) { let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted); var value: UInt64 = 0; Scanner(string: cleaned).scanHexInt64(&value); if cleaned.count == 6 { self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255) } else { self = .accentColor } } }
private func courseBoundaryOffsets(events: [CalendarEvent], hourHeight: CGFloat) -> [CGFloat] { events.flatMap { [yPosition(for: $0.start, hourHeight: hourHeight), yPosition(for: $0.end, hourHeight: hourHeight)] }.sorted() }
