import Foundation
import Observation

@MainActor @Observable
final class VoiceEditorViewModel {
    var text: String = "" {
        didSet {
            let result = SpeechText.clamped(text)
            if result.wasTruncated {
                text = result.text
                notice = "文字数の上限は\(SpeechText.maxLength)文字です"
            } else if notice != nil, text.count < SpeechText.maxLength {
                notice = nil
            }
        }
    }
    private(set) var notice: String?
    private(set) var errorMessage: String?
    private(set) var isSubmitting = false

    @ObservationIgnored private let history: HistoryViewModel
    @ObservationIgnored private let hub: SpeechSessionHub
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let openPlayback: (String, PlaybackSource) -> Void

    init(history: HistoryViewModel, hub: SpeechSessionHub, settings: SettingsStore,
         openPlayback: @escaping (String, PlaybackSource) -> Void) {
        self.history = history
        self.hub = hub
        self.settings = settings
        self.openPlayback = openPlayback
    }

    var characterCount: Int { text.count }
    var canStart: Bool { SpeechText.normalized(text) != nil && !isSubmitting }

    func dismissError() { errorMessage = nil }

    /// docs/03 UC-03: validate → lock → readiness → save → playback. The draft is kept in every outcome.
    func start() async {
        guard canStart, let normalized = SpeechText.normalized(text) else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try hub.verifyReadiness(voiceID: settings.preferredVoiceID)
        } catch {
            errorMessage = "日本語の音声が見つかりません。iOSの設定で日本語音声を追加してください。"
            return
        }
        do {
            let entry = try await history.addNew(text: normalized)
            openPlayback(entry.text, .editor)
        } catch HistoryError.corrupt, HistoryError.unsupportedSchema {
            errorMessage = "履歴を読み込めないため保存できません。履歴タブで復旧してください"
        } catch {
            errorMessage = "履歴を保存できません。空き容量などを確認してください"
        }
    }
}
