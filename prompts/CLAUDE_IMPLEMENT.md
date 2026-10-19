# Claude 実装依頼プロンプト（そのまま渡す）

あなたはiPhoneアプリ「ヘイドラム」のSwiftシニアエンジニア兼実装担当です。**Codexが独立レビュー担当**であるため、テスト可能で、デザインと要件に追跡できるコードを書いてください。

添付の `HeyDrum_DesignPack_v1_0.zip` を展開した**ルート**を作業仕様の正本とし、まず `README.md` と `CLAUDE.md` を読む。その後、`docs/00_REQUIREMENTS.md` から `docs/13_SOURCES.md` まで読み、`reference/HeyDrum_UI_Mockup.png` と `assets/drum.wav`, `assets/metal.wav` も確認してください。画像は見た目の参照であり、動作は文書を優先します。

## 実装のゴール
- iOS 17+、iPhone専用、SwiftUIアプリ「ヘイドラム」を**Xcodeで開ける実際のプロジェクト一式**として作成。
- 2音ボタン、Apple標準ja-JP TTS、入力500文字、ローカル履歴100件、白い専用読上げ画面、停止→直前画面復帰、設定内アプリ音量を実装。
- 広告はAdMob/UMPのanchored adaptive bannerでAppShell下部共通。読上げ画面にも同位置。非消耗型IAPの広告除去と復元はStoreKit2で行う。
- 広告/課金の本番IDが未発行でも公式テスト広告とXcode StoreKit Configurationで動作する構成。外部API/AIの読み上げは禁止。
- 依存注入可能なサービス、Unit/Integration/UIテストを同梱。

## 作業前に必ず
1. 既存リポジトリなら `pwd`, `git status`, `git remote -v`, `find . -maxdepth 2 -type f` で調査し、既存のコミットやファイルを破壊しない。**GitHub URLや既存Xcodeプロジェクトはここでは指定されていないので推測しない**。
2. 新規Xcodeプロジェクトが無ければ作成（Scheme / Test target / StoreKit configを含む）。広告ID・bundleIDは勝手に本番値を捏造しない。
3. 書面と画像の違いがあれば `docs/00_REQUIREMENTS.md`のMUST優先。
4. `docs/DECISIONS_LOG.md` に変更判断を記録。

## 実装手順
`docs/10_WORK_PLAN.md` のP0〜P7の順で行い、各phaseで実装→Unitテスト→Xcodeビルド→差分報告。テスト環境が利用できるなら実際にコマンドを実行し、その出力に基づいて報告する。問題が出たら直してから進む。

## 特に厳密に
- `AVSpeechSynthesizerDelegate`のイベントをsessionIDで隔離、停止/完了競合を防ぐ。
- 履歴は100件で上限、既存履歴リプレイは新規行追加なし。JSONが破損したら自動上書きしない。
- 読上げ画面では広告フッターが最下部で動かず、タブバーは非表示。右下停止は見た目小さく、タップ領域44pt以上。
- 本文と履歴はクラウド/広告サービスに送信しない。
- 課金は `Transaction.currentEntitlements`の verified productIdを正本にする。`AppStore.sync()`は復元ボタン明示タップ時のみ。
- AdMobはUMP `canRequestAds`を通過してからリクエスト。開発用IDだけ使用。商品価格はStoreKitの返す額。
- 画面実装はモックのベージュ/橙/白を再現するが、コントラストとアクセシビリティ優先。
- 画像参照の人物そのものをAppに組み込まない。

## 報告形式
各phaseで実ファイルと実行コマンド、ビルドPASS/FAIL、テストPASS/FAIL/NOT RUN、残課題、commit SHAを簡潔に報告。レビューに回す時点でCodexに `prompts/CODEX_REVIEW.md`を渡し、全P0要件に対する証跡を用意してください。コードやテストの未完成を完成扱いにしない。
