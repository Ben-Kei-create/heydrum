import Foundation
import Observation

/// Owns navigation state: selected tab, Home stack and the full-screen playback overlay (docs/02 §4).
@MainActor @Observable
final class AppCoordinator {
    var selectedTab: AppTab = .home
    var homePath: [HomeDestination] = []
    private(set) var request: PlaybackRequest?

    /// Bumped on every background/interruption. Start requests captured before it must not start speech afterwards.
    @ObservationIgnored private(set) var interruptionEpoch = 0
    /// Extra things to silence on interruption (e.g. the settings voice preview).
    @ObservationIgnored var interruptionHandlers: [() -> Void] = []
    @ObservationIgnored let playback: PlaybackViewModel
    @ObservationIgnored private let sound: SoundProviding

    init(playback: PlaybackViewModel, sound: SoundProviding) {
        self.playback = playback
        self.sound = sound
    }

    var isPlaybackVisible: Bool { request != nil }

    /// Ignored while a playback screen is already up (double-tap guard).
    func openPlayback(text: String, source: PlaybackSource, delaySeconds: Int = 0) {
        guard request == nil else { return }
        sound.stopAll()
        request = PlaybackRequest(text: text, source: source)
        playback.onSessionEnd = nil
        playback.begin(text: text, delaySeconds: delaySeconds)
    }

    /// Launch greeting: "ドラム" in Eddy's voice with the text shown as it is spoken. Skipped if anything is
    /// already on screen or no Japanese voice exists. Closes itself shortly after the voice ends (or on tap/stop).
    func startGreeting(voices: [SpeechVoiceOption], hold: TimeInterval = 0.9, maxDuration: TimeInterval = 6) {
        guard request == nil else { return }
        let eddy = GreetingVoice.identifier(in: voices)
        sound.stopAll()
        let greeting = PlaybackRequest(text: GreetingVoice.text, source: .greeting)
        request = greeting
        playback.onSessionEnd = { [weak self] in
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))
                guard self?.request?.id == greeting.id else { return }
                self?.closePlayback()
            }
        }
        playback.begin(text: greeting.text, voiceOverride: eddy)
        Task { @MainActor [weak self] in                  // safety net: never trap the user on the greeting
            try? await Task.sleep(nanoseconds: UInt64(maxDuration * 1_000_000_000))
            guard self?.request?.id == greeting.id else { return }
            self?.closePlayback()
        }
    }

    /// Stops speech and returns to where playback was opened from. Idempotent (no double pop).
    func closePlayback() {
        guard let current = request else { return }
        playback.onSessionEnd = nil
        playback.stop()
        request = nil
        switch current.source {
        case .greeting: selectedTab = .home
        case .editor: selectedTab = .home
        case .history: selectedTab = .history
        }
    }

    /// Background / audio interruption: silence everything, never auto-resume.
    func handleInterruption() {
        interruptionEpoch += 1
        interruptionHandlers.forEach { $0() }
        playback.interrupt()
        sound.stopAll()
    }
}
