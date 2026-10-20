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
        playback.begin(text: text, delaySeconds: delaySeconds)
    }

    /// Stops speech and returns to where playback was opened from. Idempotent (no double pop).
    func closePlayback() {
        guard let current = request else { return }
        playback.stop()
        request = nil
        switch current.source {
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
