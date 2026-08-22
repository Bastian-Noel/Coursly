import SwiftUI
import UIKit

struct LiveActivityColorSettingsView: View {
    @Environment(CalendarStore.self) private var store
    @State private var refreshToken = UUID()
    @State private var expandedType: String?

    private var detectedTypes: [String] { store.observedCourseTypeLabels }

    var body: some View {
        List {
            Section {
                if detectedTypes.isEmpty {
                    ContentUnavailableView(
                        "Aucun type détecté",
                        systemImage: "paintpalette",
                        description: Text("Les types sont découverts automatiquement dans les données CELCAT chargées.")
                    )
                } else {
                    ForEach(detectedTypes, id: \.self) { label in
                        HueTypeRow(
                            label: label,
                            hex: CourseTypeColorPreferences.hex(for: label),
                            expanded: expandedType == label,
                            onToggle: {
                                withAnimation(.snappy(duration: 0.22)) {
                                    expandedType = expandedType == label ? nil : label
                                }
                                HapticService.fire(.selection, enabled: store.hapticsEnabled)
                            },
                            onChange: { hue in
                                CourseTypeColorPreferences.setHex(Color.hueHex(hue), for: label)
                                refreshToken = UUID()
                            },
                            onCommit: {
                                HapticService.fire(.selection, enabled: store.hapticsEnabled)
                                Task { await store.restartLiveActivity() }
                            }
                        )
                        .id("\(label)-\(refreshToken.uuidString)")
                    }
                }
            } header: {
                Text("Couleurs par type")
            } footer: {
                Text("Touchez un type pour ouvrir uniquement son sélecteur de teinte. Le curseur suit le doigt en continu pendant le glissement.")
            }

            if !detectedTypes.isEmpty {
                Section {
                    Button("Rétablir les couleurs par défaut") {
                        CourseTypeColorPreferences.reset(labels: detectedTypes)
                        expandedType = nil
                        refreshToken = UUID()
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
    let label: String
    let hex: String
    let expanded: Bool
    let onToggle: () -> Void
    let onChange: (Double) -> Void
    let onCommit: () -> Void

    @State private var hue: Double

    init(label: String, hex: String, expanded: Bool, onToggle: @escaping () -> Void, onChange: @escaping (Double) -> Void, onCommit: @escaping () -> Void) {
        self.label = label
        self.hex = hex
        self.expanded = expanded
        self.onToggle = onToggle
        self.onChange = onChange
        self.onCommit = onCommit
        _hue = State(initialValue: Color.hue(fromHex: hex))
    }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(hue: hue, saturation: 0.82, brightness: 0.95))
                        .frame(width: 30, height: 30)
                    Text(label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                HueStrip(hue: $hue, onChange: onChange, onCommit: onCommit)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
    }
}

private struct HueStrip: View {
    @Binding var hue: Double
    let onChange: (Double) -> Void
    let onCommit: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 0.05).map { Color(hue: $0, saturation: 0.82, brightness: 0.95) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(Capsule())

                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(.black.opacity(0.2), lineWidth: 1))
                    .shadow(radius: 1.5, y: 1)
                    .frame(width: 24, height: 24)
                    .offset(x: max(0, min(width - 24, CGFloat(hue) * (width - 24))))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newHue = max(0, min(1, Double(value.location.x / width)))
                        hue = newHue
                        onChange(newHue)
                    }
                    .onEnded { _ in onCommit() }
            )
        }
        .frame(height: 28)
        .padding(.bottom, 4)
    }
}

private extension Color {
    static func hue(fromHex hex: String) -> Double {
        let uiColor = UIColor(Color(hexString: hex))
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
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
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        if cleaned.count == 6 {
            self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
        } else {
            self = .accentColor
        }
    }
}
