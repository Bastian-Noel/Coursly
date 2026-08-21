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
                .activityBackgroundTint(accentColor(context.state).opacity(0.16))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.type ?? "Cours")
                        .font(.caption.bold())
                        .foregroundStyle(accentColor(context.state))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(accentColor(context.state))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(context.state.room.isEmpty ? "Salle à confirmer" : context.state.room, systemImage: "mappin.and.ellipse")
                        Spacer()
                        Text(context.state.status.capitalized)
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Text(context.state.type ?? "C")
                    .font(.caption2.bold())
                    .foregroundStyle(accentColor(context.state))
            } compactTrailing: {
                countdown(context.state)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(accentColor(context.state))
            } minimal: {
                Image(systemName: context.state.dayFinished ? "checkmark" : "calendar")
                    .foregroundStyle(accentColor(context.state))
            }
            .keylineTint(accentColor(context.state))
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<CourslyActivityAttributes>) -> some View {
        let accent = accentColor(context.state)

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 9) {
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
                        if let type = context.state.type {
                            Text(type)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(accent, in: Capsule())
                        }

                        Label(
                            context.state.room.isEmpty ? "Salle à confirmer" : context.state.room,
                            systemImage: "mappin.and.ellipse"
                        )
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
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
                        Divider().opacity(0.4)
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
                }
            }
        }
        .padding(16)
    }

    private func accentColor(_ state: CourslyActivityAttributes.ContentState) -> Color {
        state.dayFinished ? .green : Color(hex: state.accentHex)
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
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red, green, blue: Double
        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        } else {
            red = 0.04
            green = 0.52
            blue = 1.0
        }
        self.init(red: red, green: green, blue: blue)
    }
}
