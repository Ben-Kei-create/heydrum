#!/usr/bin/env python3
"""Builds book/kdp/KDP_KIT.md and book/kdp/kdp-kit.html (copy-and-paste fields for Kindle Direct Publishing)."""
import html, json, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
M = json.load(open(os.path.join(ROOT, "kdp", "book.json"), encoding="utf-8"))

DESC = """<b>「Xcodeでアプリは作れた。でも、App Store Connectの画面を前にして、何から手を付ければいいのか分からない。」</b><br><br>
本書は、個人開発者が自分のiPhoneアプリをApp Storeに出すまでの道のりを、<b>実際にやった順番どおり</b>に解説する手引きです。画面の名前、入力する文字、コマンドを、そのまま写せる形で書きました。<br><br>
<b>この本で分かること</b>
<ul>
<li>契約（有料App契約）、Bundle ID、アプリ、アプリ内課金（非消耗型）、AdMobの登録の順番と、待ち時間のあるものを先にやる理由</li>
<li>秘密の設定をgitの外に出す方法と、テスト用の値のままReleaseを作らせない「リリースガード」</li>
<li>プライバシーマニフェスト、「Appのプライバシー」の回答、ポリシーページの公開（GitHub Pages）</li>
<li>アーカイブとアップロード、ビルド番号、無害な警告（dSYM）の見分け方</li>
<li>ストアの文言の文字数の上限、スクリーンショット（6.9インチ・6.3インチ）、アプリプレビューの注意</li>
<li>審査の提出と、「審査用に追加できません」の読み方</li>
</ul>
<b>失敗の実録つき</b><br>
筆者が実際に、<b>自動検証（ITMS-91064）で2回弾かれた</b>経緯を、原因の読み違いも含めて、そのまま載せました。「バイナリが無効」と表示されたときの正しい探し方、却下メッセージの読み方も解説します。<br><br>
<b>AIと一緒に進めるための付録</b><br>
実装が終わったら、そのままClaude Codeに貼れば、申請に必要な文言、画像、公開ページ、プライバシーの回答案を一式作らせる依頼文のひな形を収録しています。AIに任せてよいことと、自分でやることの線引きも書きました。<br><br>
<b>こんな方に</b>
<ul>
<li>初めてApp Storeにアプリを出す個人開発者</li>
<li>広告（AdMob）やアプリ内課金を入れて、プライバシーの回答や契約が不安な方</li>
<li>却下やエラーのメールの読み方を知りたい方</li>
</ul>
<b>ご注意</b><br>
画面の名称、画像のサイズ、規約は変わります。本書の内容は2026年10月時点の筆者の実体験です。迷ったときは、App Store Connectの画面の表示を優先してください。本書の文章は、AI（Claude）が作成した原稿を、著者が確認・編集したものです。"""

KEYWORDS = ["App Store 申請", "iOSアプリ 公開", "個人開発 審査", "App Store Connect", "TestFlight 手順", "Xcode アーカイブ", "AdMob アプリ内課金"]

SECTIONS = [
 ("1. Kindle電子書籍の詳細（本の情報）", [
  ("言語", "日本語"),
  ("書名", M["title"]),
  ("サブタイトル", M["subtitle"]),
  ("シリーズ名", "（空欄）"),
  ("版（任意）", M["edition"]),
  ("著者名（ペンネーム）", "NingentteWinner"), ("KDPが姓・名に分けて入力を求める場合", "画面の欄に合わせて、NingentteWinner を入力する（欄が2つ必須なら、画面の案内に従う）"),
  ("寄稿者（任意）", "（空欄）"),
  ("内容紹介（HTMLを使える欄。4,000文字まで）", DESC),
  ("出版に関する権利", "私は著作権者であり、出版に必要な権利を保有しています"),
  ("対象年齢（任意）", "（空欄）"),
  ("成人向けコンテンツ", "いいえ"),
 ]),
 ("2. 検索キーワード（7つまで。1つ50文字以内）", [(f"キーワード{i+1}", k) for i, k in enumerate(KEYWORDS)]),
 ("3. カテゴリ（最大3つ。画面の一覧から選ぶ）", [
  ("探し方", "カテゴリ選択の画面で「iPhone」「iOS」「モバイルアプリ開発」「プログラミング」で検索し、内容に近いものを選ぶ（最大3つ）。表示される一覧にないカテゴリは選べないので、画面の候補から、最も近いものを選ぶ"),
 ]),
 ("4. Kindle電子書籍のコンテンツ", [
  ("DRM（デジタル著作権管理）", "どちらでも可（出版後は変更できない）。迷うなら「いいえ」。購入者が自分の端末で自由に読める"),
  ("原稿のアップロード", "dist/app-store-shinsei-handson.epub（EPUBファイル）"),
  ("表紙のアップロード", "images/cover.jpg（1600×2560、JPEG）"),
  ("ISBN", "不要（Kindle電子書籍はASINが自動で付く）"),
  ("AI生成コンテンツ", "テキスト：「はい」。AIツール：Claude（Anthropic）。本文はAIが作成した原稿を、著者が確認・編集した。画像：本文のスクリーンショットと表紙は、アプリの画面とプログラムによる描画で、AI生成の画像ではない（「いいえ」）。翻訳：なし。※選択肢の文言は画面に従う。迷ったら「はい」と申告する"),
 ]),
 ("5. 価格設定", [
  ("KDPセレクト", "迷うなら、最初の90日は登録（Kindle Unlimitedの対象になる。この期間は、他の電子書店で売れない）。他の書店でも売る予定があるなら、登録しない"),
  ("販売地域", "全世界（全地域）の権利"),
  ("主要マーケット", "Amazon.co.jp"),
  ("ロイヤリティ", "70%（価格 ¥250〜¥1,250の範囲で選べる）"),
  ("価格（おすすめ）", "980円（税込）"),
  ("価格の別案", "780円：手に取りやすさ重視／1,250円：1冊の価値を高めに見せたい（70%の上限）"),
  ("他のマーケット", "「自動的に換算」でよい（または自分で設定）"),
 ]),
]

def md():
    out = ["# KDP 登録キット（コピペ用）", "", "この文書は `python3 -I book/tools/build_kdp_kit.py` で再生成されます。ブラウザで `book/kdp/kdp-kit.html` を開くと、各欄にコピーボタンが付きます。", ""]
    for title, fields in SECTIONS:
        out.append("## " + title); out.append("")
        for k, v in fields:
            out.append("**%s**" % k); out.append("```"); out.append(v); out.append("```"); out.append("")
    return "\n".join(out)

def htm():
    h = ['''<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>KDP 登録キット</title>
<style>body{font-family:-apple-system,"Hiragino Sans",sans-serif;max-width:860px;margin:24px auto;padding:0 16px;color:#302C29;background:#FAF8F4;line-height:1.6}
h1{font-size:22px}h2{font-size:17px;margin:28px 0 8px;border-left:6px solid #ED8D45;padding-left:10px}
.f{background:#fff;border:1px solid #DDD7D0;border-radius:12px;padding:10px 12px;margin:8px 0}.l{font-size:13px;color:#756F69;margin-bottom:4px;display:flex;justify-content:space-between;align-items:center;gap:8px}
pre{white-space:pre-wrap;word-break:break-word;margin:0;font:15px/1.6 -apple-system,"Hiragino Sans",sans-serif}
button{background:#ED8D45;color:#302C29;border:0;border-radius:10px;padding:8px 14px;font-weight:700;cursor:pointer;min-height:36px}button.ok{background:#8FD19E}.cnt{font-size:12px;color:#756F69}</style></head><body>
<h1>KDP 登録キット</h1><p class="cnt">各ブロックの「コピー」を押して、KDPの入力欄に貼り付けます。画面の選択肢の文言は、KDPの表示に従ってください。</p>''']
    for title, fields in SECTIONS:
        h.append("<h2>%s</h2>" % html.escape(title))
        for k, v in fields:
            h.append('<div class="f"><div class="l"><span>%s <span class="cnt">%d字</span></span><button onclick="cp(this)">コピー</button></div><pre>%s</pre></div>' % (html.escape(k), len(v), html.escape(v)))
    h.append('''<script>async function cp(b){const t=b.closest('.f').querySelector('pre').textContent;try{await navigator.clipboard.writeText(t)}catch(e){const a=document.createElement('textarea');a.value=t;document.body.appendChild(a);a.select();document.execCommand('copy');a.remove()}b.textContent='コピー済み';b.classList.add('ok');setTimeout(()=>{b.textContent='コピー';b.classList.remove('ok')},1400)}</script></body></html>''')
    return "\n".join(h)

open(os.path.join(ROOT, "kdp", "KDP_KIT.md"), "w", encoding="utf-8").write(md())
open(os.path.join(ROOT, "kdp", "kdp-kit.html"), "w", encoding="utf-8").write(htm())
import re
plain = re.sub(r"<[^>]+>", "", DESC.replace("<br>", "\n").replace("</li>", "\n"))
print("description chars (with tags):", len(DESC), "/ 4000;  keywords:", [len(k) for k in KEYWORDS])
assert len(DESC) <= 4000 and all(len(k) <= 50 for k in KEYWORDS) and len(KEYWORDS) <= 7
