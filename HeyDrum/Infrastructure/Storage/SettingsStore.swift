import Foundation
import Observation

/// App settings in UserDefaults (docs/05 §7). Purchase state is deliberately NOT stored here.
@MainActor @Observable
final class SettingsStore {
    enum Key {
        static let volume = "heydrum.masterVolume"
        static let speed = "heydrum.speechSpeed"
        static let voice = "heydrum.preferredVoiceID"
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
    }

    var snapshot: AppSettings {
        AppSettings(masterVolume: masterVolume, speechSpeed: speechSpeed, preferredVoiceIdentifier: preferredVoiceID)
    }

    nonisolated static func clamp(_ v: Float) -> Float {
        guard v.isFinite else { return AppSettings.defaultVolume }
        return min(1, max(0, v))
    }
}
