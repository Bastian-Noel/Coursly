import SwiftUI
import UIKit

struct LiveActivityColorSettingsView: View {
    @Environment(CalendarStore.self) private var store
    @State private var refreshToken = UUID()

    var body: some View {
        List {
            Section {
                ForEach(CourseType.allCases, id: \.rawValue) { type in
                    ColorPicker(
                        selection: Binding(
                            get: { Color(hexString: CourseTypeColorPreferences.hex(for: type)) },
                            set: { newColor in
                                CourseTypeColorPreferences.setHex(newColor.hexString, for: type)
                                refreshToken = UUID()
                                Task { await store.restartLiveActivity() }
                            }
                        ),
                        supportsOpacity: false
                    ) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hexString: CourseTypeColorPreferences.hex(for: type)))
                                .frame(width: 12, height: 12)
                            Text(type.rawValue)
                                .font(.body.weight(.semibold))
                        }
                    }
                    .id("\(type.rawValue)-\(refreshToken.uuidString)")
                }
            } header: {
                Text("Types de cours")
            } footer: {
                Text("Ces couleurs sont utilisées pour rendre le type de cours immédiatement identifiable dans l’Activité en direct.")
            }

            Section {
                Button("Rétablir les couleurs par défaut") {
                    CourseTypeColorPreferences.reset()
                    refreshToken = UUID()
                    HapticService.fire(.selection, enabled: store.hapticsEnabled)
                    Task { await store.restartLiveActivity() }
                }
            }
        }
        .navigationTitle("Couleurs des cours")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Color {
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

    var hexString: String {
        let color = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#0A84FF"
        }

        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}
