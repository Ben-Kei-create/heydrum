import XCTest

/// Produces the App Store screenshots. Not part of the normal regression run:
/// TEST_RUNNER_SHOT_DIR=/path xcodebuild ... -only-testing:HeyDrumUITests/ScreenshotTests test
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var dir: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? "" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(dir.isEmpty, "SHOT_DIR not set")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        app = XCUIApplication()
    }

    private func start(_ extra: [String] = []) {
        app.launchArguments = ["-uitest", "-uitest-purchased", "-uitest-history-sample"] + extra + ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
    }

    private func el(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func testCaptureAll() {
        start()
        XCTAssertTrue(el("homeDrumCard").waitForExistence(timeout: 10))
        shot("01-home")

        el("homeDrumCard").tap()
        XCTAssertTrue(el("drumButton").waitForExistence(timeout: 5))
        shot("02-drum")
        app.navigationBars.buttons.firstMatch.tap()

        el("homeVoiceCard").tap()
        let editor = app.textViews["voiceTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("本日は晴天なり")
        el("delay-5").tap()
        el("keyboardDismiss").tap()
        shot("03-voice")

        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackPauseButton").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.2)
        shot("04-countdown")
        Thread.sleep(forTimeInterval: 5)
        shot("05-reading")
        el("playbackStopButton").tap()

        app.tabBars.buttons["履歴"].tap()
        XCTAssertTrue(el("historyList").waitForExistence(timeout: 5))
        shot("06-history")

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(el("volumeSlider").waitForExistence(timeout: 5))
        shot("07-settings")
    }

    /// App Review screenshot for the in-app purchase (free state with the purchase row visible).
    func testCaptureIAPReview() {
        app.launchArguments = ["-uitest", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(el("removeAdsButton").waitForExistence(timeout: 5))
        shot("iap-review-settings")
    }

    /// Paced walkthrough (~25 s) recorded externally with `simctl io recordVideo` for the App Preview.
    func testPreviewFlow() {
        func pause(_ s: TimeInterval) { Thread.sleep(forTimeInterval: s) }
        start(["-uitest-chunk-interval", "0.8"])
        XCTAssertTrue(el("homeDrumCard").waitForExistence(timeout: 10))
        pause(2)
        el("homeDrumCard").tap(); pause(1.2)
        el("drumButton").tap(); pause(0.7)
        el("metalButton").tap(); pause(0.7)
        el("drumButton").tap(); pause(1.0)
        app.navigationBars.buttons.firstMatch.tap(); pause(0.8)
        el("homeVoiceCard").tap(); pause(1.0)
        let editor = app.textViews["voiceTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("本日は晴天なり"); pause(1.0)
        el("delay-3").tap(); pause(0.8)
        el("keyboardDismiss").tap(); pause(1.2)
        el("voiceStartButton").tap()
        pause(3.8)                                   // countdown 3-2-1
        pause(6.0)                                   // reading screen (text appears step by step)
        el("playbackStopButton").tap(); pause(1.2)
        app.tabBars.buttons["履歴"].tap(); pause(2.2)
        app.tabBars.buttons["設定"].tap(); pause(2.5)
    }

    /// Step-by-step evidence of the cumulative reveal (shots every ~0.9 s).
    func testRevealSequence() {
        start(["-uitest-chunk-interval", "0.9"])
        XCTAssertTrue(el("homeVoiceCard").waitForExistence(timeout: 10))
        el("homeVoiceCard").tap()
        let editor = app.textViews["voiceTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("本日は晴天なり。ご来店いただき、まことにありがとうございます。")
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        _ = el("playbackText").waitForExistence(timeout: 5)
        for i in 1...8 {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/reveal-0\(i).png"))
            Thread.sleep(forTimeInterval: 0.9)
        }
    }

    func testLongTextSequence() {
        start()
        XCTAssertTrue(el("homeVoiceCard").waitForExistence(timeout: 10))
        el("homeVoiceCard").tap()
        let editor = app.textViews["voiceTextEditor"]
        editor.tap()
        editor.typeText(String(repeating: "本日は晴天なり。ご来店ありがとうございます。", count: 8))
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        _ = el("playbackText").waitForExistence(timeout: 5)
        for i in 1...4 { Thread.sleep(forTimeInterval: 1.4); shot("long-0\(i)") }
    }

    /// Evidence for the launch greeting: "ドラム" appears with the voice, no controls.
    func testGreetingShot() {
        app.launchArguments = ["-uitest", "-uitest-greeting", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(el("playbackScreen").waitForExistence(timeout: 10))
        let predicate = NSPredicate(format: "label == %@", "ドラム")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: el("playbackText"))], timeout: 8)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/greeting.png"))
    }

    /// The reading screen in every selectable font (same text, same size).
    func testFontSamples() {
        for font in ["system", "mplus1", "kosugiMaru", "lubrifont"] {
            app = XCUIApplication()
            app.launchArguments = ["-uitest", "-uitest-purchased", "-uitest-reading-font", font, "-uitest-chunk-interval", "0.15", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
            app.launch()
            XCTAssertTrue(el("homeVoiceCard").waitForExistence(timeout: 10))
            el("homeVoiceCard").tap()
            let editor = app.textViews["voiceTextEditor"]
            XCTAssertTrue(editor.waitForExistence(timeout: 5))
            editor.tap()
            editor.typeText("本日は晴天なり。一時停止、ドラム")
            el("keyboardDismiss").tap()
            el("voiceStartButton").tap()
            let predicate = NSPredicate(format: "label == %@", "本日は晴天なり。一時停止、ドラム")
            _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: el("playbackText"))], timeout: 15)
            Thread.sleep(forTimeInterval: 0.5)
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/font-\(font).png"))
            app.terminate()
        }
    }
}
