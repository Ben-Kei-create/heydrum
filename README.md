# ヘイドラム (HeyDrum)

iPhone専用・SwiftUI。2つの音を鳴らす「ドラムモード」と、Apple標準のTTSで文章を読み上げる「音声モード」。
広告は AdMob/UMP のアンカー型アダプティブバナー(AppShell共通・1枠)、広告除去は非消耗型IAP(StoreKit 2)。
設計正本は `docs/`(DesignPack v1.0)。判断記録は `docs/DECISIONS_LOG.md`、要件対応は `docs/12_TRACEABILITY.md`、検証結果は `docs/VERIFICATION.md`。

## 環境
- Xcode 27.1 / iOS Deployment Target 17.0 / Swift 5 mode / iPhone・縦固定
- 依存: Google Mobile Ads SDK 13.11.0 (SPM, UMP 3.1.0 を同梱依存)。`Package.resolved` をコミット済み。

## ビルド・テスト
```bash
xcodebuild -project HeyDrum.xcodeproj -scheme HeyDrum -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available   # 使えるシミュレータ名を確認
xcodebuild -project HeyDrum.xcodeproj -scheme HeyDrum -destination 'platform=iOS Simulator,name=<name>' CODE_SIGNING_ALLOWED=NO test
```

## 設定 (所有者作業)
1. `Config/Local.xcconfig`(git管理外)に `DEVELOPMENT_TEAM = ...`、必要なら `HEYDRUM_BUNDLE_ID`。
2. Debug は Google 公式テストID + `HeyDrum.storekit`(仮商品 `example.heydrum.dev.remove_ads`)で動作。
3. Release は `Config/Config.example.xcconfig` を `Config/Secrets.xcconfig` にコピーして実IDを設定。空・テストID・仮ID のままだと **Release guard ビルドフェーズが失敗**する。
4. App Store Connect に同じ商品IDの非消耗型IAPを作成。`AppConfig.privacyPolicyURL` に公開URLを設定。
5. 実機確認(音声の声質・機内モード・広告・Sandbox課金)は `docs/11_RELEASE_CHECKLIST.md`。

## 未確定 / 未検証
実機での声質・機内モード・音量、AdMob本番ID、IAP実価格、プライバシーポリシーURL、TestFlight/Sandbox課金は未実施。`docs/VERIFICATION.md` 参照。
