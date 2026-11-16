#!/usr/bin/env python3
"""
BananaBank Export-Werkzeug (laeuft ausserhalb von WoW)

  1. Im Spiel:  /bb export          (noch nicht verkaufsfaehige Items)
                /bb export sale     (verkaufsfaehige Items, Kontrolle rueckwaerts)
                /bb export all      (alles)
     danach /reload, damit WoW die Datei schreibt:
     WTF/Account/<KONTO>/SavedVariables/BananaBank.lua

  2. Hier:      python3 bananabank_export.py pdf  BananaBank.lua auswahl.pdf
                python3 bananabank_export.py html BananaBank.lua auswahl.html
     Das PDF hat je Item ein Tooltip-Bild, das Icon und rechts ein ausfuellbares Kaestchen
     (in Adobe Reader / Chrome / Edge anklickbar und speicherbar).

  3. Die ausgefuellte Datei auswerten:
                python3 bananabank_export.py read auswahl.pdf
     gibt die Liste fuer /bb saleimport aus (im Spiel: /bb saleimport, Liste einfuegen).
     Bedeutung des Hakens: Export "open"  = zum Verkauf freigeben
                           Export "sale"  = Freigabe zuruecknehmen (kommt als -ID in die Liste)

Benoetigt: Python 3, reportlab, pypdf, pillow  (pip install reportlab pypdf pillow)
Icons werden von wow.zamimg.com geladen (nur Namen aus der Datei); ohne Netz bleibt der Platz leer.
"""
import os
import re
import sys
import json
import html
import urllib.request

# ---------------------------------------------------------------- Lua-Tabellen lesen
TOKEN = re.compile(r'\s*(?:(--[^\n]*)|("(?:[^"\\]|\\.)*")|(\[)|(\])|(\{)|(\})|(=)|(,)|([-+]?\d+\.?\d*(?:[eE][-+]?\d+)?)|([A-Za-z_][A-Za-z_0-9]*))')


def _unescape(s):
    s = s[1:-1]
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n == "n":
                out.append("\n"); i += 2
            elif n == "t":
                out.append("\t"); i += 2
            elif n == "r":
                out.append("\r"); i += 2
            elif n.isdigit():
                m = re.match(r"\d{1,3}", s[i + 1:])
                out.append(chr(int(m.group(0)))); i += 1 + len(m.group(0))
            else:
                out.append(n); i += 2
        else:
            out.append(c); i += 1
    return "".join(out)


def tokenize(text):
    pos, toks = 0, []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            if text[pos:].strip() == "":
                break
            raise ValueError("Lua-Parser: unerwartetes Zeichen bei %d: %r" % (pos, text[pos:pos + 30]))
        pos = m.end()
        if m.group(1):
            continue
        if m.group(2):
            toks.append(("str", _unescape(m.group(2))))
        elif m.group(3):
            toks.append(("[", None))
        elif m.group(4):
            toks.append(("]", None))
        elif m.group(5):
            toks.append(("{", None))
        elif m.group(6):
            toks.append(("}", None))
        elif m.group(7):
            toks.append(("=", None))
        elif m.group(8):
            toks.append((",", None))
        elif m.group(9):
            v = m.group(9)
            toks.append(("num", float(v) if ("." in v or "e" in v.lower()) else int(v)))
        else:
            toks.append(("id", m.group(10)))
    return toks


def parse_value(toks, i):
    kind, val = toks[i]
    if kind == "{":
        return parse_table(toks, i)
    if kind in ("str", "num"):
        return val, i + 1
    if kind == "id":
        return {"true": True, "false": False, "nil": None}.get(val, val), i + 1
    raise ValueError("Lua-Parser: Wert erwartet, gefunden %s" % kind)


def parse_table(toks, i):
    assert toks[i][0] == "{"
    i += 1
    out, arr = {}, 1
    while toks[i][0] != "}":
        if toks[i][0] == "[":
            key, i = parse_value(toks, i + 1)
            assert toks[i][0] == "]"
            i += 1
            assert toks[i][0] == "="
            val, i = parse_value(toks, i + 1)
            out[key] = val
        elif toks[i][0] == "id" and toks[i + 1][0] == "=":
            key = toks[i][1]
            val, i = parse_value(toks, i + 2)
            out[key] = val
        else:
            val, i = parse_value(toks, i)
            out[arr] = val
            arr += 1
        if toks[i][0] == ",":
            i += 1
    return out, i + 1


def load_export(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
    # nur den Block exportData herausschneiden (die Datei kann gross sein)
    m = re.search(r'\["exportData"\]\s*=\s*\{', text)
    if not m:
        sys.exit("Keine Export-Daten in der Datei. Im Spiel '/bb export' ausfuehren und danach '/reload'.")
    toks = tokenize(text[m.end() - 1:])
    data, _ = parse_table(toks, 0)
    items = [data["items"][k] for k in sorted(data.get("items", {}))]
    data["items"] = items
    return data


def tip_lines(it):
    lines = []
    t = it.get("tip") or {}
    for k in sorted(t):
        row = t[k]
        lines.append((row.get(1, ""), row.get(2, ""), row.get(3, "ffffff")))
    return lines


QUALITY = {0: "9d9d9d", 1: "ffffff", 2: "1eff00", 3: "0070dd", 4: "a335ee", 5: "ff8000"}


def money(c):
    c = int(c or 0)
    g, s, k = c // 10000, (c % 10000) // 100, c % 100
    return ("%dg " % g if g else "") + ("%ds " % s if s or g else "") + "%dc" % k


def icon_path(tex, cache):
    if not tex:
        return None
    name = tex.replace("\\", "/").split("/")[-1].lower()
    path = os.path.join(cache, name + ".jpg")
    if os.path.exists(path):
        return path
    try:
        os.makedirs(cache, exist_ok=True)
        req = urllib.request.Request("https://wow.zamimg.com/images/wow/icons/large/%s.jpg" % name,
                                     headers={"User-Agent": "BananaBank-Export"})
        with urllib.request.urlopen(req, timeout=15) as r, open(path, "wb") as f:
            f.write(r.read())
        return path
    except Exception:
        return None


def card_lines(it):
    lines = tip_lines(it)
    if not lines:
        lines = [(it.get("n", "?"), "", QUALITY.get(it.get("q", 1), "ffffff")),
                 ("(kein Tooltip - der Client kannte das Item nicht)", "", "999999")]
    return lines


# ---------------------------------------------------------------- PDF
def make_pdf(data, out, icons_dir):
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.lib.colors import HexColor, Color
    from reportlab.lib.utils import simpleSplit

    font, bold = "Helvetica", "Helvetica-Bold"
    for reg, b in (("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
                   ("C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/arialbd.ttf"),
                   ("/Library/Fonts/Arial.ttf", "/Library/Fonts/Arial Bold.ttf")):
        if os.path.exists(reg) and os.path.exists(b):
            pdfmetrics.registerFont(TTFont("BBF", reg))
            pdfmetrics.registerFont(TTFont("BBFB", b))
            font, bold = "BBF", "BBFB"
            break

    W, H = A4
    ml, mt, mb = 28, 56, 30
    card_w = 330
    icon = 36
    items = data["items"]
    mode = data.get("mode", "open")
    check_label = {"open": "Zum Verkauf freigeben", "sale": "Freigabe zurücknehmen", "all": "Verkaufsfähig markieren"}.get(mode, "Auswahl")
    title = {"open": "Noch nicht verkaufsfähige Items", "sale": "Verkaufsfähige Items (Kontrolle)", "all": "Alle Items"}.get(mode, "Items")

    c = canvas.Canvas(out, pagesize=A4)
    c.setTitle("BananaBank - " + title)
    page = [0]

    def header():
        page[0] += 1
        c.setFillColor(HexColor("#222222"))
        c.setFont(bold, 14)
        c.drawString(ml, H - 32, "BananaBank: " + title)
        c.setFont(font, 8)
        c.setFillColor(HexColor("#666666"))
        c.drawString(ml, H - 44, "%d Items  |  Haken = %s  |  Seite %d" % (len(items), check_label, page[0]))

    header()
    y = H - mt
    for it in items:
        lines = card_lines(it)
        wrapped = []
        for li, (l, r, col) in enumerate(lines):
            avail = card_w - 16 - (60 if r else 0)
            parts = simpleSplit(l, font, 8, avail) or [""]
            for k, p in enumerate(parts):
                wrapped.append((p, r if k == 0 else "", col, li == 0))
        lh = 10.5
        ch = len(wrapped) * lh + 12
        block = max(ch, icon + 8) + 10
        if y - block < mb:
            c.showPage()
            header()
            y = H - mt
        top = y
        # Icon
        ip = icon_path(it.get("tex", ""), icons_dir)
        ix = ml
        if ip:
            c.drawImage(ip, ix, top - icon, icon, icon)
            c.setStrokeColor(HexColor("#555555"))
            c.rect(ix, top - icon, icon, icon, fill=0)
        else:
            c.setStrokeColor(HexColor("#aaaaaa"))
            c.rect(ix, top - icon, icon, icon, fill=0)
        # Tooltip-Karte
        cx = ml + icon + 8
        c.setFillColor(Color(0.04, 0.04, 0.09))
        c.setStrokeColor(HexColor("#6a6a72"))
        c.roundRect(cx, top - ch, card_w, ch, 3, fill=1, stroke=1)
        ty = top - 12
        for l, r, col, first in wrapped:
            c.setFillColor(HexColor("#" + (col if re.match(r"^[0-9a-fA-F]{6}$", col or "") else "ffffff")))
            c.setFont(bold if first else font, 8)
            c.drawString(cx + 8, ty, l)
            if r:
                c.drawRightString(cx + card_w - 8, ty, r)
            ty -= lh
        # rechts: Haken und Angaben
        rx = cx + card_w + 14
        name = "chk_%d_%s" % (it["id"], mode)
        c.acroForm.checkbox(name=name, tooltip=it.get("n", ""), x=rx, y=top - 20, size=16, buttonStyle="check",
                            borderColor=HexColor("#333333"), fillColor=HexColor("#ffffff"), textColor=HexColor("#000000"),
                            forceBorder=True)
        c.setFillColor(HexColor("#222222"))
        c.setFont(font, 7.5)
        c.drawString(rx + 22, top - 12, check_label)
        info = ["ID %d  |  Menge %d" % (it["id"], it.get("c", 0))]
        if it.get("p"):
            info.append("Preis " + money(it["p"]))
        if it.get("per"):
            info.append(it["per"])
        info = [x for x in info]
        yy = top - 24
        c.setFillColor(HexColor("#555555"))
        for x in info:
            for part in simpleSplit(x, font, 7, W - rx - ml - 22):
                c.drawString(rx + 22, yy, part)
                yy -= 8.5
        y -= block
    c.save()
    print("PDF geschrieben:", out, "(%d Items, %d Seiten)" % (len(items), page[0]))


# ---------------------------------------------------------------- PDF auswerten
def read_pdf(path):
    from pypdf import PdfReader
    rd = PdfReader(path)
    fields = rd.get_fields() or {}
    on, off, mode = [], [], None
    for name, f in fields.items():
        m = re.match(r"^chk_(\d+)_(open|sale|all)$", name)
        if not m:
            continue
        val = f.get("/V")
        if str(val) in ("/Yes", "/On", "/1", "Yes", "True", "/Ja"):
            mode = m.group(2)
            (off if m.group(2) == "sale" else on).append(int(m.group(1)))
    on.sort()
    off.sort()
    print("# fuer /bb saleimport (im Spiel einfuegen):")
    print(",".join([str(i) for i in on] + ["-%d" % i for i in off]))
    print("# %d zum Verkauf freigeben, %d Freigaben zuruecknehmen" % (len(on), len(off)), file=sys.stderr)


# ---------------------------------------------------------------- HTML (interaktiv, ohne Server)
def make_html(data, out, icons_dir):
    mode = data.get("mode", "open")
    label = {"open": "Zum Verkauf freigeben", "sale": "Freigabe zurücknehmen", "all": "Verkaufsfähig markieren"}.get(mode, "Auswahl")
    rows = []
    for it in data["items"]:
        ip = icon_path(it.get("tex", ""), icons_dir)
        icon = ""
        if ip:
            import base64
            with open(ip, "rb") as f:
                icon = '<img class="ic" src="data:image/jpeg;base64,%s">' % base64.b64encode(f.read()).decode()
        else:
            icon = '<span class="ic"></span>'
        tl = []
        for l, r, col in card_lines(it):
            tl.append('<div class="l" style="color:#%s"><span>%s</span><span>%s</span></div>' % (
                col if re.match(r"^[0-9a-fA-F]{6}$", col or "") else "ffffff", html.escape(l), html.escape(r)))
        meta = "ID %d · Menge %d" % (it["id"], it.get("c", 0))
        if it.get("p"):
            meta += " · Preis " + money(it["p"])
        if it.get("per"):
            meta += " · " + it["per"]
        rows.append(
            '<div class="row" data-name="%s"><label class="chk"><input type="checkbox" value="%d"> %s</label>%s'
            '<div class="tip">%s</div><div class="meta">%s</div></div>' % (
                html.escape((it.get("n") or "").lower()), it["id"], label, icon, "".join(tl), html.escape(meta)))
    page = """<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>BananaBank Export</title><style>
body{font-family:system-ui,sans-serif;background:#f3f3f6;margin:0;padding:12px;color:#222}
h1{font-size:18px;margin:0 0 6px}.bar{position:sticky;top:0;background:#f3f3f6;padding:8px 0;z-index:2}
.bar input[type=text]{padding:6px;width:220px}.bar button{padding:6px 12px;margin-left:6px}
.row{display:flex;gap:10px;align-items:flex-start;background:#fff;border:1px solid #ddd;border-radius:6px;padding:8px;margin:8px 0;flex-wrap:wrap}
.ic{width:36px;height:36px;border:1px solid #555;flex:none;display:inline-block}
.tip{background:#0a0a17;border:1px solid #6a6a72;border-radius:4px;padding:6px 8px;min-width:260px;max-width:380px;font:12px/1.35 'DejaVu Sans',Verdana,sans-serif}
.l{display:flex;justify-content:space-between;gap:12px}.meta{font-size:11px;color:#666;max-width:260px}
.chk{font-size:13px;font-weight:600;white-space:nowrap;order:3}.chk input{width:20px;height:20px;vertical-align:middle}
textarea{width:100%%;height:90px;margin-top:6px}</style>
<h1>BananaBank: %(title)s (%(n)d Items)</h1>
<div class="bar"><input type="text" id="q" placeholder="Suchen ..."> <button onclick="out()">Auswahl berechnen</button>
<span id="cnt"></span><textarea id="res" readonly placeholder="Hier steht die Liste fuer /bb saleimport"></textarea></div>
%(rows)s
<script>
var MODE=%(mode)s;
document.getElementById('q').oninput=function(){var q=this.value.toLowerCase();
 document.querySelectorAll('.row').forEach(function(r){r.style.display=r.dataset.name.indexOf(q)<0?'none':'flex'})};
function out(){var ids=[];document.querySelectorAll('.row input:checked').forEach(function(c){ids.push((MODE=='sale'?'-':'')+c.value)});
 document.getElementById('res').value=ids.join(',');document.getElementById('cnt').textContent=' '+ids.length+' ausgewaehlt';
 document.getElementById('res').select()}
</script></html>""" % {"title": {"open": "Noch nicht verkaufsfähig", "sale": "Verkaufsfähige Items", "all": "Alle Items"}.get(mode, "Items"),
                       "n": len(data["items"]), "rows": "".join(rows), "mode": json.dumps(mode)}
    with open(out, "w", encoding="utf-8") as f:
        f.write(page)
    print("HTML geschrieben:", out)


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        print(__doc__)
        sys.exit(1)
    cmd = a[0]
    icons = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
    if cmd == "read":
        read_pdf(a[1])
    elif cmd in ("pdf", "html") and len(a) >= 3:
        data = load_export(a[1])
        (make_pdf if cmd == "pdf" else make_html)(data, a[2], icons)
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
