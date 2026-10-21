import Foundation

enum PlaybackState: Equatable {
    case idle
    case preparing
    case speaking
    case paused
    case finished
    case failed(String)
}

/// Where the playback screen was opened from; "stop" returns there (FR-008, FR-018).
enum PlaybackSource: Equatable {
    case editor
    case history(id: UUID)
    /// Launch greeting ("ドラム" in Eddy's voice). Not saved in history; closes itself.
    case greeting
}

struct PlaybackRequest: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let source: PlaybackSource
}

enum AppTab: Hashable { case home, history, settings }

enum HomeDestination: Hashable { case drum, voiceEditor }
