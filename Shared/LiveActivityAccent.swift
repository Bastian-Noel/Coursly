import Foundation

enum LiveActivityAccent {
    static func readableHex(from hex: String, minimumLuminance: Double = 0.34) -> String {
        guard var rgb = RGB(hex: hex) else { return "#0A84FF" }
        var hsv = rgb.hsv

        while rgb.relativeLuminance < minimumLuminance && (hsv.brightness < 1 || hsv.saturation > 0.34) {
            hsv.brightness = min(1, hsv.brightness + 0.04)
            hsv.saturation = max(0.34, hsv.saturation - 0.045)
            rgb = RGB(hsv: hsv)
        }
        return rgb.hex
    }

    static func relativeLuminance(of hex: String) -> Double? {
        RGB(hex: hex)?.relativeLuminance
    }

    private struct HSV {
        var hue: Double
        var saturation: Double
        var brightness: Double
    }

    private struct RGB {
        var red: Double
        var green: Double
        var blue: Double

        init?(hex: String) {
            let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        }

        init(hsv: HSV) {
            let h = (hsv.hue - floor(hsv.hue)) * 6
            let sector = Int(floor(h))
            let fraction = h - Double(sector)
            let p = hsv.brightness * (1 - hsv.saturation)
            let q = hsv.brightness * (1 - fraction * hsv.saturation)
            let t = hsv.brightness * (1 - (1 - fraction) * hsv.saturation)
            switch sector % 6 {
            case 0: (red, green, blue) = (hsv.brightness, t, p)
            case 1: (red, green, blue) = (q, hsv.brightness, p)
            case 2: (red, green, blue) = (p, hsv.brightness, t)
            case 3: (red, green, blue) = (p, q, hsv.brightness)
            case 4: (red, green, blue) = (t, p, hsv.brightness)
            default: (red, green, blue) = (hsv.brightness, p, q)
            }
        }

        var hsv: HSV {
            let maximum = max(red, max(green, blue))
            let minimum = min(red, min(green, blue))
            let delta = maximum - minimum
            let hue: Double
            if delta == 0 { hue = 0 }
            else if maximum == red { hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6 }
            else if maximum == green { hue = (((blue - red) / delta) + 2) / 6 }
            else { hue = (((red - green) / delta) + 4) / 6 }
            return HSV(hue: hue < 0 ? hue + 1 : hue, saturation: maximum == 0 ? 0 : delta / maximum, brightness: maximum)
        }

        var relativeLuminance: Double {
            func linear(_ value: Double) -> Double {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        var hex: String {
            String(
                format: "#%02X%02X%02X",
                Int(round(max(0, min(1, red)) * 255)),
                Int(round(max(0, min(1, green)) * 255)),
                Int(round(max(0, min(1, blue)) * 255))
            )
        }
    }
}
