-- BananaBank - Gildenbank fuer OctoWoW (Vanilla 1.12, Lua 5.0)
-- Teil von BananaForge. Befehl: /bb oder /bananabank
--
-- Vanilla-Regeln, die hier ueberall gelten (Lehren aus BRP, BananaLootline, HerbMineTracker):
--   * Lua 5.0: kein #, kein %, kein string.match/gmatch, kein select, keine "..."-Argumente
--   * Script-Handler bekommen keine Parameter: this, event, arg1..arg9 sind Globale
--   * kein SetSize, kein SetColorTexture, kein RegisterAddonMessagePrefix
--   * Addon-Nachrichten: max. ~250 Byte, keine "|" im Text, Versand gedrosselt ueber eine Queue

BananaBank = {}
local BB = BananaBank

BB.VERSION = "1.3.0"
BB.PREFIX = "BBNK"
BB.DONATE_NAME = "Lumihunt"
-- Einziger erlaubter Bank-Rang, deutsch und englisch. Fest eingebaut, es gibt
-- keine Einstellung dafuer. Ohne diesen Gildenrang arbeitet das Addon nicht.
BB.BANK_RANKS = { "gildenbank", "guildbank" }
BB.BANK_RANK_LABEL = "Gildenbank / Guildbank"
BB.REQ_EXPIRE = 7 * 86400      -- offene Anfragen verfallen nach 7 Tagen
BB.REQ_KEEP = 30 * 86400       -- abgeschlossene Anfragen bleiben 30 Tage sichtbar
BB.IGNORE_IDS = { [6948] = true } -- Ruhestein

local getn = table.getn
local floor = math.floor
local mod = math.mod or math.fmod
BB.mod = mod

-- ------------------------------------------------------------
-- Ausgabe
-- ------------------------------------------------------------
function BB:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100BananaBank:|r " .. tostring(msg))
end

function BB:Debug(msg)
  if BananaBankDB and BananaBankDB.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[BB]|r " .. tostring(msg))
  end
end

-- ------------------------------------------------------------
-- Text-Werkzeuge
-- ------------------------------------------------------------
function BB.Split(s, sep)
  local t = {}
  if s == nil or s == "" then return t end
  local start = 1
  while true do
    local a, b = string.find(s, sep, start, true)
    if not a then
      table.insert(t, string.sub(s, start))
      break
    end
    table.insert(t, string.sub(s, start, a - 1))
    start = b + 1
  end
  return t
end

-- Entfernt Zeichen, die das Protokoll oder den WoW-Chat stoeren
function BB.Clean(s)
  s = tostring(s or "")
  s = string.gsub(s, "[|~%^]", "")
  return s
end

local DIG = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
function BB.ToB36(n)
  n = floor(n or 0)
  if n <= 0 then return "0" end
  local s = ""
  while n > 0 do
    local r = mod(n, 36)
    s = string.sub(DIG, r + 1, r + 1) .. s
    n = floor(n / 36)
  end
  return s
end

function BB.Pad(s, len)
  while string.len(s) < len do s = "0" .. s end
  return s
end

function BB.Hash(s)
  local h = 5381
  for i = 1, string.len(s) do
    h = mod(h * 33 + string.byte(s, i), 16777213)
  end
  return h
end

function BB.Count(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

function BB.Money(copper)
  copper = floor(copper or 0)
  local g = floor(copper / 10000)
  local s = floor(mod(copper, 10000) / 100)
  local c = mod(copper, 100)
  -- Zahl und Einheit in der Farbe der Muenze. Fuehrende Nullen fallen weg:
  -- unter einem Gold steht kein "0g" davor.
  local out = ""
  if g > 0 then out = out .. "|cffffd700" .. g .. "g|r " end
  if g > 0 or s > 0 then out = out .. "|cffc7c7cf" .. s .. "s|r " end
  out = out .. "|cffeda55f" .. c .. "c|r"
  return out
end

BB.COIN_COLOR = { g = "ffd700", s = "c7c7cf", c = "eda55f" }

-- Gold, Silber, Kupfer einzeln
function BB.SplitMoney(copper)
  copper = floor(copper or 0)
  return floor(copper / 10000), floor(mod(copper, 10000) / 100), mod(copper, 100)
end

function BB.Date(ts)
  if not ts or ts == 0 then return "-" end
  return date("%d.%m. %H:%M", ts)
end

-- ------------------------------------------------------------
-- Item-Hilfen
-- ------------------------------------------------------------
BB.QUALITY_COLOR = {
  [0] = { 0.62, 0.62, 0.62, "9d9d9d" },
  [1] = { 1.00, 1.00, 1.00, "ffffff" },
  [2] = { 0.12, 1.00, 0.00, "1eff00" },
  [3] = { 0.00, 0.44, 0.87, "0070dd" },
  [4] = { 0.64, 0.21, 0.93, "a335ee" },
  [5] = { 1.00, 0.50, 0.00, "ff8000" },
}
local HEX_TO_Q = {}
for q, c in pairs(BB.QUALITY_COLOR) do HEX_TO_Q[c[4]] = q end

-- liest ID, Name und Qualitaet aus einem Item-Link
function BB.ParseLink(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  local _, _, name = string.find(link, "%[(.-)%]")
  local _, _, hex = string.find(link, "|c%x%x(%x%x%x%x%x%x)")
  local q = 1
  if hex then q = HEX_TO_Q[string.lower(hex)] or 1 end
  return tonumber(id), name, q
end

function BB.ShortTex(tex)
  if not tex then return "" end
  local _, _, short = string.find(tex, "[Ii]cons\\(.+)$")
  return short or tex
end

function BB.FullTex(short)
  if not short or short == "" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  if string.find(short, "\\") then return short end
  return "Interface\\Icons\\" .. short
end

-- Name/Qualitaet/Icon zu einer ID: erst Bestand, dann Client-Cache
function BB:ItemInfo(id)
  local st = self.stockCache and self.stockCache[id]
  if st then return st.n, st.q, st.t end
  for _, snap in pairs(BananaBankDB.snaps) do
    local it = snap.items[id]
    if it then return it.n, it.q, it.t end
  end
  local name, _, q, _, _, _, _, _, tex = GetItemInfo(id)
  if name then return name, q or 1, BB.ShortTex(tex) end
  return "#" .. id, 1, ""
end

function BB:ColoredName(id)
  local n, q = self:ItemInfo(id)
  local c = BB.QUALITY_COLOR[q or 1] or BB.QUALITY_COLOR[1]
  return "|cff" .. c[4] .. n .. "|r"
end

-- ------------------------------------------------------------
-- Datenbank
-- ------------------------------------------------------------
function BB:InitDB()
  if type(BananaBankDB) ~= "table" then BananaBankDB = {} end
  local db = BananaBankDB
  db.v = 1
  if db.lang == nil then db.lang = "auto" end
  db.banks = db.banks or {}       -- Chars dieses Accounts, die als Bank laufen
  db.snaps = db.snaps or {}       -- Bestand je Bank-Char
  db.bankCache = db.bankCache or {} -- zuletzt gesehener Bankfach-Inhalt je Bank-Char
  db.reqs = db.reqs or {}         -- Anfragen/Reservierungen nach Code
  db.ledger = db.ledger or {}     -- Buchungen nach ID
  db.seqs = db.seqs or {}         -- hoechste bekannte Buchungsnummer je Ursprung
  db.hidden = db.hidden or {}     -- vom Bank-Char ausgeblendete Item-IDs
  db.prices = db.prices or {}     -- Gildenpreise je Item-ID
  db.bind = db.bind or {}         -- Bindungsart je Item-ID (boe/bop/none)
  db.priceTs = db.priceTs or 0    -- juengster Preisstand
  db.priceScan = db.priceScan or { ts = 0, seen = 0, set = 0 }
  db.cod = db.cod ~= false        -- Nachnahme beim Versand verwenden
  db.ranks = db.ranks or {}       -- zuletzt gesehener Gildenrang je Name
  -- Altlasten aus Version 1.2.x: der Rang war frueher einstellbar
  db.bankRank, db.bankRankTs, db.rankSeenEver = nil, nil, nil
  db.basket = db.basket or {}     -- aktueller Warenkorb
  db.minimap = db.minimap or { angle = 200, hide = false }
  db.auto = db.auto or false      -- Briefe automatisch nacheinander senden
  self:CleanupRequests()
end

-- ------------------------------------------------------------
-- Gildenrang
-- Die Rangliste kommt vom Server. Ein Client kann seinen eigenen Rang
-- nicht faelschen, darum schaut jeder Client den Rang eines Bank-Chars
-- in seiner EIGENEN Gildenliste nach.
-- Es gibt genau zwei erlaubte Rangnamen (BB.BANK_RANKS). Der Rang muss in
-- der Gilde existieren, sonst ist das Addon gesperrt.
-- ------------------------------------------------------------
local function norm(s)
  s = string.lower(tostring(s or ""))
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end
BB.NormRank = norm

local function isBankRank(rank)
  local r = norm(rank)
  for i = 1, getn(BB.BANK_RANKS) do
    if BB.BANK_RANKS[i] == r then return true end
  end
  return false
end

function BB:ReadRoster()
  if not IsInGuild() then return end
  local db = BananaBankDB
  if not db then return end
  local n = 0
  if GetNumGuildMembers then
    n = GetNumGuildMembers(1) or GetNumGuildMembers() or 0
  end
  if n <= 0 then return end
  local exists = false
  for i = 1, n do
    local name, rank, rankIndex = GetGuildRosterInfo(i)
    if name and rank then
      db.ranks[name] = { r = rank, i = rankIndex or 99 }
      if isBankRank(rank) then exists = true end
    end
  end
  self.rankExists = exists
  self.rosterReady = true
end

function BB:RequestRoster()
  if IsInGuild() and GuildRoster then GuildRoster() end
end

-- Gibt es den Bank-Rang in dieser Gilde, also traegt ihn jemand in der
-- aktuellen Gildenliste?
function BB:BankRankExists()
  return self.rankExists == true
end

-- Das Addon arbeitet nur in einer Gilde, die den Bank-Rang hat.
function BB:Ready()
  return IsInGuild() and self:BankRankExists()
end

function BB:RankOf(name)
  local e = BananaBankDB.ranks[name]
  if not e then return nil, nil end
  return e.r, e.i
end

-- Darf dieser Char als Bank gelten? Nur wenn er einen der beiden Raenge
-- nachweislich traegt. Unbekannt zaehlt als nein.
function BB:MayBeBank(name)
  if not self:Ready() then return false end
  local rank = self:RankOf(name)
  if not rank then return false end
  return isBankRank(rank)
end

-- Ist dieser Char ein verifizierter Bank-Char (gesetzt und mit dem Rang)?
function BB:BankActive()
  return self:IsBank() and self:MayBeBank(self:Me())
end

-- Wer traegt den Bank-Rang?
function BB:RankHolders()
  local names = {}
  for name, e in pairs(BananaBankDB.ranks) do
    if isBankRank(e.r) then table.insert(names, name) end
  end
  table.sort(names)
  return names
end

-- Wer bekommt Warnungen zu sehen: oberste zwei Raenge und Bank-Chars
function BB:IsOfficer()
  if self:IsBank() then return true end
  local _, idx = self:RankOf(self:Me())
  return idx ~= nil and idx <= 1
end

function BB:Me()
  return UnitName("player") or "Unknown"
end

function BB:IsBank()
  return BananaBankDB and BananaBankDB.banks[self:Me()] and true or false
end

function BB:SetBank(on)
  local me = self:Me()
  if on then
    if not self:Ready() then
      self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_MISSING"), BB.BANK_RANK_LABEL) .. "|r")
      return
    end
    if not self:MayBeBank(me) then
      self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_REQUIRED"),
        BB.BANK_RANK_LABEL, (self:RankOf(me)) or "?") .. "|r")
      return
    end
    BananaBankDB.banks[me] = true
    self:Print(string.format(self.T("MSG_BANK_SET"), me))
  else
    BananaBankDB.banks[me] = nil
    self:Print(string.format(self.T("MSG_BANK_REMOVED"), me))
  end
  if self.UI and self.UI.OnBankModeChanged then self.UI:OnBankModeChanged() end
end

-- ------------------------------------------------------------
-- Bestand und Reservierungen
-- ------------------------------------------------------------
-- Gesamtbestand ueber alle Bank-Chars: id -> {c, q, t, n, per={bank=c}}
function BB:GetStock()
  local out = {}
  local db = BananaBankDB
  for bank, snap in pairs(db.snaps) do
   -- Bestaende von Chars ohne den Bank-Rang zaehlen nicht mit, auch wenn
   -- sie frueher einmal angenommen wurden.
   if self:MayBeBank(bank) then
    for id, it in pairs(snap.items) do
      if not db.hidden[id] then
        local e = out[id]
        if not e then
          e = { c = 0, q = it.q, t = it.t, n = it.n, per = {} }
          out[id] = e
        end
        e.c = e.c + it.c
        e.per[bank] = (e.per[bank] or 0) + it.c
      end
    end
   end
  end
  self.stockCache = out
  return out
end

function BB:ReqState(r)
  if r.s == "open" and time() - (r.ts or 0) > self.REQ_EXPIRE then return "expired" end
  return r.s
end

function BB:IsActive(r)
  local s = self:ReqState(r)
  return s == "open" or s == "confirmed"
end

-- reservierte Menge je Item (offene und bestaetigte Anfragen, abzueglich Versandtem)
function BB:GetReserved(exceptCode)
  local res = {}
  for code, r in pairs(BananaBankDB.reqs) do
    if code ~= exceptCode and self:IsActive(r) then
      for id, n in pairs(r.items) do
        local left = n - ((r.sent and r.sent[id]) or 0)
        if left > 0 then res[id] = (res[id] or 0) + left end
      end
    end
  end
  return res
end

function BB:GetAvailable(id, stock, res)
  stock = stock or self.stockCache or self:GetStock()
  res = res or self:GetReserved()
  local e = stock[id]
  local c = e and e.c or 0
  local a = c - (res[id] or 0)
  if a < 0 then a = 0 end
  return a, c, (res[id] or 0)
end

function BB:NewestSnapshot()
  local best
  for bank, snap in pairs(BananaBankDB.snaps) do
    if self:MayBeBank(bank) then
      if not best or snap.ts > best.ts then best = snap end
    end
  end
  return best
end

function BB:TotalGold()
  local g = 0
  for bank, snap in pairs(BananaBankDB.snaps) do
    if self:MayBeBank(bank) then g = g + (snap.gold or 0) end
  end
  return g
end

-- ------------------------------------------------------------
-- Anfrage-Codes
-- Format: BB1-<ID>-<Spieler>-<Item>x<Anzahl>.<Item>x<Anzahl>-<Pruefsumme>
-- Keine Zeichen, die Discord umformatiert (* _ ~ `) oder WoW stoeren (|).
-- ------------------------------------------------------------
function BB:ItemsToString(items)
  local ids = {}
  for id in pairs(items) do table.insert(ids, id) end
  table.sort(ids)
  local parts = {}
  for i = 1, getn(ids) do
    local id = ids[i]
    if items[id] and items[id] > 0 then
      table.insert(parts, id .. "x" .. items[id])
    end
  end
  return table.concat(parts, ".")
end

function BB:StringToItems(s)
  local items = {}
  for _, part in ipairs(BB.Split(s or "", ".")) do
    local _, _, id, n = string.find(part, "^(%d+)x(%d+)$")
    if id then items[tonumber(id)] = (items[tonumber(id)] or 0) + tonumber(n) end
  end
  return items
end

function BB:BuildCode(id, player, items)
  local body = "BB1-" .. id .. "-" .. player .. "-" .. self:ItemsToString(items)
  local chk = BB.Pad(BB.ToB36(mod(BB.Hash(body), 46656)), 3)
  return body .. "-" .. chk
end

-- sucht einen Code in beliebigem Text (z.B. ganze Discord-Nachricht)
function BB:ParseCode(text)
  if not text then return nil, "EMPTY" end
  local _, _, id, player, items, chk = string.find(text, "BB1%-(%w+)%-([^%-%s`]+)%-([%dx%.]+)%-(%w+)")
  if not id then return nil, "ERR_NO_CODE" end
  local body = "BB1-" .. id .. "-" .. player .. "-" .. items
  local expect = BB.Pad(BB.ToB36(mod(BB.Hash(body), 46656)), 3)
  if string.upper(chk) ~= expect then return nil, "ERR_CHECKSUM" end
  local it = self:StringToItems(items)
  if BB.Count(it) == 0 then return nil, "ERR_NO_ITEMS" end
  return { id = string.upper(id), p = player, items = it, code = body .. "-" .. expect }
end

function BB:NewCodeId()
  local n = mod(time(), 1679616) * 36 + math.random(0, 35)
  return BB.Pad(BB.ToB36(mod(n, 60466176)), 5)
end

-- ------------------------------------------------------------
-- Anfragen verwalten
-- Status: open -> confirmed -> sent | rejected | cancelled (expired wird berechnet)
-- ------------------------------------------------------------
BB.RANK = { open = 1, confirmed = 2, rejected = 3, cancelled = 3, sent = 4 }

function BB:CreateRequest(items)
  if not self:Ready() then return nil end
  local clean = {}
  for id, n in pairs(items) do
    if n and n > 0 then clean[id] = n end
  end
  if BB.Count(clean) == 0 then return nil end
  local id = self:NewCodeId()
  local me = self:Me()
  local r = {
    id = id, p = me, ts = time(), items = clean, s = "open", u = time(), by = me, sent = {},
  }
  r.code = self:BuildCode(id, me, clean)
  BananaBankDB.reqs[id] = r
  self:PushRequests({ r })
  return r
end

-- nimmt einen per Code eingefuegten Auftrag auf (Bank-Seite)
function BB:ImportRequest(parsed)
  local r = BananaBankDB.reqs[parsed.id]
  if not r then
    r = {
      id = parsed.id, p = parsed.p, ts = time(), items = parsed.items, s = "open",
      u = time(), by = parsed.p, sent = {}, code = parsed.code,
    }
    BananaBankDB.reqs[parsed.id] = r
  end
  return r
end

function BB:SetStatus(r, status)
  r.s = status
  r.u = time()
  r.by = self:Me()
  self:PushRequests({ r })
  if self.UI then self.UI:Refresh() end
end

function BB:MergeRequest(r)
  local db = BananaBankDB
  local cur = db.reqs[r.id]
  if not cur then
    db.reqs[r.id] = r
    return true
  end
  local changed = false
  local rc, rn = BB.RANK[cur.s] or 0, BB.RANK[r.s] or 0
  if rn > rc or (rn == rc and (r.u or 0) > (cur.u or 0)) then
    if cur.s ~= r.s or cur.u ~= r.u then changed = true end
    local before = cur.s
    cur.s, cur.u, cur.by = r.s, r.u, r.by
    -- eigene Anfrage: Statuswechsel im Chat melden
    if cur.p == self:Me() and before ~= cur.s then
      self:Print(string.format(self.T("MSG_STATUS_CHANGED"), cur.id, self.T("STATUS_" .. string.upper(cur.s))))
    end
  end
  cur.sent = cur.sent or {}
  for id, n in pairs(r.sent or {}) do
    if n > (cur.sent[id] or 0) then
      cur.sent[id] = n
      changed = true
    end
  end
  return changed
end

function BB:RequestComplete(r)
  for id, n in pairs(r.items) do
    if ((r.sent and r.sent[id]) or 0) < n then return false end
  end
  return true
end

function BB:CleanupRequests()
  local now = time()
  for code, r in pairs(BananaBankDB.reqs) do
    local st = self:ReqState(r)
    local done = not (st == "open" or st == "confirmed")
    local ref = r.u or r.ts or 0
    if st == "expired" then ref = (r.ts or 0) + self.REQ_EXPIRE end
    if done and now - ref > self.REQ_KEEP then BananaBankDB.reqs[code] = nil end
  end
end

-- Pruefsumme ueber alle bekannten Anfragen (fuer den Abgleich beim Login)
function BB:RequestDigest()
  local n, sum = 0, 0
  for code, r in pairs(BananaBankDB.reqs) do
    local sent = 0
    for _, v in pairs(r.sent or {}) do sent = sent + v end
    n = n + 1
    sum = mod(sum + BB.Hash(code .. r.s .. sent), 16777213)
  end
  return n, sum
end

-- ------------------------------------------------------------
-- Buchungen (Ledger)
-- Arten: out (Ausgabe an Spieler:in), in (Item-Spende), gold (Gold-Spende), back (Rueckläufer)
-- ------------------------------------------------------------
function BB:AddLedger(e)
  local origin = self:Me()
  local db = BananaBankDB
  local seq = (db.seqs[origin] or 0) + 1
  db.seqs[origin] = seq
  e.id = origin .. ":" .. seq
  e.t = e.t or time()
  e.p = BB.Clean(e.p or "?")
  e.n = BB.Clean(e.n or "")
  e.c = e.c or 0
  e.m = e.m or 0
  e.i = e.i or 0
  e.q = e.q or 1
  e.code = BB.Clean(e.code or "")
  db.ledger[e.id] = e
  self:ScheduleLedgerPush()
  return e
end

function BB:LedgerSorted()
  local list = {}
  for _, e in pairs(BananaBankDB.ledger) do table.insert(list, e) end
  table.sort(list, function(a, b)
    if a.t == b.t then return a.id > b.id end
    return a.t > b.t
  end)
  return list
end

-- Summen je Spieler:in: kind "out" oder "in" (in enthaelt Gold)
function BB:LedgerTotals(kind)
  local tot = {}
  for _, e in pairs(BananaBankDB.ledger) do
    local k = e.k
    local match = (kind == "out" and (k == "out" or k == "gout")) or (kind == "in" and (k == "in" or k == "gold"))
    if kind == "cod" then match = (k == "cod") end
    if match then
      local t = tot[e.p]
      if not t then
        t = { p = e.p, c = 0, m = 0 }
        tot[e.p] = t
      end
      t.c = t.c + (e.c or 0)
      t.m = t.m + (e.m or 0)
    end
  end
  -- Rueckblaeufer (Post kam zurueck) mindern die Ausgaben dieser Person
  if kind == "out" then
    for _, e in pairs(BananaBankDB.ledger) do
      local t = e.k == "back" and tot[e.p]
      if t then
        t.c = math.max(0, t.c - (e.c or 0))
        local u = e.i and e.i ~= 0 and self:GetPrice(e.i)
        if u then t.m = math.max(0, t.m - u * (e.c or 0)) end
      end
    end
  end
  local list = {}
  for _, t in pairs(tot) do table.insert(list, t) end
  table.sort(list, function(a, b)
    if a.c == b.c then return a.m > b.m end
    return a.c > b.c
  end)
  return list
end

function BB:CodTotal()
  local paid, open = 0, 0
  for _, e in pairs(BananaBankDB.ledger) do
    if e.k == "cod" then paid = paid + (e.m or 0) end
    if e.k == "out" and (e.m or 0) > 0 then open = open + e.m end
  end
  if open < paid then open = paid end
  return paid, open - paid
end

-- Platzhalter fuer Prices.lua. Laedt die Datei nicht (z.B. veraltete TOC),
-- laeuft der Rest trotzdem weiter, statt bei jedem Klick Fehler zu werfen.
function BB:PriceTotal() return 0, 0 end
function BB:GetPrice() return nil end
function BB:IsBOE() return false end
function BB:MailCod() return 0 end
function BB:PushPrices() end
function BB:ResetPrice() end
function BB:AHOpen() return false end
function BB:SchedulePricePush() end
function BB:ParsePrices() return {} end
function BB:MergePrices() return 0 end
function BB:BindOfItem() return "none" end
function BB:StartAHScan() self:Print(self.T("ERR_MODULE_MISSING")) end
function BB:StopAHScan() end
function BB:OnAuctionUpdate() end

-- Zeigt in ein paar Zeilen, warum kein Bestand da ist
function BB:Status()
  local db = BananaBankDB
  local me = self:Me()
  self:Print("--- Status v" .. self.VERSION .. " ---")
  self:Print(string.format(self.T("ST_CHAR"), me,
    self:IsBank() and self.T("YES") or self.T("NO"), BB.Count(db.banks)))
  local snaps = 0
  for bank, snap in pairs(db.snaps) do
    snaps = snaps + 1
    local mark = ""
    if snap.partial then mark = "  |cffff8000" .. self.T("ST_PARTIAL") .. "|r" end
    self:Print(string.format(self.T("ST_SNAP"), bank, BB.Count(snap.items),
      BB.Date(snap.ts), snap.from or "?") .. mark)
  end
  if snaps == 0 then self:Print("|cffff8000" .. self.T("ST_NO_SNAP") .. "|r") end
  local cache = db.bankCache[me]
  self:Print(string.format(self.T("ST_BANKCACHE"), cache and BB.Count(cache) or 0,
    self.bankOpen and self.T("YES") or self.T("NO")))
  local stock = self:GetStock()
  self:Print(string.format(self.T("ST_STOCK"), BB.Count(stock), BB.Count(db.hidden),
    BB.Count(db.prices)))
  self:Print(string.format(self.T("ST_GUILD"), IsInGuild() and self.T("YES") or self.T("NO"),
    BB.Count(db.reqs), BB.Count(db.ledger)))
  local myRank = self:RankOf(me) or "?"
  self:Print(string.format(self.T("ST_RANK"), myRank, BB.BANK_RANK_LABEL,
    self:BankRankExists() and self.T("YES") or self.T("NO")))
  local holders = self:RankHolders()
  if getn(holders) > 0 then
    self:Print(string.format(self.T("ST_RANK_HOLDERS"), getn(holders), table.concat(holders, ", ")))
  end

  -- konkreter Rat
  if not IsInGuild() then
    self:Print("|cffff4040" .. self.T("GATE_NO_GUILD") .. "|r")
  elseif not self:BankRankExists() then
    self:Print("|cffff4040" .. string.format(self.T("ST_HINT_RANK"), BB.BANK_RANK_LABEL) .. "|r")
  elseif self:IsBank() and not self:MayBeBank(me) then
    self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_LOST"), BB.BANK_RANK_LABEL) .. "|r")
  elseif not self:IsBank() and snaps == 0 then
    self:Print("|cffff8000" .. self.T("ST_HINT_SETBANK") .. "|r")
  elseif self:IsBank() and not cache then
    self:Print("|cffff8000" .. self.T("ST_HINT_BANK") .. "|r")
  elseif BB.Count(stock) == 0 and BB.Count(db.hidden) > 0 then
    self:Print("|cffff8000" .. self.T("ST_HINT_HIDDEN") .. "|r")
  end
end

function BB:CheckModules()
  local missing = {}
  if not self.priceModule then table.insert(missing, "Prices.lua") end
  if not (self.UI and self.UI.priceModule) then table.insert(missing, "UI_Prices.lua") end
  if table.getn(missing) > 0 then
    self:Print("|cffff4040" .. string.format(self.T("ERR_FILES_MISSING"), table.concat(missing, ", ")) .. "|r")
    return false
  end
  return true
end

-- ------------------------------------------------------------
-- Timer (eine OnUpdate-Schleife fuer alles)
-- ------------------------------------------------------------
BB.timers = {}
function BB:After(sec, fn, key)
  key = key or tostring(fn)
  self.timers[key] = { at = GetTime() + sec, fn = fn }
end

function BB:Cancel(key)
  self.timers[key] = nil
end

local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function()
  local now = GetTime()
  local due
  for key, t in pairs(BB.timers) do
    if now >= t.at then
      due = due or {}
      table.insert(due, key)
    end
  end
  if due then
    for i = 1, getn(due) do
      local t = BB.timers[due[i]]
      BB.timers[due[i]] = nil
      if t then t.fn() end
    end
  end
end)
