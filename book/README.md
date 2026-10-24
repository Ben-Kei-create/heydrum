# 『個人開発者のための App Store 申請ハンズオン』（Kindle出版用）

| 場所 | 中身 |
|---|---|
| `manuscript/` | 原稿（Markdown、日本語）。章ごとのファイル。約4万字 |
| `images/` | 表紙（`cover.jpg`）と、本文の図 |
| `dist/app-store-shinsei-handson.epub` | **KDPにアップロードするEPUB** |
| `kdp/KDP_HANDS_ON.md` | KDPでの登録手順、価格の決め方 |
| `kdp/kdp-kit.html` | 登録の各欄に貼る文字（コピーボタンつき） |
| `tools/build_epub.py` | EPUBを作る（外部ライブラリなし）。自己検証つき |
| `tools/make_cover.swift` | 表紙を描く（CoreGraphics） |
| `tools/build_kdp_kit.py` | 登録キットを作る |

| `PHOTO_REQUESTS.md` | 追加したいスクリーンショットの一覧と、個人情報を塗りつぶす注意 |
| `photos/` | 撮ってもらったスクリーンショットを置く場所 |

## 作り直し

```sh
swiftc -O book/tools/make_cover.swift -o /tmp/make_cover && /tmp/make_cover book/images/cover.jpg "$(python3 -I -c 'import json;print(json.load(open("book/kdp/book.json",encoding="utf-8"))["author"])')"   # 表紙（著者名は book.json）
python3 -I book/tools/build_epub.py        # book/dist/*.epub と build-report.txt
python3 -I book/tools/build_kdp_kit.py     # kdp/KDP_KIT.md と kdp-kit.html
```

原稿を直したあとは、この2つを実行します。`book/kdp/book.json` が、書名、著者名、版の情報です。

## 検証について

EPUBは、構造の検査（zipの形式、XMLの構文、目次とファイルの対応、画像、内部リンク）を自前のスクリプトで行っています。**公式のEPUBCheckとKindle Previewerでの確認は、まだ行っていません**（この環境にツールがなく、実行できなかったため）。アップロードの前に、Kindle Previewerで確認してください。
