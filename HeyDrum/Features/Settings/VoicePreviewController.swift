import Foundation
import Observation

/// "音声を試す": one short fixed sentence, never stored in history (docs/04 §6).
@MainActor @Observable
final class VoicePreviewController {
    static let sampleText = "こんにちは。ヘイドラムです。"

    private(set) var isPlaying = false
    private(set) var errorMessage: String?
    @ObservationIgnored private var sessionID: UUID?
    @ObservationIgnored private let hub: SpeechSessionHub
    @ObservationIgnored private let settings: SettingsStore

    init(hub: SpeechSessionHub, settings: SettingsStore) {
        self.hub = hub
        self.settings = settings
    }

    func play() {
        stop()
        errorMessage = nil
        do {
            sessionID = try hub.begin(
                text: Self.sampleText, voiceID: settings.preferredVoiceID,
                volume: settings.masterVolume, speed: settings.speechSpeed,
                onEvent: { [weak self] event in self?.handle(event) }
            )
            isPlaying = true
        } catch {
            errorMessage = "日本語の音声が見つかりません。iOSの設定で日本語音声を追加してください。"
        }
    }

    func stop() {
        if let id = sessionID { hub.end(id) }
        sessionID = nil
        isPlaying = false
    }

    private func handle(_ event: SpeechEvent) {
        guard event.sessionID == sessionID else { return }
        switch event {
        case .finished, .cancelled, .failed:
            sessionID = nil
            isPlaying = false
        default: break
        }
    }
}
