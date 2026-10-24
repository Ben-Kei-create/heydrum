# 第6章 秘密の設定と、リリースガード

提出の前に、**テスト用の値のまま本番に出してしまう事故**を、仕組みで防ぎます。人が気を付けるより、ビルドが失敗するほうが確実です。

## 6-1 設定を3つに分ける

アプリには、3種類の値があります。

| 種類 | 例 | どこに置く |
|---|---|---|
| 公開してよい値 | 画面の文言、色 | ソースコード |
| 環境で変わる値 | 広告ユニットID、製品ID、Bundle ID | **xcconfig**（設定ファイル） |
| 秘密にしたい値 | 本番の広告ID、チームID | **gitに入れない** xcconfig |

広告IDやチームIDは、パスワードのように秘密ではありません（アプリを解析すれば見える）。それでも、**公開リポジトリに載せないほうが安全**で、テスト用と本番用の取り違えも防げます。

## 6-2 xcconfig の構成

```
Config/
  Debug.xcconfig          ← 開発用（Googleのテスト用IDなど）。コミットする
  Release.xcconfig        ← 空にしておく。コミットする
  Config.example.xcconfig ← 見本。コミットする
  Secrets.xcconfig        ← 本番の値。.gitignore で除外
  Local.xcconfig          ← チームIDなど。.gitignore で除外
```

`Debug.xcconfig` の例（テスト用の値）：

```
HEYDRUM_BUNDLE_ID = example.app.dev
AD_UNIT_ID = ca-app-pub-3940256099942544/2435281174
ADS_TEST_MODE = YES
IN_APP_PURCHASE_PRODUCT_ID = example.app.dev.remove_ads
GAD_APPLICATION_IDENTIFIER = ca-app-pub-3940256099942544~1458002511
#include? "Local.xcconfig"
```

`Release.xcconfig` の例（空にして、秘密のファイルを読み込む）：

```
HEYDRUM_BUNDLE_ID =
AD_UNIT_ID =
ADS_TEST_MODE = NO
IN_APP_PURCHASE_PRODUCT_ID =
GAD_APPLICATION_IDENTIFIER =
#include? "Local.xcconfig"
#include? "Secrets.xcconfig"
```

`#include?` は、ファイルがなくてもエラーにしない書き方です。`.gitignore` には次を入れます。

```
Config/Secrets.xcconfig
Config/Local.xcconfig
```

### xcconfig の落とし穴

xcconfigでは、`//` から行末までが**コメント**になります。URLのような値（`https://...`）をそのまま書くと、途中から消えます。広告IDの `/` は1つなので大丈夫ですが、**URLを置くときは注意**してください。

## 6-3 Info.plist に値を渡す

xcconfigの値を、アプリの中で読むには、`Info.plist` に変数として書きます。

```xml
<key>GADApplicationIdentifier</key>
<string>$(GAD_APPLICATION_IDENTIFIER)</string>
<key>MyAdUnitID</key>
<string>$(AD_UNIT_ID)</string>
```

コードからは、`Bundle.main.object(forInfoDictionaryKey:)` で読みます。**ソースコードの中に、IDを書きません。**

## 6-4 リリースガード：テスト用の値で、Releaseを作らせない

Releaseのビルドが、次のどれかのとき、**ビルドを失敗させる**スクリプトを入れます。

- 必要な値が空。
- Googleのテスト用ID（`3940256099942544` を含む）が残っている。
- 見本のままの値（`XXXX`、`yourcompany`、`example`、`REPLACE` など）。
- IDの形式が不正（広告ユニットIDは `ca-app-pub-` ＋16桁 ＋ `/` ＋10桁、アプリIDは `~`）。
- 広告のテストモードが、オン。

```sh
#!/bin/sh
[ "$CONFIGURATION" = "Release" ] || exit 0
fail() { echo "error: Release guard: $1"; exit 1; }
for v in AD_UNIT_ID GAD_APPLICATION_IDENTIFIER IN_APP_PURCHASE_PRODUCT_ID BUNDLE_ID; do
  eval "val=\${$v}"
  [ -n "$val" ] || fail "$v is empty"
done
case "$AD_UNIT_ID$GAD_APPLICATION_IDENTIFIER" in *3940256099942544*) fail "Google TEST ad ids must not be used in Release";; esac
case "$AD_UNIT_ID$GAD_APPLICATION_IDENTIFIER$IN_APP_PURCHASE_PRODUCT_ID$BUNDLE_ID" in
  *XXXX*|*[Yy]ourcompany*|*example*|*EXAMPLE*|*REPLACE*|*placeholder*) fail "template value left in Release";;
esac
echo "$AD_UNIT_ID" | grep -Eq '^ca-app-pub-[0-9]{16}/[0-9]{10}$' || fail "AD_UNIT_ID format"
echo "$GAD_APPLICATION_IDENTIFIER" | grep -Eq '^ca-app-pub-[0-9]{16}~[0-9]{10}$' || fail "app id format"
[ "$ADS_TEST_MODE" = "NO" ] || fail "ADS_TEST_MODE must be NO in Release"
exit 0
```

これをXcodeの「Build Phases」に「Run Script」として追加し、`"$SRCROOT/tools/release_guard.sh"` を呼びます。**スクリプトのサンドボックスを有効にしている場合は、スクリプトと、読むファイルを「Input Files」に登録**してください（登録しないと、読めずに失敗します）。

### ガードのテストを書く

ガードが正しく弾くかは、**ガード自体のテスト**で確かめます。値を変えながら、成功する場合と失敗する場合を、それぞれ確かめるスクリプトです。筆者は、「空」「Googleのテスト用ID」「見本の値」「形式不正」「テストモード」「Debugは弾かない」など、20のケースを用意しました。ガードを直したときに、他のケースを壊していないか、すぐに分かります。

実際、後からガードに新しいチェックを足したとき、**挿入の場所を間違えて、他のチェックを全部すり抜けるようにしてしまいました。** ガードのテストが、その場で教えてくれました。

## ハンズオン：「失敗するはずのビルド」を、わざと作る

リリースガードは、**失敗することを確かめる**のが、一番大事です。

| # | やること | 成功の目安 |
|---|---|---|
| 1 | `Config/Secrets.xcconfig` を、いったん退避して、Releaseでビルドする | `error: Release guard: AD_UNIT_ID is empty` で、**ビルドが失敗する** |
| 2 | Googleのテスト用IDを入れて、Releaseでビルドする | `Google TEST ad ids must not be used in Release` で失敗する |
| 3 | 見本の値（`ca-app-pub-XXXX...`）を入れて、Releaseでビルドする | `template value left in Release` で失敗する |
| 4 | 形式の正しい（ダミーの）値を入れて、Releaseでビルドする | **成功する** |
| 5 | ガードのテストスクリプトを実行する | `release_guard tests: 20 passed, 0 failed` のように、全部通る |

**確認：** 1〜3が失敗し、4が成功すれば、仕組みが働いています。**ダミー値を、実際の提出に使わないでください。**

## 6-5 この章のチェックリスト

```
□ 本番の値は Secrets.xcconfig（gitの外）にある
□ Release.xcconfig は空で、Secrets を読み込む
□ ソースコードに、IDや製品IDを直接書いていない
□ リリースガードを Build Phases に入れた（Input Files も登録）
□ ガードのテストがある
□ 空のままの Release ビルドが、実際に失敗することを確かめた
```
