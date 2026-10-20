# オーナー作業ガイド（実機確認 → ID準備 → TestFlight）

このガイドは「あなたの手で」行う作業だけを、順番・リンク・貼り付ける値つきでまとめたものです。コードは変更不要です（IDは設定ファイルに入れるだけ）。

## 0. 前提（最初に1回）
| 必要なもの | リンク |
|---|---|
| Apple Developer Program（年額・課金/TestFlight/実機配布に必須） | https://developer.apple.com/programs/enroll/ |
| Apple Developer アカウント（Team ID の確認） | https://developer.apple.com/account |
| App Store Connect | https://appstoreconnect.apple.com |
| AdMob | https://admob.google.com |

Xcode: このプロジェクトは `HeyDrum.xcodeproj` を開く（`/Applications/heydrum/HeyDrum.xcodeproj`）。スキームは `HeyDrum`。

## 1. 実機で確認する（所要 15〜20分）
### 1-1. 実機にインストール
1. iPhone を Mac に接続 → iPhone の「設定 > プライバシーとセキュリティ > デベロッパモード」をオン（再起動）。
2. `Config/Local.xcconfig`（git管理外）を開き、次を設定する。**Bundle ID は自分で決める逆ドメイン形式**（後で App Store Connect に登録するものと同じにする）:
   ```
   DEVELOPMENT_TEAM = あなたのTeamID(10桁)
   HEYDRUM_BUNDLE_ID = com.あなたの名前.heydrum
   ```
   ※ `IN_APP_PURCHASE_PRODUCT_ID` は Debug では変更しない（Debug は仮商品 `example.heydrum.dev.remove_ads` とテスト広告で動く）。
3. Xcode 上部のデバイスで自分の iPhone を選び ▶（Run）。

### 1-2. チェック項目（結果は `docs/09_TEST_PLAN.md` §4 の書式でメモ）
| # | 操作 | 期待 | 対応テストID |
|---|---|---|---|
| 1 | ホーム → ドラムモード →「ドラム音」を1回押す | ドラム音だけが1回鳴る | T-003 |
| 2 | 「金属音」を1回押す | 金属音だけが1回鳴る | T-004 |
| 3 | 各ボタンを10連打 | 音が割れない・遅れが増えない・落ちない | T-005 |
| 4 | 設定 > 音量 を 0 / 70 / 100% にして各音・読み上げを確認 | 0%で無音、他は音量が変わる | T-030 |
| 5 | 設定 > 音声 の一覧を全部「音声を試す」で聴く | 好みの声を選べる。**女性ロボット風に近い声を決める**（見つからなければ設定の声一覧をメモして共有） | T-020 |
| 6 | 音声モードで次を順に読み上げ: `こんにちは` / `本日は晴天なり` / `次は13時45分` / `酸化と還元` / `こんにちは😀。` / `あいうえお⏎かきくけこ` / `東京2026年` | 自然な日本語。止まらない | docs/04 §7 |
| 7 | **機内モード**にして 6 を繰り返す。効果音と履歴再生も | すべて動く（声が鳴らなければ、その声は端末内に無い→別の声を選ぶ） | T-019 |
| 8 | 読み上げ画面の文字の大きさ。端末を机に置き **2〜3 m 離れて**読めるか。短文（〜12字）と長文（200字）の両方 | 短文が特大、長文は読める大きさでスクロール | 新要件 |
| 9 | 設定 >（iOS設定）> 画面表示と明るさ > 文字サイズを最大にして 8 を再確認 | 本文がさらに大きくなり、停止/中央ボタンが隠れない | T-031 |
| 10 | 音声モードで「5秒後」を選び開始 → 画面にカウントダウン → 5秒後に発話。途中で右下「停止」 | 停止で発話せず戻る | 新要件 |
| 11 | 読み上げ中にホームボタン/電話着信 | 止まり、勝手に再開しない | T-035 |

**文字がもっと大きい／小さい場合:** 教えてください。`HeyDrum/Domain/Models/StartDelay.swift` の `PlaybackTextStyle`（文字数別88〜30pt）を調整します。

## 2. 本番IDを用意する
### 2-1. Bundle ID を登録
https://developer.apple.com/account/resources/identifiers/list → 「+」→ App IDs → App → Description `ヘイドラム` / Bundle ID `Explicit` に **1-1 と同じ値** → Continue → Register。

### 2-2. App Store Connect にアプリを作成
https://appstoreconnect.apple.com/apps → 「+」→ 新規App
- プラットフォーム: iOS / 名前: `ヘイドラム` / プライマリ言語: 日本語 / バンドルID: 2-1 のもの / SKU: 任意（例 `heydrum-001`）

### 2-3. 広告除去の課金商品（非消耗型）を作る
App Store Connect > 該当App > 「収益化」>「アプリ内課金」> 「+」
- タイプ: **非消耗型**
- 参照名: `広告を非表示` / **製品ID: `<Bundle ID>.remove_ads`**（例 `com.あなたの名前.heydrum.remove_ads`）← これを控える（変更不可）
- 価格: 任意（コードは価格を持たず、StoreKit の表示価格を使う）
- 表示名/説明（日本語）: `広告を非表示` / `広告を非表示にします（買い切り）`
- 審査用スクリーンショット: 設定画面のスクショを添付
ヘルプ: https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases

### 2-4. AdMob でアプリと広告ユニットを作る
1. https://admob.google.com/home/ → 左メニュー「アプリ」→「アプリを追加」→ iOS →「アプリはアプリストアに登録されていますか？」はまだなら「いいえ」→ 名前 `ヘイドラム`。
2. 作成後に表示される **アプリID**（`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`）を控える。
3. そのアプリ >「広告ユニット」>「広告ユニットを追加」> **バナー** → 名前 `bottom-banner` → 作成。**広告ユニットID**（`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`）を控える。
4. **同意メッセージ（UMP/GDPR）を設定:** 左メニュー「プライバシーとメッセージ」→ 欧州の規制メッセージ/米国州規制などを作成し、このアプリに適用して公開。未設定だと同意フォームが出ず広告が出ない地域があります。
   公式手順: https://developers.google.com/admob/ios/privacy
5. 公開後は `app-ads.txt`（任意）: https://support.google.com/admob/answer/9363762

### 2-5. プライバシーポリシーURL
ひな形: `site/privacy-policy.html`（この repo にあります。連絡先メールの `★` 2か所を自分のものに書き換える）。
公開方法（一番簡単）: GitHub に **公開リポジトリ `heydrum-site` を新規作成**（https://github.com/new）→ `privacy-policy.html` を `index.html` 名でアップロード → Settings > Pages > Branch `main` / `/ (root)` → 数分後の URL（`https://<ユーザー名>.github.io/heydrum-site/`）がポリシーURL。
※ このアプリの repo の Pages は使わない（設計書が全部公開されるため）。
そのURLを:
- App Store Connect > アプリ情報 >「プライバシーポリシーURL」に入力
- `HeyDrum/App/AppConfig.swift` の `privacyPolicyURL` に `URL(string: "…")` として設定（私に URL を教えてくれれば設定します）

App Privacy（アプリのプライバシー）申告: App Store Connect > App のプライバシー。AdMob を使うので「広告データ」「識別子（デバイスID）」「使用状況データ」等の収集を **Google の公式説明に沿って** 申告する。参考: https://developers.google.com/admob/ios/privacy/strategies と https://developer.apple.com/jp/app-store/app-privacy-details/

## 3. IDを入れて TestFlight で確認する
### 3-1. `Config/Secrets.xcconfig` を作る（git管理外）
`Config/Config.example.xcconfig` をコピーして保存し、値を置き換える:
```
HEYDRUM_BUNDLE_ID = com.あなたの名前.heydrum
AD_UNIT_ID = ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz        # 2-4-3
ADS_TEST_MODE = NO
IN_APP_PURCHASE_PRODUCT_ID = com.あなたの名前.heydrum.remove_ads   # 2-3
GAD_APPLICATION_IDENTIFIER = ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy # 2-4-2
```
`DEVELOPMENT_TEAM` は `Config/Local.xcconfig` に既にあります。**Release ビルドは、ここが空・テストID・テンプレートのままだと自動で失敗**します（ガード）。確認: `sh tools/test_release_guard.sh`

### 3-2. アーカイブしてアップロード
1. Xcode 上部デバイスを「Any iOS Device (arm64)」に → メニュー Product > Archive。
2. Organizer > Distribute App > App Store Connect > Upload（署名は Automatic）。
3. App Store Connect > TestFlight でビルドの処理完了（数分〜）を待つ。暗号化の質問は「標準の暗号化のみ」を選択。
4. 内部テスター（自分）を追加: App Store Connect > TestFlight > 内部テスト > グループ。iPhone の TestFlight アプリ https://apps.apple.com/jp/app/testflight/id899247664 からインストール。

### 3-3. TestFlight での確認項目
| # | 操作 | 期待 | テストID |
|---|---|---|---|
| 1 | 起動して数秒待つ。（欧州/米国州などで同意フォームが出る地域の場合は表示） | 下部に広告枠。広告が読み込めたら表示、できなければ空の枠 | T-022/039 |
| 1b | 初回起動（広告が表示できる地域）で、同意フォーム（出る地域のみ）→ **「トラッキングの許可」画面** の順に出る。「許可しない」でも全機能が使える | ATTは1回だけ表示される。再確認は iPhone 設定 > プライバシーとセキュリティ > トラッキング | B案 |
| 2 | 各タブ・ドラム・音声・読み上げ画面で広告枠の位置 | **全部同じ下端・同じ高さ**、停止ボタンと重ならない | T-022/023 |
| 3 | 設定 >「広告を非表示にする」→ 購入（TestFlight は自動でサンドボックス課金・無料） | 即座に全画面の広告枠が消える。履歴と設定は残る | T-026 |
| 4 | アプリを完全終了して再起動 | 広告は出ない | T-026 |
| 5 | アプリ削除→再インストール →「購入を復元」 | 広告なしが復元される（履歴は戻らない） | T-028 |
| 6 | （任意）Sandbox: 設定 > App Store > サンドボックスアカウント。App Store Connect > ユーザーとアクセス > Sandboxテスター で作成。保留/キャンセル/返金の確認はここ | 広告権利が正しく付与/失効 | T-027/029 |
| 7 | 機内モードで起動 | 広告は空枠、音・読み上げ・履歴は正常 | T-039 |

**テスト広告のまま出荷しない:** 本番ID登録直後は広告が出ない/少ないことがあります（AdMob 側の審査・在庫）。それは正常です。自分の端末で本番広告を何度もタップしない（アカウント停止の恐れ）。

## 4. 申請前の最終確認
`docs/11_RELEASE_CHECKLIST.md` を上から順に。App Store 審査メモ（App Review Information）に次を書く:
> 読み上げは iOS 標準の音声合成（端末内）を使用し、外部のAI/クラウドサービスは使用しません。履歴は端末内にのみ保存されます。広告非表示は非消耗型の App 内課金です。

## 困ったら
- Release が「Release guard」で失敗 → メッセージの項目（どのIDがおかしいか）を直す。
- 声が鳴らない/海外アクセント → iOS 設定 > アクセシビリティ > 読み上げコンテンツ > 声 > 日本語 で声をダウンロード。
- 上の結果（特に 1-2 の #5、#8、3-3 の結果）を送ってもらえれば、声のデフォルト選定・文字サイズ・ドキュメントを私が更新します。
