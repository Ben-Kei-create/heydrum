# 付録G ヘイドラムの実例集

この付録は、筆者が実際に提出したアプリ「ヘイドラム」の、**入力した文言、設定、コード**です。書き方の見本として使ってください。氏名や連絡先などは、伏せ字にしてあります。

## G-1 ストアの文言

**サブタイトル（30文字まで）**

```
2つの音と、大きな文字の読み上げ
```

**プロモーション用テキスト（170文字まで）**

```
ボタンひとつで音を鳴らし、入力した文字を大きく読み上げます。離れた場所の相手にも伝わる大きな文字で表示。読み上げの開始タイミングも選べます。
```

**説明文（4,000文字まで）**

```
ヘイドラムは、「音を鳴らす」と「文字を読み上げる」だけに絞った、とてもシンプルなアプリです。

■ ドラムモード
「ドラム音」と「金属音」、2つの大きなボタンをタップするだけ。連打もOKです。

■ 音声モード
読み上げたい文字を入力して「読み上げ開始」。画面いっぱいの大きな文字で表示しながら、iPhone標準の日本語音声で読み上げます。
・文字は短いほど大きく、遠くの人にも読みやすい
・「すぐ／3秒後／5秒後／10秒後／15秒後／30秒後」から開始タイミングを選べる
・一時停止、再開、もう一度読み上げ
・読み上げ中は白い画面に文字だけを表示。右下の「停止」でいつでも元の画面へ

■ 履歴
読み上げた文章は最大100件まで端末内に保存。ワンタップで再生できます。

■ 設定
・音量の調整
・日本語の音声の選択、読み上げ速度（ゆっくり／標準／速め）
・広告の非表示（買い切り）と購入の復元

■ プライバシー
入力した文章と履歴は端末の中だけに保存され、外部へ送信されません。読み上げにクラウドやAIサービスは使いません。インターネット接続がなくても、端末に日本語音声があれば読み上げできます。

※声の種類は、お使いのiPhoneにインストールされている日本語音声によって決まります。
※無料でご利用いただけます。広告を表示します（買い切りで非表示にできます）。
```

**キーワード（100文字まで）**

```
読み上げ,音声,テキスト,大きな文字,ドラム,効果音,アナウンス,音読,タイマー,シンプル,ボタン,日本語
```

**このバージョンの最新情報**

```
初回リリースです。
```

**審査メモ**

```
読み上げは iOS 標準の音声合成（端末内）を使用し、外部のAI／クラウドサービスは使用しません。入力した文章と履歴は端末内にのみ保存されます。広告は Google AdMob（初回に同意画面が出る地域があります）、広告非表示は非消耗型の App 内課金です。ログインは不要です。
```

## G-2 アプリ内課金（非消耗型）の入力

| 項目 | 入力した値 |
|---|---|
| 参照名 | 広告を非表示 |
| 製品ID | `<Bundle ID>.remove_ads` の形（登録後は変更できない） |
| 表示名（30文字まで） | 広告を非表示 |
| 説明（45文字まで） | 広告を非表示にします（買い切り） |
| 審査メモ | 設定タブの「広告を非表示にする」から購入できます。購入すると下部の広告バナーが消えます。 |
| ファミリー共有 | オフ |

## G-3 「Appのプライバシー」の回答

**最初の質問：「データを収集しますか」→ はい**

| カテゴリ | 項目 | 用途 | ユーザーに紐づく | トラッキングに使う |
|---|---|---|---|---|
| 位置情報 | おおよその場所 | サードパーティ広告、分析 | はい | はい |
| ID | デバイスID | サードパーティ広告、分析 | はい | はい |
| 使用状況データ | 製品の操作 | サードパーティ広告、分析 | はい | はい |
| 使用状況データ | 広告データ | サードパーティ広告、分析 | はい | はい |
| 診断 | クラッシュデータ | 分析、アプリの機能 | いいえ | いいえ |
| 診断 | パフォーマンスデータ | 分析、アプリの機能 | はい | いいえ |

**収集しないもの：** 連絡先情報、健康、財務、詳細な位置情報、機密情報、連絡先、**ユーザコンテンツ（入力した文章は端末内のみ）**、閲覧履歴、検索履歴、ユーザID、購入（課金はAppleが処理）、その他。

これは、広告SDKの公式の開示に基づく**保守的な回答**です。「トラッキングに使う」は、Appleの定義に照らして、最終的にはあなた自身が判断してください。

## G-4 プライバシーマニフェスト（提出した最終版）

```xml
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

アプリ側は、`NSPrivacyTracking` を `false`、ドメインのキーは無し。広告用のSDKが、自分のマニフェストを持っています（第7章）。

## G-5 公開ページ

### サポートページ（`index.html` の内容）

#### ヘイドラム サポート

2つの音を鳴らし、文字を大きく読み上げる iPhone アプリです。

#### よくある質問

**声が鳴らない／海外アクセントになる**
iOS の「設定 > アクセシビリティ > 読み上げコンテンツ > 声 > 日本語」で声をダウンロードし、アプリの「設定 > 音声」で選び直してください。

**音が小さい**
アプリの「設定 > 音量」と、iPhone 本体の音量・消音スイッチを確認してください。

**広告を消したい／購入を復元したい**
「設定 > 広告を非表示にする」（買い切り）。機種変更や再インストール後は「設定 > 購入を復元」。

**履歴を消したい**
履歴タブで左にスワイプ、または右上の「すべて削除」。履歴は端末内にのみ保存されています。

#### お問い合わせ

（連絡先メール）

プライバシーポリシー

### プライバシーポリシー（`privacy-policy.html` の内容）

#### ヘイドラム プライバシーポリシー

制定日: 2026年10月22日 / 提供者: （提供者名）

#### 1. 入力した文章と履歴

「音声モード」で入力した文章と、読み上げの履歴（最大100件）は、お使いの端末の中にのみ保存されます。当方のサーバーへ送信することも、広告や分析のために利用することもありません。アプリを削除すると、これらのデータは失われます。

#### 2. 音声の読み上げ

読み上げには iOS 標準の音声合成機能を使用します。外部のAIサービスやクラウド音声サービスは使用しません。

#### 3. 広告

本アプリは Google AdMob により広告を表示します。広告の配信にあたり、Google が広告ID・端末情報・IPアドレスから推定されるおおよその場所・広告の表示や操作の情報・クラッシュ/性能情報などを収集することがあります。入力した文章や履歴が広告のために送信されることはありません。地域によっては、初回起動時などに同意の確認画面が表示され、アプリの「設定 > プライバシー設定」から変更できます。Google のデータの取り扱いについては https://policies.google.com/technologies/partner-sites をご覧ください。

**広告のパーソナライズと「トラッキングの許可」:** 広告をお客様に合わせて表示するために、広告識別子（IDFA）を使用する場合があります。iOS の「トラッキングの許可」画面で「許可しない」を選ぶと、広告識別子は使われません（広告は引き続き表示されますが、関連度が下がることがあります）。この選択は iPhone の「設定 > プライバシーとセキュリティ > トラッキング」からいつでも変更できます。トラッキングの許可を選ばなくても、アプリの機能はすべて利用できます。

#### 4. アプリ内課金

広告を非表示にする買い切りの課金は Apple のシステムで処理されます。当方はお支払い情報を取得・保存しません。購入の復元は「設定 > 購入を復元」から行えます。

#### 5. 取得しない情報

当方は、氏名・メールアドレス・位置情報・連絡先・マイク・写真などの情報を取得しません。アカウント登録もありません。

#### 6. 変更

本ポリシーを変更する場合は、このページで告知します。

#### 7. お問い合わせ

（連絡先メール）

## G-6 リリースガード（実際のスクリプト）

```sh
#!/bin/sh
# Release guard: fails the Release build while any id is empty, a Google TEST id, a documented template
# value, or malformed. It checks FORMAT only; it cannot prove the ids belong to the owner's accounts.
[ "$CONFIGURATION" = "Release" ] || exit 0
fail() { echo "error: Release guard: $1 (see Config/Config.example.xcconfig)"; exit 1; }
for v in AD_UNIT_ID GAD_APPLICATION_IDENTIFIER IN_APP_PURCHASE_PRODUCT_ID HEYDRUM_BUNDLE_ID; do
  eval "val=\${$v}"
  [ -n "$val" ] || fail "$v is empty"
done
case "$AD_UNIT_ID$GAD_APPLICATION_IDENTIFIER" in *3940256099942544*) fail "Google TEST ad ids must not be used in Release";; esac
case "$AD_UNIT_ID$GAD_APPLICATION_IDENTIFIER$IN_APP_PURCHASE_PRODUCT_ID$HEYDRUM_BUNDLE_ID" in
  *XXXX*|*YYYY*|*ZZZZ*|*[Yy]ourcompany*|*example*|*EXAMPLE*|*REPLACE*|*placeholder*) fail "template/placeholder value left in Release settings";;
esac
echo "$AD_UNIT_ID" | grep -Eq '^ca-app-pub-[0-9]{16}/[0-9]{10}$' || fail "AD_UNIT_ID is not a valid AdMob unit id (ca-app-pub-<16 digits>/<10 digits>)"
echo "$GAD_APPLICATION_IDENTIFIER" | grep -Eq '^ca-app-pub-[0-9]{16}~[0-9]{10}$' || fail "GAD_APPLICATION_IDENTIFIER is not a valid AdMob app id (ca-app-pub-<16 digits>~<10 digits>)"
echo "$HEYDRUM_BUNDLE_ID" | grep -Eq '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$' || fail "HEYDRUM_BUNDLE_ID is not a valid reverse-DNS identifier"
echo "$IN_APP_PURCHASE_PRODUCT_ID" | grep -Eq '^[A-Za-z0-9_.-]+$' || fail "IN_APP_PURCHASE_PRODUCT_ID has invalid characters"
[ "$ADS_TEST_MODE" = "NO" ] || fail "ADS_TEST_MODE must be NO in Release"
# Privacy manifest consistency (App Store Connect ITMS-91064). MANIFEST can be overridden for tests.
MANIFEST="${MANIFEST:-$SRCROOT/HeyDrum/Resources/PrivacyInfo.xcprivacy}"
if [ -f "$MANIFEST" ]; then
  PB=/usr/libexec/PlistBuddy
  tracking=$($PB -c "Print :NSPrivacyTracking" "$MANIFEST" 2>/dev/null || echo false)
  if $PB -c "Print :NSPrivacyTrackingDomains" "$MANIFEST" >/dev/null 2>&1; then
    n=$($PB -c "Print :NSPrivacyTrackingDomains" "$MANIFEST" | grep -c '^    ' || true)
    [ "$n" -gt 0 ] || fail "PrivacyInfo.xcprivacy has an EMPTY NSPrivacyTrackingDomains array (remove the key) - ITMS-91064"
    [ "$tracking" = "true" ] || fail "PrivacyInfo.xcprivacy lists tracking domains but NSPrivacyTracking is not true - ITMS-91064"
  else
    [ "$tracking" != "true" ] || fail "PrivacyInfo.xcprivacy has NSPrivacyTracking=true without any tracking domain - ITMS-91064"
  fi
fi
exit 0
```

## G-7 アップロード用の素材のフォルダ構成

```
store/UPLOAD/
  README_UPLOAD.md            どの欄に、どれを入れるか
  1a_screenshots-6.9in/       宣伝用（見出し付き）7枚  1320×2868
  1b_screenshots-6.3in/       宣伝用（見出し付き）7枚  1206×2622
  1c_plain-alternative-6.9in/ 画面そのまま（1aの代わり）
  1d_plain-alternative-6.3in/ 画面そのまま（1bの代わり）
  2_app-preview/              アプリプレビュー動画（任意）
  3_iap-review/               課金の審査用スクリーンショット
  4_icon-reference/           アイコンの原本（アップロードは不要）
```

![ヘイドラムの、宣伝用スクリーンショット（6.9インチ用）7枚](images/fig-store-screens.jpg)

## G-8 ヘイドラムの、提出までに実際に作ったもの

| 種類 | 中身 |
|---|---|
| アプリ | iPhone専用のSwiftUIアプリ。2つの効果音、日本語の読み上げ、履歴、設定、広告、広告除去の課金 |
| 設定 | Debug／Releaseのxcconfig、Secrets、リリースガード（20のテスト） |
| テスト | 単体・統合147件、UIテスト（画面の撮影を含む）31件 |
| 公開ページ | サポート、プライバシーポリシー（GitHub Pages） |
| ストアの素材 | 6.9インチと6.3インチの画像、課金の審査用の画像、説明文一式 |
| 記録 | 判断の記録（ADR）、検証の記録（PASS／FAIL／NOT RUN） |
