-- BananaBank Bank-Verzeichnis: Rollen der Bank-Chars, Item-Kategorien, Abgleich
--
-- Jede Bank pflegt ihre Rolle selbst: eine kurze Rolle, eine Beschreibung und die Kategorien,
-- fuer die sie zustaendig ist. Die Kategorie jedes Items bestimmt der Bank-Char beim Scan
-- (sprachunabhaengiger Code im Bestand), damit alle Clients dasselbe sehen.

local BB = BananaBank
local getn = table.getn

BB.bankModule = true
BB.BANK_ROLE_LEN = 40
BB.BANK_DESC_LEN = 160

-- Reihenfolge wie im Editor
BB.CATS = { "cloth", "leather", "herb", "ore", "potion", "bag", "recipe", "boe", "other" }
BB.CAT_SET = {}
for i = 1, getn(BB.CATS) do BB.CAT_SET[BB.CATS[i]] = true end

-- ------------------------------------------------------------
-- Item-Kategorie (laeuft auf dem Bank-Char beim Scan)
-- Typnamen sind je nach Client deutsch oder englisch, darum beide Schreibweisen.
-- ------------------------------------------------------------
local T_CONTAINER = { "container", "behälter" }
local T_RECIPE = { "recipe", "rezept" }
local T_TRADE = { "trade goods", "handwerkswaren" }
local T_CONSUMABLE = { "consumable", "verbrauchbar" }
local S_CLOTH = { "cloth", "stoff" }
local S_LEATHER = { "leather", "leder" }
local S_HERB = { "herb", "kräuter" }
local S_ORE = { "metal", "stone", "metall", "stein" }
local N_POTION = { "potion", "elixir", "flask", "trank", "elixier", "fläschchen" }

local function has(s, list)
  for i = 1, getn(list) do
    if string.find(s, list[i], 1, true) then return true end
  end
  return false
end

-- bind: "boe" | "bop" | "none" (vom Tooltip-Scan, siehe Prices.lua)
function BB:ItemCategory(id, bind)
  local name, _, _, _, itype, subtype = GetItemInfo(id)
  if not name then
    if bind == "boe" then return "boe" end
    return "other"
  end
  local t = string.lower(itype or "")
  local s = string.lower(subtype or "")
  if has(t, T_CONTAINER) then return "bag" end
  if has(t, T_RECIPE) then return "recipe" end
  if has(t, T_TRADE) then
    if has(s, S_CLOTH) then return "cloth" end
    if has(s, S_LEATHER) then return "leather" end
    if has(s, S_HERB) then return "herb" end
    if has(s, S_ORE) then return "ore" end
    return "other"
  end
  if has(t, T_CONSUMABLE) then
    if has(string.lower(name), N_POTION) then return "potion" end
    return "other"
  end
  if bind == "boe" then return "boe" end
  return "other"
end

function BB:CatName(cat)
  return self.T("CAT_" .. string.upper(cat or "other"))
end

-- ------------------------------------------------------------
-- Verzeichnis
-- ------------------------------------------------------------
function BB:IsOnline(name)
  if name == self:Me() then return true end
  local e = BananaBankDB.ranks[name]
  return e and e.online and true or false
end

-- alle aktiven Bank-Chars: Rang laut Gildenliste, oder Bestand von einer verifizierten Bank
function BB:BankList()
  local db = BananaBankDB
  local seen, list = {}, {}
  local function add(name)
    if not seen[name] and self:MayBeBank(name) then
      seen[name] = true
      table.insert(list, name)
    end
  end
  for name in pairs(db.snaps) do add(name) end
  for name in pairs(db.ranks) do add(name) end
  table.sort(list)
  return list
end

function BB:GetBankInfo(name)
  return BananaBankDB.binfo[name]
end

-- Kategorien einer Bank als Liste in Editor-Reihenfolge
function BB:BankTagList(name)
  local info = BananaBankDB.binfo[name]
  local out = {}
  if info then
    for i = 1, getn(BB.CATS) do
      if info.tags[BB.CATS[i]] then table.insert(out, BB.CATS[i]) end
    end
  end
  return out
end

-- Zahlen zu einer Bank: Items gesamt, verschiedene Items, Gold, Scan-Zeit, passende/unpassende Items
function BB:BankStats(name)
  local snap = BananaBankDB.snaps[name]
  if not snap then return nil end
  local info = BananaBankDB.binfo[name]
  local st = { items = 0, kinds = 0, gold = snap.gold or 0, ts = snap.ts or 0, wrong = 0, wrongKinds = 0 }
  local tagged = info and BB.Count(info.tags) > 0
  for id, it in pairs(snap.items) do
    st.items = st.items + it.c
    st.kinds = st.kinds + 1
    if tagged and it.k and not info.tags[it.k] then
      st.wrong = st.wrong + it.c
      st.wrongKinds = st.wrongKinds + 1
    end
  end
  return st
end

-- Banken, die fuer diese Kategorie zustaendig sind
function BB:BankTargets(cat)
  local out = {}
  for name, info in pairs(BananaBankDB.binfo) do
    if info.tags[cat] and self:MayBeBank(name) then table.insert(out, name) end
  end
  table.sort(out)
  return out
end

-- Tooltip-Zeilen zu einem Item: wohin es gehoert, und was falsch liegt
-- stockEntry = Eintrag aus GetStock (e.k = Kategorie, e.per = Menge je Bank)
function BB:BankHintLines(stockEntry)
  local cat = stockEntry and stockEntry.k
  if not cat then return nil end
  local targets = self:BankTargets(cat)
  if getn(targets) == 0 then return nil end
  local lines = {}
  table.insert(lines, { string.format(self.T("TT_BELONGS"), table.concat(targets, ", ")), "", 0.35, 0.88, 0.42 })
  local isTarget = {}
  for i = 1, getn(targets) do isTarget[targets[i]] = true end
  for bank, c in pairs(stockEntry.per or {}) do
    if not isTarget[bank] then
      table.insert(lines, { string.format(self.T("TT_WRONG"), c, bank), "", 1, 0.62, 0.17 })
    end
  end
  return lines
end

-- Menge eines Items auf den anderen Banken (ohne diesen Char): { {bank=, c=}, ... }
function BB:OtherBankCounts(id)
  local out = {}
  local me = self:Me()
  for bank, snap in pairs(BananaBankDB.snaps) do
    if bank ~= me and self:MayBeBank(bank) then
      local it = snap.items[id]
      if it and it.c > 0 then table.insert(out, { bank = bank, c = it.c }) end
    end
  end
  table.sort(out, function(a, b)
    if a.c ~= b.c then return a.c > b.c end
    return a.bank < b.bank
  end)
  return out
end

-- ------------------------------------------------------------
-- Eigene Rolle setzen (nur der Bank-Char selbst)
-- ------------------------------------------------------------
function BB:SetMyBankInfo(role, desc, tags)
  local me = self:Me()
  if not (self:IsBank() and self:MayBeBank(me)) then
    self:Print("|cffff4040" .. string.format(self.T("ERR_BANKINFO_NOBANK"), BB.BANK_RANK_LABEL) .. "|r")
    return false
  end
  local clean = {}
  for cat in pairs(tags or {}) do
    if BB.CAT_SET[cat] then clean[cat] = true end
  end
  local old = BananaBankDB.binfo[me]
  local u = time()
  if old and old.u >= u then u = old.u + 1 end
  local r = {
    name = me, u = u, tags = clean,
    role = BB.QuestClean and BB.QuestClean(role or "", BB.BANK_ROLE_LEN) or BB.Clean(role or ""),
    desc = BB.QuestClean and BB.QuestClean(desc or "", BB.BANK_DESC_LEN) or BB.Clean(desc or ""),
  }
  BananaBankDB.binfo[me] = r
  self:PushBankInfo({ r })
  if self.UI then self.UI:Refresh() end
  return true
end

-- ------------------------------------------------------------
-- Netz
-- ------------------------------------------------------------
function BB:SerializeBankInfo(list)
  local recs = {}
  for i = 1, getn(list) do
    local r = list[i]
    local tags = {}
    for j = 1, getn(BB.CATS) do
      if r.tags[BB.CATS[j]] then table.insert(tags, BB.CATS[j]) end
    end
    table.insert(recs, table.concat({
      BB.Clean(r.name), r.u or 0, table.concat(tags, ","), BB.Clean(r.role or ""), BB.Clean(r.desc or ""),
    }, "~"))
  end
  return table.concat(recs, "^")
end

function BB:ParseBankInfo(payload)
  local out = {}
  for _, rec in ipairs(BB.Split(payload, "^")) do
    local f = BB.Split(rec, "~")
    if f[1] and f[1] ~= "" and tonumber(f[2]) then
      local tags = {}
      for _, c in ipairs(BB.Split(f[3] or "", ",")) do
        if BB.CAT_SET[c] then tags[c] = true end
      end
      table.insert(out, {
        name = f[1], u = tonumber(f[2]), tags = tags,
        role = BB.QuestClean and BB.QuestClean(f[4] or "", BB.BANK_ROLE_LEN) or (f[4] or ""),
        desc = BB.QuestClean and BB.QuestClean(f[5] or "", BB.BANK_DESC_LEN) or (f[5] or ""),
      })
    end
  end
  return out
end

function BB:PushBankInfo(list, full)
  if not list then
    list = {}
    for _, r in pairs(BananaBankDB.binfo) do table.insert(list, r) end
    full = true
  end
  if getn(list) == 0 and not full then return end
  self:SendTransfer("I", full and "full" or "one", self:SerializeBankInfo(list))
end

function BB:BankInfoDigest()
  local n, sum = 0, 0
  for name, r in pairs(BananaBankDB.binfo) do
    n = n + 1
    sum = mod(sum + BB.Hash(name .. (r.u or 0)), 16777213)
  end
  return n, sum
end

-- Eintrag nur uebernehmen, wenn der Char wirklich eine Bank ist (Rang in der eigenen Gildenliste)
function BB:MergeBankInfo(r)
  if not self:MayBeBank(r.name) then
    self:Debug("Bank-Rolle von " .. tostring(r.name) .. " verworfen (keine Bank)")
    return false
  end
  if r.u > time() + 86400 then return false end
  local cur = BananaBankDB.binfo[r.name]
  if cur and cur.u >= r.u then return false end
  BananaBankDB.binfo[r.name] = r
  return true
end
