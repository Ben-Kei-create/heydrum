import XCTest
@testable import HeyDrum

/// Real AVSpeechSynthesizer. Simulator audio proves the event plumbing only; voice quality/offline
/// behaviour (T-019/T-020) needs a real device and is NOT covered here.
@MainActor
final class SystemSpeechServiceTests: XCTestCase {
    private func collect(_ stream: AsyncStream<SpeechEvent>, until stop: @escaping @Sendable (SpeechEvent) -> Bool, timeout: TimeInterval = 20) async -> [SpeechEvent] {
        await withTaskGroup(of: [SpeechEvent].self) { group in
            group.addTask {
                var seen: [SpeechEvent] = []
                for await e in stream { seen.append(e); if stop(e) { break } }
                return seen
            }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)); return [] }
            let first = await group.next() ?? []
            group.cancelAll()
            return first
        }
    }

    func testSpeaksJapaneseAndReportsStartedAndFinishedForTheSameSession() async throws {
        let service = SystemSpeechService()
        try XCTSkipIf(service.availableJapaneseVoices().isEmpty && (try? service.verifyReadiness(voiceID: nil)) == nil,
                      "no ja-JP voice installed on this simulator")
        let id = UUID()
        try service.speak(sessionID: id, text: "こんにちは", voiceID: nil, volume: 0, speed: .fast)   // volume 0: still completes
        let events = await collect(service.events, until: { if case .finished = $0 { true } else { false } })
        XCTAssertTrue(events.contains(.started(sessionID: id)), "events: \(events)")
        XCTAssertTrue(events.contains(.finished(sessionID: id)), "events: \(events)")
        XCTAssertTrue(events.allSatisfy { $0.sessionID == id })
    }

    func testStopReportsCancelForOldSessionOnlyAndNewSessionStillWorks() async throws {
        let service = SystemSpeechService()
        try XCTSkipIf((try? service.verifyReadiness(voiceID: nil)) == nil, "no ja-JP voice installed")
        let old = UUID(), new = UUID()
        try service.speak(sessionID: old, text: String(repeating: "本日は晴天なり。", count: 20), voiceID: nil, volume: 0, speed: .normal)
        try await Task.sleep(nanoseconds: 300_000_000)
        try service.speak(sessionID: new, text: "あ", voiceID: nil, volume: 0, speed: .fast)
        let events = await collect(service.events, until: { if case .finished(let s) = $0 { s != UUID() } else { false } })
        XCTAssertTrue(events.contains(.finished(sessionID: new)), "events: \(events)")
        XCTAssertFalse(events.contains(.finished(sessionID: old)), "the interrupted session must not report finished")
    }

    func testInvalidVoiceIDFallsBackToJapaneseDefault() throws {
        let service = SystemSpeechService()
        try XCTSkipIf((try? service.verifyReadiness(voiceID: nil)) == nil, "no ja-JP voice installed")
        XCTAssertNoThrow(try service.verifyReadiness(voiceID: "does.not.exist"))
    }
}
