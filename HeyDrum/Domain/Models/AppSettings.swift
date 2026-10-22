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

    /// AVSpeechUtterance rates (docs/04 §1). Owner request: about half of the previous speed (previous normal
    /// was 0.50). The engine's rate scale is NOT linear: measured on 2026-10-22 (same 31-character sentence),
    ///   Eddy : 0.50 → 7.4 s, 0.25 → 10.8 s, 0.10 → 14.2 s (1.9×), 0.00 → 16.7 s (2.3×)
    ///   Kyoko: 0.50 → 6.0 s, 0.25 →  7.4 s, 0.10 →  8.9 s (1.5×), 0.00 → 10.1 s (1.7×)
    /// so `normal` uses 0.10 and `slow` the engine minimum 0.0; `fast` stays clearly slower than before.
    var utteranceRate: Float {
        switch self {
        case .slow: 0.0
        case .normal: 0.10
        case .fast: 0.25
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
