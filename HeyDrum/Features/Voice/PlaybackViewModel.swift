import Foundation
import Observation

/// Playback state machine (docs/07 §1). Every event is checked against `sessionID`.
@MainActor @Observable
final class PlaybackViewModel {
    private(set) var state: PlaybackState = .idle
    private(set) var text = ""
    /// How much of `text` is visible, in UTF-16 units (always Character-aligned, never decreases within a session).
    private(set) var revealedUTF16 = 0
    /// Seconds left before reading starts (nil when not counting down).
    private(set) var countdownRemaining: Int?
    @ObservationIgnored private(set) var sessionID: UUID?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    /// Used instead of the user's preferred voice for this session (launch greeting).
    @ObservationIgnored private var voiceOverride: String?
    /// Called when the session ends by itself (finished / system-cancelled / failed). Not called for manual stop.
    @ObservationIgnored var onSessionEnd: (() -> Void)?
    @ObservationIgnored private var fallbackTask: Task<Void, Never>?
    @ObservationIgnored private var receivedRange = false
    @ObservationIgnored private let sleep: @Sendable (TimeInterval) async -> Void
    /// If speech starts but NO range notification arrives within this time, the whole text is shown at once.
    @ObservationIgnored private let revealFallbackDelay: TimeInterval

    @ObservationIgnored private let hub: SpeechSessionHub
    @ObservationIgnored private let settings: SettingsStore

    init(hub: SpeechSessionHub, settings: SettingsStore,
         revealFallbackDelay: TimeInterval = 2.0,
         sleep: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }) {
        self.hub = hub
        self.settings = settings
        self.revealFallbackDelay = revealFallbackDelay
        self.sleep = sleep
    }

    /// The part of the text that may be shown right now.
    var visibleText: String { TextReveal.prefix(of: text, utf16Count: revealedUTF16) }

    /// Starts a brand-new session for `text` (new `sessionID`; never touches history).
    func begin(text: String, delaySeconds: Int = 0, voiceOverride: String? = nil) {
        self.text = text
        self.voiceOverride = voiceOverride
        cancelCountdown()
        guard delaySeconds > 0 else { startSession(); return }
        resetReveal()
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
        resetReveal()
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
            fallbackTask?.cancel()          // unread text stays hidden after an interruption
            state = .finished
        default:
            break
        }
    }

    // MARK: Internals

    private func resetReveal() {
        fallbackTask?.cancel()
        fallbackTask = nil
        receivedRange = false
        revealedUTF16 = 0
    }

    private func scheduleRevealFallback(for id: UUID) {
        fallbackTask?.cancel()
        fallbackTask = Task { [weak self] in
            guard let self else { return }
            await self.sleep(self.revealFallbackDelay)
            if Task.isCancelled { return }
            guard self.sessionID == id, !self.receivedRange, self.state == .speaking || self.state == .paused else { return }
            self.revealedUTF16 = self.text.utf16.count     // no range notifications on this system: show all, no progress
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = nil
    }

    private func startSession() {
        cancelCountdown()
        if let id = sessionID { hub.end(id) }
        sessionID = nil
        resetReveal()
        state = .preparing
        do {
            sessionID = try hub.begin(
                text: text, voiceID: voiceOverride ?? settings.preferredVoiceID,
                volume: settings.masterVolume, speed: settings.speechSpeed,
                onEvent: { [weak self] event in self?.handle(event) }
            )
        } catch SpeechError.noJapaneseVoice {
            state = .failed("日本語の音声が見つかりません。iOSの設定で日本語音声を追加してください。")
            onSessionEnd?()
        } catch {
            state = .failed("読み上げを開始できませんでした。")
            onSessionEnd?()
        }
    }

    func handle(_ event: SpeechEvent) {
        guard event.sessionID == sessionID else { return }   // stale session → ignore
        switch event {
        case .started:
            if state == .preparing {
                state = .speaking
                scheduleRevealFallback(for: event.sessionID)
            }
        case .range(_, let location, let length):
            // Progress only while speaking (frozen while paused), only forward, only valid ranges.
            guard state == .speaking, let end = TextReveal.alignedEnd(in: text, location: location, length: length) else { return }
            receivedRange = true
            if end > revealedUTF16 { revealedUTF16 = end }
        case .paused:
            if state == .speaking { state = .paused }
        case .resumed:
            if state == .paused { state = .speaking }
        case .finished:
            switch state {
            case .preparing, .speaking, .paused:
                revealedUTF16 = text.utf16.count        // natural end: keep the full text (incl. trailing punctuation)
                fallbackTask?.cancel()
                state = .finished
                onSessionEnd?()
            default: break
            }
        case .cancelled:
            // The system cancelled the active session (manual stop detaches first): do NOT reveal unread text.
            switch state {
            case .preparing, .speaking, .paused:
                fallbackTask?.cancel()
                state = .finished
                onSessionEnd?()
            default: break
            }
        case .failed:
            fallbackTask?.cancel()
            state = .failed("読み上げに失敗しました。")
            onSessionEnd?()
        }
    }
}
