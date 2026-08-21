import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CourslyLiveActivityBundle: WidgetBundle {
    var body: some Widget { CourslyLiveActivityWidget() }
}

struct CourslyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourslyActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(.clear)
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
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
            } compactTrailing: {
                countdown(context.state)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(accent)
            } minimal: {
                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)
            }
            .keylineTint(accent)
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<CourslyActivityAttributes>) -> some View {
        let accent = accentColor(context.state)
        let contrast = contrastColor(context.state)

        HStack(spacing: 12) {
            Rectangle()
                .fill(accent)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(context.state.status)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(context.state.dayFinished ? Color.green : accent)

                    Spacer(minLength: 8)

                    if !context.state.dayFinished {
                        countdown(context.state)
                            .font(.headline.monospacedDigit().weight(.bold))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                    }
                }

                if context.state.dayFinished {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("Journée terminée").font(.headline)
                    }
                } else {
                    if context.state.status == "PAUSE" {
                        Text("Prochain cours")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(context.state.title)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let type = context.state.type, !type.isEmpty {
                            Text(type)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(contrast)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(accent, in: Capsule())
                        }

                        Spacer(minLength: 6)

                        if !context.state.groups.isEmpty {
                            Text(context.state.groups)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }

                    HStack(spacing: 8) {
                        Label(
                            context.state.room.isEmpty ? "Salle à confirmer" : context.state.room,
                            systemImage: "mappin.and.ellipse"
                        )
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                        Spacer(minLength: 6)

                        if !context.state.teachers.isEmpty {
                            Label(context.state.teachers, systemImage: "person.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundStyle(accent)
                        Text(context.state.start, style: .time)
                        Text("→")
                            .foregroundStyle(.tertiary)
                        Text(context.state.end, style: .time)
                    }
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)

                    if let nextTitle = context.state.nextTitle, let nextStart = context.state.nextStart {
                        HStack(spacing: 6) {
                            Text("Ensuite")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(nextTitle).font(.caption.weight(.medium)).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(nextStart, style: .time).font(.caption.monospacedDigit())
                            if let room = context.state.nextRoom, !room.isEmpty {
                                Text("· \(room)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    progressBar(context.state, accent: accent)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.trailing, 16)
    }

    @ViewBuilder
    private func progressBar(_ state: CourslyActivityAttributes.ContentState, accent: Color) -> some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            let total = max(1, state.end.timeIntervalSince(state.start))
            let elapsed = context.date.timeIntervalSince(state.start)
            let progress = max(0, min(1, elapsed / total))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(accent.opacity(0.16))
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
            Text(timerInterval: Date.now...state.end, countsDown: true)
        } else {
            Text(timerInterval: Date.now...state.start, countsDown: true)
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
