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
                        ColorPicker(
                            selection: Binding(
                                get: { Color(hexString: CourseTypeColorPreferences.hex(for: label)) },
                                set: { newColor in
                                    CourseTypeColorPreferences.setHex(newColor.hexString, for: label)
                                    refreshToken = UUID()
                                    HapticService.fire(.selection, enabled: store.hapticsEnabled)
                                    Task { await store.restartLiveActivity() }
                                }
                            ),
                            supportsOpacity: false
                        ) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color(hexString: CourseTypeColorPreferences.hex(for: label)))
                                    .frame(width: 24, height: 24)
                                Text(label)
                                    .font(.body.weight(.semibold))
                                    .lineLimit(2)
                            }
                            .frame(minHeight: 44)
                        }
                        .id("\(label)-\(refreshToken.uuidString)")
                    }
                }
            } header: {
                Text("Types détectés dans CELCAT")
            } footer: {
                Text("La liste vient directement des catégories présentes dans les données chargées. Une nouvelle catégorie apparaîtra automatiquement et recevra une couleur par défaut stable, que tu peux remplacer par n’importe quelle couleur exacte.")
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
            return "#007AFF"
        }

        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}
