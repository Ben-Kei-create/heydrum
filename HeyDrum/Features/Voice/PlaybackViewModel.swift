import Foundation
import Observation

/// Playback state machine (docs/07 §1). Every event is checked against `sessionID`.
@MainActor @Observable
final class PlaybackViewModel {
    private(set) var state: PlaybackState = .idle
    private(set) var text = ""
    private(set) var highlightRange: NSRange?
    @ObservationIgnored private(set) var sessionID: UUID?

    @ObservationIgnored private let hub: SpeechSessionHub
    @ObservationIgnored private let settings: SettingsStore

    init(hub: SpeechSessionHub, settings: SettingsStore) {
        self.hub = hub
        self.settings = settings
    }

    /// Starts a brand-new session for `text` (new `sessionID`; never touches history).
    func begin(text: String) {
        self.text = text
        startSession()
    }

    /// Centre button: pause / resume / replay / retry.
    func centerAction() {
        switch state {
        case .speaking:
            if let id = sessionID, hub.pause(id) { state = .paused }
        case .paused:
            if let id = sessionID, hub.resume(id) { state = .speaking }
        case .finished, .failed:
            startSession()
        case .preparing, .idle:
            break
        }
    }

    /// Manual stop: detach the session before stopping so a late `didCancel` is ignored.
    func stop() {
        if let id = sessionID { hub.end(id) }
        sessionID = nil
        highlightRange = nil
        state = .idle
    }

    /// Background / audio interruption: stop speaking, never resume automatically (docs/03 UC-05).
    func interrupt() {
        switch state {
        case .preparing, .speaking, .paused:
            if let id = sessionID { hub.end(id) }
            sessionID = nil
            highlightRange = nil
            state = .finished
        default:
            break
        }
    }

    // MARK: Internals

    private func startSession() {
        if let id = sessionID { hub.end(id) }
        sessionID = nil
        highlightRange = nil
        state = .preparing
        do {
            sessionID = try hub.begin(
                text: text, voiceID: settings.preferredVoiceID,
                volume: settings.masterVolume, speed: settings.speechSpeed,
                onEvent: { [weak self] event in self?.handle(event) }
            )
        } catch SpeechError.noJapaneseVoice {
            state = .failed("日本語の音声が見つかりません。iOSの設定で日本語音声を追加してください。")
        } catch {
            state = .failed("読み上げを開始できませんでした。")
        }
    }

    func handle(_ event: SpeechEvent) {
        guard event.sessionID == sessionID else { return }   // stale session → ignore
        switch event {
        case .started:
            if state == .preparing { state = .speaking }
        case .range(_, let location, let length):
            guard state == .speaking || state == .paused else { return }
            let range = NSRange(location: location, length: length)
            highlightRange = Range(range, in: text) != nil ? range : highlightRange
        case .paused:
            if state == .speaking { state = .paused }
        case .resumed:
            if state == .paused { state = .speaking }
        case .finished, .cancelled:
            // `.cancelled` for an active session means the system cancelled it (manual stop detaches first).
            switch state {
            case .preparing, .speaking, .paused:
                highlightRange = nil
                state = .finished
            default: break
            }
        case .failed:
            highlightRange = nil
            state = .failed("読み上げに失敗しました。")
        }
    }
}
