import XCTest
import AVFoundation
@testable import HeyDrum

@MainActor
final class SettingsStoreTests: XCTestCase {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "heydrum.tests.\(UUID().uuidString)")! }

    func testDefaultsAreSeventyPercentNormalSpeedNoVoice() {
        let s = SettingsStore(defaults: defaults())
        XCTAssertEqual(s.masterVolume, 0.70)
        XCTAssertEqual(s.speechSpeed, .normal)
        XCTAssertNil(s.preferredVoiceID)
    }

    // T-015 / T-030 persistence
    func testValuesPersistAcrossInstances() {
        let d = defaults()
        let a = SettingsStore(defaults: d)
        a.masterVolume = 0.25
        a.speechSpeed = .slow
        a.preferredVoiceID = "voice.x"
        let b = SettingsStore(defaults: d)
        XCTAssertEqual(b.masterVolume, 0.25)
        XCTAssertEqual(b.speechSpeed, .slow)
        XCTAssertEqual(b.preferredVoiceID, "voice.x")
        b.preferredVoiceID = nil
        XCTAssertNil(SettingsStore(defaults: d).preferredVoiceID)
    }

    func testOutOfRangeAndGarbageValuesAreClamped() {
        let d = defaults()
        d.set(7.5, forKey: SettingsStore.Key.volume)
        d.set("bogus", forKey: SettingsStore.Key.speed)
        let s = SettingsStore(defaults: d)
        XCTAssertEqual(s.masterVolume, 1)
        XCTAssertEqual(s.speechSpeed, .normal)
        s.masterVolume = -3
        XCTAssertEqual(s.masterVolume, 0)
        s.masterVolume = .nan
        XCTAssertEqual(s.masterVolume, AppSettings.defaultVolume)
    }

    func testSpeechRatesAreOrderedAndWithinSystemRange() {
        XCTAssertLessThan(SpeechSpeed.slow.utteranceRate, SpeechSpeed.normal.utteranceRate)
        XCTAssertLessThan(SpeechSpeed.normal.utteranceRate, SpeechSpeed.fast.utteranceRate)
        for speed in SpeechSpeed.allCases {
            XCTAssertGreaterThanOrEqual(speed.utteranceRate, AVSpeechUtteranceMinimumSpeechRate)
            XCTAssertLessThanOrEqual(speed.utteranceRate, AVSpeechUtteranceMaximumSpeechRate)
        }
    }
}

@MainActor
final class DrumSoundServiceTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: DrumSoundService.self) }

    // T-002 (evidence side): exactly two sound kinds exist and both ship in the bundle.
    func testExactlyTwoSoundsAreBundled() throws {
        XCTAssertEqual(SoundKind.allCases.count, 2)
        for kind in SoundKind.allCases {
            XCTAssertNotNil(bundle.url(forResource: DrumSoundService.fileName(for: kind), withExtension: "wav"))
        }
        let wavs = bundle.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? []
        XCTAssertEqual(Set(wavs.map(\.lastPathComponent)), ["drum.wav", "metal.wav"])
    }

    func testPreloadSucceedsAndRapidTapsNeverGrowPastPoolOrCrash() throws {
        let service = DrumSoundService(bundle: bundle)
        try service.preload()
        for _ in 0..<50 { service.play(.drum, volume: 0.7); service.play(.metal, volume: 1.0) }   // T-005 (simulator-level)
        service.play(.drum, volume: 0)         // 0% is allowed (silent)
        service.play(.metal, volume: 5)        // clamped
        service.stopAll()
    }

    // P0: no peak clipping in the bundled WAVs (NFR-010, docs/04 §5)
    func testBundledWavsDoNotClip() throws {
        for kind in SoundKind.allCases {
            let url = try XCTUnwrap(bundle.url(forResource: DrumSoundService.fileName(for: kind), withExtension: "wav"))
            let file = try AVAudioFile(forReading: url)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            var peak: Float = 0
            for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(samples[i])) }
            XCTAssertGreaterThan(peak, 0.1, "\(kind) is audible")
            XCTAssertLessThan(peak, 0.95, "\(kind) has headroom (no clipping)")
        }
    }
}

final class ContrastTests: XCTestCase {
    func testInkOnOrangeAndOnBeigeMeetWCAGAA() {
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.inkHex, Palette.primaryOrangeHex), 4.5)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.inkHex, Palette.warmBeigeHex), 4.5)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.inkHex, Palette.softOrangeHex), 4.5)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.inkHex, Palette.pureWhiteHex), 7)
    }

    func testMutedTextMeetsAAOnWhiteAndPaper() {
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.mutedHex, Palette.pureWhiteHex), 4.5)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.mutedHex, Palette.paperHex), 4.5)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.mutedHex, Palette.adBackgroundHex), 4.0)
    }

    /// Documents why white text on the mock's orange is NOT used.
    func testWhiteOnPrimaryOrangeFailsAA() {
        XCTAssertLessThan(Contrast.ratio(Palette.pureWhiteHex, Palette.primaryOrangeHex), 3.0)
    }
}
