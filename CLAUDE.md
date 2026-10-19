# ヘイドラム — Claude Code / Claude 実装ルール

## プロジェクト
App Store向け日本語iPhone専用アプリ「ヘイドラム」。SwiftUI + AVFoundation + StoreKit2 + Google AdMob/UMP。Claudeが実装、Codexが独立レビュー。標準ライブラリ優先、外部AI API・サーバー不使用。

## MUST READ
1. `README.md`
2. `docs/00_REQUIREMENTS.md`（上位要求）
3. `docs/01_UX_SCREEN_SPEC.md`
4. `docs/02_TECH_ARCHITECTURE.md`
5. `docs/03_INTERACTION_FLOW.md`
6. `docs/04_SPEECH_AUDIO.md`
7. `docs/05_LOCAL_DATA.md`
8. `docs/06_ADS_PURCHASES_PRIVACY.md`
9. `docs/07_STATES_AND_ERRORS.md`
10. `docs/09_TEST_PLAN.md` と `docs/12_TRACEABILITY.md`

## Must-haves
- 日本語正式名称は必ず「ヘイドラム」。
- ドラム画面はちょうど2音のみ。楽器絵・AI表現を作らない。
- テキスト入力上限500文字、読み上げでローカル履歴最大100件。
- 音声合成は `AVSpeechSynthesizer` のみ。Appleの既存ja-JPボイスで動作。女性ロボットっぽさは実機試聴。
- 読上げ専用画面は真っ白に近く、大きいテキストと目立つ中央コントロール、小さく控えめな右下停止。停止で直前画面へ戻る。
- **広告フッターはAppShellで共通管理**。未購入時に読上げ中も同じ下端。買い切りIAP（非消耗型）で広告枠ごと消す。
- consentとStoreKit購入権利未確定時に広告リクエストしない。
- 歴史・ユーザー本文をネットワークやSDKの計測項目に入れない。

## 実装上の不可事項
- UIの振る舞いを決めずに不明な点を任意変更する、テストを緩くして通す、成功ログを捏造する、外部AI TTSに切り替える、広告SDKの未承認実IDをコミットすること。
- 未設定の課金・広告IDを架空実値で偽装すること。
- `didCancel` 等のコールバックで二重遷移や過去セッション干渉を起こすこと。
- 履歴が破損した際の自動上書き。

## 進め方
`docs/10_WORK_PLAN.md` に従ってphase単位で作成/ビルド/テスト/commit/Codexへ引渡。可能な限り実行し、実行できない検査は `NOT RUN` とする。音声テストは可能な限りiPhone実機で行い、ビルドだけで女声を保証したことにしない。

## 最終出力（各phase）
1. 変更ファイル/実装内容
2. 使用したビルド・テストコマンドとその本物の結果
3. 仕様未達/外部ID未設定とその影響
4. Codexに検査してほしい重点
5. commit SHAとbranch (実際に存在する時のみ)

## Codexレビュー
`prompts/CODEX_REVIEW.md`を独立レビューの唯一の入口とする。Codexは仕様→実装→テストを検査。修正の必要性をSeverity分けし、Claudeが再実装。
