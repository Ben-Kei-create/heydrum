import Foundation

/// Selectable delays (seconds) before reading starts. 0 = immediately.
enum StartDelay {
    static let options: [Int] = [0, 3, 5, 10, 15, 30]

    static func normalize(_ value: Int) -> Int { options.contains(value) ? value : 0 }

    static func label(_ seconds: Int) -> String { seconds == 0 ? "すぐ" : "\(seconds)秒後" }
}

/// Reading-screen text size: big enough to be read from a distance, shrinking only as the text grows.
enum PlaybackTextStyle {
    static func fontSize(forCharacterCount count: Int, scale: CGFloat = 1) -> CGFloat {
        base(forCharacterCount: count) * min(max(scale, 1), 6)
    }

    /// Sized from the FULL text length (known up front) so the font never changes while text is revealed.
    /// Even 500 characters stay at 46pt or more (owner: readable from a distance).
    static func base(forCharacterCount count: Int) -> CGFloat {
        switch count {
        case ..<13: 88
        case ..<31: 72
        case ..<61: 60
        case ..<121: 52
        default: 46
        }
    }
}
