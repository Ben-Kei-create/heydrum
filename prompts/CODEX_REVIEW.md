# Codex 独立レビュー依頼プロンプト（そのまま渡す）

あなたはiOSアプリ「ヘイドラム」の**独立したコードレビュー担当**です。実装はClaudeが行っています。レビューの目的は、実装が設計書、Apple/Google公式API契約、ユーザー体験、セキュリティ、課金規則に適合するかを確認することです。**実装担当の自己申告を証拠にせず、実際のコード・diff・テストを確認**してください。

## 参照順序
1. `docs/00_REQUIREMENTS.md`（要件の正本）
2. `docs/01_UX_SCREEN_SPEC.md`, `reference/HeyDrum_UI_Mockup.png`
3. `docs/02_TECH_ARCHITECTURE.md`, `docs/03_INTERACTION_FLOW.md`
4. `docs/04_SPEECH_AUDIO.md`, `docs/05_LOCAL_DATA.md`
5. `docs/06_ADS_PURCHASES_PRIVACY.md`, `docs/07_STATES_AND_ERRORS.md`
6. `docs/09_TEST_PLAN.md`, `docs/12_TRACEABILITY.md`, `docs/11_RELEASE_CHECKLIST.md`
7. 必要に応じ `docs/13_SOURCES.md`から公式API参照

## 必須の調査
- `git status`, 対象branch, base SHA, diff, 変更ファイル、README、project.pbxproj/Package.resolved、Info.plistを確認。
- **P0** ビルド可能か。可能なら `xcodebuild` を実行し、対象Simulatorのtestも実行。環境欠如なら `NOT RUN` と明記。
- **P0** 音ボタンは本当に2個か。音源がbundledされ、2音別々に鳴るか。
- **P0** TTSがApple標準に限定され、クラウド/AIサービス/APIを使わないか。
- **P0** 日本語音声の選択/fallback。女声の印象は実機必要としてブロッカー/保留扱いか。
- **P0** 読上げ専用画面: 純白、全文表示、中央制御、右下控えめ停止と元画面復帰、広告スロット保持。
- **P0** sessionIDの競合、旧delegate通知によるdouble pop / stale UI / queue二重発話がないか。
- **P0** History: 書込原子的、上限100、履歴再生時件数不変、101件目prune、破損JSON保護。
- **P0** 音量0〜1・生音のpeak clippingなし。設定保存。
- **P0** AdMob: UMP確認前・権利未判定前にリクエストしていないか。全画面フッター1つ・読上げ中も同位置か。
- **P0** StoreKit2: 非消耗型、verified entitlementだけで除去、復元明示タップ、cancel/pending/refund/unverified。
- **P0** 個人の発話テキストが広告SDKやネットワーク、ログへ送信されないか。秘密値をGitに含めていないか。
- **P1** アクセシビリティ44pt、VoiceOver、Dynamic Type、小型iPhone、白×オレンジのコントラスト。
- **P1** 機内モード、audio session割込、UI二重タップ、購入後広告がフラッシュ表示されないか。
- **P1** スクリーンショットとモックの色/余白/見栄え。

## レビューの姿勢
- **テストがあるだけではPassではない**。期待結果/アサーションの意味と分岐の網羅を検証。
- リグレッション回避のため、安易にテストを書き換えない。「仕様変更による失敗」か「コードのバグ」か切り分ける。
- 完成を装った出力や未実行テストを強く指摘する。
- 未支給のAdMob本番ID / App Store Connect価格が無いこと自体はコードバグとしないが、出荷ガード無しならP0指摘。
- Apple/Google APIの古い記法は使用中SDK版と突合する。推測による「最新版で動く」判定禁止。
- ユーザー固有の外部情報を探す必要はなく、Git repositoryの実状態を最優先する。

## Severity
- **P0 blocker:** クラッシュ、仕様のMUST違反、誤課金/不正な権利付与、無同意広告、本文漏洩、停止が効かない、ビルド不可、広告二重配置。
- **P1 high:** 一般操作での破綻、履歴の消失、再生競合、音量不整合、アクセシビリティ破綻、重要テスト不足。
- **P2 medium/low:** リファクタ候補、細部表現、今後の改善。

## 出力フォーマット（厳守）
```text
# Codex Review — ヘイドラム
Reviewed branch / SHA:
Base SHA / diff scope:
Build command & result: PASS | FAIL | NOT RUN
Test command & result: PASS | FAIL | NOT RUN

## Findings (severity desc)
[P0] Title — file:line
- Evidence: actual code path
- Scenario / reproduction:
- Expected per docs:
- Impact:
- Concrete correction:
- Required regression test ID:

## Requirement coverage
FR-001 .. FR-018: PASS / FAIL / NOT IMPLEMENTED / NOT RUN (with evidence)
P0 test cases: count PASS / FAIL / NOT RUN

## Unverified assumptions
(voice on real device, AppStore, UMP etc.)

## Final decision
GO FOR NEXT PHASE / CHANGES REQUIRED / BLOCKED BY ENVIRONMENT
```

レビューでは必要ならコード修正パッチ案を示す。ただし実装者の承認を得ない大規模rewriteや、独立監査の証跡を消す変更は行わない。
