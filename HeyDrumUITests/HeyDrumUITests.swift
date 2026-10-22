import XCTest

final class HeyDrumUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["-uitest"] + extra + ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tab(_ label: String) -> XCUIElement { app.tabBars.buttons[label] }

    /// Taps the editor until the software keyboard really has focus (the simulator is occasionally slow).
    private func focusEditor() -> XCUIElement {
        let editor = app.textViews["voiceTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 8))
        for _ in 0..<4 {
            editor.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.keyboards.firstMatch.exists, "keyboard did not appear")
        return editor
    }

    private func typeIntoEditor(_ text: String) {
        focusEditor().typeText(text)
    }

    /// Waits until the reading text (accessibility label) equals `expected`; the text is revealed progressively.
    private func waitForReadingText(_ expected: String, timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) {
        let text = el("playbackText")
        let predicate = NSPredicate(format: "label == %@", expected)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: text)], timeout: timeout)
        XCTAssertEqual(result, .completed, "reading text never became the full text; last label: \(text.label)", file: file, line: line)
    }

    private func tapCard(_ id: String) {
        XCTAssertTrue(el(id).waitForExistence(timeout: 8))
        el(id).tap()
    }

    // T-001 / UI test 1
    func testHomeShowsTwoModeCardsAndBothOpen() {
        launch()
        XCTAssertTrue(app.navigationBars["ヘイドラム"].waitForExistence(timeout: 5))
        XCTAssertTrue(el("homeDrumCard").exists)
        XCTAssertTrue(el("homeVoiceCard").exists)
        XCTAssertTrue(el("adSlot").exists, "shared ad slot is reserved on launch")

        tapCard("homeDrumCard")
        XCTAssertTrue(app.navigationBars["ドラムモード"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()

        tapCard("homeVoiceCard")
        XCTAssertTrue(app.navigationBars["音声モード"].waitForExistence(timeout: 3))
    }

    // T-002
    func testDrumScreenHasExactlyTwoSoundButtons() {
        launch()
        tapCard("homeDrumCard")
        XCTAssertTrue(el("drumButton").waitForExistence(timeout: 3))
        XCTAssertTrue(el("metalButton").exists)
        let soundButtons = app.buttons.matching(NSPredicate(format: "identifier IN %@", ["drumButton", "metalButton"]))
        XCTAssertEqual(soundButtons.count, 2)
        XCTAssertEqual(app.buttons["ドラム音"].frame.height >= 52, true)
        for _ in 0..<5 { el("drumButton").tap(); el("metalButton").tap() }      // rapid taps do not crash
        XCTAssertTrue(el("drumButton").exists)
    }

    // UI test 2: T-008 / T-009 / T-011
    func testEditorPlaybackStopKeepsDraft() {
        launch()
        tapCard("homeVoiceCard")
        XCTAssertFalse(el("voiceStartButton").isEnabled, "empty input cannot start")
        typeIntoEditor("本日は晴天なり")
        XCTAssertTrue(el("voiceStartButton").isEnabled)
        el("voiceStartButton").tap()

        XCTAssertTrue(el("playbackScreen").waitForExistence(timeout: 5))
        waitForReadingText("本日は晴天なり")
        XCTAssertFalse(tab("履歴").isHittable, "tab bar is hidden behind the playback screen")
        XCTAssertTrue(el("playbackPauseButton").isHittable)
        let stop = el("playbackStopButton")
        XCTAssertGreaterThanOrEqual(stop.frame.width, 44)
        XCTAssertGreaterThanOrEqual(stop.frame.height, 44)
        // stop sits at the bottom-right, pause stays at the bottom-left
        XCTAssertGreaterThan(stop.frame.midX, app.frame.width * 0.7)
        XCTAssertLessThan(el("playbackPauseButton").frame.midX, app.frame.width * 0.3)
        XCTAssertFalse(el("playbackCenterButton").exists, "the orange centre control has been removed")

        stop.tap()
        XCTAssertTrue(app.navigationBars["音声モード"].waitForExistence(timeout: 3))
        XCTAssertFalse(el("playbackScreen").exists)
        XCTAssertEqual(app.textViews["voiceTextEditor"].value as? String, "本日は晴天なり", "draft is kept after stop")
    }

    func testPauseResumeLabelsChange() {
        launch()
        tapCard("homeVoiceCard")
        typeIntoEditor("あいうえお")
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackPauseButton").waitForExistence(timeout: 5))
        XCTAssertEqual(el("playbackPauseButton").label, "一時停止")
        el("playbackPauseButton").tap()
        XCTAssertEqual(el("playbackPauseButton").label, "再開")
        el("playbackPauseButton").tap()
        XCTAssertEqual(el("playbackPauseButton").label, "一時停止")
    }

    // UI test 3: T-012
    func testHistoryPlayThenStopReturnsToHistoryTab() {
        launch(["-uitest-history-count", "3"])
        tab("履歴").tap()
        let rows = app.buttons.matching(identifier: "historyRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 3)
        rows.element(boundBy: 2).tap()
        XCTAssertTrue(el("playbackScreen").waitForExistence(timeout: 5))
        el("playbackStopButton").tap()
        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "historyRow").count, 3, "no rows added by replay")
    }

    // T-016
    func testDeleteAllNeedsConfirmation() {
        launch(["-uitest-history-count", "2"])
        tab("履歴").tap()
        XCTAssertTrue(el("historyDeleteAll").waitForExistence(timeout: 5))
        el("historyDeleteAll").tap()
        XCTAssertTrue(app.staticTexts["履歴100件以内をすべて削除します。元に戻せません"].waitForExistence(timeout: 3), "confirmation is required")
        XCTAssertEqual(app.buttons.matching(identifier: "historyRow").count, 2, "nothing deleted before confirming")
        app.buttons.matching(identifier: "すべて削除").allElementsBoundByIndex.last!.tap()
        XCTAssertTrue(el("historyEmpty").waitForExistence(timeout: 3))
    }

    func testEmptyHistoryShowsGuidance() {
        launch()
        tab("履歴").tap()
        XCTAssertTrue(el("historyEmpty").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["履歴はまだありません"].exists)
    }

    // UI test 4
    func testHundredHistoryRowsScrollAndStayAboveAd() {
        launch(["-uitest-history-count", "100"])
        tab("履歴").tap()
        let list = el("historyList")
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for _ in 0..<6 { list.swipeUp() }
        let ad = el("adSlot")
        let lastVisible = app.buttons.matching(identifier: "historyRow").allElementsBoundByIndex.last { $0.isHittable }
        XCTAssertNotNil(lastVisible)
        XCTAssertLessThanOrEqual(lastVisible!.frame.maxY, ad.frame.minY + 1, "rows never overlap the ad slot")
    }

    // UI test 5: T-022 / T-023
    func testAdSlotHasIdenticalFrameOnEveryScreenIncludingPlayback() {
        launch()
        let baseline = el("adSlot").frame
        XCTAssertGreaterThan(baseline.height, 0)
        func assertSame(_ screen: String) {
            let f = el("adSlot").frame
            XCTAssertEqual(f.minY, baseline.minY, accuracy: 0.5, "\(screen) minY")
            XCTAssertEqual(f.height, baseline.height, accuracy: 0.5, "\(screen) height")
            XCTAssertEqual(f.maxY, baseline.maxY, accuracy: 0.5, "\(screen) maxY")
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "adSlot").count, 1, "\(screen): exactly one slot")
        }
        assertSame("home")
        tapCard("homeDrumCard"); XCTAssertTrue(el("drumButton").waitForExistence(timeout: 3)); assertSame("drum")
        app.navigationBars.buttons.firstMatch.tap()
        tapCard("homeVoiceCard"); XCTAssertTrue(el("voiceStartButton").waitForExistence(timeout: 3)); assertSame("voice editor")
        typeIntoEditor("広告位置")
        el("keyboardDismiss").tap()                                     // dismiss keyboard so the slot is back
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackScreen").waitForExistence(timeout: 5)); assertSame("playback")
        let slot = el("adSlot").frame
        XCTAssertLessThanOrEqual(el("playbackStopButton").frame.maxY, slot.minY + 0.5, "stop button does not overlap the ad")
        el("playbackStopButton").tap()
        tab("履歴").tap(); assertSame("history")
        tab("設定").tap(); assertSame("settings")
    }

    // UI test 6: T-026 (UI side)
    func testPurchasedStateHasNoAdSlotAnywhere() {
        launch(["-uitest-purchased"])
        XCTAssertTrue(el("homeDrumCard").waitForExistence(timeout: 5))
        XCTAssertFalse(el("adSlot").exists)
        tab("履歴").tap(); XCTAssertFalse(el("adSlot").exists)
        tab("設定").tap(); XCTAssertFalse(el("adSlot").exists)
        XCTAssertTrue(el("adsRemovedLabel").waitForExistence(timeout: 3))
        XCTAssertFalse(el("removeAdsButton").exists)
        XCTAssertTrue(el("restoreButton").exists, "restore stays reachable")
        tab("ホーム").tap()
        tapCard("homeVoiceCard")
        typeIntoEditor("購入済み")
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackScreen").waitForExistence(timeout: 5))
        XCTAssertFalse(el("adSlot").exists)
    }

    func testPurchaseFlowRemovesSlotFromSettings() {
        launch()
        tab("設定").tap()
        XCTAssertTrue(el("removeAdsButton").waitForExistence(timeout: 3))
        XCTAssertTrue(el("adSlot").exists)
        el("removeAdsButton").tap()
        XCTAssertTrue(el("adsRemovedLabel").waitForExistence(timeout: 3))
        XCTAssertFalse(el("adSlot").exists)
    }

    // UI test 7: T-031 / T-044-ish (large Dynamic Type + 500 chars)
    func testFiveHundredCharactersWithLargeTextKeepsControlsVisible() {
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        tapCard("homeVoiceCard")
        let editor = focusEditor()
        editor.typeText(String(repeating: "abcdefghi ", count: 50))    // 500 characters
        XCTAssertTrue(el("voiceCounter").label.contains("500"))
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackScreen").waitForExistence(timeout: 5))
        XCTAssertTrue(el("playbackPauseButton").isHittable)
        XCTAssertTrue(el("playbackStopButton").isHittable)
        let full = String(repeating: "abcdefghi ", count: 50).trimmingCharacters(in: .whitespaces)
        waitForReadingText(full, timeout: 40)
        XCTAssertLessThanOrEqual(el("playbackText").frame.maxY, el("playbackPauseButton").frame.minY + 1, "the newest text is scrolled into view above the controls")
        el("playbackText").swipeUp()           // the long text scrolls without covering the controls
        XCTAssertTrue(el("playbackPauseButton").isHittable)
        XCTAssertLessThanOrEqual(el("playbackStopButton").frame.maxY, el("adSlot").frame.minY + 0.5)
    }

    // T-040
    func testKeyboardHidesAdSlotAndItReturns() {
        launch()
        tapCard("homeVoiceCard")
        XCTAssertTrue(el("adSlot").exists)
        _ = focusEditor()
        XCTAssertFalse(el("adSlot").waitForExistence(timeout: 1), "ad slot steps aside while typing")
        el("keyboardDismiss").tap()
        XCTAssertTrue(el("adSlot").waitForExistence(timeout: 3))
    }

    func testSettingsShowsVolumeVoiceSpeedAndRestore() {
        launch()
        tab("設定").tap()
        XCTAssertTrue(el("volumeSlider").waitForExistence(timeout: 3))
        XCTAssertEqual(el("volumeSlider").value as? String, "100パーセント")
        XCTAssertTrue(el("speedPicker").exists)
        app.swipeUp()
        XCTAssertTrue(el("textScaleSlider").waitForExistence(timeout: 3), "text size slider")
        XCTAssertTrue(el("readingFontPicker").exists, "reading font picker")
        app.swipeDown()
        XCTAssertTrue(el("voicePreviewButton").exists)
        app.swipeUp()
        XCTAssertTrue(el("restoreButton").waitForExistence(timeout: 3))
    }

    // Start-delay grid
    func testDelayGridSelectionStartsCountdownAndStopCancelsIt() {
        launch()
        tapCard("homeVoiceCard")
        for seconds in [0, 3, 5, 10, 15, 30] { XCTAssertTrue(el("delay-\(seconds)").exists, "grid has \(seconds)") }
        el("delay-5").tap()
        XCTAssertTrue(el("voiceStartButton").label.contains("5秒後"))
        typeIntoEditor("遠くの人へ")
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        let pause = el("playbackPauseButton")
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        XCTAssertFalse(pause.isEnabled, "pause stays disabled during the countdown")
        XCTAssertTrue(el("playbackCountdownSeconds").waitForExistence(timeout: 3), "small seconds counter at the bottom")
        XCTAssertTrue(el("playbackCountdownSeconds").label.hasPrefix("あと"), el("playbackCountdownSeconds").label)
        el("playbackStopButton").tap()
        XCTAssertTrue(app.navigationBars["音声モード"].waitForExistence(timeout: 3))
        XCTAssertTrue(el("delay-5").isSelected, "selection is kept")
    }

    func testReadingTextGrowsWithDynamicType() {
        func textHeight(_ extra: [String]) -> CGFloat {
            app.terminate()
            launch(extra)
            tapCard("homeVoiceCard")
            typeIntoEditor("本日は晴天なり")
            el("keyboardDismiss").tap()
            el("voiceStartButton").tap()
            XCTAssertTrue(el("playbackText").waitForExistence(timeout: 5))
            waitForReadingText("本日は晴天なり")
            return el("playbackText").frame.height
        }
        let normal = textHeight([])
        let large = textHeight(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        XCTAssertGreaterThan(large, normal * 1.2, "reading text follows the Dynamic Type setting (\(normal) → \(large))")
    }

    func testReadingTextIsLarge() {
        launch()
        tapCard("homeVoiceCard")
        typeIntoEditor("本日は晴天なり")
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackText").waitForExistence(timeout: 5))
        waitForReadingText("本日は晴天なり")
        XCTAssertGreaterThanOrEqual(el("playbackText").frame.height, 80, "short text is rendered in a very large font")
    }

    // Owner spec: text appears with the speech instead of being shown in full up front.
    func testReadingTextIsRevealedProgressivelyAndNeverRewinds() {
        launch()
        tapCard("homeVoiceCard")
        let sentence = "本日は晴天なり。ご来店いただき、まことにありがとうございます。"
        typeIntoEditor(sentence)
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackText").waitForExistence(timeout: 5))
        var labels: [String] = []
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let l = el("playbackText").label
            if labels.last != l { labels.append(l) }
            if l == sentence { break }
            Thread.sleep(forTimeInterval: 0.15)
        }
        XCTAssertEqual(labels.last, sentence, "ends with the full text; labels: \(labels)")
        XCTAssertGreaterThanOrEqual(labels.count, 3, "text grew in several steps, not all at once: \(labels)")
        XCTAssertTrue(labels.first == "読み上げ待機中" || sentence.hasPrefix(labels.first!) && labels.first! != sentence, "the full text was not shown up front: \(labels)")
        let shown = labels.filter { $0 != "読み上げ待機中" }
        for (a, b) in zip(shown, shown.dropFirst()) {
            XCTAssertTrue(b.hasPrefix(a) && b.count > a.count, "monotonic growth: '\(a)' → '\(b)'")
        }
    }

    func testRevealPausesWithPauseAndContinuesOnResume() {
        launch()
        tapCard("homeVoiceCard")
        typeIntoEditor("あいうえおかきくけこさしすせそたちつてとなにぬねの")
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackPauseButton").waitForExistence(timeout: 5))
        let start = Date()
        while el("playbackText").label == "読み上げ待機中", Date().timeIntervalSince(start) < 8 { Thread.sleep(forTimeInterval: 0.1) }
        el("playbackPauseButton").tap()                       // pause
        XCTAssertEqual(el("playbackPauseButton").label, "再開")
        Thread.sleep(forTimeInterval: 0.5)                     // let any in-flight range settle
        let frozen = el("playbackText").label
        Thread.sleep(forTimeInterval: 1.6)
        XCTAssertEqual(el("playbackText").label, frozen, "display does not advance while paused")
        el("playbackPauseButton").tap()                       // resume
        let resumeStart = Date()
        while el("playbackText").label == frozen, Date().timeIntervalSince(resumeStart) < 6 { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertNotEqual(el("playbackText").label, frozen, "display continues after resume")
    }

    func testNoTextShownDuringCountdown() {
        launch()
        tapCard("homeVoiceCard")
        el("delay-5").tap()
        typeIntoEditor("先に見えてはいけない文章")
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackText").waitForExistence(timeout: 5))
        XCTAssertTrue(el("playbackCountdownSeconds").label.hasPrefix("あと"))
        XCTAssertFalse(el("playbackPauseButton").isEnabled)
        XCTAssertEqual(el("playbackText").label, "読み上げ待機中", "no part of the text is visible while counting down")
    }

    // Launch greeting
    func testLaunchGreetingShowsDoramuThenGoesHome() {
        launch(["-uitest-greeting"])
        XCTAssertTrue(el("playbackScreen").waitForExistence(timeout: 10), "greeting screen appears at launch")
        waitForReadingText("ドラム", timeout: 8)
        XCTAssertFalse(el("playbackPauseButton").exists, "no pause/resume controls on the greeting")
        XCTAssertTrue(el("homeDrumCard").waitForExistence(timeout: 20), "the greeting closes by itself and shows Home")
    }

    func testTappingTheGreetingSkipsIt() {
        launch(["-uitest-greeting"])
        XCTAssertTrue(el("playbackScreen").waitForExistence(timeout: 10))
        el("playbackScreen").tap()
        XCTAssertTrue(el("homeDrumCard").waitForExistence(timeout: 5))
    }

    // Bottom-left pause button: same size as stop, mirrored, toggles pause/resume.
    func testLeftPauseButtonMirrorsStopAndToggles() {
        launch()
        tapCard("homeVoiceCard")
        typeIntoEditor("あいうえおかきくけこさしすせそ")
        el("keyboardDismiss").tap()
        el("voiceStartButton").tap()
        XCTAssertTrue(el("playbackPauseButton").waitForExistence(timeout: 5))
        let pause = el("playbackPauseButton"), stop = el("playbackStopButton")
        XCTAssertEqual(pause.frame.width, stop.frame.width, accuracy: 1, "same width as the stop button")
        XCTAssertEqual(pause.frame.height, stop.frame.height, accuracy: 1, "same height as the stop button")
        XCTAssertEqual(pause.frame.midY, stop.frame.midY, accuracy: 2, "same row")
        XCTAssertLessThan(pause.frame.midX, app.frame.width * 0.3, "bottom-left")
        XCTAssertGreaterThanOrEqual(pause.frame.width, 44)
        let start = Date()
        while pause.label != "一時停止", Date().timeIntervalSince(start) < 6 { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertEqual(pause.label, "一時停止")
        pause.tap()
        XCTAssertEqual(el("playbackPauseButton").label, "再開")
        XCTAssertFalse(el("playbackCenterButton").exists, "pause is controlled only from the bottom-left")
        el("playbackPauseButton").tap()
        XCTAssertEqual(el("playbackPauseButton").label, "一時停止")
    }

    func testTextSizeSliderEnlargesTheReadingText() {
        func readingHeight(slider: CGFloat?) -> CGFloat {
            app.terminate()
            launch()
            if let slider {
                app.tabBars.buttons["設定"].tap()
                app.swipeUp()
                XCTAssertTrue(el("textScaleSlider").waitForExistence(timeout: 5))
                el("textScaleSlider").adjust(toNormalizedSliderPosition: slider)
                app.tabBars.buttons["ホーム"].tap()
            }
            tapCard("homeVoiceCard")
            typeIntoEditor("本日は晴天なり")
            el("keyboardDismiss").tap()
            el("voiceStartButton").tap()
            XCTAssertTrue(el("playbackText").waitForExistence(timeout: 5))
            waitForReadingText("本日は晴天なり")
            return el("playbackText").frame.height
        }
        let standard = readingHeight(slider: nil)
        let big = readingHeight(slider: 1.0)
        XCTAssertGreaterThan(big, standard * 1.8, "slider at max makes the text much larger (\(standard) → \(big))")
    }
}
