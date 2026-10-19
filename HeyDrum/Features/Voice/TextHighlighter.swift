import SwiftUI

enum TextHighlighter {
    /// Converts a UTF-16 `NSRange` from the speech delegate into a highlight. Invalid ranges are ignored.
    static func attributed(_ text: String, highlight: NSRange?) -> AttributedString {
        var result = AttributedString(text)
        guard let highlight,
              let stringRange = Range(highlight, in: text),
              let attributedRange = Range(stringRange, in: result) else { return result }
        result[attributedRange].backgroundColor = Palette.softOrange
        result[attributedRange].underlineStyle = .single
        result[attributedRange].underlineColor = UIColor(Palette.primaryOrange)
        return result
    }
}
