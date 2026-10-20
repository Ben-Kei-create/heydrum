import XCTest
@testable import HeyDrum

@MainActor
final class VoiceEditorViewModelTests: XCTestCase {
    // T-006
    func testCannotStartWithBlankInputAndNothingIsSaved() async {
        let h = AppHarness.make()
        for raw in ["", "   ", "\n\n"] {
            h.deps.editor.text = raw
            XCTAssertFalse(h.deps.editor.canStart)
            await h.deps.editor.start()
        }
        let count = (try? await h.history.list().count) ?? -1
        XCTAssertEqual(count, 0)
        XCTAssertTrue(h.speech.calls.isEmpty)
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
    }

    // T-007
    func testPasteOver500IsClampedWithNotice() {
        let h = AppHarness.make()
        h.deps.editor.text = String(repeating: "あ", count: 800)
        XCTAssertEqual(h.deps.editor.characterCount, 500)
        XCTAssertNotNil(h.deps.editor.notice)
    }

    // T-008
    func testStartSavesFirstThenOpensPlaybackAndSpeaks() async throws {
        let h = AppHarness.make()
        h.deps.editor.text = "  本日は晴天なり  "
        await h.deps.editor.start()
        let list = try await h.history.list()
        XCTAssertEqual(list.map(\.text), ["本日は晴天なり"])
        XCTAssertTrue(h.deps.coordinator.isPlaybackVisible)
        XCTAssertEqual(h.deps.coordinator.request?.source, .editor)
        XCTAssertEqual(h.speech.calls.map(\.text), ["本日は晴天なり"])
        XCTAssertEqual(h.deps.editor.text, "  本日は晴天なり  ", "the draft is kept (FR-018)")
    }

    // T-033
    func testDoubleStartCreatesOneEntryAndOneUtterance() async throws {
        let h = AppHarness.make()
        h.deps.editor.text = "連打"
        async let a: Void = h.deps.editor.start()
        async let b: Void = h.deps.editor.start()
        _ = await (a, b)
        let count = try await h.history.list().count
        XCTAssertEqual(count, 1)
        XCTAssertEqual(h.speech.calls.count, 1)
    }

    func testSameTextFromEditorTwiceAddsTwoRows() async throws {
        let h = AppHarness.make()
        h.deps.editor.text = "同じ文"
        await h.deps.editor.start()
        h.deps.coordinator.closePlayback()
        await h.deps.editor.start()
        let count = try await h.history.list().count
        XCTAssertEqual(count, 2)
    }

    // T-017 / ER-07
    func testSaveFailureShowsErrorKeepsDraftAndDoesNotSpeakOrNavigate() async throws {
        let h = AppHarness.make()
        await h.history.setFailWrites(true)
        h.deps.editor.text = "保存できない"
        await h.deps.editor.start()
        XCTAssertEqual(h.deps.editor.errorMessage, "履歴を保存できません。空き容量などを確認してください")
        XCTAssertEqual(h.deps.editor.text, "保存できない")
        XCTAssertTrue(h.speech.calls.isEmpty)
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
        let count = try await h.history.list().count
        XCTAssertEqual(count, 0)
    }

    // ER-01
    func testNoJapaneseVoiceBlocksSaveAndNavigation() async throws {
        let h = AppHarness.make()
        h.speech.readinessError = .noJapaneseVoice
        h.deps.editor.text = "声がない"
        await h.deps.editor.start()
        XCTAssertNotNil(h.deps.editor.errorMessage)
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
        let count = try await h.history.list().count
        XCTAssertEqual(count, 0)
    }

    // Codex P1: a save in flight must not start speech after an interruption.
    func testInterruptionDuringSaveDoesNotStartSpeechAfterwards() async throws {
        let gated = GatedRepository()
        let h = AppHarness.make(repository: gated)
        h.deps.editor.text = "割込み"
        let task = Task { await h.deps.editor.start() }
        await waitUntil("save in flight") { h.deps.editor.isSubmitting }
        await Task.yield()
        h.deps.coordinator.handleInterruption()
        await gated.release()
        await task.value
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
        XCTAssertTrue(h.speech.calls.isEmpty)
        XCTAssertEqual(h.deps.editor.text, "割込み", "draft kept")
        XCTAssertFalse(h.deps.editor.isSubmitting)
    }

    func testInterruptionDuringHistoryUpdateDoesNotStartPlayback() async throws {
        let gated = GatedRepository()
        let seeded = try await gated.seed("履歴")
        let h = AppHarness.make(repository: gated)
        await h.deps.history.reload()
        let task = Task { await h.deps.history.play(seeded) }
        try await Task.sleep(nanoseconds: 100_000_000)
        h.deps.coordinator.handleInterruption()
        await gated.release()
        await task.value
        XCTAssertFalse(h.deps.coordinator.isPlaybackVisible)
        XCTAssertTrue(h.speech.calls.isEmpty)
    }

    // Codex P1: the settings preview is also silenced by interruptions.
    func testInterruptionStopsSettingsPreviewToo() {
        let h = AppHarness.make()
        h.deps.preview.play()
        XCTAssertTrue(h.deps.preview.isPlaying)
        h.deps.coordinator.handleInterruption()
        XCTAssertFalse(h.deps.preview.isPlaying)
        XCTAssertEqual(h.speech.stopCount, 1)
    }
}
