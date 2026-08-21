import SwiftUI
import UIKit

struct LiveActivityColorSettingsView: View {
    @Environment(CalendarStore.self) private var store
    @State private var refreshToken = UUID()

    private var detectedTypes: [String] { store.observedCourseTypeLabels }

    var body: some View {
        List {
            Section {
                if detectedTypes.isEmpty {
                    ContentUnavailableView(
                        "Aucun type détecté",
                        systemImage: "paintpalette",
                        description: Text("Actualise l’emploi du temps : les catégories renvoyées par CELCAT apparaîtront ici automatiquement.")
                    )
                } else {
                    ForEach(detectedTypes, id: \.self) { label in
                        HueOnlyRow(
                            label: label,
                            hex: CourseTypeColorPreferences.hex(for: label),
                            onChange: { hue in
                                CourseTypeColorPreferences.setHex(Color.hueHex(hue), for: label)
                                refreshToken = UUID()
                                HapticService.fire(.selection, enabled: store.hapticsEnabled)
                                Task { await store.restartLiveActivity() }
                            }
                        )
                        .id("\(label)-\(refreshToken.uuidString)")
                    }
                }
            } header: {
                Text("Types détectés dans CELCAT")
            } footer: {
                Text("Seule la teinte est réglable. La saturation et la luminosité restent fixes pour garder des couleurs lisibles et cohérentes dans l’app et l’Activité en direct.")
            }

            if !detectedTypes.isEmpty {
                Section {
                    Button("Rétablir les couleurs par défaut") {
                        CourseTypeColorPreferences.reset(labels: detectedTypes)
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

private struct HueOnlyRow: View {
    let label: String
    let hex: String
    let onChange: (Double) -> Void

    @State private var hue: Double

    init(label: String, hex: String, onChange: @escaping (Double) -> Void) {
        self.label = label
        self.hex = hex
        self.onChange = onChange
        _hue = State(initialValue: Color.hue(fromHex: hex))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color(hue: hue, saturation: 0.82, brightness: 0.95))
                    .frame(width: 24, height: 24)
                Text(label)
                    .font(.body.weight(.semibold))
                Spacer()
            }

            GeometryReader { proxy in
                let width = max(1, proxy.size.width)
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: stride(from: 0.0, through: 1.0, by: 0.08).map {
                            Color(hue: $0, saturation: 0.82, brightness: 0.95)
                        },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())

                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 1))
                        .shadow(radius: 1.5, y: 1)
                        .frame(width: 22, height: 22)
                        .offset(x: max(0, min(width - 22, CGFloat(hue) * (width - 22))))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newHue = max(0, min(1, Double(value.location.x / width)))
                            if abs(newHue - hue) > 0.002 {
                                hue = newHue
                                onChange(newHue)
                            }
                        }
                )
            }
            .frame(height: 24)
        }
        .padding(.vertical, 6)
    }
}

private extension Color {
    static func hue(fromHex hex: String) -> Double {
        let uiColor = UIColor(Color(hexString: hex))
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return 0.58
        }
        return Double(hue)
    }

    static func hueHex(_ hue: Double) -> String {
        let color = UIColor(
            hue: CGFloat(max(0, min(1, hue))),
            saturation: 0.82,
            brightness: 0.95,
            alpha: 1
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }

    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        if cleaned.count == 6 {
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        } else {
            self = .accentColor
        }
    }
}
