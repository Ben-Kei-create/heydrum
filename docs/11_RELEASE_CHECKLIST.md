# 11 — 出荷チェックリスト

## ビルドと安定性
- [ ] Xcodeバージョン、iOSターゲット、Swift toolchain確認
- [ ] iPhone simulator Build/Test pass（logs有）
- [ ] iPhone実機（小型/大型の可能な範囲）で試験
- [ ] アプリ名「ヘイドラム」、肖像・楽器・AI風装飾が無い
- [ ] 2つの音だけ、連打、安全なピーク/端末音量
- [ ] 日本語読み上げ（機内モード実機含む）、声質の主観受入
- [ ] 最大500文字、500文字表示/停止/スクロール/VoiceOver
- [ ] 履歴100件、削除、再生、再起動、読み書き異常系
- [ ] 音量0/70/100%、日本語音声fallback
- [ ] 中央の再生/一時停止、右下の停止で元画面に戻る
- [ ] 読上げ画面も広告位置同一（未課金）

## 広告・課金
- [ ] 自分のAdMobアカウントでApp ID/Unit ID発行
- [ ] Privacy & Messaging/UMPに必要なメッセージを設定
- [ ] 実際に収集するデータとATT/Consent適用を確認
- [ ] 開発時テスト広告のみ、出荷時に実UnitIDのみ
- [ ] 買い切りIAP非消耗型商品作成、Product ID一致
- [ ] 商品価格はStoreKitのlocalized `displayPrice`
- [ ] 購入成功・保留・取消・復元・返金を検査
- [ ] 購入後広告枠がすべて消え、広告SDKは再リクエストしない
- [ ] StoreKit権利判定の未検証・不明は偽の購入判定をしない

## プライバシー・レビュー・メタデータ
- [ ] プライバシーポリシーURLが公開でアクセス可能
- [ ] サポートURL、連絡先を準備
- [ ] App PrivacyをSDKの実収集データを含め申告
- [ ] PrivacyInfo.xcprivacy/署名/SDK規則を確認
- [ ] 必要なSKAdNetwork/ATT設定を現行SDKに合わせる
- [ ] スクリーンショット、アイコン、説明、App Storeカテゴリ、年齢区分
- [ ] TestFlight配信テスト、TestFlight課金と広告の検証
- [ ] CodexレビューでP0/P1未解消なし
- [ ] 実際の料金/本番設定を所有者が確認
- [ ] `git status` clean、秘密情報漏洩なし

## 未確定欄
```text
Actual bundle identifier:
Developer team ID (private, don't publish in repo):
IAP product ID:
IAP selling price/territories:
Production AdMob App ID (in build secret):
Production banner ad unit (in build secret):
Privacy policy URL:
Japanese default voice ID verified on device:
Official target Xcode version:
Release version/build number:
Release date:
```

## 最終判定
`GO` は全チェックと所有者実機受入後。`NO-GO` はP0未達・誤課金/偽購入判定・無同意の広告リクエスト・本文漏洩・音声停止できない・広告重複のいずれかを含む状態。
