import AVFoundation

/// Shared `.playback` + mixWithOthers session (docs/04 §4). Silent switch does not mute; other apps' audio is not stopped.
enum AudioSessionConfigurator {
    @MainActor
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Playback attempts continue; failures surface through the speech/sound layers.
        }
    }
}
