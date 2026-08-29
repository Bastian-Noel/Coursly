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
    let progressStart: Date?
    let progressEnd: Date?
    let isInProgress: Bool
    let isFinished: Bool
    let nextTitle: String?
    let nextRoom: String?
    let nextType: String?
    let nextAccentHex: String?
    let nextStart: Date?
    let nextEnd: Date?
    let nextTeachers: String?
    let nextGroups: String?
}

struct CourslyLiveActivityWidget: Widget {
    private let parisTimeZone = TimeZone(identifier: "Europe/Paris")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourslyActivityAttributes.self) { context in
            TimelineView(.periodic(from: .now, by: 15)) { timeline in
                lockScreen(resolved(context.state, at: timeline.date), state: context.state)
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
    private func lockScreen(_ course: ResolvedCourse, state: CourslyActivityAttributes.ContentState) -> some View {
        if state.dayFinished || course.isFinished {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("JOURNÉE TERMINÉE").font(.caption.weight(.heavy)).foregroundStyle(.green)
                        Text("Tous les cours sont terminés").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    }
                    Spacer()
                }

                // Le lendemain reste une ligne secondaire : aucun détail complet ni décompte nocturne.
                if let tomorrowStart = state.tomorrowStart {
                    Divider().overlay(Color.white.opacity(0.14))
                    HStack {
                        Text("PROCHAIN COURS DEMAIN")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Color(hex: "#0A84FF"))
                        Spacer(minLength: 8)
                        Text(tomorrowStart, style: .time)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
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
                    .minimumScaleFactor(0.58)
                Spacer(minLength: 0)
                progressCountdown(course, accent: accent, comfortable: comfortable)
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

            if let nextTitle = course.nextTitle,
               let nextStart = course.nextStart,
               let nextEnd = course.nextEnd {
                quickNextCourse(
                    title: nextTitle, room: course.nextRoom, type: course.nextType,
                    teachers: course.nextTeachers, groups: course.nextGroups,
                    start: nextStart, end: nextEnd,
                    accent: Color(hex: course.nextAccentHex ?? "#0A84FF"),
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
        teachers: String?,
        groups: String?,
        start: Date,
        end: Date,
        accent: Color,
        comfortable: Bool
    ) -> some View {
        let metadata = [type, room, teachers, groups]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return VStack(spacing: comfortable ? 6 : 4) {
            Divider().overlay(Color.white.opacity(0.14))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("PROCHAIN COURS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(accent)
                    Spacer(minLength: 6)
                    Text(start, style: .time)
                    Text("–")
                    Text(end, style: .time)
                }
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))

                Text(title)
                    .font(comfortable ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if !metadata.isEmpty {
                    Text(metadata.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
        }
    }

    private func progressCountdown(_ course: ResolvedCourse, accent: Color, comfortable: Bool) -> some View {
        let progressStart = course.progressStart
        let progressEnd = course.progressEnd
        let progressTotal = max(1, (progressEnd ?? course.timerEnd).timeIntervalSince(progressStart ?? course.timerStart))
        let progress = if let progressStart, progressEnd != nil {
            max(0, min(1, Date.now.timeIntervalSince(progressStart) / progressTotal))
        } else {
            0.0
        }
        let text = remainingText(course)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(accent.opacity(0.13))
                Capsule().fill(accent).frame(width: proxy.size.width * progress)
                Text(text)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                Text(text)
                    .foregroundStyle(.black.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: proxy.size.width * progress)
                    }
            }
        }
        .font(.caption.monospacedDigit().weight(.bold))
        .contentTransition(.numericText())
        .frame(width: comfortable ? 152 : 128, height: 30)
        .overlay { Capsule().stroke(accent.opacity(0.35), lineWidth: 0.8) }
        .accessibilityLabel("Avancement du cours")
        .accessibilityValue("\(Int(progress * 100)) pour cent")
    }

    private func remainingText(_ course: ResolvedCourse) -> String {
        let target = course.isInProgress ? course.timerEnd : course.timerStart
        let minutes = max(0, Int(ceil(target.timeIntervalSinceNow / 60)))
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? String(format: "%dh %02dm", hours, remainder) : "\(minutes)m"
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
            let isSameDayPause = !inProgress && isSameParisDay(state.end, start)
            return ResolvedCourse(
                status: dynamicStatus(
                    inProgress: inProgress,
                    isLast: state.nextIsLastCourse ?? true,
                    timerEnd: timerEnd,
                    now: now,
                    waitingStatus: waitingStatus(upcomingStart: start, previousEnd: state.end, now: now)
                ),
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
                progressStart: inProgress ? timerStart : (isSameDayPause ? state.timerEnd : nil),
                progressEnd: inProgress ? timerEnd : (isSameDayPause ? timerStart : nil),
                isInProgress: inProgress,
                isFinished: false,
                nextTitle: nil,
                nextRoom: nil,
                nextType: nil,
                nextAccentHex: nil,
                nextStart: nil,
                nextEnd: nil,
                nextTeachers: nil,
                nextGroups: nil
            )
        }

        let inProgress = now >= state.timerStart
        let showFollowingCourse = inProgress
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
            progressStart: inProgress ? state.timerStart : state.progressStart,
            progressEnd: inProgress ? state.timerEnd : state.progressEnd,
            isInProgress: inProgress,
            isFinished: false,
            nextTitle: showFollowingCourse ? state.nextTitle : nil,
            nextRoom: showFollowingCourse ? state.nextRoom : nil,
            nextType: showFollowingCourse ? state.nextType : nil,
            nextAccentHex: showFollowingCourse ? state.nextAccentHex : nil,
            nextStart: showFollowingCourse ? state.nextStart : nil,
            nextEnd: showFollowingCourse ? state.nextEnd : nil,
            nextTeachers: showFollowingCourse ? state.nextTeachers : nil,
            nextGroups: showFollowingCourse ? state.nextGroups : nil
        )
    }

    private func dynamicStatus(inProgress: Bool, isLast: Bool, timerEnd: Date, now: Date, waitingStatus: String) -> String {
        guard inProgress else { return waitingStatus == "PAUSE" ? "EN PAUSE" : waitingStatus }
        if isLast { return "DERNIER COURS" }
        return timerEnd.timeIntervalSince(now) <= 20 * 60 ? "BIENTÔT TERMINÉ" : "EN COURS"
    }

    private func waitingStatus(upcomingStart: Date, previousEnd: Date, now: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = parisTimeZone
        if calendar.startOfDay(for: upcomingStart) > calendar.startOfDay(for: now) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.timeZone = parisTimeZone
            formatter.dateFormat = "HH'h'mm"
            return "PROCHAIN COURS DEMAIN À \(formatter.string(from: upcomingStart))"
        }
        return calendar.isDate(previousEnd, inSameDayAs: upcomingStart) ? "EN PAUSE" : "PREMIER COURS"
    }

    private func isSameParisDay(_ first: Date, _ second: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = parisTimeZone
        return calendar.isDate(first, inSameDayAs: second)
    }

    private func finishedCourse(_ state: CourslyActivityAttributes.ContentState) -> ResolvedCourse {
        ResolvedCourse(
            status: "JOURNÉE TERMINÉE", title: "Cours terminés", room: "", teachers: "", groups: "",
            type: nil, accentHex: "#34C759", start: state.end, end: state.end,
            timerStart: state.timerEnd, timerEnd: state.timerEnd,
            progressStart: nil, progressEnd: nil, isInProgress: false, isFinished: true,
            nextTitle: nil, nextRoom: nil, nextType: nil, nextAccentHex: nil,
            nextStart: nil, nextEnd: nil, nextTeachers: nil, nextGroups: nil
        )
    }
}

private extension Color {
    init(hex: String) {
        let readable = LiveActivityAccent.readableHex(from: hex)
        let cleaned = readable.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
