import Foundation
import Observation

/// Playback state machine (docs/07 §1). Every event is checked against `sessionID`.
@MainActor @Observable
final class PlaybackViewModel {
    private(set) var state: PlaybackState = .idle
    private(set) var text = ""
    private(set) var highlightRange: NSRange?
    /// Seconds left before reading starts (nil when not counting down).
    private(set) var countdownRemaining: Int?
    @ObservationIgnored private(set) var sessionID: UUID?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private let sleep: @Sendable (TimeInterval) async -> Void

    @ObservationIgnored private let hub: SpeechSessionHub
    @ObservationIgnored private let settings: SettingsStore

    init(hub: SpeechSessionHub, settings: SettingsStore,
         sleep: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }) {
        self.hub = hub
        self.settings = settings
        self.sleep = sleep
    }

    /// Starts a brand-new session for `text` (new `sessionID`; never touches history).
    func begin(text: String, delaySeconds: Int = 0) {
        self.text = text
        cancelCountdown()
        guard delaySeconds > 0 else { startSession(); return }
        highlightRange = nil
        state = .preparing
        countdownRemaining = delaySeconds
        countdownTask = Task { [weak self] in
            guard let self else { return }
            var remaining = delaySeconds
            while remaining > 0 {
                await self.sleep(1)
                if Task.isCancelled { return }
                remaining -= 1
                self.countdownRemaining = remaining > 0 ? remaining : nil
            }
            self.countdownTask = nil
            self.startSession()
        }
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
        cancelCountdown()
        if let id = sessionID { hub.end(id) }
        sessionID = nil
        highlightRange = nil
        state = .idle
    }

    /// Background / audio interruption: stop speaking, never resume automatically (docs/03 UC-05).
    func interrupt() {
        if countdownRemaining != nil {
            cancelCountdown()
            state = .finished
            return
        }
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

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = nil
    }

    private func startSession() {
        cancelCountdown()
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
