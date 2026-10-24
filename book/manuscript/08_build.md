# 第8章 ビルドとアップロード

## 8-1 ビルド番号の考え方

App Storeには、2種類の番号があります。

| 名前 | 例 | 意味 |
|---|---|---|
| バージョン（マーケティングバージョン） | 1.0 | ユーザーに見える番号。 |
| ビルド番号 | 1, 2, 3… | 同じバージョンの中の、提出物の通し番号。 |

**同じバージョンで、アップロードするたびに、ビルド番号を上げる**必要があります。同じ番号を、2回アップロードすることはできません。筆者は、`1.0` のまま、ビルド番号を2、3、4と上げて、アップロードしました。

Xcodeでは、ターゲットの「General」の「Build」、または、設定の `CURRENT_PROJECT_VERSION` です。**直し忘れると、アップロードで弾かれます。**

## 8-2 アーカイブとアップロード（Xcodeの画面）

1. Xcodeでプロジェクトを開く。
2. 実行先を **Any iOS Device (arm64)** にする（シミュレータでは、アーカイブできない）。
3. メニューの **Product → Archive**。数分かかる。
4. 完了すると、**Organizer** が開く。作ったアーカイブを選ぶ。
5. **Distribute App → App Store Connect → Upload** を選び、あとは「次へ」。署名は、Automatic（自動）でよい。
6. 「Upload Successful」と出れば、アップロード完了。

### 署名のつまずき

- Xcodeの、ターゲットの「Signing & Capabilities」で、Teamを選ぶ。
- 「Automatically manage signing」にチェックを入れておくと、証明書とプロビジョニングが自動で作られる。
- チームIDは、`Local.xcconfig` に `DEVELOPMENT_TEAM = XXXXXXXXXX` と書くと、リポジトリに載せずに済む。

## 8-3 コマンドラインでの方法（任意）

自動化したい人向けです。

```sh
xcodebuild -project App.xcodeproj -scheme App -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/App.xcarchive archive

cat > build/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>YOUR_TEAM_ID</string>
</dict></plist>
PLIST

xcodebuild -exportArchive -archivePath build/App.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist
```

認証が必要になるので、迷ったら、Organizerの画面のほうが確実です。

## 8-4 アップロードのあとに、何が起きるか

1. **処理中**：数分〜数十分。App Store Connectの「TestFlight」の画面に、ビルドが「処理中」で現れる。
2. **自動検証**：機械が形式を調べる。問題があれば、**メールが届く**（`ITMS-` の番号つき）。
3. **処理済み**：バージョンの画面で、選べるようになる。

**メールは、処理の数十分後〜数時間後に届くことがあります。** アップロードの直後に何も来なくても、安心しきらないでください。筆者の最初のメールは、アップロードの約10分後に届きました。

## 8-5 「Upload Symbols Failed」の警告

アップロードの画面で、次のような警告が出ることがあります。

```
Upload Symbols Failed
The archive did not include a dSYM for the GoogleMobileAds.framework ...
```

これは、**エラーではなく、警告**です。広告用の部品が、デバッグ用の記号情報（dSYM）を同梱せずに配られているためです。**審査にも、ビルドの有効性にも影響しません。** 影響があるのは、その部品の中でクラッシュしたとき、クラッシュ報告が読みにくくなる点だけです。そのまま進めて構いません。

## 8-6 ビルドを、バージョンに選ぶ

アップロードして処理が終わったら、App Store Connectで、バージョンの画面の **「ビルド」** の欄を開き、「+」から、**アップロードしたビルドを選んで、保存**します。

- 処理中のビルドは、選べない。
- **アップロードしただけでは、提出できない。** 「ビルドを選択してください」と言われて止まるのは、ここです。
- 暗号化の質問が出るときは、標準の暗号化（HTTPSなど）だけなら、「`ITSAppUsesNonExemptEncryption = NO`」を `Info.plist` に入れておくと、質問が出なくなる。**これは、あなた自身の申告になるので、内容に誤りがないことを確かめてから入れる。**

## ハンズオン：アーカイブ → アップロード → ビルドの選択

| # | やること | 成功の目安 |
|---|---|---|
| 1 | ビルド番号を、前回より大きくする | General の Build が、更新される |
| 2 | 実行先を Any iOS Device (arm64) にして、Product → Archive | Organizerに、新しいアーカイブが現れる |
| 3 | Distribute App → App Store Connect → Upload | 「Upload Successful」が出る（dSYMの警告は無視してよい） |
| 4 | App Store Connectの「TestFlight」を見る | ビルドが「処理中」→「処理済み」になる |
| 5 | メールを待つ | `ITMS-` のメールが**来ない**（来たら、第12章） |
| 6 | バージョンの画面の「ビルド」で、「+」→ ビルドを選んで保存 | ビルドの欄に、バージョンとビルド番号が出る |

**確認：** 手順6のあとで、バージョンの画面に、ビルドの行が見えれば成功です。

## 8-7 この章のチェックリスト

```
□ ビルド番号を、前回より大きくした
□ 実行先を Any iOS Device (arm64) にした
□ Archive → Distribute App → App Store Connect → Upload
□ 「Upload Successful」を確認した
□ 数時間は、自動検証のメール（ITMS-）を待つ
□ App Store Connectで、処理済みのビルドを選んで保存した
```

## この章のつまずき

| 症状 | 原因と対処 |
|---|---|
| アーカイブが選べない | 実行先がシミュレータ。Any iOS Device にする。 |
| アップロードが、ビルド番号の重複で弾かれる | ビルド番号を上げる。 |
| 「ビルドを選択してください」と言われる | アップロードだけでは足りない。バージョン画面で、ビルドを選んで保存。 |
| Upload Symbols Failed の警告 | 無害。進めてよい。 |
| ITMS-の番号つきのメールが来た | 第12章。番号を、そのまま調べる。 |
