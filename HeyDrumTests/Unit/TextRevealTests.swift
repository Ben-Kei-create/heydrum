import XCTest
@testable import HeyDrum

final class TextRevealTests: XCTestCase {
    private let tricky = "こんにちは😀。\nあいうえお👨‍👩‍👧‍👦東京2026年e\u{301}終"

    func testAlignedEndRoundsUpToCharacterBoundaries() {
        let text = "a😀b"                       // utf16: a(1) 😀(2) b(1)
        XCTAssertEqual(TextReveal.alignedEnd(in: text, location: 0, length: 1), 1)
        XCTAssertEqual(TextReveal.alignedEnd(in: text, location: 1, length: 1), 3, "mid-surrogate → whole emoji")
        XCTAssertEqual(TextReveal.alignedEnd(in: text, location: 1, length: 2), 3)
        XCTAssertEqual(TextReveal.alignedEnd(in: text, location: 3, length: 1), 4)
        let family = "👨‍👩‍👧‍👦x"
        XCTAssertEqual(TextReveal.alignedEnd(in: family, location: 0, length: 2), family.utf16.count - 1, "partial ZWJ cluster → whole family")
        let combining = "e\u{301}x"
        XCTAssertEqual(TextReveal.alignedEnd(in: combining, location: 0, length: 1), 2, "base + combining mark stay together")
    }

    func testInvalidRangesAreRejected() {
        let t = "あいう"
        XCTAssertNil(TextReveal.alignedEnd(in: t, location: -1, length: 1))
        XCTAssertNil(TextReveal.alignedEnd(in: t, location: 0, length: -1))
        XCTAssertNil(TextReveal.alignedEnd(in: t, location: 4, length: 0))
        XCTAssertNil(TextReveal.alignedEnd(in: t, location: 2, length: 5))
        XCTAssertNil(TextReveal.alignedEnd(in: t, location: 0, length: Int.max))
        XCTAssertNil(TextReveal.alignedEnd(in: t, location: Int.max, length: 1))
        XCTAssertNil(TextReveal.alignedEnd(in: t, location: 1, length: Int.max))
        XCTAssertNotNil(TextReveal.alignedEnd(in: t, location: 3, length: 0), "empty range at the very end is valid")
    }

    func testEveryRangeOverTrickyTextNeverCrashesAndPrefixIsAlwaysValid() {
        let total = tricky.utf16.count
        for loc in -1...(total + 1) {
            for len in -1...(total + 2) {
                guard let end = TextReveal.alignedEnd(in: tricky, location: loc, length: len) else { continue }
                XCTAssertLessThanOrEqual(end, total)
                XCTAssertGreaterThanOrEqual(end, min(loc + len, total))
                let shown = TextReveal.prefix(of: tricky, utf16Count: end)
                XCTAssertTrue(tricky.hasPrefix(shown))
                XCTAssertEqual(shown.utf16.count, end, "no characters lost or half-shown")
            }
        }
    }

    func testPrefixRoundsDownAndHandlesBounds() {
        XCTAssertEqual(TextReveal.prefix(of: "a😀b", utf16Count: 2), "a", "never shows half an emoji")
        XCTAssertEqual(TextReveal.prefix(of: "abc", utf16Count: 0), "")
        XCTAssertEqual(TextReveal.prefix(of: "abc", utf16Count: -3), "")
        XCTAssertEqual(TextReveal.prefix(of: "abc", utf16Count: 99), "abc")
        XCTAssertEqual(TextReveal.prefix(of: "行1\n行2", utf16Count: 3), "行1\n", "newlines are kept")
    }

    func testPlaybackFontIsLargeAndNeverShrinksBelow44() {
        var last = CGFloat.greatestFiniteMagnitude
        for n in [1, 12, 13, 30, 31, 60, 61, 120, 121, 240, 500] {
            let size = PlaybackTextStyle.fontSize(forCharacterCount: n)
            XCTAssertLessThanOrEqual(size, last)
            XCTAssertGreaterThanOrEqual(size, 44, "long text keeps a big font (owner: 44-48pt or more)")
            last = size
        }
        XCTAssertEqual(PlaybackTextStyle.fontSize(forCharacterCount: 10), 88, "short phrases keep the 88pt look")
        XCTAssertGreaterThanOrEqual(PlaybackTextStyle.fontSize(forCharacterCount: 500), 46)
        XCTAssertEqual(PlaybackTextStyle.fontSize(forCharacterCount: 500, scale: 1.5), 69, accuracy: 0.01, "Dynamic Type scale applies")
        XCTAssertEqual(PlaybackTextStyle.fontSize(forCharacterCount: 500, scale: 9), 276, accuracy: 0.01, "capped at 6x (2x Dynamic Type × 3x slider)")
        XCTAssertEqual(PlaybackTextStyle.fontSize(forCharacterCount: 10, scale: 3), 264, accuracy: 0.01, "the slider can make short text huge")
        XCTAssertEqual(PlaybackTextStyle.fontSize(forCharacterCount: 10, scale: 0.2), 88, accuracy: 0.01, "never below the standard size")
    }
}
