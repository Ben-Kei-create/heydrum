#!/usr/bin/env python3
"""Build an EPUB 3 (reflowable, Japanese, LTR) from book/manuscript/*.md without external dependencies.
Usage: python3 -I book/tools/build_epub.py            (run from the repository root)
Output: book/dist/<slug>.epub and book/dist/build-report.txt
"""
import html, json, os, re, sys, uuid, zipfile, datetime
from xml.etree import ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
META = json.load(open(os.path.join(ROOT, "kdp", "book.json"), encoding="utf-8"))
MS = os.path.join(ROOT, "manuscript")
DIST = os.path.join(ROOT, "dist")

# ---------- Markdown subset -> XHTML ----------
def inline(text: str) -> str:
    parts = re.split(r"(`[^`]*`)", text)
    out = []
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) >= 2:
            out.append("<code>%s</code>" % html.escape(part[1:-1], quote=False))
            continue
        t = html.escape(part, quote=False)
        t = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", lambda m: '<img src="%s" alt="%s"/>' % (html.escape(m.group(2)), html.escape(m.group(1))), t)
        t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", lambda m: '<a href="%s">%s</a>' % (m.group(2).replace("&amp;", "&amp;"), m.group(1)), t)
        t = re.sub(r"&lt;(https?://[^&\s]+)&gt;", lambda m: '<a href="%s">%s</a>' % (m.group(1), m.group(1)), t)
        t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
        t = re.sub(r"(?<![\*\w])\*([^*\s][^*]*?)\*(?![\*\w])", r"<em>\1</em>", t)
        out.append(t)
    return "".join(out)

def slug(i, text):
    return "s%03d" % i

def md_to_xhtml(md: str, fig_dir: str):
    """returns (body_html, headings[(level, id, text)])"""
    lines = md.split("\n")
    out, heads = [], []
    i, hid = 0, 0
    def flush_para(buf):
        if buf:
            out.append("<p>%s</p>" % inline("".join(s.strip() for s in buf)))
            buf.clear()
    para = []
    while i < len(lines):
        line = lines[i]
        if line.startswith("```"):
            flush_para(para)
            i += 1
            code = []
            while i < len(lines) and not lines[i].startswith("```"):
                code.append(lines[i]); i += 1
            out.append("<pre><code>%s</code></pre>" % html.escape("\n".join(code), quote=False))
            i += 1
            continue
        m = re.match(r"^(#{1,4}) (.*)$", line)
        if m:
            flush_para(para)
            level, text = len(m.group(1)), m.group(2).strip()
            hid += 1
            hident = "h%d" % hid
            heads.append((level, hident, re.sub(r"[`*]", "", text)))
            out.append('<h%d id="%s">%s</h%d>' % (level, hident, inline(text), level))
            i += 1
            continue
        if re.match(r"^-{3,}$", line.strip()):
            flush_para(para); out.append("<hr/>"); i += 1; continue
        if line.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:\-|]+\|\s*$", lines[i + 1]):
            flush_para(para)
            def cells(l): return [c.strip() for c in l.strip().strip("|").split("|")]
            head = cells(line); i += 2
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(cells(lines[i])); i += 1
            t = ["<table><thead><tr>%s</tr></thead><tbody>" % "".join("<th>%s</th>" % inline(c) for c in head)]
            for r in rows:
                r = (r + [""] * len(head))[:len(head)]
                t.append("<tr>%s</tr>" % "".join("<td>%s</td>" % inline(c) for c in r))
            t.append("</tbody></table>")
            out.append("".join(t))
            continue
        if re.match(r"^(- |\d+\. )", line):
            flush_para(para)
            ordered = bool(re.match(r"^\d+\. ", line))
            items = []
            while i < len(lines) and re.match(r"^(- |\d+\. )", lines[i]):
                items.append(re.sub(r"^(- |\d+\. )", "", lines[i])); i += 1
            tag = "ol" if ordered else "ul"
            out.append("<%s>%s</%s>" % (tag, "".join("<li>%s</li>" % inline(x) for x in items), tag))
            continue
        if line.startswith("> "):
            flush_para(para)
            q = []
            while i < len(lines) and lines[i].startswith(">"):
                q.append(lines[i].lstrip("> ").strip()); i += 1
            out.append("<blockquote><p>%s</p></blockquote>" % inline("".join(q)))
            continue
        if re.match(r"^!\[[^\]]*\]\([^)]+\)\s*$", line.strip()):
            flush_para(para)
            mm = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)", line.strip())
            out.append('<figure><img src="%s" alt="%s"/><figcaption>%s</figcaption></figure>' % (html.escape(mm.group(2)), html.escape(mm.group(1)), html.escape(mm.group(1))))
            i += 1
            continue
        if not line.strip():
            flush_para(para); i += 1; continue
        para.append(line); i += 1
    flush_para(para)
    return "\n".join(out), heads

XHTML = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja" lang="ja">
<head><meta charset="UTF-8"/><title>%(title)s</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
<body>%(body)s</body></html>
"""

CSS = """
body { font-family: serif; line-height: 1.8; margin: 0 0.4em; }
h1 { font-size: 1.5em; margin: 1.2em 0 0.8em; page-break-before: always; border-bottom: 2px solid #ED8D45; padding-bottom: 0.2em; }
h2 { font-size: 1.2em; margin: 1.6em 0 0.5em; border-left: 0.4em solid #ED8D45; padding-left: 0.5em; }
h3 { font-size: 1.05em; margin: 1.2em 0 0.4em; }
p { margin: 0.6em 0; text-align: left; }
blockquote { margin: 0.8em 0.4em; padding: 0.2em 0.8em; border-left: 0.25em solid #cccccc; color: #444444; }
code { font-family: monospace; font-size: 0.9em; background: #f3f0ec; padding: 0 0.15em; }
pre { font-family: monospace; font-size: 0.8em; background: #f3f0ec; padding: 0.6em; white-space: pre-wrap; word-wrap: break-word; line-height: 1.5; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 0.8em 0; font-size: 0.9em; }
th, td { border: 1px solid #bbbbbb; padding: 0.3em 0.4em; vertical-align: top; text-align: left; }
th { background: #f3e1cd; }
ul, ol { margin: 0.5em 0 0.5em 1.4em; padding: 0; }
li { margin: 0.2em 0; }
hr { border: none; border-top: 1px solid #cccccc; margin: 1.5em 0; }
figure { margin: 1em 0; text-align: center; }
figure img { max-width: 100%; height: auto; }
figcaption { font-size: 0.85em; color: #555555; }
.title { text-align: center; margin-top: 18%; }
.title h1 { font-size: 1.9em; border: none; page-break-before: avoid; }
.title p { text-align: center; }
.colophon p { font-size: 0.9em; }
a { color: #b05a1e; }
"""

def read(p): return open(p, encoding="utf-8").read()

def main():
    os.makedirs(DIST, exist_ok=True)
    chapters = []   # (filename, title, body, heads)
    # title page
    title_body = '<div class="title"><h1>%s</h1><p>%s</p><p>&#160;</p><p>%s</p></div>' % (
        html.escape(META["title"]), html.escape(META["subtitle"]), html.escape(META["author"]))
    chapters.append(("titlepage.xhtml", META["title"], title_body, [], "titlepage"))
    n = 0
    for fn in sorted(os.listdir(MS)):
        if not fn.endswith(".md"): continue
        text = read(os.path.join(MS, fn))
        # split by top-level headings
        blocks, cur = [], []
        for line in text.split("\n"):
            if line.startswith("# ") and cur:
                blocks.append(cur); cur = []
            cur.append(line)
        if cur: blocks.append(cur)
        for b in blocks:
            if not "".join(b).strip(): continue
            n += 1
            body, heads = md_to_xhtml("\n".join(b), "")
            title = heads[0][2] if heads else "章 %d" % n
            chapters.append(("ch%02d.xhtml" % n, title, body, heads, "bodymatter"))
    # colophon
    today = META.get("published_label", "")
    colo = ('<div class="colophon"><h1>奥付</h1><p>%s</p><p>著者：%s</p><p>%s</p><p>%s</p></div>' % (
        html.escape(META["title"] + "　" + META["subtitle"]), html.escape(META["author"]),
        html.escape(META["edition"]), html.escape(META["copyright"])))
    chapters.append(("colophon.xhtml", "奥付", colo, [("1", "c", "奥付")], "backmatter"))

    # images used
    img_dir = os.path.join(ROOT, "images")
    used = set()
    for _, _, body, _, _ in chapters:
        used.update(re.findall(r'<img src="([^"]+)"', body))
    for u in used:
        if not os.path.exists(os.path.join(ROOT, u)):
            sys.exit("missing image: " + u)

    book_id = META.get("identifier") or "urn:uuid:" + str(uuid.uuid4())
    modified = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    slugname = META["slug"]
    out_path = os.path.join(DIST, slugname + ".epub")

    manifest, spine, nav_items = [], [], []
    for fn, title, body, heads, kind in chapters:
        pid = fn.replace(".", "_")
        manifest.append('<item id="%s" href="%s" media-type="application/xhtml+xml"/>' % (pid, fn))
        spine.append('<itemref idref="%s"/>' % pid)
    for fn, title, body, heads, kind in chapters:
        if fn == "titlepage.xhtml": continue
        subs = [h for h in heads if h[0] == 2]
        li = '<li><a href="%s">%s</a>' % (fn, html.escape(title))
        if subs:
            li += "<ol>" + "".join('<li><a href="%s#%s">%s</a></li>' % (fn, h[1], html.escape(h[2])) for h in subs) + "</ol>"
        li += "</li>"
        nav_items.append(li)

    nav = XHTML % {"title": "目次", "body": '<nav epub:type="toc" id="toc"><h1>目次</h1><ol>%s</ol></nav><nav epub:type="landmarks" hidden="hidden"><ol><li><a epub:type="cover" href="cover.xhtml">表紙</a></li><li><a epub:type="toc" href="nav.xhtml">目次</a></li><li><a epub:type="bodymatter" href="ch01.xhtml">本文</a></li></ol></nav>' % "".join(nav_items)}
    cover_x = XHTML % {"title": "表紙", "body": '<div style="text-align:center"><img src="images/cover.jpg" alt="表紙" style="max-height:98vh;max-width:100%"/></div>'}

    ncx_points, pl = [], 0
    for fn, title, body, heads, kind in chapters:
        if fn == "titlepage.xhtml": continue
        pl += 1
        ncx_points.append('<navPoint id="n%d" playOrder="%d"><navLabel><text>%s</text></navLabel><content src="%s"/></navPoint>' % (pl, pl, html.escape(title), fn))
    ncx = '<?xml version="1.0" encoding="UTF-8"?>\n<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="%s"/><meta name="dtb:depth" content="1"/><meta name="dtb:totalPageCount" content="0"/><meta name="dtb:maxPageNumber" content="0"/></head><docTitle><text>%s</text></docTitle><navMap>%s</navMap></ncx>' % (html.escape(book_id), html.escape(META["title"]), "".join(ncx_points))

    img_items = []
    for k, u in enumerate(sorted(used)):
        mt = "image/jpeg" if u.lower().endswith((".jpg", ".jpeg")) else "image/png"
        img_items.append('<item id="img%d" href="%s" media-type="%s"/>' % (k, html.escape(u.replace("images/", "images/")), mt))
    cover_item = '<item id="cover-image" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>'
    opf = ('<?xml version="1.0" encoding="UTF-8"?>\n<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="ja">'
           '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
           '<dc:identifier id="bookid">%s</dc:identifier><dc:title>%s</dc:title><dc:creator>%s</dc:creator><dc:language>ja</dc:language>'
           '<dc:description>%s</dc:description><dc:publisher>%s</dc:publisher><dc:date>%s</dc:date>'
           '<meta property="dcterms:modified">%s</meta><meta name="cover" content="cover-image"/></metadata>'
           '<manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
           '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
           '<item id="cover_xhtml" href="cover.xhtml" media-type="application/xhtml+xml"/>'
           '<item id="css" href="style.css" media-type="text/css"/>%s%s%s</manifest>'
           '<spine toc="ncx" page-progression-direction="ltr"><itemref idref="cover_xhtml" linear="no"/>%s</spine></package>') % (
        html.escape(book_id), html.escape(META["title"] + "　" + META["subtitle"]), html.escape(META["author"]),
        html.escape(META["description_short"]), html.escape(META["publisher"]), META["date"], modified,
        cover_item, "".join(img_items), "".join(manifest), "".join(spine))

    container = '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'

    with zipfile.ZipFile(out_path, "w") as z:
        z.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        def add(name, data): z.writestr("OEBPS/" + name if not name.startswith("META-INF") else name, data, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("META-INF/container.xml", container, compress_type=zipfile.ZIP_DEFLATED)
        add("content.opf", opf); add("nav.xhtml", nav); add("toc.ncx", ncx); add("cover.xhtml", cover_x); add("style.css", CSS)
        for fn, title, body, heads, kind in chapters:
            add(fn, XHTML % {"title": html.escape(title), "body": body})
        z.write(os.path.join(ROOT, "images", "cover.jpg"), "OEBPS/images/cover.jpg", compress_type=zipfile.ZIP_STORED)
        for u in sorted(used):
            z.write(os.path.join(ROOT, u), "OEBPS/" + u, compress_type=zipfile.ZIP_STORED)

    # ---------- self-validation ----------
    problems = []
    with zipfile.ZipFile(out_path) as z:
        names = z.namelist()
        if names[0] != "mimetype": problems.append("mimetype is not first")
        if z.getinfo("mimetype").compress_type != zipfile.ZIP_STORED: problems.append("mimetype is compressed")
        for nme in names:
            if nme.endswith((".xhtml", ".opf", ".ncx", ".xml")):
                try: ET.fromstring(z.read(nme))
                except ET.ParseError as e: problems.append("XML error in %s: %s" % (nme, e))
        root = ET.fromstring(z.read("OEBPS/content.opf"))
        ns = {"o": "http://www.idpf.org/2007/opf"}
        ids = {}
        for it in root.find("o:manifest", ns):
            ids[it.get("id")] = it.get("href")
            if "OEBPS/" + it.get("href") not in names: problems.append("manifest file missing: " + it.get("href"))
        for it in root.find("o:spine", ns):
            if it.get("idref") not in ids: problems.append("spine id missing: " + it.get("idref"))
        # internal anchors and images
        allhtml = {n: z.read(n).decode("utf-8") for n in names if n.endswith(".xhtml")}
        for n, h in allhtml.items():
            for href in re.findall(r'href="([^"#]+)(?:#([^"]*))?"', h):
                tgt, frag = href
                if tgt.startswith("http") or tgt == "style.css": continue
                if "OEBPS/" + tgt not in names: problems.append("%s -> missing %s" % (n, tgt))
                elif frag and ('id="%s"' % frag) not in allhtml.get("OEBPS/" + tgt, ""): problems.append("%s -> missing anchor %s#%s" % (n, tgt, frag))
            for src in re.findall(r'<img src="([^"]+)"', h):
                if "OEBPS/" + src not in names: problems.append("%s -> missing image %s" % (n, src))
    chars = sum(len(re.sub(r"<[^>]+>", "", b)) for _, _, b, _, _ in chapters)
    size = os.path.getsize(out_path)
    report = ["EPUB: %s" % out_path, "size: %.2f MB" % (size / 1048576), "chapters: %d" % len(chapters), "approx characters (HTML text): %d" % chars,
              "problems: %d" % len(problems)] + ["  - " + p for p in problems]
    open(os.path.join(DIST, "build-report.txt"), "w", encoding="utf-8").write("\n".join(report) + "\n")
    print("\n".join(report))
    sys.exit(1 if problems else 0)

if __name__ == "__main__":
    main()
