import XCTest
@testable import HeyDrum

@MainActor
final class PlaybackViewModelTests: XCTestCase {
    private func make() -> (PlaybackViewModel, FakeSpeechService, SpeechSessionHub, SettingsStore) {
        let speech = FakeSpeechService()
        let hub = SpeechSessionHub(speech: speech)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "heydrum.tests.\(UUID().uuidString)")!)
        return (PlaybackViewModel(hub: hub, settings: settings), speech, hub, settings)
    }

    func testBeginSpeaksWithSettingsAndEntersPreparingThenSpeaking() async {
        let (vm, speech, _, settings) = make()
        settings.masterVolume = 0.4
        settings.speechSpeed = .fast
        vm.begin(text: "本日は晴天なり")
        XCTAssertEqual(vm.state, .preparing)
        XCTAssertEqual(speech.calls.count, 1)
        XCTAssertEqual(speech.calls[0].text, "本日は晴天なり")
        XCTAssertEqual(speech.calls[0].volume, 0.4)
        XCTAssertEqual(speech.calls[0].speed, .fast)
        speech.send(.started(sessionID: speech.lastSessionID!))
        await waitUntil("speaking") { vm.state == .speaking }
    }

    // T-010
    func testPauseThenResumeCallsServiceOnceEach() async {
        let (vm, speech, _, _) = make()
        vm.begin(text: "a")
        speech.send(.started(sessionID: speech.lastSessionID!))
        await waitUntil("speaking") { vm.state == .speaking }
        vm.centerAction()
        XCTAssertEqual(vm.state, .paused)
        XCTAssertEqual(speech.pauseCount, 1)
        vm.centerAction()
        XCTAssertEqual(vm.state, .speaking)
        XCTAssertEqual(speech.resumeCount, 1)
        XCTAssertEqual(speech.calls.count, 1, "resume must not start a new session")
    }

    func testFailedPauseKeepsSpeaking() async {
        let (vm, speech, _, _) = make()
        speech.pauseResult = false
        vm.begin(text: "a")
        speech.send(.started(sessionID: speech.lastSessionID!))
        await waitUntil("speaking") { vm.state == .speaking }
        vm.centerAction()
        XCTAssertEqual(vm.state, .speaking)
    }

    // T-011
    func testStopStopsSpeechImmediatelyAndGoesIdle() async {
        let (vm, speech, _, _) = make()
        vm.begin(text: "a")
        speech.send(.started(sessionID: speech.lastSessionID!))
        await waitUntil("speaking") { vm.state == .speaking }
        vm.stop()
        XCTAssertEqual(speech.stopCount, 1)
        XCTAssertEqual(vm.state, .idle)
        XCTAssertNil(vm.sessionID)
    }

    // T-034
    func testLateCancelAndFinishAfterStopAreIgnored() async {
        let (vm, speech, _, _) = make()
        vm.begin(text: "old")
        let old = speech.lastSessionID!
        speech.send(.started(sessionID: old))
        await waitUntil("speaking") { vm.state == .speaking }
        vm.stop()
        vm.begin(text: "new")
        let new = speech.lastSessionID!
        XCTAssertNotEqual(old, new)
        speech.send(.cancelled(sessionID: old))
        speech.send(.finished(sessionID: old))
        speech.send(.range(sessionID: old, location: 0, length: 1))
        await settle()
        XCTAssertEqual(vm.state, .preparing, "stale events must not touch the new session")
        XCTAssertEqual(vm.revealedUTF16, 0, "stale range must not reveal text of the new session")
        speech.send(.started(sessionID: new))
        await waitUntil("speaking") { vm.state == .speaking }
    }

    func testCancelAfterManualStopDoesNotMoveStateToFinished() async {
        let (vm, speech, _, _) = make()
        vm.begin(text: "a")
        let id = speech.lastSessionID!
        speech.send(.started(sessionID: id))
        await waitUntil("speaking") { vm.state == .speaking }
        vm.stop()
        speech.send(.cancelled(sessionID: id))
        await settle()
        XCTAssertEqual(vm.state, .idle)
    }

    func testFinishedShowsReplayAndReplayUsesNewSessionWithSameText() async {
        let (vm, speech, _, _) = make()
        vm.begin(text: "もう一度")
        let first = speech.lastSessionID!
        speech.send(.started(sessionID: first))
        speech.send(.finished(sessionID: first))
        await waitUntil("finished") { vm.state == .finished }
        vm.centerAction()
        XCTAssertEqual(vm.state, .preparing)
        XCTAssertEqual(speech.calls.count, 2)
        XCTAssertEqual(speech.calls[1].text, "もう一度")
        XCTAssertNotEqual(speech.calls[1].sessionID, first)
    }

    func testSpeakErrorEndsInFailedAndRetryWorks() async {
        let (vm, speech, _, _) = make()
        speech.speakError = .noJapaneseVoice
        vm.begin(text: "a")
        guard case .failed = vm.state else { return XCTFail("expected failed, got \(vm.state)") }
        speech.speakError = nil
        vm.centerAction()
        XCTAssertEqual(vm.state, .preparing)
    }

    func testServiceFailureEventMovesToFailed() async {
        let (vm, speech, _, _) = make()
        vm.begin(text: "a")
        speech.send(.failed(sessionID: speech.lastSessionID!, message: "x"))
        await waitUntil("failed") { if case .failed = vm.state { true } else { false } }
    }

    func testInterruptionStopsWithoutAutoResume() async {
        let (vm, speech, _, _) = make()
        vm.begin(text: "a")
        let id = speech.lastSessionID!
        speech.send(.started(sessionID: id))
        await waitUntil("speaking") { vm.state == .speaking }
        vm.interrupt()
        XCTAssertEqual(vm.state, .finished)
        XCTAssertEqual(speech.stopCount, 1)
        speech.send(.resumed(sessionID: id))
        await settle()
        XCTAssertEqual(vm.state, .finished, "no automatic resume")
        XCTAssertEqual(speech.calls.count, 1)
    }

    func testNewBeginStopsPreviousSession() async {
        let (vm, speech, _, _) = make()
        vm.begin(text: "a")
        vm.begin(text: "b")
        XCTAssertEqual(speech.calls.count, 2)
        XCTAssertEqual(speech.stopCount, 1)
    }
}
