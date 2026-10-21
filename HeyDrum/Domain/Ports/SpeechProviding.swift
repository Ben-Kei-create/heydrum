import Foundation

enum GreetingVoice {
    /// The launch greeting uses Apple's "Eddy" Japanese voice. Matched by NAME (never a guessed identifier);
    /// nil when it is not installed (the default Japanese voice is then used).
    static func identifier(in voices: [SpeechVoiceOption]) -> String? {
        voices.first(where: { $0.displayName == "Eddy" || $0.displayName.hasPrefix("Eddy（") || $0.displayName.hasPrefix("Eddy (") })?.id
    }
    static let text = "ドラム"
}

struct SpeechVoiceOption: Identifiable, Equatable, Sendable {
    let id: String               // AVSpeechSynthesisVoice.identifier
    let displayName: String
}

enum SpeechEvent: Sendable, Equatable {
    case started(sessionID: UUID)
    case range(sessionID: UUID, location: Int, length: Int)  // UTF-16 range
    case paused(sessionID: UUID)
    case resumed(sessionID: UUID)
    case finished(sessionID: UUID)
    case cancelled(sessionID: UUID)
    case failed(sessionID: UUID, message: String)

    var sessionID: UUID {
        switch self {
        case .started(let id), .paused(let id), .resumed(let id), .finished(let id), .cancelled(let id): id
        case .range(let id, _, _): id
        case .failed(let id, _): id
        }
    }
}

enum SpeechError: Error, Equatable {
    case noJapaneseVoice
    case synthesisFailed(String)
}

/// Single-consumer contract: `events` is consumed by exactly one `SpeechSessionHub`.
@MainActor
protocol SpeechProviding: AnyObject {
    var events: AsyncStream<SpeechEvent> { get }
    func availableJapaneseVoices() -> [SpeechVoiceOption]
    /// Throws `SpeechError.noJapaneseVoice` when neither the preferred voice nor a ja-JP voice exists.
    func verifyReadiness(voiceID: String?) throws
    func speak(sessionID: UUID, text: String, voiceID: String?, volume: Float, speed: SpeechSpeed) throws
    func pause() -> Bool
    func resume() -> Bool
    func stop()
}
