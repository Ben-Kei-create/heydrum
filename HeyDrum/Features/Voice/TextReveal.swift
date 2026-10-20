import Foundation

/// Cumulative reveal of the reading text (owner spec 2026-10-20): only the part the synthesizer has
/// announced (via `willSpeakRangeOfSpeechString`) is shown. All offsets are UTF-16, like `NSRange`.
enum TextReveal {
    /// UTF-16 end offset, rounded UP to a Character boundary, covering `[location, location + length)`.
    /// Returns nil for an invalid range (negative, or beyond the text), which callers must ignore.
    static func alignedEnd(in text: String, location: Int, length: Int) -> Int? {
        let total = text.utf16.count
        guard location >= 0, length >= 0, location <= total, length <= total - location else { return nil }
        let end = location + length
        if end == 0 { return 0 }
        var offset = 0
        for character in text {
            offset += character.utf16.count
            if offset >= end { return offset }
        }
        return total
    }

    /// The prefix of `text` that is `utf16Count` UTF-16 units long (must be Character-aligned, as
    /// returned by `alignedEnd`; otherwise it is rounded down so no half character is ever shown).
    static func prefix(of text: String, utf16Count: Int) -> String {
        guard utf16Count > 0 else { return "" }
        guard utf16Count < text.utf16.count else { return text }
        var shown = ""
        var offset = 0
        for character in text {
            let next = offset + character.utf16.count
            if next > utf16Count { break }
            shown.append(character)
            offset = next
        }
        return shown
    }
}
