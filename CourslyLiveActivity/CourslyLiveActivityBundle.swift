import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CourslyLiveActivityBundle: WidgetBundle {
    var body: some Widget { CourslyLiveActivityWidget() }
}

struct CourslyLiveActivityWidget: Widget {
    private let parisTimeZone = TimeZone(identifier: "Europe/Paris")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourslyActivityAttributes.self) { context in
            lockScreen(context)
                .environment(\.timeZone, parisTimeZone)
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .activityBackgroundTint(Color.black.opacity(0.38))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let accent = accentColor(context.state)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 8) {
                        Circle().fill(accent).frame(width: 9, height: 9)
                        Text(context.state.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        countdown(context.state)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(accent)
                    }
                }
            } compactLeading: {
                Circle().fill(accent).frame(width: 9, height: 9)
            } compactTrailing: {
                countdown(context.state)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(accent)
            } minimal: {
                Circle().fill(accent).frame(width: 10, height: 10)
            }
            .keylineTint(accent)
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<CourslyActivityAttributes>) -> some View {
        let state = context.state
        let accent = accentColor(state)

        if state.dayFinished {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("JOURNÉE TERMINÉE")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.green)
                    Text("Tous les cours sont terminés")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        } else {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Label(state.status, systemImage: "stopwatch")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(accent)
                            .lineLimit(1)

                        countdown(state)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(accent.opacity(0.38), lineWidth: 0.8)
                            }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 5) {
                        Text(state.start, style: .time)
                        Text("–")
                        Text(state.end, style: .time)

                        Spacer(minLength: 5)

                        if let type = state.type, !type.isEmpty {
                            Label(type, systemImage: "graduationcap.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(accent.opacity(0.38), lineWidth: 0.7)
                                }
                        }
                    }
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.68))

                    Text(state.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    let metadata = [
                        state.room.isEmpty ? nil : state.room,
                        state.teachers.isEmpty ? nil : state.teachers,
                        state.groups.isEmpty ? nil : state.groups
                    ].compactMap { $0 }

                    if !metadata.isEmpty {
                        Text(metadata.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                    }

                    progressBar(state, accent: accent)

                    if let nextTitle = state.nextTitle,
                       let nextStart = state.nextStart {
                        compactNextCourse(
                            title: nextTitle,
                            room: state.nextRoom,
                            type: state.nextType,
                            start: nextStart,
                            accent: nextAccentColor(state)
                        )
                    }
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 11)
            }
            .background(accent.opacity(0.05))
        }
    }

    private func compactNextCourse(
        title: String,
        room: String?,
        type: String?,
        start: Date,
        accent: Color
    ) -> some View {
        VStack(spacing: 5) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Label("PROCHAIN", systemImage: "calendar")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(accent)

                        if let type, !type.isEmpty {
                            Text(type)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(accent)
                                .lineLimit(1)
                        }
                    }

                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)
                }

                Spacer(minLength: 3)

                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 0.5, height: 32)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(start, style: .time)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                    if let room, !room.isEmpty {
                        Text(room)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }
                .frame(minWidth: 48, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func progressBar(_ state: CourslyActivityAttributes.ContentState, accent: Color) -> some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            let total = max(1, state.timerEnd.timeIntervalSince(state.timerStart))
            let elapsed = context.date.timeIntervalSince(state.timerStart)
            let progress = max(0, min(1, elapsed / total))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(0, proxy.size.width * progress))
                }
            }
            .frame(height: 6)
            .accessibilityLabel("Avancement du cours")
            .accessibilityValue("\(Int(progress * 100)) pour cent")
        }
    }

    private func accentColor(_ state: CourslyActivityAttributes.ContentState) -> Color {
        state.dayFinished ? .green : Color(hex: state.accentHex)
    }

    private func nextAccentColor(_ state: CourslyActivityAttributes.ContentState) -> Color {
        guard let hex = state.nextAccentHex else { return .blue }
        return Color(hex: hex)
    }

    @ViewBuilder
    private func countdown(_ state: CourslyActivityAttributes.ContentState) -> some View {
        if state.dayFinished {
            Text("✓")
        } else if state.isInProgress {
            Text(timerInterval: Date.now...state.timerEnd, countsDown: true)
        } else {
            Text(timerInterval: Date.now...state.timerStart, countsDown: true)
        }
    }
}

private extension Color {
    init(hex: String) {
        let components = Self.rgb(fromHex: hex)
        self.init(red: components.red, green: components.green, blue: components.blue)
    }

    static func rgb(fromHex hex: String) -> (red: Double, green: Double, blue: Double) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        guard cleaned.count == 6 else { return (0.0, 0.48, 1.0) }
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }
}
