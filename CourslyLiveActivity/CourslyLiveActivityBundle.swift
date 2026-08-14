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
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(context.state.status).font(.caption.bold()).foregroundStyle(.tint)
                    Spacer()
                    if let type = context.state.type { Text(type).font(.caption.bold()).padding(5).background(.tint.opacity(0.15), in: Capsule()) }
                }
                Text(context.state.title).font(.headline).lineLimit(1)
                HStack {
                    Label(context.state.room.isEmpty ? "Salle à confirmer" : context.state.room, systemImage: "mappin.and.ellipse")
                    Spacer()
                    Text(timerInterval: Date.now < context.state.start ? Date.now...context.state.start : Date.now...context.state.end, countsDown: true).monospacedDigit()
                }.font(.subheadline)
                if let next = context.state.nextTitle { Text("Ensuite · \(next)").font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            .padding().activityBackgroundTint(.gray.opacity(0.18)).activitySystemActionForegroundColor(.accentColor)
            .widgetURL(URL(string: "coursly://event/\(context.attributes.eventID)"))
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { EmptyView() }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
        }
    }
}
