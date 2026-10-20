import XCTest
@testable import HeyDrum

/// Owner spec 2026-10-20: the reading text is revealed cumulatively from the speech range notifications.
@MainActor
final class PlaybackRevealTests: XCTestCase {
    private struct Rig {
        let vm: PlaybackViewModel
        let speech: FakeSpeechService
        let ticker: ManualTicker
    }

    private func make() -> Rig {
        let speech = FakeSpeechService()
        let hub = SpeechSessionHub(speech: speech)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "heydrum.tests.\(UUID().uuidString)")!)
        let ticker = ManualTicker()
        let vm = PlaybackViewModel(hub: hub, settings: settings, sleep: { await ticker.sleep($0) })
        return Rig(vm: vm, speech: speech, ticker: ticker)
    }

    private func startSpeaking(_ r: Rig, _ text: String) async -> UUID {
        r.vm.begin(text: text)
        let id = r.speech.lastSessionID!
        r.speech.send(.started(sessionID: id))
        await waitUntil("speaking") { r.vm.state == .speaking }
        return id
    }

    private func range(_ r: Rig, _ id: UUID, _ loc: Int, _ len: Int) { r.speech.send(.range(sessionID: id, location: loc, length: len)) }

    func testNothingIsShownBeforeSpeechAndBeforeTheFirstRange() async {
        let r = make()
        r.vm.begin(text: "本日は晴天なり")
        XCTAssertEqual(r.vm.visibleText, "", "preparing: no text")
        r.speech.send(.started(sessionID: r.speech.lastSessionID!))
        await waitUntil("speaking") { r.vm.state == .speaking }
        XCTAssertEqual(r.vm.visibleText, "", "started but nothing announced yet")
    }

    func testCountdownShowsNoText() async {
        let r = make()
        r.vm.begin(text: "秘密の文章", delaySeconds: 3)
        XCTAssertEqual(r.vm.visibleText, "")
        XCTAssertEqual(r.vm.countdownRemaining, 3)
    }

    func testRangesAccumulateTheTextFromTheBeginning() async {
        let r = make()
        let id = await startSpeaking(r, "本日は晴天なり。")
        range(r, id, 0, 2)                              // 本日
        await waitUntil("2") { r.vm.visibleText == "本日" }
        range(r, id, 2, 1)                              // は
        await waitUntil("3") { r.vm.visibleText == "本日は" }
        range(r, id, 3, 4)                              // 晴天なり
        await waitUntil("7") { r.vm.visibleText == "本日は晴天なり" }
        XCTAssertFalse(r.vm.visibleText.contains("。"), "not yet announced")
    }

    func testOverlappingBackwardAndRepeatedRangesNeverRewindTheDisplay() async {
        let r = make()
        let id = await startSpeaking(r, "あいうえおかきくけこ")
        range(r, id, 0, 6)
        await waitUntil("6") { r.vm.revealedUTF16 == 6 }
        range(r, id, 2, 2)                              // earlier / smaller end
        range(r, id, 0, 3)
        range(r, id, 4, 2)                              // same end
        await settle()
        XCTAssertEqual(r.vm.revealedUTF16, 6, "display only moves forward")
        range(r, id, 4, 4)                              // overlapping, larger end
        await waitUntil("8") { r.vm.revealedUTF16 == 8 }
    }

    func testRangeBeforeStartedAndInvalidRangesAreIgnored() async {
        let r = make()
        r.vm.begin(text: "あいう")
        let id = r.speech.lastSessionID!
        range(r, id, 0, 2)                              // still preparing
        await settle()
        XCTAssertEqual(r.vm.revealedUTF16, 0)
        r.speech.send(.started(sessionID: id))
        await waitUntil("speaking") { r.vm.state == .speaking }
        for (loc, len) in [(-1, 2), (0, -1), (9, 1), (1, 99), (0, Int.max), (Int.max, 1)] { range(r, id, loc, len) }
        await settle()
        XCTAssertEqual(r.vm.visibleText, "")
        range(r, id, 0, 1)
        await waitUntil("valid after invalid") { r.vm.visibleText == "あ" }
    }

    func testStaleSessionRangesAreIgnored() async {
        let r = make()
        let old = await startSpeaking(r, "古い文章です")
        r.vm.stop()
        r.vm.begin(text: "新しい文章です")
        let new = r.speech.lastSessionID!
        r.speech.send(.started(sessionID: new))
        await waitUntil("speaking") { r.vm.state == .speaking }
        range(r, old, 0, 6)
        await settle()
        XCTAssertEqual(r.vm.visibleText, "", "old session cannot reveal the new text")
        range(r, new, 0, 3)
        await waitUntil("new") { r.vm.visibleText == "新しい" }
    }

    func testPauseFreezesTheDisplayAndResumeContinues() async {
        let r = make()
        let id = await startSpeaking(r, "あいうえおかきくけこ")
        range(r, id, 0, 3)
        await waitUntil("3") { r.vm.revealedUTF16 == 3 }
        r.vm.centerAction()                             // pause
        XCTAssertEqual(r.vm.state, .paused)
        range(r, id, 3, 3)                              // late notification while paused
        await settle()
        XCTAssertEqual(r.vm.revealedUTF16, 3, "frozen while paused")
        r.vm.centerAction()                             // resume
        XCTAssertEqual(r.vm.state, .speaking)
        range(r, id, 3, 3)
        await waitUntil("6") { r.vm.revealedUTF16 == 6 }
    }

    func testNaturalFinishShowsTheFullTextIncludingTrailingPunctuation() async {
        let r = make()
        let text = "お疲れさまでした。"
        let id = await startSpeaking(r, text)
        range(r, id, 0, 4)
        await waitUntil("4") { r.vm.revealedUTF16 == 4 }
        r.speech.send(.finished(sessionID: id))
        await waitUntil("finished") { r.vm.state == .finished }
        XCTAssertEqual(r.vm.visibleText, text)
    }

    func testSystemCancelAndInterruptDoNotRevealUnreadText() async {
        let r = make()
        let text = "あいうえおかきくけこ"
        let id = await startSpeaking(r, text)
        range(r, id, 0, 4)
        await waitUntil("4") { r.vm.revealedUTF16 == 4 }
        r.speech.send(.cancelled(sessionID: id))
        await waitUntil("finished") { r.vm.state == .finished }
        XCTAssertEqual(r.vm.visibleText, "あいうえ")

        let r2 = make()
        let id2 = await startSpeaking(r2, text)
        range(r2, id2, 0, 3)
        await waitUntil("3") { r2.vm.revealedUTF16 == 3 }
        r2.vm.interrupt()
        XCTAssertEqual(r2.vm.state, .finished)
        XCTAssertEqual(r2.vm.visibleText, "あいう", "background/interruption keeps the partial text")
        r2.ticker.tick()
        await settle()
        XCTAssertEqual(r2.vm.visibleText, "あいう", "the fallback timer must not publish the rest either")
    }

    func testManualStopHidesEverythingAndLateEventsDoNothing() async {
        let r = make()
        let id = await startSpeaking(r, "あいうえお")
        range(r, id, 0, 2)
        await waitUntil("2") { r.vm.revealedUTF16 == 2 }
        r.vm.stop()
        XCTAssertEqual(r.vm.visibleText, "")
        range(r, id, 2, 3)
        r.speech.send(.finished(sessionID: id))
        await settle()
        XCTAssertEqual(r.vm.visibleText, "")
        XCTAssertEqual(r.vm.state, .idle)
    }

    func testReplayRetryAndNewSessionsResetTheDisplay() async {
        let r = make()
        let text = "もう一度読みます"
        let id = await startSpeaking(r, text)
        r.speech.send(.finished(sessionID: id))
        await waitUntil("finished") { r.vm.state == .finished }
        XCTAssertEqual(r.vm.visibleText, text)
        r.vm.centerAction()                             // replay
        XCTAssertEqual(r.vm.visibleText, "", "replay starts from an empty display")
        XCTAssertEqual(r.vm.state, .preparing)

        let r2 = make()
        r2.speech.speakError = .noJapaneseVoice
        r2.vm.begin(text: "失敗")
        r2.speech.speakError = nil
        r2.vm.centerAction()                            // retry
        XCTAssertEqual(r2.vm.visibleText, "")
        r2.vm.begin(text: "別の文")                      // new session
        XCTAssertEqual(r2.vm.visibleText, "")
    }

    func testEmojiCombiningMarksAndNewlinesNeverCrashOrLoseCharacters() async {
        let r = make()
        let text = "こんにちは😀。\nあいうえお👨‍👩‍👧‍👦東京2026年e\u{301}終"
        let id = await startSpeaking(r, text)
        let emoji = (text as NSString).range(of: "😀").location
        range(r, id, emoji + 1, 1)                      // mid-surrogate notification
        await waitUntil("emoji whole") { r.vm.visibleText.hasSuffix("😀") }
        XCTAssertTrue(text.hasPrefix(r.vm.visibleText))
        let family = (text as NSString).range(of: "👨‍👩‍👧‍👦").location
        range(r, id, family + 3, 2)                     // inside the ZWJ sequence
        await waitUntil("family whole") { r.vm.visibleText.hasSuffix("👨‍👩‍👧‍👦") }
        r.speech.send(.finished(sessionID: id))
        await waitUntil("full") { r.vm.visibleText == text }
    }

    // No range notifications on a system: after the fallback delay the whole text is shown at once (no progress).
    func testWithoutAnyRangeNotificationsTheFullTextAppearsAfterTheFallbackDelay() async {
        let r = make()
        _ = await startSpeaking(r, "通知が来ない環境")
        await waitUntil("fallback waiter") { r.ticker.pending == 1 }
        XCTAssertEqual(r.vm.visibleText, "")
        r.ticker.tick()
        await waitUntil("fallback") { r.vm.visibleText == "通知が来ない環境" }
    }

    func testFallbackDoesNothingOnceRangesArrive() async {
        let r = make()
        let id = await startSpeaking(r, "あいうえお")
        await waitUntil("fallback waiter") { r.ticker.pending == 1 }
        range(r, id, 0, 2)
        await waitUntil("2") { r.vm.revealedUTF16 == 2 }
        r.ticker.tick()
        await settle()
        XCTAssertEqual(r.vm.visibleText, "あい", "progress display is kept; fallback is only for silent engines")
    }
}
