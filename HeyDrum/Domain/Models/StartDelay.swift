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
        base(forCharacterCount: count) * min(max(scale, 1), 2)
    }

    static func base(forCharacterCount count: Int) -> CGFloat {
        switch count {
        case ..<13: 88
        case ..<31: 68
        case ..<61: 54
        case ..<121: 44
        case ..<241: 36
        default: 30
        }
    }
}
