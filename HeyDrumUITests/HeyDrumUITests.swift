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
        XCTAssertEqual(el("playbackText").label, "本日は晴天なり")
        XCTAssertFalse(tab("履歴").isHittable, "tab bar is hidden behind the playback screen")
        XCTAssertTrue(el("playbackCenterButton").isHittable)
        let stop = el("playbackStopButton")
        XCTAssertGreaterThanOrEqual(stop.frame.width, 44)
        XCTAssertGreaterThanOrEqual(stop.frame.height, 44)
        // stop sits at the bottom-right, centre control is centred
        XCTAssertGreaterThan(stop.frame.midX, app.frame.width * 0.7)
        XCTAssertEqual(el("playbackCenterButton").frame.midX, app.frame.midX, accuracy: 4)

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
        XCTAssertTrue(el("playbackCenterButton").waitForExistence(timeout: 5))
        XCTAssertEqual(el("playbackCenterButton").label, "一時停止")
        el("playbackCenterButton").tap()
        XCTAssertEqual(el("playbackCenterButton").label, "再開")
        el("playbackCenterButton").tap()
        XCTAssertEqual(el("playbackCenterButton").label, "一時停止")
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
        XCTAssertTrue(el("playbackCenterButton").isHittable)
        XCTAssertTrue(el("playbackStopButton").isHittable)
        el("playbackText").swipeUp()           // the long text scrolls without covering the controls
        XCTAssertTrue(el("playbackCenterButton").isHittable)
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
        XCTAssertEqual(el("volumeSlider").value as? String, "70パーセント")
        XCTAssertTrue(el("speedPicker").exists)
        XCTAssertTrue(el("voicePreviewButton").exists)
        app.swipeUp()
        XCTAssertTrue(el("restoreButton").waitForExistence(timeout: 3))
    }
}
