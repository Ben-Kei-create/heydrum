# 02 — Swift実装アーキテクチャ・インターフェース詳細

## 1. 採用方式
SwiftUI + MVVM（過剰なClean Architectureを作らない）。`@MainActor @Observable` ViewModel/Coordinator、Repository protocolによるローカル永続化、Audio/StoreKit/AdMobは薄いServiceラッパー。依存注入でユニットテスト可。Swift Concurrencyを採用し、コールバックはMainActorに正規化する。

**使用フレームワーク:** SwiftUI、Observation、AVFAudio/AVFoundation、StoreKit、Foundation、GoogleMobileAds、UserMessagingPlatform。読み上げに `Speech` フレームワーク（音声認識）は使用しない。外部ネットワークは広告・IAP・同意・ポリシーWebリンク以外禁止。

**基本構成:** 
```text
HeyDrum/
├── HeyDrumApp.swift                     // entry; dependency composition
├── App/
│   ├── AppCoordinator.swift             // route and origin, lifecycle
│   ├── AppShellView.swift               // shared screen + fixed ad slot
│   ├── AppConfig.swift                  // identifiers via build config
│   └── AppDependencies.swift            // injection container
├── Design/
│   ├── Theme.swift                      // color and typography tokens
│   ├── PrimaryButton.swift
│   ├── SectionCard.swift
│   └── AdSlotView.swift
├── Features/
│   ├── Home/HomeView.swift
│   ├── Drum/DrumView.swift
│   ├── Voice/VoiceEditorView.swift
│   ├── Voice/VoiceEditorViewModel.swift
│   ├── Voice/PlaybackView.swift
│   ├── Voice/PlaybackViewModel.swift
│   ├── History/HistoryView.swift
│   ├── History/HistoryViewModel.swift
│   └── Settings/SettingsView.swift
├── Domain/
│   ├── Models/HistoryEntry.swift
│   ├── Models/PlaybackState.swift
│   ├── Models/AppSettings.swift
│   ├── Ports/HistoryRepository.swift
│   ├── Ports/SpeechProviding.swift
│   ├── Ports/SoundProviding.swift
│   └── Ports/PurchaseProviding.swift
├── Infrastructure/
│   ├── Audio/SystemSpeechService.swift
│   ├── Audio/DrumSoundService.swift
│   ├── Storage/JSONHistoryRepository.swift
│   ├── Storage/SettingsStore.swift
│   ├── Purchase/StoreKitPurchaseService.swift
│   └── Ads/AdMobManager.swift
├── Resources/
│   ├── Sounds/drum.wav
│   ├── Sounds/metal.wav
│   ├── Localizable.xcstrings
│   └── PrivacyInfo.xcprivacy (必要なAPI使用判定後)
└── Tests/
    ├── Unit/
    ├── Integration/
    ├── UI/
    └── Fixtures/
```
`Info.plist` は Xcode設定自動生成でも可。`Secrets` はGit管理しない。テストターゲットのパスは実際のXcode構造に調整。

## 2. Domainモデル
```swift
struct HistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
    var lastPlayedAt: Date
}

struct AppSettings: Codable, Equatable, Sendable {
    var masterVolume: Float = 1.0  // 0...1 (default = max since 2026-10-22)
    var speechSpeed: SpeechSpeed = .normal
    var preferredVoiceIdentifier: String? = nil
}

enum SpeechSpeed: String, Codable, CaseIterable, Sendable {
    case slow, normal, fast
}

enum PlaybackState: Equatable {
    case idle
    case preparing
    case speaking
    case paused
    case finished
    case failed(String)
}

enum PlaybackOrigin: Equatable {
    case editor
    case history
}
```
Swiftのモデルは例。`Date`同値時は `id.uuidString` で決定的ソート。不正文字列・過大サイズをRepositoryで再検査。

## 3. Portインターフェース（実装を誘導する契約）
```swift
@MainActor
protocol SpeechProviding: AnyObject {
    var events: AsyncStream<SpeechEvent> { get }
    func availableJapaneseVoices() -> [SpeechVoiceOption]
    func speak(sessionID: UUID, text: String, voiceID: String?,
               volume: Float, speed: SpeechSpeed) throws
    func pause() -> Bool
    func resume() -> Bool
    func stop()
}

struct SpeechVoiceOption: Identifiable, Equatable, Sendable {
    let id: String               // AVSpeechSynthesisVoice.identifier
    let displayName: String
}

enum SpeechEvent: Sendable {
    case started(sessionID: UUID)
    case range(sessionID: UUID, location: Int, length: Int)  // UTF16 range
    case paused(sessionID: UUID)
    case resumed(sessionID: UUID)
    case finished(sessionID: UUID)
    case cancelled(sessionID: UUID)
    case failed(sessionID: UUID, message: String)
}

@MainActor
protocol SoundProviding: AnyObject {
    func preload() throws
    func play(_ sound: SoundKind, volume: Float)
    func stopAll()
}

enum SoundKind { case drum, metal }

protocol HistoryRepository: Sendable {
    func list() async throws -> [HistoryEntry]
    func appendNew(text: String, at: Date) async throws -> HistoryEntry
    func markPlayed(id: UUID, at: Date) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}

@MainActor
protocol PurchaseProviding: AnyObject {
    var entitlement: EntitlementState { get }
    func startObservingTransactions()
    func refreshEntitlements() async
    func loadProduct() async
    func purchaseRemoveAds() async -> PurchaseOutcome
    func restore() async throws
}

enum EntitlementState { case checking, free, purchased, unavailable }
enum PurchaseOutcome { case purchased, pending, cancelled, failed(String) }
```
**実装時の重要修正ポイント:** `AsyncStream` を `var events` で複数取得しても競合が起こらないよう、単一コンシューマを明確化（Sessionごとの `AsyncStream` を返す方式でもよい）。`SpeechEvent.sessionID` は `speak(sessionID:...)` に渡した `sessionID` と一致させる。AVSpeechSynthesizerのdelegateイベントは古いsessionを捨てる。

## 4. 画面Coordinator契約
```swift
enum AppTab { case home, history, settings }
enum AppRoute: Equatable {
    case home
    case drum
    case voiceEditor
    case history
    case settings
    case playback(text: String, source: PlaybackSource)
}
enum PlaybackSource: Equatable {
    case editor
    case history(id: UUID)
}
```
SwiftUI `NavigationStack(path:)` + root tab selection を使用。`PlaybackView` を広告フッターの**上**へ描画。戻るの処理はCoordinatorが担当し、再生セッション終了→前画面に復帰。history replay からの元画面への復帰は必ずhistoryにする。遷移操作の2重タップを防止。

## 5. 責務境界
- **View:** 画面の見た目とユーザー入力、アクセシビリティ。`AVSpeechSynthesizer` を直接作らない。
- **VoiceEditorVM:** 入力500文字制限、空欄検証、開始要求。現在の草稿を保持。
- **PlaybackVM:** 再生状態機械、左下ボタン動作、累積表示の進捗(`revealedUTF16`)、停止時Coordinator通知。sessionID管理。
- **HistoryVM:** 最新100件の取得/削除/更新、保存成否表示。読み上げ詳細はCoordinatorへ渡す。
- **SystemSpeechService:** 1インスタンスのAVSpeechSynthesizer、delegate、音声選択、stop/pause/resume実処理。
- **DrumSoundService:** `AVAudioPlayer`プールとバンドルWAV。音量は単一設定から取得。
- **HistoryRepository:** 日付/ID保持、最大100の原子的保存・CRUD。画面依存なし。
- **StoreKitPurchaseService:** StoreKit2検証・transactions更新・復元。`UserDefaults.purchased=true`を権利判定に使わない。
- **AdMobManager:** 同意確定後の広告ロードとバナー寿命、 entitlementに基づく一括非表示。ユーザー文字列を広告リクエストに渡さない。
- **SettingsStore:** UserDefaults/AppStorageの設定とバリデーション。課金と履歴の正本にはしない。

## 6. DI / テストダブル
`AppDependencies.live` で全依存を1箇所で生成する。`Preview` とテストには `FakeSpeechService`, `FakeSoundService`, `InMemoryHistoryRepository`, `FakePurchaseService`, `FakeAdProvider` を注入。

テストダブルでは音声delegate相当の `.started` `.finished` `.cancelled` `.range` を任意順で送れること。広告の読み込みの成否も任意に切り替えられること。起動、購入完了後の広告スロット除去、音声停止による復帰を外部SDK無しでテストする。

## 7. 競合制御
- 音声再生セッションはアプリで**常に最大1つ**。`activeSessionID` と送信イベントIDで識別。
- 手動停止では `activeSessionID` を無効化した上で `stopSpeaking(at: .immediate)`。古い `didCancel` で新画面に遷移しない。
- 発話完了イベントはユーザーが停止中・背景移行中なら無視。
- 履歴登録は1回の新規再生につき1回。連打/再試行時の二重登録防止は `requestID` で管理。
- IAP更新は全画面共通の購入状態ストアをmain actorから発行し、古い広告を確実に破棄。

## 8. 軽量化と禁止事項
- v1ではFirebase、Realm、CloudKit、Combine大規模設計、第三者TTS、定期fetch、リモートConfig、独自バックエンドは禁止。
- StoreKit権利判定をmock値のまま出荷しない。
- ソースで `fatalError` により通常の不具合をクラッシュさせない。デバッグ専用assertに留める。
- ObservableObjectとObservationを混在させない。新規プロジェクトはObservation主体とする。
- ユーザー読み上げテキストを `print`, analytics, error reporting, AdMob extras 等に渡さない。
