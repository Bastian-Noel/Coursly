import SwiftUI
import UIKit

struct CourseBlock: View {
    @Environment(CalendarStore.self) private var store
    let event: CalendarEvent
    let availableWidth: CGFloat
    let height: CGFloat
    let highlighted: Bool
    var weekLayout = false
    var isPast = false

    private var layout: CourseCardLayout {
        CourseCardLayout(width: availableWidth, height: height, weekLayout: weekLayout)
    }

    var body: some View {
        let _ = store.courseColorRevision
        HStack(spacing: 0) {
            Rectangle()
                .fill(stripeColor)
                .frame(width: layout.stripeWidth)
                .frame(maxHeight: .infinity)

            content
                .padding(.leading, layout.horizontalPadding)
                .padding(.trailing, max(2, layout.horizontalPadding - 1))
                .padding(.vertical, layout.verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(width: max(1, availableWidth), height: max(1, height), alignment: .topLeading)
        .background(Rectangle().fill(cardFill))
        .overlay {
            if highlighted {
                Rectangle().stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .overlay {
            cornerTimes
        }
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var content: some View {
        switch layout.density {
        case .micro:
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(layout.titleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !event.room.isEmpty {
                    Label(event.room, systemImage: "mappin")
                        .font(layout.metadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                }
            }

        case .compact:
            VStack(alignment: .leading, spacing: 2) {
                header
                Text(event.title)
                    .font(layout.titleFont)
                    .lineLimit(layout.titleLines)
                    .minimumScaleFactor(0.58)
                compactMetadata
            }

        case .regular:
            VStack(alignment: .leading, spacing: layout.lineSpacing) {
                header
                Text(event.title)
                    .font(layout.titleFont)
                    .lineLimit(layout.titleLines)
                    .minimumScaleFactor(0.68)

                if !event.room.isEmpty {
                    metadataLine(icon: "mappin.and.ellipse", text: event.room)
                }
                if !event.teachers.isEmpty {
                    metadataLine(icon: "person.fill", text: event.teachers.joined(separator: " · "))
                }
                if !event.displayGroupsText.isEmpty {
                    metadataLine(icon: "person.2.fill", text: event.displayGroupsText)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if let type = event.displayTypeLabel, !type.isEmpty {
                Text(type)
                    .font(layout.typeFont)
                    .foregroundStyle(stripeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            Spacer(minLength: 0)
        }
    }

    private var cornerTimes: some View {
        ZStack {
            Text(shortTime(event.start))
                .padding(.top, layout.verticalPadding)
                .padding(.trailing, max(2, layout.horizontalPadding - 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(shortTime(event.end))
                .padding(.trailing, max(2, layout.horizontalPadding - 1))
                .padding(.bottom, layout.verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .font(layout.timeFont)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var compactMetadata: some View {
        HStack(spacing: 4) {
            if !event.room.isEmpty {
                compactMetadataItem(icon: "mappin", text: event.room)
            }
            if layout.showsTeacher, !event.teachers.isEmpty {
                compactMetadataItem(icon: "person.fill", text: event.teachers.joined(separator: ", "))
            }
            if layout.showsGroup, !event.displayGroupsText.isEmpty {
                compactMetadataItem(icon: "person.2.fill", text: event.displayGroupsText)
            }
        }
        .font(layout.metadataFont)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.42)
    }

    private func metadataLine(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(layout.metadataFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func compactMetadataItem(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
    }

    private var baseHex: String {
        if event.source == .local { return "#AF52DE" }
        guard let label = event.displayTypeLabel, !label.isEmpty else { return "#0A84FF" }
        return CourseTypeColorPreferences.hex(for: label)
    }

    private var baseColor: Color { Color(courslyHex: baseHex) }

    private var stripeColor: Color {
        guard isPast else { return baseColor }
        return weekLayout
            ? Color(courslyHex: baseHex, saturationScale: 0.72, brightnessScale: 0.64)
            : Color(courslyHex: baseHex, saturationScale: 0.42, brightnessScale: 0.53)
    }

    private var cardFill: Color {
        if isPast {
            return weekLayout
                ? Color(courslyHex: baseHex, saturationScale: 0.58, brightnessScale: 0.62).opacity(0.27)
                : Color(courslyHex: baseHex, saturationScale: 0.28, brightnessScale: 0.46).opacity(0.38)
        }
        return baseColor.opacity(event.source == .local ? 0.11 : 0.15)
    }

    private var accessibilityText: String {
        var parts = [event.displayTypeLabel, event.title].compactMap { $0 }
        parts.append("de \(shortTime(event.start)) à \(shortTime(event.end))")
        if !event.room.isEmpty { parts.append("salle \(event.room)") }
        if !event.teachers.isEmpty { parts.append(event.teachers.joined(separator: ", ")) }
        if !event.displayGroupsText.isEmpty { parts.append(event.displayGroupsText) }
        return parts.joined(separator: ", ")
    }
}

private struct CourseCardLayout {
    enum Density { case micro, compact, regular }

    let width: CGFloat
    let height: CGFloat
    let weekLayout: Bool

    var density: Density {
        if height < 46 { return .micro }
        if weekLayout || height <= 94 || width < 150 { return .compact }
        return .regular
    }

    var stripeWidth: CGFloat { width < 85 ? 2.5 : 3.5 }
    var horizontalPadding: CGFloat { width < 90 ? 3 : 6 }
    var verticalPadding: CGFloat { height < 60 ? 2 : 4 }
    var lineSpacing: CGFloat { height < 125 ? 2 : 4 }
    var titleLines: Int { height < 70 ? 1 : (weekLayout || width < 125 ? 2 : 3) }
    var showsTeacher: Bool { height >= 62 && width >= 72 }
    var showsGroup: Bool { height >= 72 && width >= 92 }

    var titleFont: Font {
        if height < 48 { return .system(size: 8, weight: .bold) }
        if weekLayout || width < 100 { return .system(size: height < 70 ? 8.5 : 9.5, weight: .bold) }
        if height <= 94 { return .system(size: 11, weight: .bold) }
        return width < 180 ? .caption.weight(.bold) : .subheadline.weight(.bold)
    }

    var metadataFont: Font {
        if weekLayout || width < 100 { return .system(size: height < 70 ? 6.2 : 7.2, weight: .medium) }
        return height <= 94 ? .system(size: 8, weight: .medium) : .caption
    }

    var typeFont: Font { .system(size: weekLayout || width < 100 ? 7 : 9, weight: .heavy) }
    var timeFont: Font { .system(size: weekLayout || width < 100 ? 7 : 9, weight: .semibold, design: .rounded).monospacedDigit() }
}

struct CoursePressButtonStyle: ButtonStyle {
    let hapticsEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        CoursePressedLabel(
            label: configuration.label,
            isPressed: configuration.isPressed,
            hapticsEnabled: hapticsEnabled
        )
    }
}

private struct CoursePressedLabel<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let hapticsEnabled: Bool

    var body: some View {
        label
            .scaleEffect(isPressed ? 0.972 : 1)
            .brightness(isPressed ? -0.055 : 0)
            .opacity(isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.11), value: isPressed)
            .onChange(of: isPressed) { _, pressed in
                guard pressed else { return }
                HapticService.fire(.courseOpened, enabled: hapticsEnabled)
            }
    }
}

private extension Color {
    init(courslyHex hex: String, saturationScale: Double = 1, brightnessScale: Double = 1) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        guard cleaned.count == 6 else { self = .accentColor; return }

        let original = UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard original.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            self = Color(original)
            return
        }
        self.init(
            hue: Double(hue),
            saturation: Double(max(0, min(1, saturation * CGFloat(saturationScale)))),
            brightness: Double(max(0, min(1, brightness * CGFloat(brightnessScale))))
        )
    }
}
