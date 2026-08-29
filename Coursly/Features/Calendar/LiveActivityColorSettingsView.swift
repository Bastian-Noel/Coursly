import SwiftUI
import UIKit

private struct CourseColorGroup: Identifiable {
    let id: String
    let label: String
    let detectionStatus: CourseColorDetectionStatus
    let groupID: UUID?
    let frequency: Int
}

enum CourseColorDetectionStatus: Equatable {
    case configured(matches: [String])
    case dynamic(variants: [String])

    var text: String? {
        switch self {
        case let .configured(matches) where !matches.isEmpty:
            return "Types détectés : \(matches.joined(separator: " · "))"
        case .configured:
            return "Aucun cours correspondant dans les données chargées"
        case .dynamic:
            return nil
        }
    }

    var isEmptyConfiguredGroup: Bool {
        if case let .configured(matches) = self { return matches.isEmpty }
        return false
    }
}

enum CourseColorFrequencyOrder {
    static func precedes(firstFrequency: Int, firstLabel: String, secondFrequency: Int, secondLabel: String) -> Bool {
        if firstFrequency != secondFrequency { return firstFrequency > secondFrequency }
        return firstLabel.localizedCaseInsensitiveCompare(secondLabel) == .orderedAscending
    }
}

struct LiveActivityColorSettingsView: View {
    @Environment(CalendarStore.self) private var store
    @State private var refreshToken = UUID()
    @State private var expandedType: String?

    private var detectedGroups: [CourseColorGroup] {
        let classifier = CourseTypeClassifier()
        // La fréquence vient des cours réellement chargés ; les anciens types mémorisés restent visibles avec un poids nul.
        let frequencies = Dictionary(grouping: store.remoteEvents.compactMap(\.colorTypeLabel), by: { $0 })
            .mapValues(\.count)
        let configured = classifier.groups.map { group in
            let matches = store.observedCourseTypeLabels.filter(group.matches)
            CourseColorGroup(
                id: "group:\(group.id.uuidString)",
                label: group.name,
                detectionStatus: .configured(matches: matches),
                groupID: group.id,
                frequency: matches.reduce(0) { $0 + (frequencies[$1] ?? 0) }
            )
        }
        let ungroupedLabels = store.observedCourseTypeLabels.filter { classifier.match($0) == nil }
        let dynamic = Dictionary(grouping: ungroupedLabels, by: { classifier.groupingKey(for: $0) }).map { key, labels in
            let sorted = labels.sorted { first, second in
                if first.count == second.count {
                    return first.localizedCaseInsensitiveCompare(second) == .orderedAscending
                }
                return first.count > second.count
            }
            return CourseColorGroup(
                id: key,
                label: sorted.first ?? "Type",
                detectionStatus: .dynamic(variants: Array(sorted.dropFirst())),
                groupID: nil,
                frequency: sorted.reduce(0) { $0 + (frequencies[$1] ?? 0) }
            )
        }
        return (configured + dynamic).sorted {
            CourseColorFrequencyOrder.precedes(
                firstFrequency: $0.frequency,
                firstLabel: $0.label,
                secondFrequency: $1.frequency,
                secondLabel: $1.label
            )
        }
    }

    var body: some View {
        List {
            Section {
                if detectedGroups.isEmpty {
                    ContentUnavailableView("Aucun type détecté", systemImage: "paintpalette", description: Text("Les types sont découverts automatiquement dans les données CELCAT chargées."))
                } else {
                    ForEach(detectedGroups) { group in
                        HueTypeRow(
                            label: group.label,
                            detectionStatus: group.detectionStatus,
                            hex: group.groupID.map {
                                CourseTypeColorPreferences.hex(forGroupID: $0, fallbackName: group.label)
                            } ?? CourseTypeColorPreferences.hex(for: group.label),
                            expanded: expandedType == group.id,
                            onToggle: {
                                withAnimation(.snappy(duration: 0.22)) { expandedType = expandedType == group.id ? nil : group.id }
                                HapticService.fire(.selection, enabled: store.hapticsEnabled)
                            },
                            onCommit: { hue in
                                if let groupID = group.groupID {
                                    CourseTypeColorPreferences.setHex(Color.hueHex(hue), forGroupID: groupID)
                                } else {
                                    CourseTypeColorPreferences.setHex(Color.hueHex(hue), for: group.label)
                                }
                                store.courseColorsDidChange()
                                HapticService.fire(.selection, enabled: store.hapticsEnabled)
                                Task { await store.restartLiveActivity() }
                            }
                        ).id("\(group.id)-\(refreshToken.uuidString)")
                    }
                }
            } header: { Text("Couleurs par type") }
            footer: { Text("Chaque regroupement regex possède une seule teinte, affichée sous son nom. Les types CELCAT non regroupés restent séparés.") }

            if !detectedGroups.isEmpty {
                Section {
                    Button("Rétablir les couleurs par défaut") {
                        CourseTypeColorPreferences.reset(
                            labels: detectedGroups.filter { $0.groupID == nil }.map(\.label),
                            groupIDs: detectedGroups.compactMap(\.groupID)
                        )
                        expandedType = nil; refreshToken = UUID()
                        store.courseColorsDidChange()
                        HapticService.fire(.selection, enabled: store.hapticsEnabled)
                        Task { await store.restartLiveActivity() }
                    }
                }
            }
        }
        .navigationTitle("Couleurs des cours")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HueTypeRow: View {
    let label: String; let detectionStatus: CourseColorDetectionStatus; let hex: String; let expanded: Bool
    let onToggle: () -> Void; let onCommit: (Double) -> Void
    @State private var hue: Double

    init(label: String, detectionStatus: CourseColorDetectionStatus, hex: String, expanded: Bool, onToggle: @escaping () -> Void, onCommit: @escaping (Double) -> Void) {
        self.label = label; self.detectionStatus = detectionStatus; self.hex = hex; self.expanded = expanded; self.onToggle = onToggle; self.onCommit = onCommit
        _hue = State(initialValue: Color.hue(fromHex: hex))
    }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(hue: hue, saturation: 0.82, brightness: 0.95)).frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label).font(.body.weight(.semibold)).foregroundStyle(.primary)
                        if let statusText = detectionStatus.text {
                            Text(statusText)
                                .font(.caption2)
                                .foregroundStyle(
                                    detectionStatus.isEmptyConfiguredGroup
                                        ? Color.secondary.opacity(0.62)
                                        : Color.secondary
                                )
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption.bold()).foregroundStyle(.secondary).rotationEffect(.degrees(expanded ? 180 : 0))
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)

            if expanded {
                HueStrip(hue: $hue, onCommit: { onCommit(hue) }).transition(.opacity.combined(with: .move(edge: .top)))
            }
        }.padding(.vertical, 2)
    }
}

private struct HueStrip: View {
    @Binding var hue: Double
    let onCommit: () -> Void
    private let thumbSize: CGFloat = 26

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            ZStack(alignment: .leading) {
                LinearGradient(colors: stride(from: 0.0, through: 1.0, by: 0.04).map { Color(hue: $0, saturation: 0.82, brightness: 0.95) }, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 18).clipShape(Capsule()).padding(.vertical, 9)
                Circle().fill(.white).overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1)).shadow(radius: 1.5, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: max(0, min(width - thumbSize, CGFloat(hue) * (width - thumbSize))))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let trackWidth = max(1, width - thumbSize)
                        let centeredX = value.location.x - thumbSize / 2
                        let newHue = max(0, min(1, Double(centeredX / trackWidth)))
                        hue = newHue
                    }
                    .onEnded { _ in onCommit() }
            )
        }
        .frame(height: 44)
        .accessibilityLabel("Teinte \(labelForHue(hue))")
    }

    private func labelForHue(_ value: Double) -> String { "\(Int(value * 360)) degrés" }
}

private extension Color {
    static func hue(fromHex hex: String) -> Double {
        let uiColor = UIColor(Color(hexString: hex)); var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return 0.58 }
        return Double(hue)
    }
    static func hueHex(_ hue: Double) -> String {
        let color = UIColor(hue: CGFloat(max(0, min(1, hue))), saturation: 0.82, brightness: 0.95, alpha: 1)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
    }
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted); var value: UInt64 = 0; Scanner(string: cleaned).scanHexInt64(&value)
        if cleaned.count == 6 { self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255) }
        else { self = .accentColor }
    }
}
