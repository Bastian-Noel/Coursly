import SwiftUI
import UIKit

struct CourseBlock: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
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
            if event.source == .local {
                DottedCourseStripe(color: stripeColor, width: layout.stripeWidth)
            } else {
                Rectangle()
                    .fill(stripeColor)
                    .frame(width: layout.stripeWidth)
                    .frame(maxHeight: .infinity)
            }

            content
                .padding(.leading, layout.horizontalPadding)
                .padding(.trailing, max(2, layout.horizontalPadding - 1))
                .padding(.vertical, layout.verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(primaryTextColor)
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(width: max(1, availableWidth), height: max(1, height), alignment: .topLeading)
        .background(Rectangle().fill(cardFill))
        .overlay {
            if highlighted {
                Rectangle().stroke(Color.white.opacity(0.42), lineWidth: 1)
            }
        }
        .overlay {
            if !weekLayout {
                cornerTimes
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var content: some View {
        if weekLayout {
            weekContent
        } else {
            switch layout.density {
            case .micro:
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(layout.titleFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !event.room.isEmpty {
                        metadataLine(icon: "mappin", text: event.room)
                    }
                }

            case .compact:
                VStack(alignment: .leading, spacing: 2) {
                    header
                    Text(event.title)
                        .font(layout.titleFont)
                        .lineLimit(layout.titleLines)
                        .minimumScaleFactor(0.58)
                    dayCompactMetadata
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
    }

    private var weekContent: some View {
        ViewThatFits(in: .vertical) {
            weekContentVariant(metadataLimit: 3)
            weekContentVariant(metadataLimit: 2)
            weekContentVariant(metadataLimit: 1)
            weekContentVariant(metadataLimit: 0)
        }
    }

    private func weekContentVariant(metadataLimit: Int) -> some View {
        let metadata = Array(weekMetadata.prefix(metadataLimit))
        return VStack(alignment: .leading, spacing: layout.weekLineSpacing) {
            HStack(spacing: 3) {
                Text(shortTime(event.start))
                Text("–").foregroundStyle(.tertiary)
                Text(shortTime(event.end))
            }
            .font(layout.weekTimeFont)
            .foregroundStyle(metadataTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .center)

            Text(event.title)
                .font(layout.titleFont)
                .lineLimit(5)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(metadata.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(layout.metadataFont)
                    .foregroundStyle(metadataTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var weekMetadata: [String] {
        var values: [String] = []
        if !event.room.isEmpty { values.append(event.room) }
        if !event.teachers.isEmpty { values.append(event.teachers.joined(separator: " · ")) }
        if !event.displayGroupsText.isEmpty { values.append(event.displayGroupsText) }
        return values
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
        .foregroundStyle(metadataTextColor)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var dayCompactMetadata: some View {
        VStack(alignment: .leading, spacing: 1) {
            if !event.room.isEmpty {
                metadataLine(icon: "mappin", text: event.room)
            }
            if layout.showsTeacher, !event.teachers.isEmpty {
                metadataLine(icon: "person.fill", text: event.teachers.joined(separator: " · "))
            }
            if layout.showsGroup, !event.displayGroupsText.isEmpty {
                metadataLine(icon: "person.2.fill", text: event.displayGroupsText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metadataLine(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .frame(width: layout.metadataIconWidth, alignment: .center)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .font(layout.metadataFont)
        .foregroundStyle(metadataTextColor)
    }


    private var baseHex: String {
        if event.source == .local { return "#AF52DE" }
        guard let label = event.colorTypeLabel, !label.isEmpty else { return "#0A84FF" }
        return CourseTypeColorPreferences.hex(for: label)
    }

    private var baseColor: Color { Color(courslyHex: baseHex) }

    private var primaryTextColor: Color {
        if highlighted { return .white }
        return colorScheme == .dark
            ? Color(courslyHex: baseHex, saturationScale: 0.52, brightnessScale: 1.55)
            : Color(courslyHex: baseHex, saturationScale: 0.78, brightnessScale: 0.48)
    }

    private var metadataTextColor: Color {
        highlighted ? Color.white.opacity(0.86) : primaryTextColor.opacity(0.78)
    }

    private var stripeColor: Color {
        if highlighted { return Color.white.opacity(0.92) }
        guard isPast else { return baseColor }
        return weekLayout
            ? Color(courslyHex: baseHex, saturationScale: 0.72, brightnessScale: 0.64)
            : Color(courslyHex: baseHex, saturationScale: 0.42, brightnessScale: 0.53)
    }

    private var cardFill: Color {
        if highlighted { return baseColor }
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

private struct DottedCourseStripe: View {
    let color: Color
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width / 2, y: 1))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height - 1))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [3, 4]))
        }
        .frame(width: max(3, width))
        .frame(maxHeight: .infinity)
        .allowsHitTesting(false)
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
    var metadataIconWidth: CGFloat { width < 90 ? 11 : 15 }
    var horizontalPadding: CGFloat { width < 90 ? 3 : 6 }
    var verticalPadding: CGFloat { height < 60 ? 2 : 4 }
    var lineSpacing: CGFloat { height < 125 ? 2 : 4 }
    var weekLineSpacing: CGFloat { height < 70 ? 1 : 2 }
    var titleLines: Int { height < 70 ? 1 : (width < 125 ? 2 : 3) }
    var showsTeacher: Bool { height >= 62 }
    var showsGroup: Bool { height >= 76 }

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
    var timeFont: Font { .system(size: width < 100 ? 7 : 9, weight: .semibold, design: .rounded).monospacedDigit() }
    var weekTimeFont: Font { .system(size: width < 65 ? 6 : 7, weight: .medium, design: .rounded).monospacedDigit() }
}

struct CoursePressButtonStyle: ButtonStyle {
    let hapticsEnabled: Bool
    var interactionEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        CoursePressedLabel(
            label: configuration.label,
            isPressed: configuration.isPressed,
            hapticsEnabled: hapticsEnabled,
            interactionEnabled: interactionEnabled
        )
    }
}

private struct CoursePressedLabel<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let hapticsEnabled: Bool
    let interactionEnabled: Bool
    @State private var hapticTask: Task<Void, Never>?

    var body: some View {
        label
            .scaleEffect(isPressed && interactionEnabled ? 0.972 : 1)
            .brightness(isPressed && interactionEnabled ? -0.055 : 0)
            .opacity(isPressed && interactionEnabled ? 0.92 : 1)
            .animation(.snappy(duration: 0.11), value: isPressed)
            .onChange(of: isPressed) { _, pressed in
                hapticTask?.cancel()
                guard pressed, interactionEnabled else { return }
                HapticService.prepare(.courseOpened, enabled: hapticsEnabled)
                hapticTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(45))
                    guard !Task.isCancelled else { return }
                    HapticService.fire(.courseOpened, enabled: hapticsEnabled)
                }
            }
            .onChange(of: interactionEnabled) { _, enabled in
                if !enabled { hapticTask?.cancel() }
            }
            .onDisappear { hapticTask?.cancel() }
    }
}

enum CourseInteractionGate {
    static func isHorizontalNavigation(_ translation: CGSize) -> Bool {
        abs(translation.width) >= 8 && abs(translation.width) > abs(translation.height) * 1.15
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
