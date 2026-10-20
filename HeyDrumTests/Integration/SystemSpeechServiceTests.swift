import XCTest
@testable import HeyDrum

/// Real AVSpeechSynthesizer. Simulator audio proves the event plumbing only; voice quality/offline
/// behaviour (T-019/T-020) needs a real device and is NOT covered here.
@MainActor
final class SystemSpeechServiceTests: XCTestCase {
    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [SpeechEvent] = []
        func add(_ e: SpeechEvent) { lock.lock(); items.append(e); lock.unlock() }
        var all: [SpeechEvent] { lock.lock(); defer { lock.unlock() }; return items }
    }

    /// Collects events until `stop` matches or the timeout passes; partial events are returned on timeout.
    private func collect(_ stream: AsyncStream<SpeechEvent>, until stop: @escaping @Sendable (SpeechEvent) -> Bool, timeout: TimeInterval = 20) async -> [SpeechEvent] {
        let box = Box()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await e in stream { box.add(e); if stop(e) { break } }
            }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)) }
            _ = await group.next()
            group.cancelAll()
        }
        return box.all
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

    /// The cumulative display depends on these notifications from the REAL engine.
    func testRealEngineSendsForwardRangeNotificationsInsideTheText() async throws {
        let service = SystemSpeechService()
        try XCTSkipIf((try? service.verifyReadiness(voiceID: nil)) == nil, "no ja-JP voice installed")
        let text = "本日は晴天なり。ご来店いただき、まことにありがとうございます。"
        let id = UUID()
        try service.speak(sessionID: id, text: text, voiceID: nil, volume: 0, speed: .fast)
        let events = await collect(service.events, until: { if case .finished = $0 { true } else { false } }, timeout: 40)
        let ranges: [(Int, Int)] = events.compactMap { if case .range(let sid, let l, let n) = $0, sid == id { (l, n) } else { nil } }
        XCTAssertTrue(events.contains(.finished(sessionID: id)), "events: \(events)")
        XCTAssertFalse(ranges.isEmpty, "the engine must announce at least one range")
        var lastEnd = 0
        for (loc, len) in ranges {
            let end = TextReveal.alignedEnd(in: text, location: loc, length: len)
            XCTAssertNotNil(end, "range (\(loc),\(len)) must be valid for the text")
            if let end { XCTAssertGreaterThanOrEqual(end, lastEnd, "engine ranges move forward"); lastEnd = end }
        }
        XCTAssertGreaterThan(ranges.count, 1, "several chunks, i.e. progressive display is possible (got \(ranges))")
    }

    func testInvalidVoiceIDFallsBackToJapaneseDefault() throws {
        let service = SystemSpeechService()
        try XCTSkipIf((try? service.verifyReadiness(voiceID: nil)) == nil, "no ja-JP voice installed")
        XCTAssertNoThrow(try service.verifyReadiness(voiceID: "does.not.exist"))
    }
}
