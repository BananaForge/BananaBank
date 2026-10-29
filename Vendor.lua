-- BananaBank: Haendlerwerte, Trash und Klassenbeschraenkungen
--
-- * Haendlerwert je Stueck kommt aus VendorData.lua (Daten aus ShaguTweaks, MIT-Lizenz).
-- * Preis fuer alles ausser BOE, Rezepten und Taschen: Haendlerwert + 25 % (siehe Prices.lua, GetPrice).
-- * Trash: graue Items (Qualitaet "Schlecht") und Items, deren Haendlerwert unter der Grenze liegt
--   (Standard 2 Silber, einstellbar).
-- * Klassenbeschraenkung ("Classes: Druid") wird beim Bank-Scan aus dem Tooltip gelesen und mit dem Item
--   synchronisiert; angefragt werden darf nur mit passender Klasse.

local BB = BananaBank
local getn = table.getn

BB.vendorModule = true
BB.TRASH_DEFAULT = 200         -- 2 Silber
BB.VENDOR_MARKUP = 1.25

-- ------------------------------------------------------------
-- Haendlerwert
-- ------------------------------------------------------------
function BB:VendorValue(id)
  local d = BB.VendorDB
  local v = d and d[id]
  if v and v > 0 then return v end
  return nil
end

-- Haendlerwert + 25 %, auf ganze Kupfer gerundet
function BB:VendorPrice(id)
  local v = self:VendorValue(id)
  if not v then return nil end
  return math.floor(v * BB.VENDOR_MARKUP + 0.5)
end

-- ------------------------------------------------------------
-- Trash
-- ------------------------------------------------------------
function BB:TrashMax()
  local m = BananaBankDB and BananaBankDB.trashMax
  if not m or m < 1 then m = BB.TRASH_DEFAULT end
  return m
end

local PROTECTED_TYPES = {
  ["recipe"] = true, ["rezept"] = true, ["quest"] = true, ["key"] = true, ["schlüssel"] = true, ["schluessel"] = true,
  ["container"] = true, ["behälter"] = true, ["behaelter"] = true, ["quiver"] = true, ["köcher"] = true, ["koecher"] = true,
  ["projectile"] = true, ["geschoss"] = true,
}

-- Qualitaet eines Items: erst der Client, sonst die Bestaende der Banken
local function qualityOf(id)
  local _, _, q = GetItemInfo(id)
  if q then return q end
  local e = BB.stockCache and BB.stockCache[id]
  return e and e.q or nil
end

-- Automatik: graue Items und Items unter der Wertgrenze.
-- Quest-Items und Schluessel sind nie Trash; unter der Wertgrenze auch keine BOE, Rezepte und Taschen.
function BB:TrashAuto(id)
  if not id then return false end
  local db = BananaBankDB
  if BB.IGNORE_IDS and BB.IGNORE_IDS[id] then return false end
  local _, _, _, _, itype = GetItemInfo(id)
  local ltype = itype and string.lower(itype)
  if ltype and (ltype == "quest" or ltype == "key" or ltype == "schlüssel" or ltype == "schluessel") then return false end
  -- grau = Trash, egal was der Haendler zahlt
  if qualityOf(id) == 0 then return true end
  local v = self:VendorValue(id)
  if not v or v >= self:TrashMax() then return false end
  if db.bind and db.bind[id] == "boe" then return false end
  if self:NeedsPrice(id) or (self.ItemIsBag and self:ItemIsBag(id)) then return false end
  if ltype and PROTECTED_TYPES[ltype] then return false end
  return true
end

-- Trash? Nur auf Bank-Chars. Eine manuelle Entscheidung (Mittelklick) geht der Automatik vor.
function BB:IsTrash(id)
  if not id or not self:IsBank() then return false end
  local o = BananaBankDB.trashOv and BananaBankDB.trashOv[id]
  if o then
    if o.s == "t" then return true end
    if o.s == "n" then return false end
  end
  return self:TrashAuto(id)
end

-- ------------------------------------------------------------
-- Manuelle Trash-Entscheidungen, unter den Bank-Chars geteilt
-- trashOv[id] = { s = "t" (Trash) | "n" (kein Trash) | "a" (zurueck zur Automatik), ts =, by = }
-- ------------------------------------------------------------
function BB:TrashOverride(id)
  local o = BananaBankDB.trashOv and BananaBankDB.trashOv[id]
  if o and o.s ~= "a" then return o.s, o end
  return nil
end

function BB:TrashOverrideCount()
  local n = 0
  for _, o in pairs(BananaBankDB.trashOv or {}) do
    if o.s ~= "a" then n = n + 1 end
  end
  return n
end

function BB:SetTrashOverride(id, state)
  if not id then return end
  local db = BananaBankDB
  db.trashOv = db.trashOv or {}
  local ts = time()
  local cur = db.trashOv[id]
  if cur and cur.ts >= ts then ts = cur.ts + 1 end
  db.trashOv[id] = { s = state, ts = ts, by = self:Me() }
  self:ScheduleTrashPush()
end

-- Mittelklick: den angezeigten Zustand umkehren; entspricht das Ergebnis der Automatik, faellt die Entscheidung weg
function BB:TrashToggle(id)
  if not id or not self:IsBank() or not self:MayBeBank(self:Me()) then return nil end
  local want = not self:IsTrash(id)
  local state
  if want == self:TrashAuto(id) then state = "a" else state = want and "t" or "n" end
  self:SetTrashOverride(id, state)
  return want, state
end

function BB:TrashResetAll()
  for id, o in pairs(BananaBankDB.trashOv or {}) do
    if o.s ~= "a" then self:SetTrashOverride(id, "a") end
  end
end

-- Alte Ausnahmeliste (Strg-Klick, 3.3.0) in die neue Form uebernehmen
function BB:TrashMigrate()
  local db = BananaBankDB
  if not db or not db.trashKeep then return end
  for id in pairs(db.trashKeep) do
    if not (db.trashOv and db.trashOv[id]) then self:SetTrashOverride(id, "n") end
  end
  db.trashKeep = nil
end

-- Sync: "id:s:ts:von" mit ";" getrennt
function BB:SerializeTrash()
  local recs = {}
  for id, o in pairs(BananaBankDB.trashOv or {}) do
    table.insert(recs, id .. ":" .. o.s .. ":" .. o.ts .. ":" .. BB.Clean(o.by or ""))
  end
  return table.concat(recs, ";")
end

function BB:ParseTrash(payload)
  local out = {}
  for _, rec in ipairs(BB.Split(payload or "", ";")) do
    local f = BB.Split(rec, ":")
    local id, ts = tonumber(f[1]), tonumber(f[3])
    if id and ts and (f[2] == "t" or f[2] == "n" or f[2] == "a") and f[4] and f[4] ~= "" then
      table.insert(out, { id = id, s = f[2], ts = ts, by = f[4] })
    end
  end
  return out
end

-- nur von verifizierten Bank-Chars (Rang laut eigener Gildenliste), je Item gewinnt der neuere Eintrag
function BB:MergeTrash(payload)
  local db = BananaBankDB
  db.trashOv = db.trashOv or {}
  local changed = false
  for _, r in ipairs(self:ParseTrash(payload)) do
    local cur = db.trashOv[r.id]
    if r.ts <= time() + 86400 and (not cur or r.ts > cur.ts) and self:MayBeBank(r.by) then
      db.trashOv[r.id] = { s = r.s, ts = r.ts, by = r.by }
      changed = true
    end
  end
  if changed and self.UI then self.UI:Refresh() end
  return changed
end

function BB:TrashDigest()
  local n, sum = 0, 0
  for id, o in pairs(BananaBankDB.trashOv or {}) do
    n = n + 1
    sum = mod(sum + BB.Hash(id .. o.s .. o.ts), 16777213)
  end
  return n, sum
end

function BB:PushTrash()
  if BB.Count(BananaBankDB.trashOv or {}) == 0 then return end
  self:SendTransfer("T", "one", self:SerializeTrash())
end

function BB:ScheduleTrashPush()
  self:After(3, function() BB:PushTrash() end, "trashpush")
end

-- Menge je Item, die nicht verkauft werden darf: reservierte Anfragen und offene Quest-Mengen
function BB:TrashKeep()
  local keep = self:GetReserved()
  if self.QuestStats then
    local stats = self:QuestStats()
    for qid, q in pairs(BananaBankDB.quests) do
      if self:QuestIsActive(q) then
        local s = stats[qid]
        for iid, need in pairs(q.items) do
          local left = need - ((s and s.got[iid]) or 0)
          if left > 0 then keep[iid] = (keep[iid] or 0) + left end
        end
      end
    end
  end
  return keep
end

-- Taschen des Chars: was wuerde verkauft? { {bag, slot, id, c, v}, ... }, Summe in Kupfer
function BB:TrashPlan()
  local plan, total = {}, 0
  local keep = self:TrashKeep()
  -- Gesamtbestand dieses Chars je Item (Taschen + Bank), damit Reserviertes drin bleibt
  local have = {}
  local bags = self:ScanContainers(BB.BAG_LIST)
  for id, e in pairs(bags) do have[id] = (have[id] or 0) + e.c end
  local bank = BananaBankDB.bankCache and BananaBankDB.bankCache[self:Me()]
  if self.bankOpen then bank = self:ScanContainers(BB.BANK_LIST) end
  for id, e in pairs(bank or {}) do have[id] = (have[id] or 0) + e.c end
  for _, bag in ipairs(BB.BAG_LIST) do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local id = BB.ParseLink(link)
        if id and self:IsTrash(id) then
          local _, c = GetContainerItemInfo(bag, slot)
          c = c or 1
          if (have[id] or 0) - c >= (keep[id] or 0) then
            have[id] = have[id] - c
            local v = self:VendorValue(id) or 0
            table.insert(plan, { bag = bag, slot = slot, id = id, c = c, v = v })
            total = total + v * c
          end
        end
      end
    end
  end
  return plan, total
end

-- Trash in der Bank (Anzahl Stapel, Items), nur nach dem letzten Scan
function BB:TrashInBank()
  local stacks, items = 0, 0
  local bank = BananaBankDB.bankCache and BananaBankDB.bankCache[self:Me()]
  if self.bankOpen then bank = self:ScanContainers(BB.BANK_LIST) end
  for id, e in pairs(bank or {}) do
    if self:IsTrash(id) then
      stacks = stacks + 1
      items = items + e.c
    end
  end
  return stacks, items
end

-- ------------------------------------------------------------
-- Klassen
-- ------------------------------------------------------------
local lookup
local function classLookup()
  if lookup then return lookup end
  lookup = {}
  local en = { DRUID = "Druid", HUNTER = "Hunter", MAGE = "Mage", PALADIN = "Paladin", PRIEST = "Priest",
    ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior" }
  local de = { DRUID = "Druide", HUNTER = "Jäger", MAGE = "Magier", PALADIN = "Paladin", PRIEST = "Priester",
    ROGUE = "Schurke", SHAMAN = "Schamane", WARLOCK = "Hexenmeister", WARRIOR = "Krieger" }
  local deF = { DRUID = "Druidin", HUNTER = "Jägerin", MAGE = "Magierin", PRIEST = "Priesterin",
    ROGUE = "Schurkin", SHAMAN = "Schamanin", WARLOCK = "Hexenmeisterin", WARRIOR = "Kriegerin" }
  for tok, n in pairs(en) do lookup[string.lower(n)] = tok end
  for tok, n in pairs(de) do lookup[string.lower(n)] = tok end
  for tok, n in pairs(deF) do lookup[string.lower(n)] = tok end
  for _, tbl in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
    for tok, n in pairs(tbl) do lookup[string.lower(n)] = tok end
  end
  return lookup
end

-- "Druide" -> "DRUID"
function BB.ClassToken(name)
  if not name or name == "" then return nil end
  local s = string.gsub(name, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return classLookup()[string.lower(s)]
end

-- "MAGE,PRIEST" -> "Magier, Priester" (Sprache des Clients)
function BB:ClassLabels(list)
  local out = {}
  for _, tok in ipairs(BB.Split(list or "", ",")) do
    local n = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[tok]
    table.insert(out, n or (string.upper(string.sub(tok, 1, 1)) .. string.lower(string.sub(tok, 2))))
  end
  return table.concat(out, ", ")
end

local tip
local function classTip()
  if not tip then
    tip = CreateFrame("GameTooltip", "BananaBankClassTip", UIParent, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  return tip
end

local function classPrefixes()
  local out = { "Classes: ", "Klassen: ", "Classes:", "Klassen:" }
  if ITEM_CLASSES_ALLOWED then
    local p = string.find(ITEM_CLASSES_ALLOWED, "%s", 1, true)
    if p and p > 1 then table.insert(out, 1, string.sub(ITEM_CLASSES_ALLOWED, 1, p - 1)) end
  end
  return out
end

-- Klassenbeschraenkung eines Slots: "MAGE,PRIEST" oder "" (keine); nil, wenn der Tooltip nicht lesbar war
function BB:ClassOfSlot(bag, slot)
  local t = classTip()
  t:ClearLines()
  if bag == -1 then
    if not BankButtonIDToInvSlotID then return nil end
    t:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))
  else
    t:SetBagItem(bag, slot)
  end
  local n = t:NumLines() or 0
  if n < 1 then return nil end
  local prefixes = classPrefixes()
  for i = 2, n do
    local fs = getglobal("BananaBankClassTipTextLeft" .. i)
    local line = fs and fs:GetText()
    if line then
      for j = 1, getn(prefixes) do
        local pre = prefixes[j]
        if string.sub(line, 1, string.len(pre)) == pre then
          local list = {}
          for _, part in ipairs(BB.Split(string.sub(line, string.len(pre) + 1), ",")) do
            local tok = BB.ClassToken(part)
            if tok then table.insert(list, tok) end
          end
          if getn(list) > 0 then return table.concat(list, ",") end
        end
      end
    end
  end
  return ""
end

-- Cache je Item-ID
function BB:ClassOfItem(id, bag, slot)
  local db = BananaBankDB
  db.classr = db.classr or {}
  local known = db.classr[id]
  if known ~= nil then return known end
  local res = self:ClassOfSlot(bag, slot)
  if res ~= nil then db.classr[id] = res end
  return res or ""
end

-- Darf dieser Spieler dieses Item laut Klasse anfragen? nil = ja, sonst der Hinweistext
function BB:ClassBlockText(name, id)
  local e = self.stockCache and self.stockCache[id]
  local cr = e and e.cr
  if not cr or cr == "" then return nil end
  local tok
  if name == self:Me() then
    local _, c = UnitClass("player")
    tok = c
  else
    local r = BananaBankDB.ranks[name]
    tok = r and r.cls
  end
  if not tok then return nil end
  if string.find("," .. cr .. ",", "," .. tok .. ",", 1, true) then return nil end
  return string.format(self.T("RB_CLASS"), self:ClassLabels(cr))
end
