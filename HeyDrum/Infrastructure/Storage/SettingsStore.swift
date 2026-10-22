import Foundation
import Observation

/// App settings in UserDefaults (docs/05 §7). Purchase state is deliberately NOT stored here.
@MainActor @Observable
final class SettingsStore {
    enum Key {
        static let volume = "heydrum.masterVolume"
        static let speed = "heydrum.speechSpeed"
        static let voice = "heydrum.preferredVoiceID"
        static let startDelay = "heydrum.startDelaySeconds"
        static let textScale = "heydrum.readingTextScale"
        static let font = "heydrum.readingFont"
    }

    var masterVolume: Float {
        didSet {
            let clamped = Self.clamp(masterVolume)
            if clamped != masterVolume { masterVolume = clamped; return }
            defaults.set(masterVolume, forKey: Key.volume)
        }
    }

    var speechSpeed: SpeechSpeed {
        didSet { defaults.set(speechSpeed.rawValue, forKey: Key.speed) }
    }

    var preferredVoiceID: String? {
        didSet {
            if let preferredVoiceID { defaults.set(preferredVoiceID, forKey: Key.voice) } else { defaults.removeObject(forKey: Key.voice) }
        }
    }

    /// Font of the reading screen text (default: system, as before).
    var readingFont: ReadingFont {
        didSet { defaults.set(readingFont.rawValue, forKey: Key.font) }
    }

    /// Reading-text size multiplier chosen with the slider in Settings (1.0 = standard, up to 3.0).
    var readingTextScale: Double {
        didSet {
            let clamped = Self.clampTextScale(readingTextScale)
            if clamped != readingTextScale { readingTextScale = clamped; return }
            defaults.set(readingTextScale, forKey: Key.textScale)
        }
    }

    /// Delay between pressing "読み上げ開始" and the first word (grid choice in the editor).
    var startDelaySeconds: Int {
        didSet {
            if !StartDelay.options.contains(startDelaySeconds) { startDelaySeconds = StartDelay.normalize(startDelaySeconds); return }
            defaults.set(startDelaySeconds, forKey: Key.startDelay)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.volume) != nil {
            masterVolume = Self.clamp(defaults.float(forKey: Key.volume))
        } else {
            masterVolume = AppSettings.defaultVolume
        }
        speechSpeed = defaults.string(forKey: Key.speed).flatMap(SpeechSpeed.init(rawValue:)) ?? .normal
        preferredVoiceID = defaults.string(forKey: Key.voice)
        readingFont = ReadingFont.from(defaults.string(forKey: Key.font))
        startDelaySeconds = StartDelay.normalize(defaults.integer(forKey: Key.startDelay))
        readingTextScale = defaults.object(forKey: Key.textScale) == nil ? 1.0 : Self.clampTextScale(defaults.double(forKey: Key.textScale))
    }

    var snapshot: AppSettings {
        AppSettings(masterVolume: masterVolume, speechSpeed: speechSpeed, preferredVoiceIdentifier: preferredVoiceID)
    }

    nonisolated static let textScaleRange: ClosedRange<Double> = 1.0...3.0

    nonisolated static func clampTextScale(_ v: Double) -> Double {
        guard v.isFinite else { return 1.0 }
        return min(textScaleRange.upperBound, max(textScaleRange.lowerBound, v))
    }

    nonisolated static func clamp(_ v: Float) -> Float {
        guard v.isFinite else { return AppSettings.defaultVolume }
        return min(1, max(0, v))
    }
}
