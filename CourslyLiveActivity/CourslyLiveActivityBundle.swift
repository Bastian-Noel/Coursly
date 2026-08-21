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
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.type ?? "Cours")
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state).font(.caption.monospacedDigit())
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
                Text(context.state.type ?? "C").font(.caption2.bold())
            } compactTrailing: {
                countdown(context.state).font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: context.state.dayFinished ? "checkmark" : "calendar")
            }
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<CourslyActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(context.state.status)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(context.state.dayFinished ? Color.green : statusColor(context.state))
                Spacer()
                if !context.state.dayFinished {
                    countdown(context.state)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
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
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let type = context.state.type {
                        Text(type)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.tint.opacity(0.16), in: Capsule())
                    }
                    Label(
                        context.state.room.isEmpty ? "Salle à confirmer" : context.state.room,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.subheadline)
                    .lineLimit(1)
                }

                HStack {
                    Text(context.state.start, style: .time)
                    Spacer()
                    Text(context.state.end, style: .time)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                if context.state.isInProgress, context.state.end > context.state.start {
                    ProgressView(
                        timerInterval: context.state.start...context.state.end,
                        countsDown: false
                    )
                    .tint(Color.accentColor)
                }

                if let nextTitle = context.state.nextTitle, let nextStart = context.state.nextStart {
                    Divider().opacity(0.45)
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
        .padding(16)
    }

    private func statusColor(_ state: CourslyActivityAttributes.ContentState) -> Color {
        state.status == "PAUSE" ? .orange : .accentColor
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
