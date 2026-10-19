import XCTest
@testable import HeyDrum

@MainActor
final class CoordinatorAndHistoryFlowTests: XCTestCase {
    private func entries(_ n: Int) -> [HistoryEntry] {
        (0..<n).map { i in
            HistoryEntry(id: UUID(), text: "履歴\(i)", createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)),
                         lastPlayedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)))
        }
    }

    // T-012
    func testHistoryPlaybackThenStopReturnsToHistoryTabCountUnchanged() async throws {
        let seeded = entries(3)
        let h = AppHarness.make(items: seeded)
        await h.deps.history.reload()
        let target = seeded[0]                                   // oldest row
        await h.deps.history.play(target)
        XCTAssertEqual(h.deps.coordinator.request?.source, .history(id: target.id))
        XCTAssertEqual(h.speech.calls.last?.text, target.text)
        XCTAssertEqual(h.deps.history.entries.first?.id, target.id, "replayed row moves to the top")
        XCTAssertEqual(h.deps.history.entries.count, 3)

        h.deps.coordinator.selectedTab = .settings              // simulate being elsewhere; stop must go to History
        h.deps.coordinator.closePlayback()
        XCTAssertEqual(h.deps.coordinator.selectedTab, .history)
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
        XCTAssertEqual(h.speech.stopCount, 1)
        let list = try await h.history.list()
        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(Set(list.map(\.id)), Set(seeded.map(\.id)), "IDs unchanged")
    }

    func testStopFromEditorReturnsToHomeAndKeepsDraft() async {
        let h = AppHarness.make()
        h.deps.editor.text = "下書き"
        await h.deps.editor.start()
        h.deps.coordinator.closePlayback()
        XCTAssertEqual(h.deps.coordinator.selectedTab, .home)
        XCTAssertEqual(h.deps.editor.text, "下書き")
    }

    func testClosePlaybackIsIdempotentAndOpenIsGuardedAgainstDoubleTap() async {
        let h = AppHarness.make()
        h.deps.coordinator.openPlayback(text: "a", source: .editor)
        h.deps.coordinator.openPlayback(text: "b", source: .editor)        // ignored
        XCTAssertEqual(h.speech.calls.count, 1)
        h.deps.coordinator.closePlayback()
        h.deps.coordinator.closePlayback()                                  // no double pop
        XCTAssertEqual(h.speech.stopCount, 1)
    }

    func testPlayFromHistoryFailsWithoutNavigatingWhenWriteFails() async {
        let h = AppHarness.make(items: entries(2))
        await h.deps.history.reload()
        await h.history.setFailWrites(true)
        await h.deps.history.play(h.deps.history.entries[0])
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
        XCTAssertNotNil(h.deps.history.message)
        XCTAssertTrue(h.speech.calls.isEmpty)
    }

    func testCorruptHistoryExposesProblemAndRefusesSaves() async throws {
        let store = MemoryHistoryStore(data: Data("junk".utf8))
        let vm = HistoryViewModel(repository: JSONHistoryRepository(store: store))
        await vm.reload()
        XCTAssertEqual(vm.loadProblem, .corrupt)
        do { _ = try await vm.addNew(text: "x"); XCTFail("must not save") } catch {}
        XCTAssertEqual(store.current, Data("junk".utf8))
        await vm.resetCorruptStore()
        XCTAssertNil(vm.loadProblem)
        XCTAssertEqual(store.quarantined.count, 1)
    }

    func testDeleteAndDeleteAll() async {
        let h = AppHarness.make(items: entries(3))
        await h.deps.history.reload()
        await h.deps.history.delete(h.deps.history.entries[0])
        XCTAssertEqual(h.deps.history.entries.count, 2)
        await h.deps.history.deleteAll()
        XCTAssertTrue(h.deps.history.entries.isEmpty)
    }

    func testBackgroundDuringPlaybackStopsWithoutAutoResume() async {
        let h = AppHarness.make()
        h.deps.coordinator.openPlayback(text: "a", source: .editor)
        h.speech.send(.started(sessionID: h.speech.lastSessionID!))
        await waitUntil("speaking") { h.deps.playback.state == .speaking }
        h.deps.coordinator.handleInterruption()
        XCTAssertEqual(h.deps.playback.state, .finished)
        XCTAssertTrue(h.deps.coordinator.isPlaybackVisible, "screen stays; only explicit replay restarts")
        XCTAssertEqual(h.speech.calls.count, 1)
        XCTAssertGreaterThanOrEqual(h.sound.stopAllCount, 1)
    }

    func testVoicePreviewIsStoppedAndNeverCreatesHistory() async throws {
        let h = AppHarness.make()
        h.deps.preview.play()
        XCTAssertEqual(h.speech.calls.last?.text, VoicePreviewController.sampleText)
        h.deps.preview.stop()
        XCTAssertEqual(h.speech.stopCount, 1)
        let count = try await h.history.list().count
        XCTAssertEqual(count, 0)
    }
}
