import AVFoundation

/// Apple's built-in synthesizer only (no cloud / AI TTS). One long-lived `AVSpeechSynthesizer`.
@MainActor
final class SystemSpeechService: NSObject, SpeechProviding, AVSpeechSynthesizerDelegate {
    /// Maps live utterances to the session they were created for. Delegate callbacks may arrive off the
    /// main actor, so access is lock-protected. Holding the utterance also keeps its identity stable.
    private final class SessionMap: @unchecked Sendable {
        private let lock = NSLock()
        private var map: [ObjectIdentifier: (AVSpeechUtterance, UUID)] = [:]

        func set(_ utterance: AVSpeechUtterance, id: UUID) {
            lock.lock(); defer { lock.unlock() }
            map[ObjectIdentifier(utterance)] = (utterance, id)
        }
        func id(for utterance: AVSpeechUtterance) -> UUID? {
            lock.lock(); defer { lock.unlock() }
            return map[ObjectIdentifier(utterance)]?.1
        }
        func remove(_ utterance: AVSpeechUtterance) {
            lock.lock(); defer { lock.unlock() }
            map[ObjectIdentifier(utterance)] = nil
        }
    }

    let events: AsyncStream<SpeechEvent>
    private let continuation: AsyncStream<SpeechEvent>.Continuation
    private let synthesizer = AVSpeechSynthesizer()
    private let sessions = SessionMap()

    override init() {
        var c: AsyncStream<SpeechEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .unbounded) { c = $0 }
        continuation = c
        super.init()
        synthesizer.delegate = self
    }

    // MARK: SpeechProviding

    func availableJapaneseVoices() -> [SpeechVoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ja-JP" }
            .sorted { $0.name < $1.name }
            .map { SpeechVoiceOption(id: $0.identifier, displayName: Self.displayName(for: $0)) }
    }

    func verifyReadiness(voiceID: String?) throws {
        guard resolveVoice(voiceID) != nil else { throw SpeechError.noJapaneseVoice }
    }

    func speak(sessionID: UUID, text: String, voiceID: String?, volume: Float, speed: SpeechSpeed) throws {
        guard let voice = resolveVoice(voiceID) else { throw SpeechError.noJapaneseVoice }
        AudioSessionConfigurator.activate()
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, speed.utteranceRate))
        utterance.pitchMultiplier = 1.08
        utterance.volume = SettingsStore.clamp(volume)
        utterance.preUtteranceDelay = 0
        sessions.set(utterance, id: sessionID)
        synthesizer.speak(utterance)
    }

    func pause() -> Bool { synthesizer.pauseSpeaking(at: .immediate) }
    func resume() -> Bool { synthesizer.continueSpeaking() }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }

    // MARK: Voice selection (docs/04: never guess identifiers, never claim a voice is female)

    private func resolveVoice(_ identifier: String?) -> AVSpeechSynthesisVoice? {
        if let identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier), voice.language.hasPrefix("ja") {
            return voice
        }
        return AVSpeechSynthesisVoice(language: "ja-JP")
    }

    private static func displayName(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .enhanced: "\(voice.name)（拡張）"
        case .premium: "\(voice.name)（プレミアム）"
        default: voice.name
        }
    }

    // MARK: AVSpeechSynthesizerDelegate (may be called off the main actor)

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let id = sessions.id(for: utterance) else { return }
        continuation.yield(.started(sessionID: id))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let id = sessions.id(for: utterance) else { return }
        sessions.remove(utterance)
        continuation.yield(.finished(sessionID: id))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard let id = sessions.id(for: utterance) else { return }
        sessions.remove(utterance)
        continuation.yield(.cancelled(sessionID: id))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        guard let id = sessions.id(for: utterance) else { return }
        continuation.yield(.paused(sessionID: id))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        guard let id = sessions.id(for: utterance) else { return }
        continuation.yield(.resumed(sessionID: id))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard let id = sessions.id(for: utterance) else { return }
        continuation.yield(.range(sessionID: id, location: characterRange.location, length: characterRange.length))
    }
}
