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

    /// Conservative AVSpeechUtterance rates (docs/04 §1). Final tuning needs on-device listening.
    var utteranceRate: Float {
        switch self {
        case .slow: 0.43
        case .normal: 0.50
        case .fast: 0.57
        }
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    static let defaultVolume: Float = 0.70
    var masterVolume: Float = AppSettings.defaultVolume
    var speechSpeed: SpeechSpeed = .normal
    var preferredVoiceIdentifier: String? = nil
}
