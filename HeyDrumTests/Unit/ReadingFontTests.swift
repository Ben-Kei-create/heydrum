import XCTest
import CoreText
import UIKit
@testable import HeyDrum

@MainActor
final class ReadingFontTests: XCTestCase {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "heydrum.tests.\(UUID().uuidString)")! }

    func testAllBundledFontsAreRegisteredAndAvailable() {
        for font in ReadingFont.allCases {
            XCTAssertTrue(font.isAvailable, "\(font.label) must load from the app bundle (UIAppFonts)")
            if let name = font.postScriptName { XCTAssertNotNil(UIFont(name: name, size: 20), name) }
        }
        XCTAssertEqual(ReadingFont.allCases.count, 4)
    }

    func testSelectionPersistsAndUnknownValuesFallBackToSystem() {
        let d = defaults()
        let a = SettingsStore(defaults: d)
        XCTAssertEqual(a.readingFont, .system, "default stays the system font")
        a.readingFont = .kosugiMaru
        XCTAssertEqual(SettingsStore(defaults: d).readingFont, .kosugiMaru)
        d.set("no-such-font", forKey: SettingsStore.Key.font)
        XCTAssertEqual(SettingsStore(defaults: d).readingFont, .system)
        XCTAssertEqual(ReadingFont.from(nil), .system)
    }

    /// Everyday hiragana/katakana (incl. small kana and ヴ), digits and punctuation. Only very rare kana (ゕ ゖ ゔ ヷ-ヺ)
    /// are missing in some fonts; they fall back to the system font. The owner's reading texts must render in these fonts without missing glyphs (kana and digits at minimum).
    func testFontsCoverKanaDigitsAndTheGreetingWord() {
        let kana = (0x3041...0x3093).compactMap(UnicodeScalar.init).map(Character.init) + (0x30A1...0x30F4).compactMap(UnicodeScalar.init).map(Character.init)
        let required = Array(String(kana)) + Array("0123456789。、！？ー「ドラム」")
        let sampleKanji = Array("本日は晴天来店一時停止読上開始音声東京年")
        for font in ReadingFont.allCases {
            guard let name = font.postScriptName else { continue }
            let ct = CTFontCreateWithName(name as CFString, 20, nil)
            func missing(_ chars: [Character]) -> [Character] {
                chars.filter { ch in
                    var glyphs = [CGGlyph](repeating: 0, count: ch.utf16.count)
                    let units = Array(ch.utf16)
                    return !CTFontGetGlyphsForCharacters(ct, units, &glyphs, units.count) || glyphs.contains(0)
                }
            }
            XCTAssertEqual(missing(required), [], "\(font.label): kana/digits/punctuation must be covered")
            print("FONT-COVERAGE \(font.label): missing sample kanji = \(String(missing(sampleKanji)))")
        }
    }
}
