#!/usr/bin/env python3
"""
BananaBank Export-Werkzeug (laeuft ausserhalb von WoW)

  1. Im Spiel:  /bb export          (noch nicht verkaufsfaehige Items)
                /bb export sale     (verkaufsfaehige Items, Kontrolle rueckwaerts)
                /bb export guild    (Gildenitems, Kontrolle)
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
     Bedeutung des Hakens: Export "open"  = zum Verkauf freigeben (ID)
                           Export "sale"  = Freigabe zuruecknehmen (-ID)
                           Export "guild" = Gildenitem-Markierung entfernen (-gID)
                           zweiter Haken  = Gildenitem, nicht verkaufen (gID)

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


def price_lines(it):
    """Preisangaben fuer PDF und HTML: AH-Preis laut letztem Scan, guenstigstes Angebot, Gildenpreis."""
    import datetime
    out = []
    pa, pl, p = int(it.get("pa") or 0), int(it.get("pl") or 0), int(it.get("p") or 0)
    if pa:
        out.append("AH-Preis: " + money(pa) + (" (ca., aus Gildenpreis)" if it.get("pderived") else ""))
    elif it.get("psrc") == "man":
        out.append("AH-Preis: kein Scan (Handpreis)")
    else:
        out.append("AH-Preis: kein Scan")
    if pl:
        out.append("Günstigstes Angebot: " + money(pl))
    if p:
        out.append("Gildenpreis: " + money(p) + (" (Handpreis)" if it.get("psrc") == "man" else ""))
    ts = int(it.get("pts") or 0)
    if ts and pa:
        stand = datetime.datetime.fromtimestamp(ts).strftime("%d.%m. %H:%M")
        n = int(it.get("pn") or 0)
        out.append("Stand " + stand + (" · %d Angebote" % n if n else ""))
    return out


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
    check_label = {"open": "Zum Verkauf freigeben", "sale": "Freigabe zurücknehmen", "all": "Verkaufsfähig markieren",
                   "guild": "Gildenitem-Markierung entfernen"}.get(mode, "Auswahl")
    title = {"open": "Noch nicht verkaufsfähige Items", "sale": "Verkaufsfähige Items (Kontrolle)", "all": "Alle Items",
             "guild": "Gildenitems (Kontrolle)"}.get(mode, "Items")

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
        # Angaben rechts neben dem Haken vorab umbrechen, damit die Zeilenhoehe passt
        rx = ml + icon + 8 + card_w + 14
        info = ["ID %d  |  Menge %d" % (it["id"], it.get("c", 0))]
        info.extend(price_lines(it))
        if it.get("per"):
            info.append(it["per"])
        info_w = []
        for x in info:
            info_w.extend(simpleSplit(x, font, 7, W - rx - ml - 22) or [""])
        info_h = 24 + (22 if mode != "guild" else 0) + len(info_w) * 8.5 + 4
        block = max(ch, icon + 8, info_h) + 10
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
        if mode != "guild":
            c.acroForm.checkbox(name="gld_%d_%s" % (it["id"], mode), tooltip="Gildenitem: " + it.get("n", ""), x=rx, y=top - 42, size=16,
                                buttonStyle="check", borderColor=HexColor("#2a4a9a"), fillColor=HexColor("#ffffff"),
                                textColor=HexColor("#000000"), forceBorder=True)
            c.setFillColor(HexColor("#2a4a9a"))
            c.drawString(rx + 22, top - 34, "Gildenitem (nicht verkaufen)")
            c.setFillColor(HexColor("#222222"))
        yy = top - 24 - (22 if mode != "guild" else 0)
        c.setFont(font, 7)
        c.setFillColor(HexColor("#555555"))
        for part in info_w:
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
    tokens = []
    n_on = n_off = n_g = n_goff = 0
    for name, f in fields.items():
        m = re.match(r"^(chk|gld)_(\d+)_(open|sale|all|guild)$", name)
        if not m:
            continue
        if str(f.get("/V")) not in ("/Yes", "/On", "/1", "Yes", "True", "/Ja"):
            continue
        kind, id_, mode = m.group(1), int(m.group(2)), m.group(3)
        if kind == "gld":
            tokens.append((id_, "g%d" % id_)); n_g += 1
        elif mode == "sale":
            tokens.append((id_, "-%d" % id_)); n_off += 1
        elif mode == "guild":
            tokens.append((id_, "-g%d" % id_)); n_goff += 1
        else:
            tokens.append((id_, "%d" % id_)); n_on += 1
    tokens.sort()
    print("# fuer /bb saleimport (im Spiel einfuegen):")
    print(",".join(t for _, t in tokens))
    print("# %d freigeben, %d Freigaben zuruecknehmen, %d Gildenitems, %d Gildenitem-Markierungen entfernen" % (n_on, n_off, n_g, n_goff),
          file=sys.stderr)


# ---------------------------------------------------------------- HTML (interaktiv, ohne Server)
def money_html(c):
    c = int(c or 0)
    g, s_, k = c // 10000, (c % 10000) // 100, c % 100
    out = []
    if g:
        out.append('<span class="g">%dg</span>' % g)
    if s_:
        out.append('<span class="s">%ds</span>' % s_)
    if k or not out:
        out.append('<span class="k">%dc</span>' % k)
    return " ".join(out)


def price_html(it):
    import datetime
    rows = []
    pa, pl, p = int(it.get("pa") or 0), int(it.get("pl") or 0), int(it.get("p") or 0)
    if pa:
        extra = ' <em>(ca.)</em>' if it.get("pderived") else ""
        rows.append("<div><b>AH-Preis</b> %s%s</div>" % (money_html(pa), extra))
    elif it.get("psrc") == "man":
        rows.append('<div><b>AH-Preis</b> <em>kein Scan (Handpreis)</em></div>')
    else:
        rows.append('<div><b>AH-Preis</b> <em>kein Scan</em></div>')
    if pl:
        rows.append("<div><b>Günstigstes</b> %s</div>" % money_html(pl))
    if p:
        rows.append("<div><b>Gildenpreis</b> %s%s</div>" % (money_html(p), " <em>(Handpreis)</em>" if it.get("psrc") == "man" else ""))
    ts = int(it.get("pts") or 0)
    if ts and pa:
        stand = datetime.datetime.fromtimestamp(ts).strftime("%d.%m. %H:%M")
        n = int(it.get("pn") or 0)
        rows.append('<div class="dim">Stand %s%s</div>' % (stand, " · %d Angebote" % n if n else ""))
    return "".join(rows)


def logo_data_uri():
    try:
        import base64, io
        from PIL import Image
        here = os.path.dirname(os.path.abspath(__file__))
        path = os.path.join(here, "..", "Media", "Logo64.tga")
        if not os.path.exists(path):
            return ""
        im = Image.open(path).convert("RGBA")
        buf = io.BytesIO()
        im.save(buf, "PNG")
        return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    except Exception:
        return ""


HTML_TEMPLATE = r"""<!doctype html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>BananaBank – Verkaufsliste prüfen</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@500;700&display=swap" rel="stylesheet">
<style>
:root{
  --gold:#ffd142; --gold2:#c79938; --brass:#8c6629; --text:#ebe6d6; --muted:#999eb3;
  --bg:#080b17; --panel:#0e1429; --blue:#142a5c; --green:#59d959; --red:#f24d40; --orange:#ff9926;
  --q0:#9d9d9d; --q1:#ffffff; --q2:#1eff00; --q3:#0070dd; --q4:#a335ee; --q5:#ff8000;
}
*{box-sizing:border-box}
html{background:#05070f}
body{margin:0;color:var(--text);font:14px/1.45 "Trebuchet MS",Verdana,"Segoe UI",sans-serif;
  background:
    radial-gradient(ellipse at 50% -10%, rgba(40,70,150,.35), transparent 60%),
    radial-gradient(ellipse at 50% 120%, rgba(140,102,41,.18), transparent 55%),
    repeating-linear-gradient(45deg, rgba(255,255,255,.012) 0 2px, transparent 2px 4px),
    var(--bg);
  min-height:100vh}
.wrap{max-width:1180px;margin:0 auto;padding:14px 14px 60px}
h1,h2,.title{font-family:"Cinzel","Palatino Linotype","Book Antiqua",Georgia,serif;letter-spacing:.04em}

/* Kopf */
.head{display:flex;align-items:center;gap:16px;padding:14px 18px;margin-bottom:12px;
  background:linear-gradient(180deg,#121b3a,#0b1128);border:2px solid var(--brass);border-radius:6px;
  box-shadow:0 0 0 1px #000,inset 0 0 0 1px rgba(255,209,66,.25),0 6px 24px rgba(0,0,0,.6)}
.head img{width:56px;height:56px;image-rendering:auto;filter:drop-shadow(0 2px 4px #000)}
.head h1{margin:0;font-size:28px;color:var(--gold);text-shadow:0 2px 0 #000,0 0 14px rgba(255,209,66,.35)}
.head .sub{color:var(--muted);font-size:13px;margin-top:2px}
.head .modebadge{margin-left:auto;text-align:right;color:var(--gold2);font-family:"Cinzel",Georgia,serif;font-size:13px}
.head .modebadge b{display:block;color:var(--gold);font-size:18px}

/* Werkzeugleiste */
.bar{position:sticky;top:0;z-index:5;margin-bottom:12px;padding:10px 12px;
  background:linear-gradient(180deg,rgba(18,27,58,.97),rgba(9,14,32,.97));border:2px solid var(--brass);border-radius:6px;
  box-shadow:0 0 0 1px #000,0 8px 20px rgba(0,0,0,.6)}
.row1{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.bar input[type=text],.bar select{background:#050818;color:var(--text);border:1px solid var(--brass);border-radius:4px;
  padding:7px 9px;font:inherit;min-width:0}
.bar input[type=text]{width:230px}
.bar input[type=text]:focus,.bar select:focus{outline:none;border-color:var(--gold);box-shadow:0 0 6px rgba(255,209,66,.5)}
.btn{cursor:pointer;color:#2a1b00;font-weight:700;font-family:"Cinzel",Georgia,serif;letter-spacing:.03em;
  background:linear-gradient(180deg,#ffe58a,#e0a92b 55%,#b9821a);border:1px solid #5a3d08;border-radius:4px;padding:7px 14px;
  box-shadow:inset 0 1px 0 rgba(255,255,255,.6),0 2px 0 #3a2704}
.btn:hover{filter:brightness(1.1)}.btn:active{transform:translateY(1px);box-shadow:inset 0 1px 0 rgba(255,255,255,.4)}
.btn.ghost{color:var(--gold);background:linear-gradient(180deg,#1b2650,#101a3a);border-color:var(--brass);
  box-shadow:inset 0 1px 0 rgba(255,209,66,.25),0 2px 0 #000}
.count{margin-left:auto;font-family:"Cinzel",Georgia,serif;color:var(--gold);font-size:16px;text-shadow:0 1px 0 #000}
.count small{color:var(--muted);font:12px "Trebuchet MS",sans-serif}
.chips{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px;align-items:center}
.chips .lbl{color:var(--muted);font-size:12px;margin-right:2px}
.chip{cursor:pointer;user-select:none;padding:3px 10px;border:1px solid var(--brass);border-radius:999px;background:#0a1030;
  color:var(--muted);font-size:12px}
.chip.on{background:linear-gradient(180deg,#2a3a78,#16224f);color:var(--gold);border-color:var(--gold);box-shadow:0 0 8px rgba(255,209,66,.3)}
.chip[data-q="0"].on{color:var(--q0)}.chip[data-q="1"].on{color:var(--q1)}.chip[data-q="2"].on{color:var(--q2)}
.chip[data-q="3"].on{color:#4aa3ff}.chip[data-q="4"].on{color:#c77dff}.chip[data-q="5"].on{color:var(--q5)}
.res{display:none;margin-top:10px}
.res.show{display:block}
.res textarea{width:100%;height:78px;background:#f1e3b6;color:#2a1b00;border:2px solid var(--brass);border-radius:4px;
  padding:8px;font:13px/1.4 Consolas,"Courier New",monospace;box-shadow:inset 0 0 18px rgba(120,80,10,.35)}
.res .hint{color:var(--muted);font-size:12px;margin:4px 0}
.res .hint code{color:var(--gold);background:#050818;padding:1px 5px;border-radius:3px}

/* Karten */
.list{display:flex;flex-direction:column;gap:10px}
.card{position:relative;display:flex;flex-wrap:wrap;gap:14px;align-items:flex-start;padding:12px 14px 12px 12px;
  background:linear-gradient(180deg,rgba(20,32,70,.85),rgba(10,16,38,.92));border:2px solid #3a4468;border-radius:6px;
  box-shadow:0 0 0 1px #000,0 4px 14px rgba(0,0,0,.5);transition:border-color .15s, box-shadow .15s}
.card:hover{border-color:var(--brass)}
.card.checked{border-color:var(--gold);box-shadow:0 0 0 1px #000,0 0 18px rgba(255,209,66,.35),inset 0 0 40px rgba(255,209,66,.07)}
.icon{flex:none;width:44px;height:44px;border:2px solid var(--qc,#555);border-radius:4px;background:#000 center/cover no-repeat;
  box-shadow:0 0 8px color-mix(in srgb,var(--qc,#555) 55%,transparent),inset 0 0 0 1px #000}
.tip{flex:0 1 380px;min-width:250px;background:rgba(6,6,16,.96);border:2px solid #6a6a78;border-radius:6px;padding:7px 10px;
  font:12.5px/1.4 "Trebuchet MS","DejaVu Sans",sans-serif;box-shadow:0 0 0 1px #000,inset 0 0 0 1px rgba(255,255,255,.06)}
.tip .l{display:flex;justify-content:space-between;gap:14px}
.tip .l:first-child{font-weight:700;font-size:13.5px}
.meta{flex:1 1 220px;min-width:200px;font-size:12px;color:var(--muted);line-height:1.55}
.meta b{color:var(--text);font-weight:600;margin-right:4px}
.meta .id{color:var(--gold2);font-family:Consolas,monospace}
.meta em{color:var(--orange);font-style:normal;font-size:11px}
.meta .dim{opacity:.8}
.meta .banks{color:#8fb4ff;margin-top:2px}
.g{color:#ffd100}.s{color:#c7c7cf}.k{color:#c47a3a}
.picks{flex:none;display:flex;gap:16px;margin-left:auto;padding-right:4px}
.pick.gi .box{border-color:#4a6fc4}
.pick.gi span{color:#8fb4ff}
.pick.gi:hover .box{border-color:#8fb4ff;box-shadow:inset 0 0 8px #000,0 0 10px rgba(110,160,255,.5)}
.pick.gi input:checked + .box{background:linear-gradient(180deg,#1d2f5c,#0e1a3a);border-color:#8fb4ff}
.pick.gi input:checked ~ span{color:#8fb4ff}
.pick.gi input:checked + .box svg{stroke:#9cc2ff;filter:drop-shadow(0 0 4px rgba(120,170,255,.8))}
.card.gcheck{border-color:#6f93e8;box-shadow:0 0 0 1px #000,0 0 18px rgba(110,160,255,.35),inset 0 0 40px rgba(110,160,255,.07)}
.pick{flex:none;display:flex;flex-direction:column;align-items:center;gap:4px;cursor:pointer}
.pick span{font-family:"Cinzel",Georgia,serif;font-size:11px;color:var(--gold2);text-align:center;max-width:110px;line-height:1.2}
.pick input{position:absolute;opacity:0;pointer-events:none}
.box{width:34px;height:34px;border:2px solid var(--gold2);border-radius:4px;background:#050818;
  box-shadow:inset 0 0 8px #000,0 0 0 1px #000;display:flex;align-items:center;justify-content:center;transition:all .12s}
.box svg{width:24px;height:24px;stroke:var(--gold);stroke-width:3.5;fill:none;stroke-linecap:round;stroke-linejoin:round;opacity:0}
.pick:hover .box{border-color:var(--gold);box-shadow:inset 0 0 8px #000,0 0 10px rgba(255,209,66,.45)}
.pick input:checked + .box{background:linear-gradient(180deg,#1d3a1d,#0e2a0e);border-color:var(--green)}
.pick input:checked ~ span{color:var(--green)}
.pick input:checked + .box svg{opacity:1;stroke:#7dff7d;filter:drop-shadow(0 0 4px rgba(90,255,90,.7))}
.pick input:focus-visible + .box{outline:2px solid var(--gold);outline-offset:2px}
.empty{text-align:center;color:var(--muted);padding:40px 0;font-family:"Cinzel",Georgia,serif}
.foot{margin-top:24px;text-align:center;color:var(--muted);font-size:12px}
.foot b{color:var(--gold2)}
@media(max-width:700px){.head h1{font-size:22px}.head .modebadge{display:none}.bar{position:static}.tip{flex:1 1 calc(100% - 70px);min-width:0}.meta,.picks{flex-basis:100%}.picks{margin-left:0;flex-wrap:wrap}.pick{flex-direction:row;gap:10px}.pick span{max-width:none;text-align:left}.bar input[type=text]{width:100%}}
</style></head><body><div class="wrap">

<div class="head">
  __LOGO__
  <div><h1>BananaBank</h1><div class="sub">__SUB__</div></div>
  <div class="modebadge">__MODE__<b>__N__ Items</b></div>
</div>

<div class="bar">
  <div class="row1">
    <input type="text" id="q" placeholder="Suchen …" autocomplete="off">
    <select id="sort">
      <option value="name">Sortierung: Name</option>
      <option value="q">Qualität ↓</option>
      <option value="p">AH-Preis ↓</option>
      <option value="c">Menge ↓</option>
      <option value="orig">Reihenfolge Export</option>
    </select>
    <button class="btn ghost" id="vis">Sichtbare anhaken</button>
    <button class="btn ghost" id="clr">Alle abwählen</button>
    <button class="btn" id="go">Liste erstellen</button>
    <div class="count"><span id="cnt">0</span> <small>ausgewählt<span id="gcntw"> · <span id="gcnt">0</span> Gildenitem</span> · <span id="shown">0</span> sichtbar</small></div>
  </div>
  <div class="chips" id="qchips"><span class="lbl">Qualität:</span>__QCHIPS__</div>
  <div class="chips" id="sel"><span class="lbl">Anzeige:</span>
    <span class="chip on" data-sel="all">Alle</span><span class="chip" data-sel="on">Nur angehakt</span><span class="chip" data-sel="off">Nur offene</span><span class="chip" data-sel="gi">Nur Gildenitem</span>
  </div>
  <div class="res" id="res">
    <div class="hint">Diese Liste im Spiel mit <code>/bb saleimport</code> einfügen (Bank-Rang). __IMPORTHINT__</div>
    <textarea id="out" readonly></textarea>
    <button class="btn" id="copy" style="margin-top:6px">In die Zwischenablage kopieren</button>
  </div>
</div>

<div class="list" id="list">
__ROWS__
</div>
<div class="empty" id="none" style="display:none">Keine Items passen zum Filter.</div>

<div class="foot">Haken = <b>__LABEL__</b> · Der Stand deiner Haken bleibt in diesem Browser gespeichert · BananaBank __VERSION__</div>
</div>

<script>
var MODE=__MODEJSON__, HASGI=(MODE!=='guild'), KEY="bb-export-__TS__-"+MODE;
var list=document.getElementById('list');
var cards=[].slice.call(list.querySelectorAll('.card'));
var qOn={0:1,1:1,2:1,3:1,4:1,5:1}, selMode='all';
function mb(c){return c.querySelector('input.m')}
function gb(c){return c.querySelector('input.gi')}
function paint(c){c.classList.toggle('checked',!!(mb(c)&&mb(c).checked));c.classList.toggle('gcheck',!!(gb(c)&&gb(c).checked))}
function save(){try{var v=[];cards.forEach(function(c){if(mb(c)&&mb(c).checked)v.push('m'+c.dataset.id);if(gb(c)&&gb(c).checked)v.push('g'+c.dataset.id)});localStorage.setItem(KEY,v.join(','))}catch(e){}}
function load(){try{var v=localStorage.getItem(KEY);if(!v)return;var set={};v.split(',').forEach(function(x){set[x]=1});
  cards.forEach(function(c){if(set['m'+c.dataset.id]&&mb(c))mb(c).checked=true;if(set['g'+c.dataset.id]&&gb(c))gb(c).checked=true;paint(c)})}catch(e){}}
function apply(){
  var q=document.getElementById('q').value.toLowerCase(), shown=0, on=0, gon=0;
  cards.forEach(function(c){
    var m=mb(c)&&mb(c).checked, g=gb(c)&&gb(c).checked; if(m)on++; if(g)gon++;
    var ok=c.dataset.name.indexOf(q)>=0 && qOn[c.dataset.q];
    if(selMode==='on'&&!(m||g))ok=false; if(selMode==='off'&&(m||g))ok=false; if(selMode==='gi'&&!g)ok=false;
    c.style.display=ok?'':'none'; if(ok)shown++;
  });
  document.getElementById('cnt').textContent=on;
  document.getElementById('gcnt').textContent=gon;
  document.getElementById('gcntw').style.display=HASGI?'':'none';
  document.getElementById('shown').textContent=shown;
  document.getElementById('none').style.display=shown?'none':'block';
}
function sortNow(){
  var k=document.getElementById('sort').value;
  var arr=cards.slice();
  arr.sort(function(a,b){
    if(k==='name')return a.dataset.name<b.dataset.name?-1:1;
    if(k==='q')return (b.dataset.q-a.dataset.q)||(a.dataset.name<b.dataset.name?-1:1);
    if(k==='p')return (b.dataset.p-a.dataset.p);
    if(k==='c')return (b.dataset.c-a.dataset.c);
    return a.dataset.i-b.dataset.i;});
  arr.forEach(function(c){list.appendChild(c)});
}
function num(t){return parseInt(t.replace(/\D/g,''),10)}
function build(){
  var ids=[];cards.forEach(function(c){
    if(mb(c)&&mb(c).checked)ids.push((MODE==='sale'?'-':(MODE==='guild'?'-g':''))+c.dataset.id);
    if(gb(c)&&gb(c).checked)ids.push('g'+c.dataset.id)});
  ids.sort(function(a,b){return num(a)-num(b)});
  var o=document.getElementById('out');o.value=ids.join(',');document.getElementById('res').classList.add('show');return ids.length;
}
list.addEventListener('change',function(e){var c=e.target.closest('.card');if(!c)return;
  /* Verkauf und Gildenitem schliessen sich aus */
  if(e.target.checked){var other=e.target.classList.contains('m')?gb(c):mb(c);if(other)other.checked=false}
  paint(c);save();apply();
  if(document.getElementById('res').classList.contains('show'))build();});
document.getElementById('q').oninput=apply;
document.getElementById('sort').onchange=sortNow;
document.getElementById('go').onclick=function(){build();document.getElementById('out').select()};
document.getElementById('vis').onclick=function(){cards.forEach(function(c){if(c.style.display!=='none'&&mb(c)){mb(c).checked=true;if(gb(c))gb(c).checked=false;paint(c)}});save();apply()};
document.getElementById('clr').onclick=function(){if(!confirm('Alle Haken entfernen?'))return;cards.forEach(function(c){if(mb(c))mb(c).checked=false;if(gb(c))gb(c).checked=false;paint(c)});save();apply()};
document.getElementById('copy').onclick=function(){var o=document.getElementById('out');o.select();
  try{document.execCommand('copy');this.textContent='Kopiert ✓'}catch(e){} var b=this;setTimeout(function(){b.textContent='In die Zwischenablage kopieren'},1800)};
document.getElementById('qchips').addEventListener('click',function(e){var q=e.target.dataset.q;if(q===undefined)return;
  qOn[q]=qOn[q]?0:1;e.target.classList.toggle('on',!!qOn[q]);apply()});
document.getElementById('sel').addEventListener('click',function(e){var s=e.target.dataset.sel;if(!s)return;selMode=s;
  [].forEach.call(document.querySelectorAll('#sel .chip'),function(x){x.classList.toggle('on',x===e.target)});apply()});
load();sortNow();apply();
</script></body></html>
"""


CHECK_SVG = '<svg viewBox="0 0 24 24"><path d="M4 12.5l5 5L20 6.5"/></svg>'


def make_html(data, out, icons_dir):
    import base64
    mode = data.get("mode", "open")
    label = {"open": "Zum Verkauf freigeben", "sale": "Freigabe zurücknehmen", "all": "Verkaufsfähig markieren",
             "guild": "Gildenitem-Markierung entfernen"}.get(mode, "Auswahl")
    stamp = label
    mode_txt = {"open": "Noch nicht verkaufsfähig", "sale": "Verkaufsfähige Items (Kontrolle)", "all": "Alle Items",
                "guild": "Gildenitems (Kontrolle)"}.get(mode, "Items")
    qnames = {0: "Schlecht", 1: "Gewöhnlich", 2: "Ungewöhnlich", 3: "Selten", 4: "Episch", 5: "Legendär"}
    qcol = {0: "#9d9d9d", 1: "#ffffff", 2: "#1eff00", 3: "#0070dd", 4: "#a335ee", 5: "#ff8000"}
    present = sorted({int(it.get("q", 1)) for it in data["items"]})
    qchips = "".join('<span class="chip on" data-q="%d">%s</span>' % (q, qnames.get(q, str(q))) for q in present)
    rows = []
    for idx, it in enumerate(data["items"]):
        q = int(it.get("q", 1))
        ip = icon_path(it.get("tex", ""), icons_dir)
        if ip:
            with open(ip, "rb") as f:
                bg = 'background-image:url(data:image/jpeg;base64,%s)' % base64.b64encode(f.read()).decode()
        else:
            bg = ""
        tl = []
        for l, r, col in card_lines(it):
            tl.append('<div class="l" style="color:#%s"><span>%s</span><span>%s</span></div>' % (
                col if re.match(r"^[0-9a-fA-F]{6}$", col or "") else "ffffff", html.escape(l), html.escape(r)))
        meta = '<div><span class="id">ID %d</span> · <b>Menge</b>%d</div>%s' % (it["id"], it.get("c", 0), price_html(it))
        if it.get("per"):
            meta += '<div class="banks">%s</div>' % html.escape(it["per"])
        pa = int(it.get("pa") or it.get("p") or 0)
        main_pick = ('<label class="pick"><input type="checkbox" class="m"><div class="box">' + CHECK_SVG +
                     '</div><span>' + html.escape(label) + '</span></label>')
        gi_pick = "" if mode == "guild" else (
            '<label class="pick gi"><input type="checkbox" class="gi"><div class="box">' + CHECK_SVG +
            '</div><span>Gildenitem<br>(nicht verkaufen)</span></label>')
        card = ('<div class="card" data-id="%d" data-i="%d" data-q="%d" data-p="%d" data-c="%d" data-name="%s">'
                '<div class="icon" style="--qc:%s;%s"></div><div class="tip">%s</div><div class="meta">%s</div>'
                % (it["id"], idx, q, pa, it.get("c", 0), html.escape((it.get("n") or "").lower()),
                   qcol.get(q, "#fff"), bg, "".join(tl), meta))
        rows.append(card + '<div class="picks">' + main_pick + gi_pick + '</div></div>')
    logo = logo_data_uri()
    page = HTML_TEMPLATE
    import datetime
    sub = "Verkaufsliste prüfen"
    if data.get("ts"):
        sub += " · Export vom " + datetime.datetime.fromtimestamp(int(data["ts"])).strftime("%d.%m.%Y %H:%M")
    if data.get("by"):
        sub += " · " + str(data["by"])
    hint = "Zahlen = freigeben, mit Minus (-12345) = Freigabe zurücknehmen, mit g (g12345) = Gildenitem."
    for k, v in (("__LOGO__", '<img src="%s" alt="">' % logo if logo else ""), ("__SUB__", html.escape(sub)), ("__MODE__", mode_txt),
                 ("__N__", str(len(data["items"]))), ("__QCHIPS__", qchips), ("__IMPORTHINT__", hint), ("__ROWS__", "\n".join(rows)),
                 ("__LABEL__", label), ("__VERSION__", html.escape(str(data.get("version", "")))), ("__MODEJSON__", json.dumps(mode)),
                 ("__TS__", str(data.get("ts", 0)))):
        page = page.replace(k, v)
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
