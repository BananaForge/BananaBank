-- BananaBank Regelsatz: wer darf anfragen, und welche Qualitaet ab welchem Rang.
-- Wird nur von einem Char mit dem Rang Gildenbank gepflegt und mit der Gilde synchronisiert.
-- Ohne gespeicherten Regelsatz sind alle Anfragen gesperrt.

local BB = BananaBank
local getn = table.getn

BB.rulesModule = true
BB.RULE_KEYS = { "req", "q2", "q3", "q4" }

-- ------------------------------------------------------------
-- Raenge: Name und Position (0 = hoechster Rang)
-- ------------------------------------------------------------
function BB:RankList()
  if self.rankListCache then return self.rankListCache end
  local out, seen = {}, {}
  local n = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
  if n and n > 0 and GuildControlGetRankName then
    for i = 1, n do
      local name = GuildControlGetRankName(i)
      if name and name ~= "" then
        table.insert(out, { i = i - 1, n = name })
        seen[i - 1] = true
      end
    end
  end
  for _, e in pairs(BananaBankDB.ranks) do
    if e.r and e.i and not seen[e.i] then
      seen[e.i] = true
      table.insert(out, { i = e.i, n = e.r })
    end
  end
  table.sort(out, function(a, b) return a.i < b.i end)
  self.rankListCache = out
  return out
end

-- Rang einer Regel aufloesen: erst nach Name, sonst nach Position (Rang wurde umbenannt).
-- Gibt Position, aktuellen Namen und ob der Name noch stimmt zurueck.
function BB:RuleRank(spec)
  if not spec then return nil end
  local list = self:RankList()
  local want = string.lower(spec.n or "")
  for i = 1, getn(list) do
    if string.lower(list[i].n) == want then return list[i].i, list[i].n, true end
  end
  for i = 1, getn(list) do
    if list[i].i == spec.i then return spec.i, list[i].n, false end
  end
  return spec.i, nil, false
end

-- ------------------------------------------------------------
-- Pruefung
-- ------------------------------------------------------------
local QKEY = { [2] = "q2", [3] = "q3" }

-- Darf dieser Spieler anfragen (und dieses Qualitaetsstufe)? true | false, Grund, Rangname
-- Gruende: NORULES, UNKNOWN, RANK, QUALITY (dann Rangname und Regelschluessel)
function BB:CanRequest(name, q)
  name = name or self:Me()
  if self:MayBeBank(name) then return true end
  local rules = BananaBankDB.rules
  if not rules or not rules.req then return false, "NORULES" end
  local e = BananaBankDB.ranks[name]
  if not e then return false, "UNKNOWN" end
  local reqI, reqN = self:RuleRank(rules.req)
  if not reqI or e.i > reqI then return false, "RANK", reqN or rules.req.n end
  if q and q >= 2 then
    local key = q >= 4 and "q4" or QKEY[q]
    local qi, qn = self:RuleRank(rules[key])
    if not qi or e.i > qi then return false, "QUALITY", qn or (rules[key] and rules[key].n) or "?", key end
  end
  return true
end

-- Text fuer den Spieler, warum etwas gesperrt ist (nil = erlaubt)
function BB:BlockText(name, q)
  local ok, why, rank, key = self:CanRequest(name, q)
  if ok then return nil end
  if why == "NORULES" then return self.T("RB_NORULES") end
  if why == "UNKNOWN" then return self.T("RB_UNKNOWN") end
  if why == "RANK" then return string.format(self.T("RB_RANK"), rank or "?") end
  return string.format(self.T("RB_QUALITY"), self.T("RB_" .. string.upper(key or "q2")), rank or "?")
end

function BB:ItemBlockText(name, id)
  local _, q = self:ItemInfo(id)
  return self:BlockText(name, q)
end

-- Pruefung einer fertigen Anfrage durch die Bank. Gibt true oder false und die Liste der Verstoesse zurueck.
function BB:CheckRequestRules(r)
  local bad = {}
  local ok, why = self:CanRequest(r.p, nil)
  if not ok then
    table.insert(bad, { why = why, text = self:BlockText(r.p, nil) })
    return false, bad
  end
  for id in pairs(r.items) do
    local t = self:ItemBlockText(r.p, id)
    if t then table.insert(bad, { id = id, text = t }) end
  end
  return getn(bad) == 0, bad
end

-- ------------------------------------------------------------
-- Speichern und Synchronisieren
-- ------------------------------------------------------------
function BB:SaveRules(edit)
  local me = self:Me()
  if not self:MayBeBank(me) then
    self:Print("|cffff4040" .. self.T("RL_NOPERM") .. "|r")
    return false
  end
  for i = 1, getn(BB.RULE_KEYS) do
    local sp = edit[BB.RULE_KEYS[i]]
    if not sp or not sp.n then
      self:Print("|cffff4040" .. self.T("RL_INCOMPLETE") .. "|r")
      return false
    end
  end
  local db = BananaBankDB
  local old = db.rules and db.rules.ts or 0
  local rules = { ts = math.max(time(), old + 1), by = me }
  for i = 1, getn(BB.RULE_KEYS) do
    local sp = edit[BB.RULE_KEYS[i]]
    rules[BB.RULE_KEYS[i]] = { n = sp.n, i = sp.i }
  end
  db.rules = rules
  self:PushRules()
  self:Print(self.T("RL_SAVED_MSG"))
  if self.UI then self.UI:Refresh() end
  return true
end

local function cleanName(s)
  s = BB.Clean(s or "")
  s = string.gsub(s, ",", "")
  return s
end

function BB:SerializeRules(rules)
  local parts = { rules.ts, BB.Clean(rules.by or "") }
  for i = 1, getn(BB.RULE_KEYS) do
    local sp = rules[BB.RULE_KEYS[i]]
    table.insert(parts, cleanName(sp.n) .. "," .. (sp.i or 0))
  end
  return table.concat(parts, "~")
end

function BB:ParseRules(payload)
  local f = BB.Split(payload or "", "~")
  local ts = tonumber(f[1])
  if not ts or not f[2] or f[2] == "" then return nil end
  local rules = { ts = ts, by = f[2] }
  for i = 1, getn(BB.RULE_KEYS) do
    local sp = BB.Split(f[2 + i] or "", ",")
    if not sp[1] or sp[1] == "" or not tonumber(sp[2]) then return nil end
    rules[BB.RULE_KEYS[i]] = { n = sp[1], i = tonumber(sp[2]) }
  end
  return rules
end

function BB:PushRules()
  local rules = BananaBankDB.rules
  if not rules then return end
  self:SendTransfer("R", "one", self:SerializeRules(rules))
end

-- Nur von einem verifizierten Bank-Char (Rang laut eigener Gildenliste), neuerer Stand gewinnt
function BB:MergeRules(payload)
  local r = self:ParseRules(payload)
  if not r then return false end
  local cur = BananaBankDB.rules
  if r.ts > time() + 86400 or (cur and r.ts <= (cur.ts or 0)) then return false end
  if not self:MayBeBank(r.by) then
    self:Debug("Regeln von " .. tostring(r.by) .. " verworfen (kein Bank-Rang)")
    return false
  end
  BananaBankDB.rules = r
  if self.UI then self.UI:Refresh() end
  return true
end
