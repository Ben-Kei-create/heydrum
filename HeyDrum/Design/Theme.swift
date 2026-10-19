import SwiftUI

/// Design tokens from docs/01 §2. Hex values are kept as constants so contrast can be unit-tested.
enum Palette {
    static let inkHex: UInt32 = 0x302C29
    static let primaryOrangeHex: UInt32 = 0xED8D45
    static let orangePressedHex: UInt32 = 0xD8752C
    static let softOrangeHex: UInt32 = 0xF9E1CD
    static let warmBeigeHex: UInt32 = 0xEDE1D0
    static let paperHex: UInt32 = 0xFAF8F4
    static let pureWhiteHex: UInt32 = 0xFFFFFF
    static let mutedHex: UInt32 = 0x756F69
    static let strokeHex: UInt32 = 0xDDD7D0
    static let adBackgroundHex: UInt32 = 0xF2F0ED

    static let ink = Color(hex: inkHex)
    static let primaryOrange = Color(hex: primaryOrangeHex)
    static let orangePressed = Color(hex: orangePressedHex)
    static let softOrange = Color(hex: softOrangeHex)
    static let warmBeige = Color(hex: warmBeigeHex)
    static let paper = Color(hex: paperHex)
    static let pureWhite = Color(hex: pureWhiteHex)
    static let muted = Color(hex: mutedHex)
    static let stroke = Color(hex: strokeHex)
    static let adBackground = Color(hex: adBackgroundHex)
}

enum Metrics {
    static let unit: CGFloat = 4
    static let outerPadding: CGFloat = 20
    static let cardSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 24
    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 14
    static let chipRadius: CGFloat = 12
    static let minTap: CGFloat = 44
    static let buttonHeight: CGFloat = 56
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// WCAG 2.x relative luminance / contrast ratio.
enum Contrast {
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF) + 0.7152 * channel((hex >> 8) & 0xFF) + 0.0722 * channel(hex & 0xFF)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
