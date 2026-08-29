import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CourslyLiveActivityBundle: WidgetBundle {
    var body: some Widget { CourslyLiveActivityWidget() }
}

private struct ResolvedCourse {
    let status: String
    let title: String
    let room: String
    let teachers: String
    let groups: String
    let type: String?
    let accentHex: String
    let start: Date
    let end: Date
    let timerStart: Date
    let timerEnd: Date
    let isInProgress: Bool
    let isFinished: Bool
    let nextTitle: String?
    let nextRoom: String?
    let nextType: String?
    let nextAccentHex: String?
    let nextStart: Date?
}

struct CourslyLiveActivityWidget: Widget {
    private let parisTimeZone = TimeZone(identifier: "Europe/Paris")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourslyActivityAttributes.self) { context in
            TimelineView(.periodic(from: .now, by: 15)) { timeline in
                lockScreen(resolved(context.state, at: timeline.date), dayFinished: context.state.dayFinished)
            }
            .environment(\.timeZone, parisTimeZone)
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .activityBackgroundTint(Color.black.opacity(0.40))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let course = resolved(context.state, at: .now)
            let accent = Color(hex: course.accentHex)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 8) {
                        Circle().fill(accent).frame(width: 9, height: 9)
                        Text(course.title).font(.caption.weight(.semibold)).lineLimit(1)
                        Spacer(minLength: 4)
                        countdown(course).font(.caption2.monospacedDigit()).foregroundStyle(accent)
                    }
                }
            } compactLeading: {
                Circle().fill(accent).frame(width: 9, height: 9)
            } compactTrailing: {
                countdown(course).font(.caption2.monospacedDigit()).foregroundStyle(accent)
            } minimal: {
                Circle().fill(accent).frame(width: 10, height: 10)
            }
            .keylineTint(accent)
        }
    }

    @ViewBuilder
    private func lockScreen(_ course: ResolvedCourse, dayFinished: Bool) -> some View {
        if dayFinished || course.isFinished {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("JOURNÉE TERMINÉE").font(.caption.weight(.heavy)).foregroundStyle(.green)
                    Text("Tous les cours sont terminés").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        } else {
            ViewThatFits(in: .vertical) {
                courseLayout(course, comfortable: true)
                courseLayout(course, comfortable: false)
            }
        }
    }

    private func courseLayout(_ course: ResolvedCourse, comfortable: Bool) -> some View {
        let accent = Color(hex: course.accentHex)
        let metadata = [course.room, course.teachers, course.groups].filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: comfortable ? 7 : 5) {
            HStack(spacing: 7) {
                Image(systemName: course.isInProgress ? "stopwatch.fill" : "clock.fill")
                    .font(.caption.weight(.bold))
                Text(course.status)
                    .font(.caption.weight(.heavy))
                    .lineLimit(1)
                countdown(course)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .contentTransition(.numericText())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(accent.opacity(0.38), lineWidth: 0.8)
                    }
                Spacer(minLength: 0)
            }
            .foregroundStyle(accent)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(course.start, style: .time)
                Text("–")
                Text(course.end, style: .time)
                Spacer(minLength: 4)
                if let type = course.type, !type.isEmpty {
                    Text(type)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(accent.opacity(0.34), lineWidth: 0.7)
                        }
                }
            }
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(.white.opacity(0.70))

            Text(course.title)
                .font(comfortable ? .title3.weight(.bold) : .headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(comfortable ? 2 : 1)
                .minimumScaleFactor(0.70)

            if !metadata.isEmpty {
                Text(metadata.joined(separator: " · "))
                    .font(comfortable ? .caption : .caption2)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(comfortable ? 2 : 1)
                    .minimumScaleFactor(0.58)
            }

            progressBar(course, accent: accent)

            if let nextTitle = course.nextTitle, let nextStart = course.nextStart {
                quickNextCourse(
                    title: nextTitle, room: course.nextRoom, type: course.nextType,
                    start: nextStart, accent: Color(hex: course.nextAccentHex ?? "#0A84FF"),
                    comfortable: comfortable
                )
            }
        }
        .padding(.horizontal, comfortable ? 15 : 13)
        .padding(.vertical, comfortable ? 12 : 9)
        .background(accent.opacity(0.045))
    }

    private func quickNextCourse(
        title: String,
        room: String?,
        type: String?,
        start: Date,
        accent: Color,
        comfortable: Bool
    ) -> some View {
        VStack(spacing: comfortable ? 6 : 4) {
            Divider().overlay(Color.white.opacity(0.14))
            HStack(alignment: .center, spacing: 9) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROCHAIN COURS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(accent)
                    Text(title)
                        .font(comfortable ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    if comfortable, let type, !type.isEmpty {
                        Text(type).font(.caption2.weight(.semibold)).foregroundStyle(accent).lineLimit(1)
                    }
                }
                Spacer(minLength: 3)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(start, style: .time)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                    if let room, !room.isEmpty {
                        Text(room).font(.caption2).foregroundStyle(.white.opacity(0.64)).lineLimit(1)
                    }
                }
            }
        }
    }

    private func progressBar(_ course: ResolvedCourse, accent: Color) -> some View {
        let total = max(1, course.timerEnd.timeIntervalSince(course.timerStart))
        let elapsed = Date.now.timeIntervalSince(course.timerStart)
        let progress = max(0, min(1, elapsed / total))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                Capsule().fill(accent).frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Avancement du cours")
        .accessibilityValue("\(Int(progress * 100)) pour cent")
    }

    @ViewBuilder
    private func countdown(_ course: ResolvedCourse) -> some View {
        if course.isFinished {
            Text("✓")
        } else if course.isInProgress {
            Text(timerInterval: Date.now...course.timerEnd, countsDown: true)
        } else {
            Text(timerInterval: Date.now...course.timerStart, countsDown: true)
        }
    }

    private func resolved(_ state: CourslyActivityAttributes.ContentState, at now: Date) -> ResolvedCourse {
        if state.dayFinished {
            return finishedCourse(state)
        }

        if now >= state.timerEnd {
            guard let title = state.nextTitle,
                  let start = state.nextStart,
                  let end = state.nextEnd,
                  let timerStart = state.nextTimerStart,
                  let timerEnd = state.nextTimerEnd else {
                return finishedCourse(state)
            }
            if now >= timerEnd { return finishedCourse(state) }
            let inProgress = now >= timerStart
            return ResolvedCourse(
                status: dynamicStatus(inProgress: inProgress, isLast: state.nextIsLastCourse ?? true, timerEnd: timerEnd, now: now, waitingStatus: "PAUSE"),
                title: title,
                room: state.nextRoom ?? "",
                teachers: state.nextTeachers ?? "",
                groups: state.nextGroups ?? "",
                type: state.nextType,
                accentHex: state.nextAccentHex ?? "#0A84FF",
                start: start,
                end: end,
                timerStart: timerStart,
                timerEnd: timerEnd,
                isInProgress: inProgress,
                isFinished: false,
                nextTitle: nil,
                nextRoom: nil,
                nextType: nil,
                nextAccentHex: nil,
                nextStart: nil
            )
        }

        let inProgress = now >= state.timerStart
        return ResolvedCourse(
            status: dynamicStatus(inProgress: inProgress, isLast: state.isLastCourse, timerEnd: state.timerEnd, now: now, waitingStatus: state.status),
            title: state.title,
            room: state.room,
            teachers: state.teachers,
            groups: state.groups,
            type: state.type,
            accentHex: state.accentHex,
            start: state.start,
            end: state.end,
            timerStart: state.timerStart,
            timerEnd: state.timerEnd,
            isInProgress: inProgress,
            isFinished: false,
            nextTitle: state.nextTitle,
            nextRoom: state.nextRoom,
            nextType: state.nextType,
            nextAccentHex: state.nextAccentHex,
            nextStart: state.nextStart
        )
    }

    private func dynamicStatus(inProgress: Bool, isLast: Bool, timerEnd: Date, now: Date, waitingStatus: String) -> String {
        guard inProgress else { return waitingStatus }
        if isLast { return "DERNIER COURS" }
        return timerEnd.timeIntervalSince(now) <= 20 * 60 ? "BIENTÔT TERMINÉ" : "EN COURS"
    }

    private func finishedCourse(_ state: CourslyActivityAttributes.ContentState) -> ResolvedCourse {
        ResolvedCourse(
            status: "JOURNÉE TERMINÉE", title: "Cours terminés", room: "", teachers: "", groups: "",
            type: nil, accentHex: "#34C759", start: state.end, end: state.end,
            timerStart: state.timerEnd, timerEnd: state.timerEnd, isInProgress: false, isFinished: true,
            nextTitle: nil, nextRoom: nil, nextType: nil, nextAccentHex: nil, nextStart: nil
        )
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        guard cleaned.count == 6 else { self = .blue; return }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

