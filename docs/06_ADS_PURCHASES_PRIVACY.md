# 06 — バナー広告・課金・プライバシー詳細

## 1. 対象と原則
無料アプリ。音声生成は無料・外部AIなし。収益化は下部バナー1箇所と広告解除の**一回限り買い切り**のみ。音声入力・履歴・音量機能を課金制にしない。広告視聴で機能ロック解除などは行わない。

## 2. 広告SDK
- Google Mobile Ads SDKをSPM導入。iOS版公式の **anchored adaptive banner** を採用。SDKのSwift名・APIは導入時の公式サンプルに合わせる（旧 `GADBannerView` と新 `BannerView` など表記差あり）。
- **開発中テストUnitID:** `ca-app-pub-3940256099942544/2435281174`（Google公式テスト用）。本番の実広告IDはユーザーが発行する。テストと本番の混在禁止。
- AdMob App IDはInfo.plist `GADApplicationIdentifier` 等に設定（実値を `Secrets.xcconfig` でinjectしGit管理から除外）。
- `AdSlotView` はAppShellに**1つのみ**。画面ごとにbannerを生成し直してジャンプ・ダブルロードを起こさない。
- スロット高は `standardAnchoredAdaptive` の実サイズから決め、**同一device geometryで固定**。幅変更時だけ再計算。読上げ画面とホームで共通。
- バナーがロード失敗/在庫なし/オフラインでもread-aloud処理を停止させず、落ち着いた空スロットにする。SDKの仕様上広告が無い時に余白を畳む挙動を選ぶと「全画面同じ場所」に矛盾するためv1では空スロットを維持。
- キーボードが出ているときの広告は隠し（UI-03明示例外）、閉じたら再表示。隠す/再表示で毎回広告を新規リクエストしない。
- アドSDKが返した広告を内容・サイズで不正に改変しない。広告クリックの誤誘導・誤配置防止（大ボタンとの間に十分な余白）。
- 購入済みは**AdMob広告ロードしない**。既ロードBannerViewは破棄し共通フッターごと削除。

## 3. プライバシー同意
- `UserMessagingPlatform` (UMP)を公式手順に従って導入し、毎回起動時に最新のConsentInformation更新/必要フォーム表示を実施。
- `canRequestAds == true` になるまで広告リクエストしない（旧セッション有効同意を含む）。例外設計は承認なしで作らない。
- 「プライバシー設定」が求められる地域/状態では設定画面から再表示できる導線を用意。
- App Tracking Transparency (ATT)は**他社アプリやWebサイトを横断したトラッキングを実際に行う場合**に適切な説明文とユーザー許可を要求する。『非パーソナライズ広告だから常にATT不要』とも『AdMobだから常に必要』とも即断しない。組込SDKの実際のデータ流とAppleガイドで検証。
- 初期方針: 行動ターゲティングよりプライバシー重視。対象地域・AdMobの設定に応じ非パーソナライズ/制限付き広告など合法的に配信できる方法を検討。合意が必要なのに拒否・未確定ならロードしない。
- 音声の入力テキスト・履歴を **広告リクエストに渡すことは絶対禁止**。
- App Store ConnectのApp PrivacyはSDK収集内容も含めて申告。プライバシーポリシーURLと `PrivacyInfo.xcprivacy` / SDK署名・manifest要件を配布時確認。

## 4. StoreKit 2商品
- 種類: **non-consumable** (非消耗型)、買い切り、非サブスク。
- 商品ID: `YOUR_BUNDLE_ID.remove_ads` は例。発行したIDを `AppConfig` から参照。実価格はApp Store Connectで設定。
- 画面には `Product.displayPrice` で取得した現地価格と `一度の購入で広告を非表示`、必要に応じ「購入を復元」。購入前に独自の金額ハードコードなし。
- 商品ロード不能時: 購入ボタン無効、`現在購入情報を取得できません`。無料機能はそのまま使える。
- StoreKit config `HeyDrum.storekit` をテストターゲットに追加し、購入・取消・pending・refund・restoreを検証。

## 5. 権利判定フロー
- 起動直後 `entitlement = checking`。`Transaction.updates` を常時監視し、`Transaction.currentEntitlements` を列挙。verified・正しいproductID・非revokedのtransactionだけ `purchased` とする。
- 判定に失敗した場合は `unavailable` として再試行導線。購入済みユーザーに広告を誤表示しないため、未判定で広告リクエストしない。
- 購入結果 `.success(.verified(tx))` の際、商品ID確認→権利反映→`await tx.finish()`→ entitlements再評価。
- `.pending` は権利を付与せず保留説明、`.userCancelled` は静かに元画面、`.unverified` は不正と判断して権利を与えずエラー表示。
- 返金/revocationが確認された場合は正しい状態に戻す。`Transaction.updates` イベントだけでなく前景復帰時にも必要に応じ再評価。
- 復元ボタン `AppStore.sync()` は**ユーザーがタップした時だけ**実行（システム認証を伴う場合がある）。実行後に currentEntitlementsを再読。購入済みでない場合も説明を返す。
- 誤ってボタンを連打して二重課金画面を出さないよう実行中はdisabled。

## 6. 画面間での挙動
```text
                     StoreKit verified entitlement
                  ┌────────────┬─────────────┐
                  │ purchased  │ free        │
                  ▼            ▼             │
          no ad slot       consent process    │
                               │              │
                               ▼              │
                         canRequestAds?       │
                         yes → load banner    │
                         no  → blank slot     │
                                              │
                 All screens share one AppShell ad slot
```
`settings` で購入完了→ `AppShell`が広告スロット削除→読み上げ画面にも即座に反映。再生状態への影響はゼロ。

## 7. アプリ内表示・法的情報
- プライバシーポリシーは公開URLにホスト。入力文章が端末にローカル保存されること、広告SDKが別途データを収集し得ること、課金はAppleによって処理されること、購入復元、問い合わせ先を含める。
- Terms/プライバシー・広告同意オプションは必要に応じ追加。
- OSのSpeech合成で使った音声を外部サービスへ送信しない設計。利用したAPIによるシステム内部のデータ処理はAppleの公表に従う。
- 広告SDK・IAPの審査要件、地域法令は申請時の最新文書に従い更新する。

## 8. テスト（必須）
1. テストバナーが全画面の下側同一位置に表示。
2. 読上げ中もバナーが前面に固定、停止ボタンとの重なりなし。
3. 通信無し/広告失敗時も2効果音と読み上げ・履歴が正常。
4. 初回同意拒否時広告リクエスト無し、同意更新可能。
5. 購入済みは即座に全画面広告が消え、再起動後も表示されない。
6. sandbox購入/取消/pending/購入復元/返金（模擬）を確認。
7. 端末再インストールでは購入権利を復元できるが履歴はクラウドで自動復元すると保証しない。
8. 購入後も履歴・音声設定はそのまま。
