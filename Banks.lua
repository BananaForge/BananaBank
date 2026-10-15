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
BB.CATS = { "cloth", "leather", "herb", "ore", "trade", "potion", "bag", "recipe", "boe", "other" }
BB.CAT_SET = {}
for i = 1, getn(BB.CATS) do BB.CAT_SET[BB.CATS[i]] = true end

-- ------------------------------------------------------------
-- Item-Kategorie (laeuft auf dem Bank-Char beim Scan)
-- Typnamen sind je nach Client deutsch oder englisch, darum beide Schreibweisen.
-- Verkaufsfaehig: alles, was beim Anlegen bindet (jede Art von Item), und alle Rezepte.
-- Zweite Angabe (sub): bei Rezepten der Beruf, bei BOE die Ruestungs-/Waffenposition.
-- ------------------------------------------------------------
BB.RECIPE_SUBS = { "alch", "bs", "ench", "eng", "lw", "tail", "cook", "fa" }
BB.BOE_SUBS = { "head", "neck", "shoulder", "chest", "waist", "legs", "feet", "wrist", "hands", "finger",
  "trinket", "back", "shield", "weapon" }
BB.SUB_SET = { other = true }
for i = 1, getn(BB.RECIPE_SUBS) do BB.SUB_SET[BB.RECIPE_SUBS[i]] = true end
for i = 1, getn(BB.BOE_SUBS) do BB.SUB_SET[BB.BOE_SUBS[i]] = true end
BB.TRADE_SUBS = { "alch", "ench", "eng", "bs", "jc", "cook", "tail" }
for i = 1, getn(BB.TRADE_SUBS) do BB.SUB_SET[BB.TRADE_SUBS[i]] = true end

local T_CONTAINER = { "container", "behälter" }
local T_RECIPE = { "recipe", "rezept" }
local T_TRADE = { "trade goods", "handwerkswaren" }
local T_CONSUMABLE = { "consumable", "verbrauchbar" }
local S_CLOTH = { "cloth", "stoff" }
local S_LEATHER = { "leather", "leder" }
local S_HERB = { "herb", "kräuter" }
local S_ORE = { "metal", "stone", "metall", "stein" }
local N_POTION = { "potion", "elixir", "flask", "trank", "elixier", "fläschchen" }
local PROF = {
  { "alch", { "alchem", "alchim" } }, { "bs", { "blacksmith", "schmied" } },
  { "ench", { "enchant", "verzauber" } }, { "eng", { "engineer", "ingenieur" } },
  { "lw", { "leatherwork", "lederverarb" } }, { "tail", { "tailor", "schneider" } },
  { "cook", { "cook", "koch" } }, { "fa", { "first aid", "erste hilfe" } },
}
local SLOT = {
  INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_CHEST = "chest",
  INVTYPE_ROBE = "chest", INVTYPE_BODY = "chest", INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs",
  INVTYPE_FEET = "feet", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands", INVTYPE_FINGER = "finger",
  INVTYPE_TRINKET = "trinket", INVTYPE_CLOAK = "back", INVTYPE_SHIELD = "shield", INVTYPE_HOLDABLE = "shield",
  INVTYPE_WEAPON = "weapon", INVTYPE_2HWEAPON = "weapon", INVTYPE_WEAPONMAINHAND = "weapon",
  INVTYPE_WEAPONOFFHAND = "weapon", INVTYPE_RANGED = "weapon", INVTYPE_THROWN = "weapon",
  INVTYPE_RANGEDRIGHT = "weapon",
}

local function has(s, list)
  for i = 1, getn(list) do
    if string.find(s, list[i], 1, true) then return true end
  end
  return false
end

-- Stoff, Leder und Erz erkennt man an der Namensendung (manche Server melden bei allen Handwerkswaren denselben Untertyp)
function BB:NameCategory(name)
  local n = string.lower(name or "")
  if string.find(n, "cloth$") or string.find(n, "stoff$") then return "cloth" end
  if string.find(n, "leather$") or string.find(n, "leder$") or string.find(n, " hide$") then return "leather" end
  if string.find(n, " ore$") or string.find(n, " bar$") or string.find(n, "erz$") or string.find(n, "barren$") then return "ore" end
  return nil
end

-- Handwerksmaterial nach Beruf: erst Untertyp des Items, dann Namensstichwoerter
local TRADE_SUB_TYPE = {
  { "parts", "eng" }, { "teile", "eng" }, { "explosives", "eng" }, { "sprengstoff", "eng" }, { "devices", "eng" },
  { "enchanting", "ench" }, { "verzauberkunst", "ench" }, { "meat", "cook" }, { "fleisch", "cook" },
  { "jewelcrafting", "jc" }, { "juwelenschleifen", "jc" }, { "gem", "jc" }, { "edelstein", "jc" },
}
local TRADE_NAME = {
  { "jc", { "moonstone", "ruby", "citrine", "jade", "agate", "aquamarine", "opal", "sapphire", "emerald", "diamond", "pearl", "tigerseye", "malachite", "shadowgem", "quartz", "quarz", "mondstein", "rubin", "citrin", "achat", "saphir", "smaragd", "diamant", "perle", "tigerauge" } },
  { "ench", { "dust", "essence", "shard", "vellum", "staub", "essenz", "splitter", "pergament" } },
  { "eng", { "tube", "bolts", "powder", "fuse", "trigger", "casing", "gear", "rohr", "bolzen", "pulver", "zünder" } },
  { "tail", { "thread", "dye", "faden", "farbstoff" } },
  { "bs", { "coal", "flux", "kohle", "flussmittel" } },
  { "alch", { "vial", "oil", "phiole", "öl" } },
  { "cook", { "meat", "egg", "fleisch", "ei " } },
}
function BB:TradeSub(subtype, name)
  local st = string.lower(subtype or "")
  for i = 1, getn(TRADE_SUB_TYPE) do
    if string.find(st, TRADE_SUB_TYPE[i][1], 1, true) then return TRADE_SUB_TYPE[i][2] end
  end
  local n = string.lower(name or "")
  for i = 1, getn(TRADE_NAME) do
    if has(n, TRADE_NAME[i][2]) then return TRADE_NAME[i][1] end
  end
  return "other"
end

-- bind: "boe" | "bop" | "none" (vom Tooltip-Scan, siehe Prices.lua). Gibt Kategorie und Unterart zurueck.
function BB:ItemCategory(id, bind)
  local name, _, _, _, itype, subtype, _, equip = GetItemInfo(id)
  if not name then
    if bind == "boe" then return "boe", "other" end
    return "other", nil
  end
  local t = string.lower(itype or "")
  local s = string.lower(subtype or "")
  if has(t, T_RECIPE) then
    for i = 1, getn(PROF) do
      if has(s, PROF[i][2]) then return "recipe", PROF[i][1] end
    end
    return "recipe", "other"
  end
  if bind == "boe" then return "boe", SLOT[equip or ""] or "other" end
  if has(t, T_CONTAINER) then return "bag", nil end
  if has(t, T_TRADE) then
    if has(s, S_CLOTH) then return "cloth", nil end
    if has(s, S_LEATHER) then return "leather", nil end
    if has(s, S_HERB) then return "herb", nil end
    if has(s, S_ORE) then return "ore", nil end
    local nk = self:NameCategory(name)
    if nk then return nk, nil end
    return "trade", BB:TradeSub(subtype, name)
  end
  if has(t, T_CONSUMABLE) then
    if has(string.lower(name), N_POTION) then return "potion", nil end
    return "other", nil
  end
  return "other", nil
end

-- Filter im Bestand (fuer alle sichtbar): Typ auswaehlen, zum Beispiel alle Alchemie-Rezepte
-- header = Ueberschrift im Menue; k = Kategorie ("sell" = BOE und Rezepte), s = Unterart
BB.TYPE_FILTERS = {
  { key = "all", label = "TF_ALL" },
  { key = "sell", label = "TF_SELL", k = "sell" },
  { header = "TF_H_RECIPES" },
  { key = "rec", label = "TF_REC_ALL", k = "recipe" },
  { key = "rec:alch", label = "SUB_ALCH", k = "recipe", s = "alch", grp = "TF_G_RECIPE" },
  { key = "rec:bs", label = "SUB_BS", k = "recipe", s = "bs", grp = "TF_G_RECIPE" },
  { key = "rec:ench", label = "SUB_ENCH", k = "recipe", s = "ench", grp = "TF_G_RECIPE" },
  { key = "rec:eng", label = "SUB_ENG", k = "recipe", s = "eng", grp = "TF_G_RECIPE" },
  { key = "rec:lw", label = "SUB_LW", k = "recipe", s = "lw", grp = "TF_G_RECIPE" },
  { key = "rec:tail", label = "SUB_TAIL", k = "recipe", s = "tail", grp = "TF_G_RECIPE" },
  { key = "rec:cook", label = "SUB_COOK", k = "recipe", s = "cook", grp = "TF_G_RECIPE" },
  { key = "rec:fa", label = "SUB_FA", k = "recipe", s = "fa", grp = "TF_G_RECIPE" },
  { key = "rec:other", label = "SUB_OTHER", k = "recipe", s = "other", grp = "TF_G_RECIPE" },
  { header = "TF_H_BOE" },
  { key = "boe", label = "TF_BOE_ALL", k = "boe" },
  { key = "boe:head", label = "SUB_HEAD", k = "boe", s = "head", grp = "TF_G_BOE" },
  { key = "boe:neck", label = "SUB_NECK", k = "boe", s = "neck", grp = "TF_G_BOE" },
  { key = "boe:shoulder", label = "SUB_SHOULDER", k = "boe", s = "shoulder", grp = "TF_G_BOE" },
  { key = "boe:chest", label = "SUB_CHEST", k = "boe", s = "chest", grp = "TF_G_BOE" },
  { key = "boe:waist", label = "SUB_WAIST", k = "boe", s = "waist", grp = "TF_G_BOE" },
  { key = "boe:legs", label = "SUB_LEGS", k = "boe", s = "legs", grp = "TF_G_BOE" },
  { key = "boe:feet", label = "SUB_FEET", k = "boe", s = "feet", grp = "TF_G_BOE" },
  { key = "boe:wrist", label = "SUB_WRIST", k = "boe", s = "wrist", grp = "TF_G_BOE" },
  { key = "boe:hands", label = "SUB_HANDS", k = "boe", s = "hands", grp = "TF_G_BOE" },
  { key = "boe:back", label = "SUB_BACK", k = "boe", s = "back", grp = "TF_G_BOE" },
  { key = "boe:finger", label = "SUB_FINGER", k = "boe", s = "finger", grp = "TF_G_BOE" },
  { key = "boe:trinket", label = "SUB_TRINKET", k = "boe", s = "trinket", grp = "TF_G_BOE" },
  { key = "boe:shield", label = "SUB_SHIELD", k = "boe", s = "shield", grp = "TF_G_BOE" },
  { key = "boe:weapon", label = "SUB_WEAPON", k = "boe", s = "weapon", grp = "TF_G_BOE" },
  { key = "boe:other", label = "SUB_OTHER", k = "boe", s = "other", grp = "TF_G_BOE" },
  { header = "TF_H_MATS" },
  { key = "mat", label = "TF_MAT_ALL", k = "mat" },
  { key = "mat:cloth", label = "CAT_CLOTH", k = "cloth", grp = "TF_G_MAT" },
  { key = "mat:leather", label = "CAT_LEATHER", k = "leather", grp = "TF_G_MAT" },
  { key = "mat:herb", label = "CAT_HERB", k = "herb", grp = "TF_G_MAT" },
  { key = "mat:ore", label = "CAT_ORE", k = "ore", grp = "TF_G_MAT" },
  { key = "mat:alch", label = "SUB_ALCH", k = "trade", s = "alch", grp = "TF_G_MAT" },
  { key = "mat:ench", label = "SUB_ENCH", k = "trade", s = "ench", grp = "TF_G_MAT" },
  { key = "mat:eng", label = "SUB_ENG", k = "trade", s = "eng", grp = "TF_G_MAT" },
  { key = "mat:bs", label = "SUB_BS", k = "trade", s = "bs", grp = "TF_G_MAT" },
  { key = "mat:jc", label = "SUB_JC", k = "trade", s = "jc", grp = "TF_G_MAT" },
  { key = "mat:tail", label = "SUB_TAIL", k = "trade", s = "tail", grp = "TF_G_MAT" },
  { key = "mat:cook", label = "SUB_COOK", k = "trade", s = "cook", grp = "TF_G_MAT" },
  { key = "mat:other", label = "SUB_OTHER", k = "trade", s = "other", grp = "TF_G_MAT" },
  { key = "potion", label = "CAT_POTION", k = "potion" },
  { key = "bag", label = "CAT_BAG", k = "bag" },
  { key = "other", label = "CAT_OTHER", k = "other" },
}

function BB:FindTypeFilter(key)
  for i = 1, getn(BB.TYPE_FILTERS) do
    if BB.TYPE_FILTERS[i].key == key then return BB.TYPE_FILTERS[i] end
  end
  return nil
end

-- passt ein Bestandseintrag (e.k, e.s) zum Filter? Items ohne Kategorie (alter Stand) nur bei "Alle".
function BB:MatchTypeFilter(spec, e)
  if not spec or spec.key == "all" then return true end
  local k = e.k
  if not k then return false end
  if spec.k == "sell" then return k == "boe" or k == "recipe" end
  if spec.k == "mat" then return k == "cloth" or k == "leather" or k == "herb" or k == "ore" or k == "trade" end
  if k ~= spec.k then return false end
  if spec.s and e.s ~= spec.s then return false end
  return true
end

-- Kategorie fuer die Anzeige: gespeicherte aus dem Snapshot, sonst lokal bestimmt, sonst nach dem Namen.
-- So landen auch Eintraege alter Snapshots (ohne Kategorie) in der richtigen Gruppe.
function BB:ResolveCategory(id, e)
  if not e.k or e.k == "other" or e.k == "trade" then
    local nk = self:NameCategory(e.n)
    if nk then return nk, nil end
  end
  if e.k == "trade" and not e.s then
    local _, _, _, _, _, st = GetItemInfo(id)
    return "trade", self:TradeSub(st, e.n)
  end
  if e.k and e.k ~= "other" then return e.k, e.s end
  local bind = BananaBankDB.bind and BananaBankDB.bind[id]
  local k, sub = self:ItemCategory(id, bind)
  if k and k ~= "other" then return k, sub end
  local n = string.lower(e.n or "")
  if string.find(n, "cloth$") or string.find(n, "stoff$") then return "cloth", nil end
  if string.find(n, "leather$") or string.find(n, "leder$") or string.find(n, " hide$") then return "leather", nil end
  if string.find(n, " ore$") or string.find(n, " bar$") or string.find(n, "erz$") or string.find(n, "barren$") then return "ore", nil end
  if string.find(n, "potion") or string.find(n, "elixir") or string.find(n, "flask") or string.find(n, "trank") then return "potion", nil end
  if not GetItemInfo(id) then
    local sub = self:TradeSub(nil, n)
    if sub ~= "other" then return "trade", sub end
  end
  return "other", nil
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

-- ------------------------------------------------------------
-- Hauptbank: der Name, an den Mitglieder Spenden und Post schicken (von Verwaltern gesetzt, synchronisiert)
-- ------------------------------------------------------------
BB.MAIN_BANK_DEFAULT = "Bananenbank"

function BB:MainBank()
  local n = BananaBankDB and BananaBankDB.mainBank
  if n and n ~= "" then return n end
  return BB.MAIN_BANK_DEFAULT
end

-- WoW-Charaktername: nur Buchstaben, 2 bis 12 Zeichen, erster gross
local function cleanCharName(s)
  s = BB.Clean(s or "")
  local out = ""
  for i = 1, string.len(s) do
    local c = string.sub(s, i, i)
    if string.find(c, "[%a\128-\255]") then out = out .. c end
  end
  if string.len(out) < 2 or string.len(out) > 24 then return nil end
  return string.upper(string.sub(out, 1, 1)) .. string.lower(string.sub(out, 2))
end
BB.CleanCharName = cleanCharName

function BB:SetMainBank(name)
  if not self:CanManageQuests() then
    self:Print("|cffff4040" .. self.T("ERR_QUEST_NOPERM") .. "|r")
    return false
  end
  local n = cleanCharName(name)
  if not n then
    self:Print("|cffff4040" .. self.T("SET_MAIN_BAD") .. "|r")
    return false
  end
  local db = BananaBankDB
  db.mainBank = n
  db.mainTs = math.max(time(), (db.mainTs or 0) + 1)
  db.mainBy = self:Me()
  self:PushMainBank()
  self:Print(string.format(self.T("SET_MAIN_OK"), n))
  if self.UI then self.UI:Refresh() end
  return true
end

function BB:PushMainBank()
  local db = BananaBankDB
  if (db.mainTs or 0) == 0 or not db.mainBank then return end
  self:SendTransfer("N", "one", table.concat({ BB.Clean(db.mainBank), db.mainTs, BB.Clean(db.mainBy or "") }, "~"))
end

function BB:MergeMainBank(payload)
  local f = BB.Split(payload or "", "~")
  local name, ts, by = cleanCharName(f[1]), tonumber(f[2]), f[3]
  if not name or not ts or not by or by == "" then return false end
  if ts > time() + 86400 or ts <= (BananaBankDB.mainTs or 0) then return false end
  -- nur von Verwaltern (Gildenmeister, Gildenbank, Offiziere) laut eigener Gildenliste
  if not self:CanManageQuests(by) then return false end
  BananaBankDB.mainBank, BananaBankDB.mainTs, BananaBankDB.mainBy = name, ts, by
  if self.UI then self.UI:Refresh() end
  return true
end
