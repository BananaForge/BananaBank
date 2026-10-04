-- BananaBank Gildenquests: Daten, Fortschritt aus dem Spendenbuch, Punkte, Reservierung, Log
--
-- Eine Quest verlangt ein oder mehrere Items. Der Fortschritt wird NICHT extra gezaehlt,
-- sondern aus dem Spendenbuch abgeleitet: Nimmt der Bank-Char eine Lieferung an (Post oder
-- Handel), schreibt er die Quest in den Buchungseintrag (Feld code). Alle Clients rechnen
-- dieselbe Summe, und wer offline war, holt sie beim Abgleich nach.

local BB = BananaBank
local getn = table.getn
local floor = math.floor

BB.questModule = true
BB.QUEST_MAX_ITEMS = 6
BB.QUEST_MAX_OPEN = 8
BB.QUEST_TITLE_LEN = 40
BB.QUEST_TEXT_LEN = 180
BB.QUEST_LOG_MAX = 400
BB.QUEST_POINTS = 10          -- eine ganze Quest allein erledigt = 10 Punkte
BB.QRANK = { open = 1, closed = 2, cancelled = 3 }

-- ------------------------------------------------------------
-- Rechte: Gildenmeister (Rang 1), Gildenbank (Rang 2), Offiziere (Rang 3)
-- Der Rang kommt aus der eigenen Gildenliste, nicht vom Absender.
-- ------------------------------------------------------------
function BB:CanManageQuests(name)
  name = name or self:Me()
  if not self:Ready() then return false end
  local _, idx = self:RankOf(name)
  if idx and idx <= 2 then return true end
  return self:MayBeBank(name)
end

-- ------------------------------------------------------------
-- Text-Werkzeuge
-- ------------------------------------------------------------
local function cutUtf8(s, len)
  if string.len(s) <= len then return s end
  local e = len
  while e > 0 do
    local nb = string.byte(s, e + 1)
    if nb and nb >= 128 and nb < 192 then e = e - 1 else break end
  end
  return string.sub(s, 1, e)
end

local function cleanText(s, len)
  s = BB.Clean(s)
  s = string.gsub(s, "[%c]+", " ")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return cutUtf8(s, len)
end
BB.QuestClean = cleanText

local function cleanName(s)
  s = cleanText(s, 60)
  s = string.gsub(s, "[,:;]", " ")
  return s
end

-- ------------------------------------------------------------
-- Datenbank-Zugriff
-- ------------------------------------------------------------
function BB:QuestList()
  local list = {}
  for _, q in pairs(BananaBankDB.quests) do table.insert(list, q) end
  return list
end

function BB:QuestNeed(q)
  local n = 0
  for _, need in pairs(q.items) do n = n + need end
  return n
end

-- Name, Qualitaet, Icon eines Quest-Items: zuerst der eigene Client, dann die Angaben der Quest
function BB:QuestItemInfo(q, id)
  local name, quality, tex = self:ItemInfo(id)
  if string.sub(name, 1, 1) ~= "#" then return name, quality, tex end
  local m = q and q.meta and q.meta[id]
  if m then return m.n, m.q or 1, m.t or "" end
  return name, quality, tex
end

-- ------------------------------------------------------------
-- Fortschritt (aus dem Spendenbuch abgeleitet)
-- stats[id] = { got = {itemId = n}, eff = {itemId = min(n, Bedarf)}, by = {Spieler = n},
--               done, need, complete }
-- ------------------------------------------------------------
function BB:QuestStats()
  if self.qStats and not self.qDirty then return self.qStats end
  local db = BananaBankDB
  local out = {}
  for id in pairs(db.quests) do out[id] = { got = {}, eff = {}, by = {}, done = 0, need = 0 } end
  for _, e in pairs(db.ledger) do
    if e.k == "in" and e.code ~= "" then
      local s = out[e.code]
      local q = s and db.quests[e.code]
      if q and q.items[e.i] then
        s.got[e.i] = (s.got[e.i] or 0) + e.c
        s.by[e.p] = (s.by[e.p] or 0) + e.c
      end
    end
  end
  for id, s in pairs(out) do
    local q = db.quests[id]
    for iid, need in pairs(q.items) do
      local g = s.got[iid] or 0
      if g > need then g = need end
      s.eff[iid] = g
      s.done = s.done + g
      s.need = s.need + need
    end
    s.complete = s.need > 0 and s.done >= s.need
  end
  self.qStats = out
  self.qDirty = false
  return out
end

-- offen | complete | expired | closed | cancelled
function BB:QuestState(q)
  if q.s == "cancelled" then return "cancelled" end
  if q.s == "closed" then return "closed" end
  local s = self:QuestStats()[q.id]
  if s and s.complete then return "complete" end
  if q.due and q.due > 0 and time() > q.due then return "expired" end
  return "open"
end

function BB:QuestIsActive(q)
  local st = self:QuestState(q)
  return st == "open" or st == "complete"
end

-- Reihenfolge der besten Helfer einer Quest: { {p=, c=}, ... }
function BB:QuestTop(q)
  local s = self:QuestStats()[q.id]
  local list = {}
  if s then
    for p, c in pairs(s.by) do table.insert(list, { p = p, c = c }) end
  end
  table.sort(list, function(a, b)
    if a.c == b.c then return a.p < b.p end
    return a.c > b.c
  end)
  return list
end

-- ------------------------------------------------------------
-- Ranking: Punkte = Anteil an jeder Quest, zusammengezaehlt
-- since: nur Lieferungen ab diesem Zeitpunkt (nil = dauerhaft)
-- ------------------------------------------------------------
function BB:QuestRanking(since)
  local db = BananaBankDB
  local need = {}
  for id, q in pairs(db.quests) do need[id] = self:QuestNeed(q) end
  local per = {}
  for _, e in pairs(db.ledger) do
    if e.k == "in" and e.code ~= "" and (not since or e.t >= since) then
      local q = db.quests[e.code]
      if q and q.s ~= "cancelled" and q.items[e.i] and need[q.id] > 0 then
        local r = per[e.p]
        if not r then
          r = { p = e.p, pts = 0, c = 0, quests = {}, nq = 0 }
          per[e.p] = r
        end
        r.pts = r.pts + e.c / need[q.id] * BB.QUEST_POINTS
        r.c = r.c + e.c
        if not r.quests[q.id] then
          r.quests[q.id] = true
          r.nq = r.nq + 1
        end
      end
    end
  end
  local list = {}
  for _, r in pairs(per) do table.insert(list, r) end
  table.sort(list, function(a, b)
    if a.pts ~= b.pts then return a.pts > b.pts end
    if a.c ~= b.c then return a.c > b.c end
    return a.p < b.p
  end)
  return list
end

-- ------------------------------------------------------------
-- Zuordnung einer Lieferung (Bank-Char): welche Quest bekommt wie viel?
-- Aeltere Quests zuerst. Ueberschuss bleibt normale Spende.
-- ------------------------------------------------------------
function BB:ResolveQuestItem(name, tex)
  local db = BananaBankDB
  local short = BB.ShortTex(tex)
  local texHit
  for _, q in pairs(db.quests) do
    if self:QuestState(q) == "open" then
      for iid in pairs(q.items) do
        local lname = GetItemInfo(iid)
        local m = q.meta and q.meta[iid]
        if (lname and lname == name) or (m and m.n == name) then return iid end
        if short ~= "" and m and m.t == short then texHit = iid end
      end
    end
  end
  return texHit
end

function BB:QuestSplit(id, count)
  if not id or id == 0 then return { { code = "", c = count } } end
  local stats = self:QuestStats()
  local cand = {}
  for _, q in pairs(BananaBankDB.quests) do
    local need = q.items[id]
    if need and self:QuestState(q) == "open" then
      local s = stats[q.id]
      local left = need - ((s and s.got[id]) or 0)
      if left > 0 then table.insert(cand, { q = q, left = left }) end
    end
  end
  table.sort(cand, function(a, b)
    if a.q.ts ~= b.q.ts then return a.q.ts < b.q.ts end
    return a.q.id < b.q.id
  end)
  local parts = {}
  local rest = count
  for i = 1, getn(cand) do
    if rest <= 0 then break end
    local take = cand[i].left
    if take > rest then take = rest end
    table.insert(parts, { code = cand[i].q.id, c = take })
    rest = rest - take
  end
  if rest > 0 then table.insert(parts, { code = "", c = rest }) end
  return parts
end

-- Bank-Char hat eine Lieferung fuer eine Quest gebucht
function BB:OnQuestDelivery(e)
  local q = BananaBankDB.quests[e.code]
  if not q then return end
  self:QLog("deliver", q, self:Me(), string.format("%s: %dx %s", e.p, e.c, e.n), e.id)
  local s = self:QuestStats()[q.id]
  local need = q.items[e.i] or 0
  local got = (s and s.eff[e.i]) or 0
  self:Print(string.format(self.T("QMSG_PROGRESS"), q.title, e.n, got, need))
end

-- ------------------------------------------------------------
-- Reservierung: gelieferte Items einer Quest bleiben fuer Anfragen gesperrt
-- ------------------------------------------------------------
function BB:QuestReserved(res)
  local stats = self:QuestStats()
  for id, q in pairs(BananaBankDB.quests) do
    if q.rs == 1 and self:QuestIsActive(q) then
      local s = stats[id]
      if s then
        for iid in pairs(q.items) do
          local n = s.eff[iid] or 0
          if n > 0 then res[iid] = (res[iid] or 0) + n end
        end
      end
    end
  end
end

-- ------------------------------------------------------------
-- Log (versteckt, nur ueber /bb questlog fuer Quest-Verwalter)
-- ------------------------------------------------------------
function BB:QLog(act, q, actor, x, key)
  local db = BananaBankDB
  db.qlog = db.qlog or {}
  if key then
    if not self.qlogKeys then
      self.qlogKeys = {}
      for i = 1, getn(db.qlog) do
        if db.qlog[i].k then self.qlogKeys[db.qlog[i].k] = true end
      end
    end
    if self.qlogKeys[key] then return end
    self.qlogKeys[key] = true
  end
  table.insert(db.qlog, {
    t = time(), a = actor or "?", act = act, id = q and q.id or "", title = q and q.title or "",
    x = x or "", k = key,
  })
  while getn(db.qlog) > BB.QUEST_LOG_MAX do
    local old = table.remove(db.qlog, 1)
    if old and old.k and self.qlogKeys then self.qlogKeys[old.k] = nil end
  end
end

function BB:PrintQuestLog(n)
  if not self:CanManageQuests() then
    self:Print("|cffff4040" .. self.T("ERR_QUEST_NOPERM") .. "|r")
    return
  end
  local log = BananaBankDB.qlog or {}
  n = tonumber(n) or 15
  if n < 1 then n = 1 end
  if n > 60 then n = 60 end
  local from = getn(log) - n + 1
  if from < 1 then from = 1 end
  self:Print(string.format(self.T("QLOG_HEAD"), getn(log) - from + 1, getn(log)))
  for i = from, getn(log) do
    local e = log[i]
    local line = date("%d.%m. %H:%M", e.t) .. "  |cffffd100" .. e.a .. "|r  " ..
      self.T("QLOG_" .. string.upper(e.act)) .. "  \"" .. e.title .. "\""
    if e.x and e.x ~= "" then line = line .. "  |cff9a9cb3" .. e.x .. "|r" end
    DEFAULT_CHAT_FRAME:AddMessage(line)
  end
end

-- ------------------------------------------------------------
-- Quests anlegen und aendern (nur Quest-Verwalter)
-- ------------------------------------------------------------
local function noPerm(self)
  self:Print("|cffff4040" .. self.T("ERR_QUEST_NOPERM") .. "|r")
end

function BB:CountOpenQuests()
  local n = 0
  for _, q in pairs(BananaBankDB.quests) do
    if q.s == "open" then n = n + 1 end
  end
  return n
end

-- items = { [id] = Bedarf }, meta = { [id] = { n=, q=, t= } }
function BB:CreateQuest(title, text, items, meta, days, reserve)
  if not self:CanManageQuests() then noPerm(self) return nil end
  title = cleanText(title, BB.QUEST_TITLE_LEN)
  text = cleanText(text, BB.QUEST_TEXT_LEN)
  if title == "" then self:Print("|cffff4040" .. self.T("ERR_QUEST_TITLE") .. "|r") return nil end
  if BB.Count(items) == 0 then self:Print("|cffff4040" .. self.T("ERR_QUEST_ITEMS") .. "|r") return nil end
  if self:CountOpenQuests() >= BB.QUEST_MAX_OPEN then
    self:Print("|cffff4040" .. string.format(self.T("ERR_QUEST_MAX"), BB.QUEST_MAX_OPEN) .. "|r")
    return nil
  end
  local now = time()
  local id = "G" .. self:NewCodeId()
  while BananaBankDB.quests[id] do id = "G" .. self:NewCodeId() end
  local q = {
    id = id, c = self:Me(), ts = now, s = "open", u = now, by = self:Me(),
    due = (days and days > 0) and (now + days * 86400) or 0, rs = reserve and 1 or 0,
    title = title, text = text, items = items, meta = meta or {},
  }
  BananaBankDB.quests[id] = q
  self.qDirty = true
  self:QLog("create", q, self:Me(), nil, id .. ":open:" .. q.u)
  self:PushQuests({ q })
  self:QuestTick()
  return q
end

function BB:EditQuest(q, title, text, items, meta, days, reserve)
  if not self:CanManageQuests() then noPerm(self) return false end
  if q.s ~= "open" then return false end
  title = cleanText(title, BB.QUEST_TITLE_LEN)
  text = cleanText(text, BB.QUEST_TEXT_LEN)
  if title == "" then self:Print("|cffff4040" .. self.T("ERR_QUEST_TITLE") .. "|r") return false end
  if BB.Count(items) == 0 then self:Print("|cffff4040" .. self.T("ERR_QUEST_ITEMS") .. "|r") return false end
  q.title, q.text, q.items, q.meta = title, text, items, meta or {}
  q.rs = reserve and 1 or 0
  if days and days >= 0 then
    if days == 0 then q.due = 0 else q.due = time() + days * 86400 end
  end
  q.u = math.max(time(), (q.u or 0) + 1)
  q.by = self:Me()
  self.qDirty = true
  self:QLog("edit", q, self:Me(), nil, q.id .. ":open:" .. q.u)
  self:PushQuests({ q })
  self:QuestTick()
  return true
end

-- status: "closed" (abgeschlossen, Reservierung endet) oder "cancelled"
function BB:SetQuestStatus(q, status)
  if not self:CanManageQuests() then noPerm(self) return false end
  if (BB.QRANK[q.s] or 0) >= BB.QRANK[status] then return false end
  q.s = status
  q.u = math.max(time(), (q.u or 0) + 1)
  q.by = self:Me()
  self.qDirty = true
  self:QLog(status == "closed" and "close" or "cancel", q, self:Me(), nil, q.id .. ":" .. status .. ":" .. q.u)
  self:PushQuests({ q })
  self:QuestTick()
  return true
end

-- ------------------------------------------------------------
-- Netz: Quests serialisieren und zusammenfuehren
-- ------------------------------------------------------------
function BB:SerializeQuests(list)
  local recs = {}
  for i = 1, getn(list) do
    local q = list[i]
    local its = {}
    for id, need in pairs(q.items) do
      local m = (q.meta and q.meta[id]) or {}
      table.insert(its, table.concat({ id, need, m.q or 1, BB.Clean(m.t or ""), cleanName(m.n or "") }, ":"))
    end
    table.insert(recs, table.concat({
      q.id, BB.Clean(q.c), q.ts or 0, q.s, q.u or 0, BB.Clean(q.by or ""), q.due or 0, q.rs or 0,
      cleanText(q.title, BB.QUEST_TITLE_LEN), cleanText(q.text or "", BB.QUEST_TEXT_LEN),
      table.concat(its, ","),
    }, "~"))
  end
  return table.concat(recs, "^")
end

function BB:ParseQuests(payload)
  local out = {}
  for _, rec in ipairs(BB.Split(payload, "^")) do
    local f = BB.Split(rec, "~")
    if f[1] and string.len(f[1]) == 6 and BB.QRANK[f[4] or ""] and f[9] and f[9] ~= "" then
      local items, meta, n = {}, {}, 0
      for _, p in ipairs(BB.Split(f[11] or "", ",")) do
        local g = BB.Split(p, ":")
        local id, need = tonumber(g[1]), tonumber(g[2])
        if id and need and need > 0 and need <= 99999 and n < BB.QUEST_MAX_ITEMS then
          items[id] = need
          meta[id] = { q = tonumber(g[3]) or 1, t = g[4] or "", n = g[5] or ("#" .. id) }
          n = n + 1
        end
      end
      if n > 0 then
        table.insert(out, {
          id = f[1], c = f[2], ts = tonumber(f[3]) or 0, s = f[4], u = tonumber(f[5]) or 0,
          by = f[6], due = tonumber(f[7]) or 0, rs = tonumber(f[8]) or 0,
          title = cleanText(f[9], BB.QUEST_TITLE_LEN), text = cleanText(f[10] or "", BB.QUEST_TEXT_LEN),
          items = items, meta = meta,
        })
      end
    end
  end
  return out
end

function BB:PushQuests(list, full)
  if not list then
    list = self:QuestList()
    full = true
  end
  if getn(list) == 0 and not full then return end
  self:SendTransfer("G", full and "full" or "one", self:SerializeQuests(list))
end

function BB:QuestDigest()
  local n, sum = 0, 0
  for id, q in pairs(BananaBankDB.quests) do
    n = n + 1
    sum = mod(sum + BB.Hash(id .. q.s .. (q.u or 0)), 16777213)
  end
  return n, sum
end

-- Zustand aus dem Netz uebernehmen. Gibt true zurueck, wenn sich etwas geaendert hat.
function BB:MergeQuest(r)
  local db = BananaBankDB
  -- nur Quests von Quest-Verwaltern, geprueft in der EIGENEN Gildenliste
  if not self:CanManageQuests(r.by) then
    self:Debug("Quest von " .. tostring(r.by) .. " verworfen (kein Quest-Recht)")
    return false
  end
  local cur = db.quests[r.id]
  if not cur then
    db.quests[r.id] = r
    self.qDirty = true
    self:QLog("create", r, r.c, nil, r.id .. ":open:" .. r.ts)
    if r.s ~= "open" then
      self:QLog(r.s == "closed" and "close" or "cancel", r, r.by, nil, r.id .. ":" .. r.s .. ":" .. r.u)
    end
    return true
  end
  local rc, rn = BB.QRANK[cur.s] or 0, BB.QRANK[r.s] or 0
  local changed = false
  if rn > rc then
    cur.s = r.s
    changed = true
    self:QLog(r.s == "closed" and "close" or "cancel", cur, r.by, nil, r.id .. ":" .. r.s .. ":" .. r.u)
  end
  if r.u > (cur.u or 0) and rn >= rc then
    if rn == rc and rn == 1 then
      cur.title, cur.text, cur.items, cur.meta = r.title, r.text, r.items, r.meta
      cur.due, cur.rs = r.due, r.rs
      self:QLog("edit", cur, r.by, nil, r.id .. ":open:" .. r.u)
    end
    cur.u, cur.by = r.u, r.by
    changed = true
  elseif rn > rc then
    cur.u, cur.by = math.max(cur.u or 0, r.u), r.by
  end
  if changed then self.qDirty = true end
  return changed
end

-- ------------------------------------------------------------
-- Ereignisse: neue Quest, fertig, abgelaufen ... (nur Meldungen, kein Zustand)
-- ------------------------------------------------------------
function BB:QuestTick()
  local db = BananaBankDB
  if not db then return end
  local first = not self.qSeen
  self.qSeen = self.qSeen or {}
  local stats = self:QuestStats()
  for id, q in pairs(db.quests) do
    local st = self:QuestState(q)
    local prev = self.qSeen[id]
    if not first and prev ~= st then
      if prev == nil and (st == "open" or st == "complete") then
        self:Print(string.format(self.T("QMSG_NEW"), q.title, q.by or "?"))
        if self.UI and self.UI.ShowQuestToast then
          self.UI:ShowQuestToast(self.T("QTOAST_NEW"), q.title, false)
        end
      elseif st == "complete" then
        local top = self:QuestTop(q)
        local best = top[1] and top[1].p or "-"
        self:Print(string.format(self.T("QMSG_DONE"), q.title, best))
        self:QLog("complete", q, "-", best, id .. ":complete")
        if self.UI and self.UI.ShowQuestToast then
          self.UI:ShowQuestToast(self.T("QTOAST_DONE"), q.title .. "  |cffa8a8c0" .. string.format(self.T("QTOAST_BEST"), best) .. "|r", true)
        end
      elseif st == "expired" then
        self:Print(string.format(self.T("QMSG_EXPIRED"), q.title))
        self:QLog("expire", q, "-", nil, id .. ":expire")
      elseif st == "closed" then
        self:Print(string.format(self.T("QMSG_CLOSED"), q.title, q.by or "?"))
      elseif st == "cancelled" then
        self:Print(string.format(self.T("QMSG_CANCELLED"), q.title, q.by or "?"))
      end
    end
    self.qSeen[id] = st
  end
  if self.UI then
    if self.UI.RefreshQuestTracker then self.UI:RefreshQuestTracker() end
    self.UI:Refresh()
  end
end

-- einmal pro Minute: Fristen pruefen
local tickFrame = CreateFrame("Frame")
local tickAcc = 0
tickFrame:SetScript("OnUpdate", function()
  tickAcc = tickAcc + (arg1 or 0)
  if tickAcc < 60 then return end
  tickAcc = 0
  if BananaBankDB and BB.qSeen then BB:QuestTick() end
end)
