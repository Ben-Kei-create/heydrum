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

### ADR-013 / Start-delay grid (owner request 2026-10-20)
- 音声モードに「読み上げ開始のタイミング」グリッド(すぐ/3/5/10/15/30秒後)を追加。選択は `SettingsStore.startDelaySeconds` に保存。ボタン押下時に履歴を保存し、読上げ画面を開いてカウントダウン(中央ボタンに残り秒数、ステータス「N秒後に読み上げます」)後に発話。停止・背景化・割込みでカウントダウンは破棄され、自動開始しない。履歴再生・「もう一度」は即時。
- **対応テスト:** StartDelayTests、UI testDelayGridSelectionStartsCountdownAndStopCancelsIt。

### ADR-014 / Reading text size (owner request)
- 読上げ画面の本文を、遠くからでも読める大きさに変更。文字数に応じて88→30pt(`PlaybackTextStyle`)、さらに Dynamic Type(`@ScaledMetric`、最大2倍)に追随。長文はスクロール。

### ADR-015 / Codex review 2026-10-20 fixes
- P0 Release guard: `tools/release_guard.sh` に分離。空・Google テストID・配布テンプレート値(XXXX/yourcompany 等)・AdMob ID 形式・bundle/product 形式を拒否(`tools/test_release_guard.sh` 14件)。形式検証のみで、IDの所有権は検証できない。
- P0 広告同意: `requestBanner()` 直前と SDK 起動後に最新 `canRequestAds`/権利を再確認。プライバシー設定フォーム後に再評価(拒否→バナー破棄・空スロット維持、許可→重複なく再開)。
- P1 保存/履歴更新待ち中の割込み: `AppCoordinator.interruptionEpoch` を導入し、待機中に背景化・割込みがあれば再生を開始しない(下書きは保持、保存済み履歴は残る)。
- P1 設定プレビューも割込みで停止(`interruptionHandlers`)。
- P1 本文の Dynamic Type 追随(ADR-014)。
- P2 `generate_original_sounds.py` の出力先を `HeyDrum/Resources/Sounds/` に修正。UIテストの割込みカウントダウン検証を実アクセシビリティ構造(中央ボタンのラベル)に合わせ、選択状態は `isSelected` を厳密に検査。StoreKit 失敗注入を `setSimulatedError` に更新。
- アプリアイコン右下に「Hey!」を追加(オーナー指示)。

### ADR-016 / App icon replaced (owner decision 2026-10-20)
- アイコンを、オーナー提供のガラス調イラスト(黒い半透明の人型がオレンジのスマホ+吹き出しを持つ)に差し替え。1024×1024、透過なし。以前の「Hey!」入りフラット版は `reference/app-icon/heydrum-flat-hey-previous.png` に保存。
- **要求への影響:** docs/00 §1「人物・ロボット等のモチーフを使わない」は主に画面UI向けの記述。アイコンの人型は抽象的で顔や実在人物ではない。オーナー指示のため採用。審査ガイドライン上の懸念は特にないが、提出前に小サイズ(60pt)での視認性を実機で確認すること。

### ADR-017 / B plan: personalised ads + ATT (owner decision 2026-10-20)
- ATT許可画面を実装(`UMPConsentService.requestTrackingAuthorization`)。順序は 同意(UMP) → ATT → 広告SDK起動。`canRequestAds` が偽・課金済み・権利未判定のときは出さない。ATT後に権利/同意を再確認してから SDK 起動。`NSUserTrackingUsageDescription` を Info.plist に追加、`PrivacyInfo.xcprivacy` は `NSPrivacyTracking=true`。
- App Store の「トラッキングに使う」は、おおよその場所・デバイスID・製品の操作・広告データを「はい」(保守的)。プライバシーポリシーに広告ID/ATTの説明を追加。
- ADR-012「ATTは要求しない」を置換。 **テスト:** AdTrackingPromptTests(4)。

### ADR-018 / Cumulative reading display (owner change 2026-10-20)
- **変更:** 読上げ画面を「全文表示＋下線」から「発話の進行に合わせた累積表示」へ変更。本文は開始前・カウントダウン中は非表示。`willSpeakRange` の末尾(Character境界に切り上げ)まで表示が前進する。下線/ハイライト(`TextHighlighter`)は廃止。
- **フォント:** 全文の文字数で決まる固定サイズ(88/72/60/52/46pt)に変更し、500字でも46pt以上。再生中に縮まない。Dynamic Type(`@ScaledMetric`, 最大2倍)維持。左揃え・上寄せで既表示行は動かず、長文は最新部分へ自動スクロール。
- **安全側の決定:** 手動停止・背景化・割込み・システム取消では未読部分を公開しない／自然終了のみ全文。`speaking`中の通知のみ反映(一時停止中は凍結)。range通知が全く来ない環境では`didStart`から2秒後に全文を一括表示(進行用タイマーではなく欠如時の安全策)。VoiceOverのラベルは表示中の文字のみ。
- **限界(明記):** 通知は単語等のまとまり単位で、1文字ごとの音素同期ではない。実機の声・OSで通知の粒度は異なり得る（要実機確認）。
- **要求への影響:** FR-007(MUST)をオーナーが変更。docs/00,01,02,03,04,07,09,12を整合。既存テストの「全文を初期表示」assertは仕様変更に伴い更新（削除ではなく累積表示の検証へ置換）。
- **対応テスト:** T-009, T-046〜T-053。

### ADR-019 / Defaults: max volume, half speed (owner 2026-10-22)
- 音量の初期値を 0.70 → **1.0**。すでに保存された値は維持(新規インストール/未設定のみ最大)。端末の音量はシステムに従う。
- 読み上げ速度: 最初は 0.20/0.25/0.32 に下げたが、**実エンジンで測ると0.25は従来(0.50)の約1.3倍しか遅くならなかった**(rateは非線形)。実測に基づき slow/normal/fast = **0.0/0.10/0.25** に修正(従来 0.43/0.50/0.57)。Eddy normal≈1.9倍、Kyoko normal≈1.5倍(詳細はdocs/04)。「ちょうど1/2」は声によって達成できないため、さらに遅くするなら文の区切りにポーズを入れる案を別途検討(未実装)。実機での体感確認はT-057。

### ADR-020 / Launch greeting "ドラム" in Eddy's voice (owner 2026-10-22)
- 起動のたびに読上げ画面と同じ表示でEddyが「ドラム」と読み上げ、文字を同時表示。Eddyは名前照合(識別子の推測なし)、不在なら既定のja-JP声。履歴非保存、約0.9秒後に自動で閉じる/タップでスキップ/最長6秒で必ず閉じる。FR-019を追加。
- **留意:** 起動のたびに音が鳴る仕様のため、静かな場所では驚かせる可能性がある(音量は設定値に従う。無効化スイッチは今回の依頼に含まれないため未実装)。Appleの審査上の問題は想定していないが、必要なら設定にオフスイッチを追加できる。

### ADR-021 / Reading text size slider, left pause button, seconds counter (owner 2026-10-22)
- 設定に「読み上げ文字の大きさ」スライダー(1.0〜3.0倍、既定1.0)を追加。読上げ画面のフォントは 基準(文字数別46〜88pt) × min(Dynamic Type,2) × スライダー倍率(合計上限6倍)。プレビューつき。
- 読上げ画面の左下に、右下の「停止」と同サイズ(44pt領域・28pt円・16pt記号)・同色(グレー、オレンジ不使用)の一時停止/再開/もう一度ボタンを追加(中央の主ボタンは仕様(FR-007)どおり維持)。起動時あいさつ画面では非表示。
- 開始タイミング(カウントダウン)の残り秒数を、画面下中央に小さなグレーの数字(例「3秒」)で表示。中央の丸ボタン内の大きな数字は廃止(スピナー表示)。
- 対応: T-058(文字サイズ), T-059(左下一時停止), T-060(秒数表示)。

### ADR-022 / Selectable reading fonts (owner 2026-10-22)
- オーナー提供の3フォント(M PLUS 1 / Kosugi Maru / WDXL Lubrifont JP N)を同梱し、設定>「読み上げ文字の大きさ」でフォントを選べる(既定は従来どおりシステム)。読上げ画面とあいさつ画面の本文に適用。`UIAppFonts` で登録、`ReadingFont`(PostScript名で参照、未登録ならシステムにフォールバック)。
- 同梱ファイル: MPLUS1-Bold.ttf(1.8MB), KosugiMaru-Regular.ttf(3.6MB), WDXLLubrifontJPN-Regular.ttf(10.3MB) ≒ アプリが約16MB増える。
- ライセンス: M PLUS 1 と WDXL Lubrifont は SIL OFL 1.1、Kosugi Maru は Apache 2.0。いずれも同梱・再配布可。ライセンス全文を `Resources/Fonts/License-*.txt` に同梱し、アプリ内「設定>フォントのライセンス」で表示(著作権表示と全文の同梱が条件)。再配布時にフォントを改変していない。
- 注意: Kosugi Maru と Lubrifont はウェイトが1種類(太字にならない)。ごく稀なかな(ゕゖゔヷ-ヺ)は一部フォントに無く、その文字だけシステムフォントで表示される(`FONT-COVERAGE`ログ、テスト済み: 常用のかな・数字・句読点・サンプル漢字は全フォントで表示可)。
- 対応テスト: ReadingFontTests(3), UI(設定にピッカー), 画面サンプル `docs/evidence/reading-fonts.png`。

### ADR-023 / Codex review of 15371f8 (2026-10-22)
- P1: 最初のrange通知の前に一時停止すると、2秒のfallbackが停止中に全文を公開していた → 一時停止でfallbackタイマーを止め、再開後に(range未着なら)数え直す。停止/割込み/新session/range受信済みの組合せはテスト化(PlaybackRevealTests +5)。
- P2: 速度の実時間テストを、声の固定・予備再生・3回の交互測定の中央値に変更し、声名と値をレポートに出力。固定rateの検査(SettingsStoreTests)と実時間ベンチ(統合テスト)を区別。
- P2: docs/09 の T-055 を 0.0/0.10/0.25 と非線形の実測方針に更新、T-058〜061 の行の `\n` を実際の改行に修正。

### ADR-024 / Remove central orange playback control (owner 2026-10-22)
- スクリーンショットに残っていた中央のオレンジ色ボタンを削除する明示指示。FR-007およびADR-021の中央主ボタン維持を置換。
- 読上げ中・一時停止中・完了・失敗の全状態で中央ボタンを廃止し、左下のグレーのボタンへ操作を集約。右下の停止/戻る、状態文、下部カウントダウン、共通広告枠は維持。
- 既存UIテストを左下操作と中央ボタン不在の検証へ更新。
- 検証: Xcode27.1 / iPhone18 Pro iOS27.0、build-for-testing成功。UI4件（入力保持/停止、下部pause/resumeと中央ボタン不在、カウントダウン、500文字Dynamic Type）すべてPASS。ログ・結果: `/tmp/heydrum-remove-orange/`。
