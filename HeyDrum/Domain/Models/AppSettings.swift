import Foundation

enum SpeechSpeed: String, Codable, CaseIterable, Sendable, Identifiable {
    case slow, normal, fast
    var id: String { rawValue }

    var label: String {
        switch self {
        case .slow: "ゆっくり"
        case .normal: "標準"
        case .fast: "速め"
        }
    }

    /// AVSpeechUtterance rates (docs/04 §1). Owner request: about half of the previous speed
    /// (previous normal was 0.50, i.e. the system default). Final tuning needs on-device listening.
    var utteranceRate: Float {
        switch self {
        case .slow: 0.20
        case .normal: 0.25
        case .fast: 0.32
        }
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    /// Owner request: the app starts at maximum app volume (device volume still applies).
    static let defaultVolume: Float = 1.0
    var masterVolume: Float = AppSettings.defaultVolume
    var speechSpeed: SpeechSpeed = .normal
    var preferredVoiceIdentifier: String? = nil
}
