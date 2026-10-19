import Foundation
import Observation

/// Owns navigation state: selected tab, Home stack and the full-screen playback overlay (docs/02 §4).
@MainActor @Observable
final class AppCoordinator {
    var selectedTab: AppTab = .home
    var homePath: [HomeDestination] = []
    private(set) var request: PlaybackRequest?

    @ObservationIgnored let playback: PlaybackViewModel
    @ObservationIgnored private let sound: SoundProviding

    init(playback: PlaybackViewModel, sound: SoundProviding) {
        self.playback = playback
        self.sound = sound
    }

    var isPlaybackVisible: Bool { request != nil }

    /// Ignored while a playback screen is already up (double-tap guard).
    func openPlayback(text: String, source: PlaybackSource) {
        guard request == nil else { return }
        sound.stopAll()
        request = PlaybackRequest(text: text, source: source)
        playback.begin(text: text)
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
        playback.interrupt()
        sound.stopAll()
    }
}
