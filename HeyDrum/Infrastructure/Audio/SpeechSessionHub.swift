import Foundation

/// The single consumer of `SpeechProviding.events`. Routes events to the handler registered for their
/// session and drops everything else, so stale `didCancel`/`didFinish` callbacks can never reach a newer
/// screen (docs/02 §7, docs/07). At most one session is active at any time.
@MainActor
final class SpeechSessionHub {
    private let speech: SpeechProviding
    private var handlers: [UUID: (SpeechEvent) -> Void] = [:]
    private(set) var activeSessionID: UUID?
    private var consumer: Task<Void, Never>?

    init(speech: SpeechProviding) {
        self.speech = speech
        let stream = speech.events
        consumer = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                self.dispatch(event)
            }
        }
    }

    deinit { consumer?.cancel() }

    func verifyReadiness(voiceID: String?) throws { try speech.verifyReadiness(voiceID: voiceID) }
    func availableVoices() -> [SpeechVoiceOption] { speech.availableJapaneseVoices() }

    /// Stops any active session, then starts a new one. Throws without leaving a session registered.
    func begin(text: String, voiceID: String?, volume: Float, speed: SpeechSpeed,
               onEvent: @escaping (SpeechEvent) -> Void) throws -> UUID {
        if let active = activeSessionID { end(active) }
        let id = UUID()
        handlers[id] = onEvent
        activeSessionID = id
        do {
            try speech.speak(sessionID: id, text: text, voiceID: voiceID, volume: volume, speed: speed)
        } catch {
            handlers[id] = nil
            activeSessionID = nil
            throw error
        }
        return id
    }

    /// Detaches the session first (so its late `didCancel` is dropped), then stops the synthesizer.
    func end(_ id: UUID) {
        handlers[id] = nil
        guard activeSessionID == id else { return }
        activeSessionID = nil
        speech.stop()
    }

    func pause(_ id: UUID) -> Bool { activeSessionID == id ? speech.pause() : false }
    func resume(_ id: UUID) -> Bool { activeSessionID == id ? speech.resume() : false }

    private func dispatch(_ event: SpeechEvent) {
        guard let handler = handlers[event.sessionID] else { return }
        switch event {
        case .finished, .cancelled, .failed:
            handlers[event.sessionID] = nil
            if activeSessionID == event.sessionID { activeSessionID = nil }
        default: break
        }
        handler(event)
    }
}
