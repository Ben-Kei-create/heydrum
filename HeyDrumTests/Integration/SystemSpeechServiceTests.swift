import XCTest
import AVFoundation
@testable import HeyDrum

/// Real AVSpeechSynthesizer. Simulator audio proves the event plumbing only; voice quality/offline
/// behaviour (T-019/T-020) needs a real device and is NOT covered here.
/// Times a real `AVSpeechSynthesizer` utterance (volume 0) from didStart to didFinish.
@MainActor
private final class RateProbe: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var started: Date?
    private var continuation: CheckedContinuation<TimeInterval?, Never>?

    func measure(text: String, rate: Float, timeout: TimeInterval = 90) async -> TimeInterval? {
        synthesizer.delegate = self
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = rate
        utterance.volume = 0
        return await withCheckedContinuation { (c: CheckedContinuation<TimeInterval?, Never>) in
            continuation = c
            synthesizer.speak(utterance)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if let c = self.continuation { self.continuation = nil; self.synthesizer.stopSpeaking(at: .immediate); c.resume(returning: nil) }
            }
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        Task { @MainActor in self.started = Date() }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in
            guard let c = self.continuation, let started = self.started else { return }
            self.continuation = nil
            c.resume(returning: Date().timeIntervalSince(started))
        }
    }
}

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

    /// Owner asked for "half the speed". Measures the real engine: old normal (0.50) vs the new rates.
    func testNewRatesAreReallySlowerThanTheOldNormalRate() async throws {
        let probe = SystemSpeechService()
        try XCTSkipIf((try? probe.verifyReadiness(voiceID: nil)) == nil, "no ja-JP voice installed")
        let text = "本日は晴天なり。ご来店いただき、まことにありがとうございます。"
        let old = await RateProbe().measure(text: text, rate: 0.50)
        let slow = await RateProbe().measure(text: text, rate: SpeechSpeed.slow.utteranceRate)
        let normal = await RateProbe().measure(text: text, rate: SpeechSpeed.normal.utteranceRate)
        let fast = await RateProbe().measure(text: text, rate: SpeechSpeed.fast.utteranceRate)
        try XCTSkipUnless(old != nil && normal != nil && slow != nil && fast != nil, "speech did not finish in time (machine too slow): old=\(String(describing: old)) slow=\(String(describing: slow)) normal=\(String(describing: normal)) fast=\(String(describing: fast))")
        let report = String(format: "old(0.50)=%.2fs slow(%.2f)=%.2fs normal(%.2f)=%.2fs fast(%.2f)=%.2fs ratio normal/old=%.2f",
                            old!, SpeechSpeed.slow.utteranceRate, slow!, SpeechSpeed.normal.utteranceRate, normal!, SpeechSpeed.fast.utteranceRate, fast!, normal! / old!)
        print("RATE-MEASUREMENT \(report)")
        XCTContext.runActivity(named: report) { _ in }
        XCTAssertGreaterThan(normal!, old! * 1.35, "new normal must be clearly slower than the old one. \(report)")
        XCTAssertGreaterThan(slow!, normal!, report)
        XCTAssertGreaterThan(normal!, fast!, report)
        XCTAssertGreaterThan(fast!, old! * 1.1, "even 'fast' is slower than the old normal. \(report)")
    }

    /// Calibration probe: prints how long the real engine needs at several rates (not an assertion).
    func testRateSweepForCalibration() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HEYDRUM_CALIBRATE"] != nil, "calibration probe: set TEST_RUNNER_HEYDRUM_CALIBRATE=1")
        let probe = SystemSpeechService()
        try XCTSkipIf((try? probe.verifyReadiness(voiceID: nil)) == nil, "no ja-JP voice installed")
        let text = "本日は晴天なり。ご来店いただき、まことにありがとうございます。"
        var lines: [String] = []
        for rate in [Float(0.5), 0.35, 0.25, 0.15, 0.10, 0.05, 0.0] {
            let d = await RateProbe().measure(text: text, rate: rate)
            lines.append(String(format: "rate %.2f → %@", rate, d.map { String(format: "%.2fs", $0) } ?? "timeout"))
        }
        print("RATE-SWEEP " + lines.joined(separator: " | "))
    }

    func testInvalidVoiceIDFallsBackToJapaneseDefault() throws {
        let service = SystemSpeechService()
        try XCTSkipIf((try? service.verifyReadiness(voiceID: nil)) == nil, "no ja-JP voice installed")
        XCTAssertNoThrow(try service.verifyReadiness(voiceID: "does.not.exist"))
    }
}
