# 08 — Xcodeプロジェクト構築・設定手順

## 1. 前提
- Mac + 最新の安定版Xcode（実環境で`xcodebuild -version`を記録）。iPhone実機1台以上。Apple Developer Program及びApp Store Connectへのアクセスは**公開時**に必要。
- iOS Deployment Target `17.0`。Devices `iPhone`。Supported orientations `Portrait`。UI language `Japanese`。
- SwiftUI App lifecycle、Swift、Swift Testing/XCTestなど実際のSDKとテスト方針に合わせる。
- 新規Xcodeプロジェクトと同名のSwiftターゲット `HeyDrum` を作成。**実際のBundle IDをユーザー所有の識別子で設定**。

## 2. 外部依存は最低限
- SwiftUI/AVFoundation/StoreKitは標準SDK。
- SPMで最新安定の **Google Mobile Ads SDK for iOS** を導入。Google公式のSwift Package URL・製品名をドキュメントで確認。`UserMessagingPlatform` はSDK/パッケージの指示に従って導入。古いブログ記事・非公式ライブラリを使わない。
- SDKは互換性のあるバージョンへ固定し `Package.resolved` をcommit。再現性確認。
- サードパーティ解析SDKや音声SDKを追加しない。

## 3. 開発用config
`AppConfig` のビルド環境を分ける。

```text
Development:
  AD_UNIT_ID=ca-app-pub-3940256099942544/2435281174
  ADS_TEST_MODE=true
  IN_APP_PURCHASE_PRODUCT_ID=EXAMPLE.REPLACE.ME.remove_ads
  GAD_APPLICATION_IDENTIFIER=(AdMobの**公式テストApp ID** または権限ある開発用ID)

Release:
  AD_UNIT_ID=(所有者発行の実広告UnitID)
  ADS_TEST_MODE=false
  IN_APP_PURCHASE_PRODUCT_ID=(App Store Connectで登録済の実商品ID)
  GAD_APPLICATION_IDENTIFIER=(所有者発行の実AppID)
```

- 具体値は `Secrets.xcconfig` またはBuild Settingから `Info.plist`へ展開。テンプレート `Config.example.xcconfig` と.gitignoreを用意。実IDが未設定なら**リリースビルドをFail**するチェックを追加。
- **公式GoogleテストバナーIDは公開アプリでは禁止**。広告テスト時は公式テストID/テストデバイスで実施する。
- IAP `HeyDrum.storekit` はXcodeのStoreKit Configurationで非消耗型商品を作成し、Unit/UIテストが行えるようにする。テスト価格は仮のものと本番と区別する。

## 4. アセット
- `assets/drum.wav`、`assets/metal.wav` を**コピーし、Build Phases Copy Bundle Resourcesに含める**。2音だけをUIから呼ぶ。
- App Iconはコードからの仮アイコンでもよいが、出荷前に独自素材を作成。写真の人物の肖像は流用しない。
- `reference/HeyDrum_UI_Mockup.png` は設計参照であり、App内へ画像として埋め込まない。
- Launch画面は白〜紙色の無装飾でよい。人物写真・楽器イラスト・AIマークを使わない。

## 5. 権限・システム設定
- **マイク許可不要**（録音・音声認識しない）。`NSSpeechRecognitionUsageDescription`も不要。
- `UIBackgroundModes=audio` は追加しない。
- AdMob App ID、必要時の `SKAdNetworkItems` やprivacy manifest、ATT説明文は**最新版SDK/配信形態の要求に従う**。不要な権限（位置情報/連絡先など）を追加しない。
- iOS画面表示はDynamic Type, safe area, Portraitに対応。
- ローカル履歴はアプリのcontainer内に保存。外部ストレージアクセス不要。

## 6. セキュリティ
- 入力文を広告SDK/URL query/クラッシュログに付与しない。
- 商品価格をリモートから勝手に上書きしない。StoreKitの `displayPrice` が正本。
- ユーザー文字列を不必要にnetwork通信へ渡すAPI設計を禁止。
- SDKが要求する正当な設定以外のATS例外は追加しない。

## 7. 再現可能ビルドと自動チェック
`HeyDrum.xcodeproj` を作った場合の例（workspaceなら `-workspace` へ変える）:

```bash
xcodebuild -list -project HeyDrum.xcodeproj
xcodebuild -project HeyDrum.xcodeproj -scheme HeyDrum \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project HeyDrum.xcodeproj -scheme HeyDrum \
  -destination 'platform=iOS Simulator,name=<installed simulator>' test
```

- `<installed simulator>` は `xcrun simctl list devices available`で決める。固定の架空モデル名を使わない。
- 実機で `run` / 2音 / Japanese TTS / バナー / StoreKit sandbox を確認。
- READMEに環境、Xcode版、bundle ID設定手順、AdMob setup、StoreKit config、ビルドと実機テスト方法、未決事項を書く。

## 8. App Store Connectで別途行う作業
1. App登録、Bundle ID、署名チーム、権限。
2. 非消耗型IAP `広告を非表示` を設定し商品ID/価格を確定。
3. AdMobでApp・広告Unit作成、アプリ紐付け、必要に応じapp-ads.txtなど配信準備。
4. 日本語説明、キーワード、スクリーンショット、アイコン、サポート/プライバシーポリシーURL、App Privacyを用意。
5. 必要な地域の同意ダイアログ、課金Sandbox、TestFlightで検証。
6. App Reviewの追加説明として「音声読み上げはApple内蔵TTS・ローカル履歴、広告除去は非消耗型課金」を記載できる状態にする。

## 9. 実装担当が報告する環境情報
```text
Xcode version:
Swift toolchain:
iOS deployment:
Simulator tested:
Real device OS:
Bundle identifier:
StoreKit product ID (not personal/secret):
AdMob configured? DEV / PROD / not configured
Build command + outcome:
Test command + passed/failed/skipped:
```
