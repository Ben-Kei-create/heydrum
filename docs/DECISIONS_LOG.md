# 実装上の意思決定ログ

## ADR-001 2026-10-19
- **決定:** iPhone/iOS 17+、SwiftUI/MVVM、Swift Concurrency、Apple標準TTS、JSON履歴actor、StoreKit2、AdMob/UMP。
- **理由:** アプリが非常にシンプルであり、学習コストやサーバー運用を極小化できる。
- **代替案:** SwiftDataは100件の簡単な履歴にはオーバースペックとして不採用。

## ADR-002 2026-10-19
- **決定:** 500文字上限、VoiceEditorの再生を新履歴として保存、Historyの再生は既存履歴のlastPlayedAt更新。
- **理由:** モックアップ/履歴最大100件の要求と再生履歴の使いやすさのバランス。

## ADR-003 2026-10-19
- **決定:** 音声が自然終了しても読上げ画面に留まり、リプレイ可能。手動停止で元画面に戻る。
- **理由:** 再生画面を専用に見せたいという要求との整合。

## ADR-004 2026-10-19
- **決定:** 広告はAppShellで1つの共通スロットを固定。キーボード中のみ非表示、課金後はスロット削除。
- **理由:** すべての画面で同じ広告位置を守るため。

## ADR-005 2026-10-19
- **決定:** 女性ロボット風声はOSボイスを実機確認して選ぶ。識別子を推測しない。
- **理由:** システム音声の性別/提供状況が機種とOSに依存するため。

## 追加の書式
`ADR-XXX / 日付 / 変更理由 / 要求への影響 / 対応テスト / 所有者承認要否` を記録する。ユーザー明示のMUSTを無断で変更しない。

---
## Implementation decisions (Claude, 2026-10-19)

### ADR-006 / Single-consumer speech events via SpeechSessionHub
- **変更理由:** docs/02 §3 の `events: AsyncStream` は複数コンシューマで競合し得る。`SpeechSessionHub` が唯一のコンシューマとなり、sessionID→ハンドラで振り分け、登録のないsession(停止後のdidCancel等)を破棄する。設定の「音声を試す」も同じハブを使う。
- **要求への影響:** なし(MUSTの強化)。 **テスト:** T-010/011/033/034。 **承認要否:** 不要。

### ADR-007 / Navigation shape
- `AppRoute` enum の代わりに `AppTab` + `HomeDestination`(Home用NavigationStack) + `PlaybackRequest`(全画面オーバーレイ)。読上げ画面はタブ群の上に重ねて表示し、下の画面(入力下書き・スクロール)を保持する。広告スロットはオーバーレイの外(AppShell下部)にあるため位置が変わらない。
- 広告スロットは `safeAreaInset` ではなく VStack 末尾に配置。`safeAreaInset` では iOS 27 のタブバーが広告に隠れた(スクリーンショットで確認)。

### ADR-008 / Adaptive banner API
- 導入した Google Mobile Ads SDK 13.11.0 では `portraitAnchoredAdaptiveBanner(width:)` が deprecated で `largePortraitAnchoredAdaptiveBanner(width:)` が推奨。非deprecatedの後者を採用(高さ50〜150pt、端末縦幅の20%以内)。**スロットが従来の標準バナーより高くなる**。縮めたい場合は `AdSizing.adSize(forWidth:)` の1箇所を変更(deprecated APIに戻す)。**所有者判断を推奨。**

### ADR-009 / Button text colour
- 白文字×#ED8D45 のコントラストは約2.5:1でAA未達(`ContrastTests`)。オレンジ上の文字・アイコンは `ink`(#302C29, 約5.6:1)を使用。モックと異なるが docs/01 §2 の方針通り。

### ADR-010 / Entitlement source
- `Transaction.currentEntitlements` はエラーを返さないため、列挙結果が空なら `.free`。`.unavailable` は商品ID未設定のときのみ。購入状態をUserDefaultsに保存しない。

### ADR-011 / Replay does not touch history
- 読上げ完了後の「もう一度」は履歴を更新しない(docs/05 の「更新可」は任意)。履歴からの再生のみ `lastPlayedAt` を更新。

### ADR-012 / Misc
- 効果音の音量変更は次のタップから反映(効果音は1.4秒未満)。
- ATT は要求しない(広告に独自トラッキングを追加していない)。公開前にSDKの実データ流とApple基準で再確認すること(docs/06 §3)。
- Info.plist は `Config/Info.plist`(同期グループ外)に置き、広告ID等は xcconfig から展開。`DEVELOPMENT_TEAM` は git 管理外の `Config/Local.xcconfig`。
- 既存のXcodeテンプレート(`heydrum.xcodeproj`, `MyApp.swift`; macOSの大文字小文字非区別でHeyDrumと衝突)は作業用領域へ退避し、`HeyDrum.xcodeproj`に置換した。
- 履歴保存に `.atomic` 書込み。ファイル保護属性は OS 既定(未指定)。
- キーボード上に「閉じる」ボタンを追加(広告スロットのキーボード中非表示→復帰を確実に操作可能にするため)。
