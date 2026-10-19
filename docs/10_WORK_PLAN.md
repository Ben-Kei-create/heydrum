# 10 — Claude実装計画・Codexレビューゲート

## 原則
設計を基準に小さく統合し、**各ゲートでCodexが独立検査**。CI/実機環境が無い場合は「未実施」と報告し、実行済を装わない。進行は逐次でよいが、各フェーズ完了時にgit commit・テスト・Codex引渡を実施する。

| Phase | Claudeの実装 | 出力 / 完了ゲート |
|---|---|---|
| P0 | Xcode App作成、Theme、AppShell、Navigation、DI、Mock画面 | Build成功、設計通り5主要画面+履歴タブ、タブ/広告stubレイアウト |
| P1 | DrumSoundService、同梱WAV、音量0〜100% | 実機2音が別々に鳴る、連打安定、T-002〜T-005 |
| P2 | TextEditor、HistoryRepository、History UI、上限100 | T-006/T-007/T-013〜T-018/T-042/043のunit pass |
| P3 | SystemSpeechService、PlaybackVM、読上げ画面、停止/復帰 | T-008〜T-012/T-019〜T-021/T-033/T-034 |
| P4 | Settings、音声選択、速度、復帰、VoiceOver/Dynamic Type | T-030〜T-035/T-040/T-044 |
| P5 | StoreKit2、IAP設定、EntitlementGate、復元 | T-026〜T-029（StoreKit Sandboxまで確認） |
| P6 | AdMob/UMP、共通固定広告枠、プライバシー/consent | T-022〜T-025/T-039。購入後全スロット除去 |
| P7 | 総合UI polish、ケース別テスト、文書更新、Releaseガード | P0全Pass、Codex P0/P1なし、出荷チェックリスト記入 |

## 受け渡しプロトコル
1. Claudeは実装前に優先要求の矛盾を1度チェックし、`DECISIONS_LOG.md`で判断を残す。
2. 実装の各フェーズで `git status` を確認し、必要なファイルだけcommit。広告Secretやアカウント情報をcommitしない。
3. Claudeは `xcodebuild build`, `xcodebuild test` を**実行できる環境なら実際に実行**。コマンド・結果を残す。
4. Codexに差分範囲・基準仕様・実際のログを渡す。
5. Codex指摘をSeverity順（P0/P1/P2）に管理。Claudeが修正→回帰テスト→Codex再検査。
6. Codexの指摘解消後、所有者が実機で声質・見た目・課金/広告を受入。

## Gitポリシー
- デフォルトbranchを決めつけず `git status`, `git branch --show-current`, `git remote -v` を確認する。**不明なリモートへ勝手にpushしない**。
- 推奨branch: `feature/heydrum-ios-mvp`、レビュー用 `review/heydrum-*`。実環境のbranch規約を優先。
- 1フェーズ1〜数commitsの追跡可能な粒度。
- テストコードは機能と同時commit。設計差分はdocsを更新。
- CIを設定できるならmacOS runnerに構築。ただし利用料金の事前承認なく有料環境を作らない。

## ブロッカーの扱い
- **Apple Developer契約 / AdMob本番ID / IAP実価格未設定:** テスト構成で開発を続行し、公開のみBlocked。
- **端末に合う女性系voiceが見つからない:** 利用可能ボイスを記録しUIで選択可能にする。要件上の「女性風」はオーナー実機試聴で最終確認。
- **SDK API改名:** 公式最新版を採用、対応PRと設計書のAPI表記を合わせる。
- **外部審査やアカウントの利用不可:** 事実を記録、ローカル/シミュレータで検査可能な箇所まで完了させる。
