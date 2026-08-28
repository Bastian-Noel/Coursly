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
                .activityBackgroundTint(accentColor(context.state).opacity(0.10))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            let accent = accentColor(context.state)
            let contrast = contrastColor(context.state)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.type ?? "Cours")
                        .font(.caption.bold())
                        .foregroundStyle(contrast)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(accent, in: Capsule())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        HStack {
                            Text(context.state.room.isEmpty ? "Salle à confirmer" : context.state.room)
                            Spacer()
                            if !context.state.teachers.isEmpty {
                                Text(context.state.teachers).lineLimit(1)
                            }
                        }
                        .font(.caption)
                        progressBar(context.state, accent: accent)
                    }
                }
            } compactLeading: {
                Circle().fill(accent).frame(width: 10, height: 10)
            } compactTrailing: {
                countdown(context.state)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(accent)
            } minimal: {
                Circle().fill(accent).frame(width: 12, height: 12)
            }
            .keylineTint(accent)
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<CourslyActivityAttributes>) -> some View {
        let accent = accentColor(context.state)

        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(context.state.status)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(context.state.dayFinished ? Color.green : accent)

                    Spacer(minLength: 8)

                    if !context.state.dayFinished {
                        countdown(context.state)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                    }
                }

                if context.state.dayFinished {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Journée terminée")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                } else {
                    HStack(spacing: 4) {
                        Text(context.state.start, style: .time)
                        Text("–").foregroundStyle(.tertiary)
                        Text(context.state.end, style: .time)
                    }
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text(context.state.title)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    if let type = context.state.type, !type.isEmpty {
                        Text(type)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }

                    let metadata = [
                        context.state.room.isEmpty ? nil : context.state.room,
                        context.state.teachers.isEmpty ? nil : context.state.teachers,
                        context.state.groups.isEmpty ? nil : context.state.groups
                    ].compactMap { $0 }

                    if !metadata.isEmpty {
                        Text(metadata.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                    }

                    progressBar(context.state, accent: accent)

                    if let nextTitle = context.state.nextTitle,
                       let nextStart = context.state.nextStart {
                        Rectangle()
                            .fill(accent.opacity(0.18))
                            .frame(height: 0.5)

                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("PROCHAIN COURS")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(accent)
                                Text(nextTitle)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 6)

                            VStack(alignment: .trailing, spacing: 1) {
                                Text(nextStart, style: .time)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                if let room = context.state.nextRoom, !room.isEmpty {
                                    Text(room)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(accent.opacity(0.08))
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .background(accent.opacity(context.state.dayFinished ? 0.03 : 0.07))
        .overlay {
            Rectangle().stroke(accent.opacity(0.16), lineWidth: 0.5)
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
                    Capsule().fill(accent.opacity(0.16))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(0, proxy.size.width * progress))
                }
            }
            .frame(height: 5)
            .accessibilityLabel("Avancement du cours")
            .accessibilityValue("\(Int(progress * 100)) pour cent")
        }
    }

    private func accentColor(_ state: CourslyActivityAttributes.ContentState) -> Color {
        state.dayFinished ? .green : Color(hex: state.accentHex)
    }

    private func contrastColor(_ state: CourslyActivityAttributes.ContentState) -> Color {
        Color.contrast(forHex: state.dayFinished ? "#34C759" : state.accentHex)
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

    static func contrast(forHex hex: String) -> Color {
        let rgb = rgb(fromHex: hex)
        let luminance = 0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue
        return luminance > 0.62 ? .black : .white
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
