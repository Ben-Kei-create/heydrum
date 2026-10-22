import SwiftUI
import UIKit

/// Font choices for the reading screen (owner request 2026-10-22). The fonts are bundled and registered
/// through `UIAppFonts`; all three are open-licensed (see Resources/Fonts/License-*.txt and the in-app credits).
enum ReadingFont: String, CaseIterable, Identifiable, Sendable {
    case system, mplus1, kosugiMaru, lubrifont
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "標準（システム）"
        case .mplus1: "M PLUS 1"
        case .kosugiMaru: "Kosugi Maru（丸ゴシック）"
        case .lubrifont: "WDXL Lubrifont JP N"
        }
    }

    var postScriptName: String? {
        switch self {
        case .system: nil
        case .mplus1: "MPLUS1-Bold"
        case .kosugiMaru: "KosugiMaru-Regular"
        case .lubrifont: "WDXLLubrifontJPN-Regular"
        }
    }

    /// False when the bundled file could not be registered (then the system font is used).
    var isAvailable: Bool {
        guard let name = postScriptName else { return true }
        return UIFont(name: name, size: 12) != nil
    }

    func font(size: CGFloat) -> Font {
        guard let name = postScriptName, isAvailable else { return .system(size: size, weight: .bold) }
        return .custom(name, fixedSize: size)
    }

    static func from(_ raw: String?) -> ReadingFont { raw.flatMap(ReadingFont.init(rawValue:)) ?? .system }
}
