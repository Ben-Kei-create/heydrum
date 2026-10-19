# 12 — 要件トレーサビリティ

| 要件 | 主要設計 | 主要実装 | テスト |
|---|---|---|---|
| FR-001 | 01 UI-01 | HomeView | T-001 |
| FR-002 | 01 UI-02 / 04 | DrumView, DrumSoundService | T-002/003/004/005 |
| FR-003 | 01 Tokens | Theme.swift, Assets | T-045 |
| FR-004 | 01 UI-03 / 05 | VoiceEditorVM | T-006/007/040 |
| FR-005/006 | 04 speech | SystemSpeechService | T-008/019/020/021/036 |
| FR-007/008 | 01 UI-05 / 07 | PlaybackVM, AppCoordinator | T-009/010/011/034 |
| FR-009/010/011 | 05 | JSONHistoryRepository, HistoryVM | T-012〜T-018/041〜043 |
| FR-012 | 01 ad slot / 06 | AppShell, AdSlotView, AdMobManager | T-022〜025/039 |
| FR-013/014 | 06 | StoreKitPurchaseService | T-026〜029 |
| FR-015 | 04 / 05 / 01 UI-06 | SettingsStore, SettingsView | T-030 |
| FR-016 | 04 | SoundService + TTS + History | T-019 |
| FR-017 | 01 / 08 | Localizable.xcstrings | T-001/032 |
| FR-018 | 03 UC-05 | AppCoordinator + EditorVM | T-011/012 |
| NFR-001〜003 | 02 / 05 | AppDependencies + Repository | T-017/018/038 |
| NFR-004/006 | 01 | UI components | T-031/032/044 |
| NFR-005/007 | 06 | Consent/StoreKit/Data isolation | T-024/025/036/037 |
| NFR-008 | 04 / 07 | Session state machine | T-010/011/033/034 |
| NFR-009/010 | 04 / assets | AVFoundation, bundled WAV | T-003/004/019/036 |

各テストについてCodexは `NOT IMPLEMENTED / NOT RUN / PASS / FAIL` のいずれかで報告。仕様を満たすコードが存在するだけではテストPASSとしない。


## Implementation mapping (actual files)
FR-001 HomeView · FR-002 DrumView/DrumSoundService · FR-004 VoiceEditorViewModel/SpeechText · FR-005/006 SystemSpeechService + SpeechSessionHub · FR-007/008 PlaybackView/PlaybackViewModel/AppCoordinator · FR-009/010/011 JSONHistoryRepository/HistoryViewModel · FR-012 AppShellView/AdSlotView/AdMobManager · FR-013/014 StoreKitPurchaseService/SettingsView · FR-015 SettingsStore/SettingsView · Tests: see docs/VERIFICATION.md (status per test ID).
