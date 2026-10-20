import XCTest
@testable import HeyDrum

/// Sleep replacement that only advances when the test calls `tick()`.
final class ManualTicker: @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(_ seconds: TimeInterval) async {
        await withCheckedContinuation { c in lock.lock(); waiters.append(c); lock.unlock() }
    }

    var pending: Int { lock.lock(); defer { lock.unlock() }; return waiters.count }

    func tick() {
        lock.lock(); let c = waiters.isEmpty ? nil : waiters.removeFirst(); lock.unlock()
        c?.resume()
    }
}

@MainActor
final class StartDelayTests: XCTestCase {
    private func make() -> (PlaybackViewModel, FakeSpeechService, ManualTicker, SettingsStore) {
        let speech = FakeSpeechService()
        let hub = SpeechSessionHub(speech: speech)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "heydrum.tests.\(UUID().uuidString)")!)
        let ticker = ManualTicker()
        let vm = PlaybackViewModel(hub: hub, settings: settings, sleep: { await ticker.sleep($0) })
        return (vm, speech, ticker, settings)
    }

    func testOptionsAndLabels() {
        XCTAssertEqual(StartDelay.options, [0, 3, 5, 10, 15, 30])
        XCTAssertEqual(StartDelay.label(0), "すぐ")
        XCTAssertEqual(StartDelay.label(3), "3秒後")
        XCTAssertEqual(StartDelay.normalize(7), 0)
        XCTAssertEqual(StartDelay.normalize(10), 10)
    }

    func testCountdownSpeaksOnlyAfterTheDelay() async {
        let (vm, speech, ticker, _) = make()
        vm.begin(text: "あとで", delaySeconds: 3)
        XCTAssertEqual(vm.state, .preparing)
        XCTAssertEqual(vm.countdownRemaining, 3)
        XCTAssertTrue(speech.calls.isEmpty)
        for expected in [2, 1] as [Int] {
            await waitUntil("tick waiter") { ticker.pending == 1 }
            ticker.tick()
            await waitUntil("countdown \(expected)") { vm.countdownRemaining == expected }
            XCTAssertTrue(speech.calls.isEmpty)
        }
        await waitUntil("tick waiter") { ticker.pending == 1 }
        ticker.tick()
        await waitUntil("speak") { speech.calls.count == 1 }
        XCTAssertNil(vm.countdownRemaining)
        XCTAssertEqual(speech.calls[0].text, "あとで")
    }

    func testZeroDelaySpeaksImmediately() {
        let (vm, speech, _, _) = make()
        vm.begin(text: "すぐ", delaySeconds: 0)
        XCTAssertEqual(speech.calls.count, 1)
        XCTAssertNil(vm.countdownRemaining)
    }

    func testStopDuringCountdownNeverSpeaks() async {
        let (vm, speech, ticker, _) = make()
        vm.begin(text: "止める", delaySeconds: 5)
        await waitUntil("tick waiter") { ticker.pending == 1 }
        vm.stop()
        XCTAssertNil(vm.countdownRemaining)
        XCTAssertEqual(vm.state, .idle)
        ticker.tick()                       // late tick after stop
        await settle()
        XCTAssertTrue(speech.calls.isEmpty)
        XCTAssertEqual(vm.state, .idle)
    }

    func testBackgroundDuringCountdownCancelsWithoutAutoStart() async {
        let (vm, speech, ticker, _) = make()
        vm.begin(text: "背景", delaySeconds: 3)
        await waitUntil("tick waiter") { ticker.pending == 1 }
        vm.interrupt()
        ticker.tick()
        await settle()
        XCTAssertTrue(speech.calls.isEmpty)
        XCTAssertEqual(vm.state, .finished)
        vm.centerAction()                   // explicit replay starts immediately
        XCTAssertEqual(speech.calls.count, 1)
    }

    func testNewBeginReplacesCountdown() async {
        let (vm, speech, ticker, _) = make()
        vm.begin(text: "a", delaySeconds: 10)
        await waitUntil("tick waiter") { ticker.pending == 1 }
        vm.begin(text: "b", delaySeconds: 0)
        ticker.tick()
        await settle()
        XCTAssertEqual(speech.calls.map(\.text), ["b"], "old countdown must not start a second utterance")
    }

    func testSettingPersistsAndInvalidValuesFallBackToZero() {
        let d = UserDefaults(suiteName: "heydrum.tests.\(UUID().uuidString)")!
        let a = SettingsStore(defaults: d)
        XCTAssertEqual(a.startDelaySeconds, 0)
        a.startDelaySeconds = 10
        XCTAssertEqual(SettingsStore(defaults: d).startDelaySeconds, 10)
        a.startDelaySeconds = 7
        XCTAssertEqual(a.startDelaySeconds, 0)
        d.set(99, forKey: SettingsStore.Key.startDelay)
        XCTAssertEqual(SettingsStore(defaults: d).startDelaySeconds, 0)
    }

    func testEditorPassesSelectedDelayToPlayback() async throws {
        let h = AppHarness.make()
        h.settings.startDelaySeconds = 5
        h.deps.editor.text = "五秒後"
        await h.deps.editor.start()
        XCTAssertEqual(h.deps.playback.countdownRemaining, 5)
        XCTAssertTrue(h.speech.calls.isEmpty, "nothing is spoken during the countdown")
        let saved = try await h.history.list().count
        XCTAssertEqual(saved, 1, "history is saved when the button is pressed, not after the delay")
        h.deps.coordinator.closePlayback()
        XCTAssertNil(h.deps.playback.countdownRemaining)
    }
}
