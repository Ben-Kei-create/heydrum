# ハンズオン: ビルドから申請まで（共通）

所要の目安: 初回は半日〜1日（Appleの契約・口座の承認待ちを除く）。2回目以降は1〜2時間。

## 0. 全体の順番（チェックリスト）
```
□ A. 先にやる（待ち時間があるもの）
  □ Apple Developer Program に加入（年額）
  □ App Store Connect「ビジネス」で『有料App契約』を承認（Account Holder が実施。口座・税務も）
□ B. 登録
  □ Bundle ID を Developer サイトで登録（変更不可）
  □ App Store Connect で「新規App」を作成
  □ （課金あり）アプリ内課金の商品を作成（製品IDは変更不可）
  □ （広告あり）AdMob でアプリ+広告ユニット作成、同意メッセージ（UMP）を設定
□ C. 公開ページ
  □ プライバシーポリシー URL（https の公開URL）
  □ サポート URL（https の公開URL、連絡先入り）
□ D. コード側
  □ 秘密の設定を git 管理外へ（Secrets.xcconfig）
  □ リリースガード（空・テストID・テンプレート値でReleaseを失敗させる）
  □ 権限・暗号化・プライバシーマニフェスト・フォント等ライセンス表記
□ E. ビルド
  □ Archive → アップロード → ビルドが「処理済み」になるのを待つ
□ F. App Store Connect の入力（下の§5）
□ G. 提出 → 審査 → リリース
□ H. TestFlight で実機確認（提出前でも可）
```

## 1. 契約（最初に。ここで止まる人が多い）
- https://appstoreconnect.apple.com/business → 「契約」→ **有料App契約（Paid Applications）** を承認。無料アプリ（課金・有料なし）でも、**アプリ内課金を作るなら必須**。
- 承認できるのは **Account Holder（Legalロール）** だけ。先に https://developer.apple.com/account で最新の Apple Developer Program License Agreement に同意しておく。
- 口座・税務情報は個人情報なので自分で入力。入力完了まで状態が「処理中」でも、課金商品の作成は進められることが多い。

## 2. Bundle ID・アプリ・課金商品
1. https://developer.apple.com/account/resources/identifiers/list →「+」→ App IDs → App → Explicit。**逆ドメイン形式**（例 `com.yourname.appname`）。
2. https://appstoreconnect.apple.com/apps →「+」→ 新規App。
   - プラットフォーム／名前／プライマリ言語／バンドルID（上で登録したもの。一覧に出ないときは再読込）／SKU（任意の文字列）
   - **ユーザアクセス**: 個人開発なら「アクセス制限なし」
3. 課金: 対象App > 収益化 > アプリ内課金 >「+」。広告除去などは**非消耗型**。製品ID＝`<BundleID>.remove_ads` のように決める（**登録後は変更不可**）。表示名30字・説明45字・審査用スクショ（設定画面など）が必要。

## 3. 広告（AdMob を使う場合）
- https://admob.google.com → アプリを追加（iOS）→ **アプリID** を控える → 広告ユニット（バナー等）を作成 → **広告ユニットID** を控える。
- 「プライバシーとメッセージ」で同意メッセージ（UMP）を作って**公開**（未設定だと地域により広告が出ない）。
- 開発中は **Google公式のテストID** だけを使う。**自分の本番広告を自分でタップしない**（アカウント停止の恐れ）。
- 本番IDは **リポジトリにコミットしない**（`Config/Secrets.xcconfig` を `.gitignore`）。

## 4. ビルドとアップロード
### 4-1. 秘密の設定とリリースガード
`Secrets.xcconfig`（git管理外）に本番値を置き、Releaseで空・テストID・テンプレート値だったらビルドを失敗させる（`tools/release_guard.sh`、テストは `tools/test_release_guard.sh`）。Run Script Phase から `exec "$SRCROOT/tools/release_guard.sh"` を呼ぶ（スクリプトのサンドボックスを使う場合は inputPaths に登録）。

### 4-2. Xcode でアップロード（GUI）
1. 実行先を **Any iOS Device (arm64)** にする。
2. Product > **Archive**。
3. Organizer > **Distribute App > App Store Connect > Upload** → 「次へ」（署名は Automatic でよい）。
4. 数分〜数十分でApp Store Connectの「ビルド」に現れる（メールが届く）。

### 4-3. コマンドラインでアップロード（任意）
```bash
xcodebuild -project App.xcodeproj -scheme App -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/App.xcarchive archive
cat > build/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>YOUR_TEAM_ID</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath build/App.xcarchive -exportOptionsPlist build/ExportOptions.plist
```
（Apple IDの認証が必要。迷ったらGUIが確実。）

### 4-4. 「ビルドを選択してください」で止まるとき
アップロード後、バージョン画面の「**ビルド**」欄で「+」からビルドを選んで**保存**。処理中は選べない。**暗号化の質問**は、標準の暗号化のみなら `Info.plist` に `ITSAppUsesNonExemptEncryption = NO` を入れておくと出なくなる（自分の申告なので内容に誤りがないこと）。

## 5. App Store Connect の入力（このとおり埋める）
| 場所 | 入力 |
|---|---|
| アプリ情報 | サブタイトル、カテゴリ、**プライバシーポリシーURL（https公開URL）**、著作権、年齢制限 |
| **コンテンツ配信権** | 第三者の素材（フォント・画像・音・広告SDK）を含むなら「**はい、必要な権利を保有**」。ライセンスが許す素材だけを使うこと |
| バージョン情報 | プロモーションテキスト、説明文、キーワード、最新情報、**日本語のサポートURL（必須）** |
| **プレビューとスクリーンショット** | サイズごとに別の欄。**2つ以上のサイズを求められることがある**（下の表と`03_REFERENCE.md`）。 |
| **ビルド** | 4-4 |
| **アプリのプライバシー** | データ収集の回答（SDK含む）→ **保存 → 「公開」まで**押す |
| アプリ内課金 | 各商品のメタデータ・審査用スクショ・審査メモ |
| App Review情報 | 連絡先（氏名・電話は **+81 90 1234 5678** の形式）、審査メモ、サインイン不要ならオフ |
| 価格と配信 | 無料／価格、配信地域、手動リリースか自動か |
最後に右上「**審査用に追加**」。エラーがあれば画面上部に項目名が出る。全部消えるまで直す。

## 6. 提出後
- 状態: 審査待ち → 審査中 → 承認（または却下）。目安は24〜48時間。
- 却下されたら、**Resolution Center** のメッセージに返信か、修正して再提出。典型例は `03_REFERENCE.md`。
- リリース方式（承認後すぐ／手動）は「バージョンのリリース」で設定。

## 7. 実体験からのつまずき集
| 症状 | 原因と対処 |
|---|---|
| 課金商品が作れない／アプリ更新ができない | 有料App契約が未承認。§1 |
| 新規アプリのバンドルID一覧に出ない | Developer サイトで未登録、または画面の再読込が必要 |
| プライバシーポリシーURLが「形式が正しくありません」 | ローカルのファイルパスではなく `https://` から始まる**公開URL**が必要。GitHub Pages 等で公開 |
| 「サポートURLは必須」 | 日本語のサポートURL（連絡先入りの公開ページ）が必要 |
| 「Dynamic Island 搭載iPhone（中型ディスプレイ）のスクショが必要」 | **6.3インチ**（1206×2622）の欄。6.9インチ（1320×2868）とは別にアップロード |
| 「審査用に追加できません: ビルドを選択」 | アップロードしただけでは不足。バージョン画面でビルドを選んで保存 |
| 「アプリのプライバシー」を入力したのに反映されない | **保存後に「公開」** を押していない |
| シミュレータでテストが始まらない・極端に遅い | シミュレータを `simctl shutdown`→`boot`。Macの負荷（他アプリ）も確認 |
| 画面録画が空／長すぎる | `simctl io recordVideo` は別プロセスで確実に SIGINT で止める。難しければ静止画をffmpegでつなぐ |
| StoreKitテストが1回目だけ失敗 | 起動直後のレースやシミュレータ状態。状態をリセットして再実行、テスト側で商品読み込みをリトライ |

## 8. 公開ページ（無料・簡単）の作り方
1. https://github.com/new で **Public** のリポジトリ（例 `appname-site`）を作る。
2. `index.html`（サポート: FAQ＋連絡先）と `privacy-policy.html` を置く。ひな形は Claude に作らせる（`02` のプロンプト）。
3. Settings > Pages > Branch `main` / `/ (root)`。数分で `https://<ユーザー名>.github.io/<リポジトリ名>/` が見える。
4. **メールアドレスと提供者名は公開される**（消してもキャッシュに残る）。アプリ専用のアドレスを使うと安全。
- Claude Code から作る場合は `gh repo create <name> --public --source . --push` と `gh api -X POST repos/<owner>/<name>/pages -f "source[branch]=main" -f "source[path]=/"`（**公開は必ず本人の了承を取ってから**）。
