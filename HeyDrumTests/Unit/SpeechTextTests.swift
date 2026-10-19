import XCTest
@testable import HeyDrum

final class SpeechTextTests: XCTestCase {
    // T-006
    func testEmptyWhitespaceAndNewlinesAreRejected() {
        for raw in ["", " ", "\n", " \n\t \n", "　\u{3000}"] {
            XCTAssertNil(SpeechText.normalized(raw), "'\(raw.debugDescription)' must be rejected")
        }
    }

    // T-007
    func testOneAndFiveHundredCharactersAreAccepted() {
        XCTAssertEqual(SpeechText.normalized("あ"), "あ")
        let five = String(repeating: "あ", count: 500)
        XCTAssertEqual(SpeechText.normalized(five), five)
    }

    func testFiveHundredAndOneIsRejectedAndClampedTo500() {
        let over = String(repeating: "あ", count: 501)
        XCTAssertNil(SpeechText.normalized(over))
        let clamped = SpeechText.clamped(over)
        XCTAssertEqual(clamped.text.count, 500)
        XCTAssertTrue(clamped.wasTruncated)
        XCTAssertFalse(SpeechText.clamped(String(repeating: "あ", count: 500)).wasTruncated)
    }

    func testCountIsInGraphemeClusters() {
        let family = String(repeating: "👨‍👩‍👧‍👦", count: 500)   // each is 1 Character, many UTF-16 units
        XCTAssertEqual(family.count, 500)
        XCTAssertNotNil(SpeechText.normalized(family))
        XCTAssertNil(SpeechText.normalized(family + "あ"))
    }

    func testInnerNewlinesAreKeptAndOuterWhitespaceTrimmed() {
        XCTAssertEqual(SpeechText.normalized("  あいうえお\nかきくけこ \n"), "あいうえお\nかきくけこ")
    }
}
