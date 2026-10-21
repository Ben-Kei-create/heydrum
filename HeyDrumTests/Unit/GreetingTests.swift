import XCTest
@testable import HeyDrum

/// Launch greeting: "ドラム" in Eddy's voice, text shown as it is spoken (owner request 2026-10-22).
@MainActor
final class GreetingTests: XCTestCase {
    private let eddy = SpeechVoiceOption(id: "com.apple.eloquence.ja-JP.Eddy", displayName: "Eddy")
    private let kyoko = SpeechVoiceOption(id: "kyoko", displayName: "Kyoko")

    func testVoiceIsMatchedByNameNotGuessedIdentifier() {
        XCTAssertEqual(GreetingVoice.identifier(in: [kyoko, eddy]), eddy.id)
        XCTAssertEqual(GreetingVoice.identifier(in: [SpeechVoiceOption(id: "x", displayName: "Eddy（日本語（日本））")]), "x")
        XCTAssertEqual(GreetingVoice.identifier(in: [SpeechVoiceOption(id: "y", displayName: "Eddy (Japanese)")]), "y")
        XCTAssertNil(GreetingVoice.identifier(in: [kyoko, SpeechVoiceOption(id: "z", displayName: "Eddyson")]))
        XCTAssertNil(GreetingVoice.identifier(in: []))
        XCTAssertEqual(GreetingVoice.text, "ドラム")
    }

    func testGreetingSpeaksDoramuWithEddyAtTheSettingsVolumeAndSavesNoHistory() async throws {
        let h = AppHarness.make()
        h.settings.preferredVoiceID = "user.chosen.voice"        // the greeting ignores the user's voice
        h.deps.coordinator.startGreeting(voices: [kyoko, eddy])
        XCTAssertEqual(h.deps.coordinator.request?.source, .greeting)
        XCTAssertEqual(h.speech.calls.count, 1)
        XCTAssertEqual(h.speech.calls[0].text, "ドラム")
        XCTAssertEqual(h.speech.calls[0].voiceID, eddy.id)
        XCTAssertEqual(h.speech.calls[0].volume, 1.0, "default volume is the maximum")
        let saved = try await h.history.list().count
        XCTAssertEqual(saved, 0)
    }

    func testNormalPlaybackAfterTheGreetingUsesTheUsersVoiceAgain() async {
        let h = AppHarness.make()
        h.settings.preferredVoiceID = "user.chosen.voice"
        h.deps.coordinator.startGreeting(voices: [eddy])
        h.deps.coordinator.closePlayback()
        h.deps.coordinator.openPlayback(text: "通常", source: .editor)
        XCTAssertEqual(h.speech.calls.last?.voiceID, "user.chosen.voice")
    }

    func testWithoutEddyTheDefaultJapaneseVoiceIsUsed() {
        let h = AppHarness.make()
        h.deps.coordinator.startGreeting(voices: [kyoko])
        XCTAssertNil(h.speech.calls.first?.voiceID, "nil → AVSpeechSynthesisVoice(language: ja-JP) in the real service")
    }

    func testTextAppearsWithTheVoiceNotBefore() async {
        let h = AppHarness.make()
        h.deps.coordinator.startGreeting(voices: [eddy])
        XCTAssertEqual(h.deps.playback.visibleText, "")
        let id = h.speech.lastSessionID!
        h.speech.send(.started(sessionID: id))
        await waitUntil("speaking") { h.deps.playback.state == .speaking }
        XCTAssertEqual(h.deps.playback.visibleText, "")
        h.speech.send(.range(sessionID: id, location: 0, length: 3))
        await waitUntil("revealed") { h.deps.playback.visibleText == "ドラム" }
    }

    func testGreetingClosesItselfAfterTheVoiceEnds() async {
        let h = AppHarness.make()
        h.deps.coordinator.startGreeting(voices: [eddy], hold: 0.05)
        let id = h.speech.lastSessionID!
        h.speech.send(.started(sessionID: id))
        h.speech.send(.range(sessionID: id, location: 0, length: 3))
        h.speech.send(.finished(sessionID: id))
        await waitUntil("text kept") { h.deps.playback.visibleText == "ドラム" }
        XCTAssertTrue(h.deps.coordinator.isPlaybackVisible, "the word stays visible for a moment")
        await waitUntil("closed") { !h.deps.coordinator.isPlaybackVisible }
        XCTAssertEqual(h.deps.coordinator.selectedTab, .home)
    }

    func testStopOrTapSkipsTheGreetingAndLateEventsDoNothing() async {
        let h = AppHarness.make()
        h.deps.coordinator.startGreeting(voices: [eddy], hold: 0.05)
        let id = h.speech.lastSessionID!
        h.deps.coordinator.closePlayback()
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
        XCTAssertEqual(h.speech.stopCount, 1)
        h.speech.send(.finished(sessionID: id))
        await settle()
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
        XCTAssertEqual(h.deps.playback.state, .idle)
    }

    func testFailureOrMissingVoiceNeverTrapsTheUserOnTheGreeting() async {
        let h = AppHarness.make()
        h.speech.speakError = .noJapaneseVoice
        h.deps.coordinator.startGreeting(voices: [], hold: 0.05)
        await waitUntil("closed after failure") { !h.deps.coordinator.isPlaybackVisible }
    }

    func testSafetyNetClosesAGreetingThatNeverEnds() async {
        let h = AppHarness.make()
        h.deps.coordinator.startGreeting(voices: [eddy], hold: 0.05, maxDuration: 0.15)
        await waitUntil("closed by safety net") { !h.deps.coordinator.isPlaybackVisible }
    }

    func testGreetingDoesNotInterruptAnExistingPlayback() {
        let h = AppHarness.make()
        h.deps.coordinator.openPlayback(text: "既に再生中", source: .editor)
        h.deps.coordinator.startGreeting(voices: [eddy])
        XCTAssertEqual(h.deps.coordinator.request?.source, .editor)
        XCTAssertEqual(h.speech.calls.count, 1)
    }

    func testBackgroundDuringGreetingStopsItWithoutResuming() async {
        let h = AppHarness.make()
        h.deps.coordinator.startGreeting(voices: [eddy])
        let id = h.speech.lastSessionID!
        h.speech.send(.started(sessionID: id))
        await waitUntil("speaking") { h.deps.playback.state == .speaking }
        h.deps.coordinator.handleInterruption()
        XCTAssertEqual(h.deps.playback.state, .finished)
        XCTAssertEqual(h.speech.calls.count, 1)
    }
}
