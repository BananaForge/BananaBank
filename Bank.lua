-- BananaBank Bank-Seite
-- Laeuft nur auf Chars, die per /bb setbank als Bank festgelegt sind.

local BB = BananaBank
local getn = table.getn

BB.BAG_LIST = { 0, 1, 2, 3, 4 }
BB.BANK_LIST = { -1, 5, 6, 7, 8, 9, 10 }

-- ------------------------------------------------------------
-- Scan
-- ------------------------------------------------------------
function BB:ScanContainers(bags)
  local items = {}
  for _, bag in ipairs(bags) do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local id, name, q = BB.ParseLink(link)
        local tex, count = GetContainerItemInfo(bag, slot)
        local bind = "none"
        if id then
          -- Faellt der Tooltip-Test aus, gilt das Item als ungebunden.
          -- Ein Fehler hier darf nie dazu fuehren, dass Items verschwinden.
          local ok, res = pcall(function() return self:BindOfItem(id, bag, slot) end)
          if ok and res then bind = res end
        end
        -- Seelengebundenes laesst sich nicht verschicken, also gar nicht erst anzeigen
        if id and not BB.IGNORE_IDS[id] and bind ~= "soul" then
          local e = items[id]
          if not e then
            e = { c = 0, q = q, t = BB.ShortTex(tex), n = name or ("#" .. id) }
            items[id] = e
          end
          e.c = e.c + (count or 1)
        end
      end
    end
  end
  return items
end

function BB:UpdateSnapshot(push)
  if not self:IsBank() then return end
  -- Rang verloren? Dann nicht mehr als Bank senden.
  if self:MayBeBank(self:Me()) == false then
    if not self.warnedRank then
      self.warnedRank = true
      self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_LOST"),
        BananaBankDB.bankRank) .. "|r")
    end
    return
  end
  local db = BananaBankDB
  local me = self:Me()
  -- nach dem Schliessen liefert der Client fuer Bankfaecher 0 Plaetze: dann Cache behalten
  if self.bankOpen and (GetContainerNumSlots(-1) or 0) > 0 then
    db.bankCache[me] = self:ScanContainers(BB.BANK_LIST)
  end
  -- Kein gelesener Bankinhalt? Dann wenigstens die Taschen zeigen, statt gar nichts.
  local partial = false
  if not db.bankCache[me] then
    partial = true
    if not self.warnedNoBank then
      self.warnedNoBank = true
      self:Print("|cffff8000" .. self.T("MSG_OPEN_BANK_FIRST") .. "|r")
    end
  end
  local items = {}
  local function add(src)
    for id, it in pairs(src) do
      local e = items[id]
      if not e then
        e = { c = 0, q = it.q, t = it.t, n = it.n }
        items[id] = e
      end
      e.c = e.c + it.c
    end
  end
  if db.bankCache[me] then add(db.bankCache[me]) end
  add(self:ScanContainers(BB.BAG_LIST))
  local ts = time()
  local old = db.snaps[me]
  if old and old.ts >= ts then ts = old.ts + 1 end
  db.snaps[me] = { ts = ts, gold = GetMoney(), items = items, from = me, partial = partial }
  if push then self:PushSnapshot(me) end
  if self.UI then self.UI:Refresh() end
end

function BB:ScheduleSnapshot(delay)
  if not self:IsBank() then return end
  self:After(delay or 3, function() BB:UpdateSnapshot(true) end, "snapshot")
end

-- Bestand an diesem Char (Taschen + Bank, Bank nur live wenn offen, sonst Cache)
function BB:LocalCount(id)
  local c = 0
  local bags = self:ScanContainers(BB.BAG_LIST)
  if bags[id] then c = c + bags[id].c end
  local bank
  if self.bankOpen then
    bank = self:ScanContainers(BB.BANK_LIST)
  else
    bank = BananaBankDB.bankCache[self:Me()] or {}
  end
  if bank[id] then c = c + bank[id].c end
  return c
end

-- ------------------------------------------------------------
-- Anfrage bestaetigen / ablehnen
-- ------------------------------------------------------------
function BB:Notify(r, key)
  if BananaBankDB.whisper == false then return end
  if not r or r.p == self:Me() then return end
  SendChatMessage(string.format(self.T(key), r.id), "WHISPER", nil, r.p)
end

function BB:ConfirmRequest(r)
  if not r or r.s ~= "open" then return end
  self:SetStatus(r, "confirmed")
  self:Print(string.format(self.T("MSG_CONFIRMED"), r.id, r.p))
  self:Notify(r, "WHISPER_CONFIRMED")
end

function BB:RejectRequest(r)
  if not r then return end
  local st = self:ReqState(r)
  if st ~= "open" and st ~= "confirmed" and st ~= "expired" then return end
  if self.prep and self.prep.r == r then self.prep = nil end
  if self.job and self.job.r == r then self.job = nil end
  self:SetStatus(r, "rejected")
  self:Print(string.format(self.T("MSG_REJECTED"), r.id))
  self:Notify(r, "WHISPER_REJECTED")
end

-- ------------------------------------------------------------
-- Items holen: exakte Stapel in die Taschen legen (fuer je einen Brief)
-- ------------------------------------------------------------
local function slotKey(bag, slot) return bag .. ":" .. slot end

local function findEmptyBagSlot(used)
  for _, bag in ipairs(BB.BAG_LIST) do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      if not GetContainerItemLink(bag, slot) and not used[slotKey(bag, slot)] then
        return bag, slot
      end
    end
  end
end

local function findStack(bags, id, used)
  local bestBag, bestSlot, bestCount
  for _, bag in ipairs(bags) do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      if not used[slotKey(bag, slot)] then
        local link = GetContainerItemLink(bag, slot)
        if link then
          local lid = BB.ParseLink(link)
          if lid == id then
            local _, count, locked = GetContainerItemInfo(bag, slot)
            if not locked then
              -- groessten Stapel zuerst: weniger Briefe
              if not bestCount or (count or 1) > bestCount then
                bestBag, bestSlot, bestCount = bag, slot, (count or 1)
              end
            end
          end
        end
      end
    end
  end
  return bestBag, bestSlot, bestCount
end

function BB:StartPrepare(r)
  if not r or r.s ~= "confirmed" then
    self:Print(self.T("ERR_NOT_CONFIRMED"))
    return
  end
  local need = {}
  for id, n in pairs(r.items) do
    local left = n - ((r.sent and r.sent[id]) or 0)
    if left > 0 then need[id] = left end
  end
  if BB.Count(need) == 0 then
    self:Print(self.T("MSG_NOTHING_LEFT"))
    return
  end
  self.prep = nil
  self.job = { r = r, need = need, slots = {}, missing = {} }
  self:Print(string.format(self.T("MSG_PREPARING"), r.id))
  self:PrepareStep()
end

function BB:PrepareFail(key)
  self.job = nil
  self:Print("|cffff4040" .. self.T(key) .. "|r")
  if self.UI then self.UI:Refresh() end
end

function BB:PrepareStep()
  local job = self.job
  if not job then return end
  if CursorHasItem() then ClearCursor() end

  local used = {}
  for i = 1, getn(job.slots) do
    local s = job.slots[i]
    used[slotKey(s.bag, s.slot)] = true
    local _, count, locked = GetContainerItemInfo(s.bag, s.slot)
    if locked then
      self:After(0.3, function() BB:PrepareStep() end, "prep")
      return
    end
    if s.pending then
      local lid = BB.ParseLink(GetContainerItemLink(s.bag, s.slot))
      if lid ~= s.id or count ~= s.c then
        if (s.tries or 0) < 8 then
          s.tries = (s.tries or 0) + 1
          self:After(0.4, function() BB:PrepareStep() end, "prep")
          return
        end
        return self:PrepareFail("ERR_MOVE_FAILED")
      end
      s.pending = nil
    end
  end

  local id, need
  for nid, n in pairs(job.need) do
    if n > 0 then
      id, need = nid, n
      break
    end
  end
  if not id then return self:PrepareDone() end

  -- 1. Taschen des Bank-Chars
  local bag, slot, count = findStack(BB.BAG_LIST, id, used)
  if bag then
    if count <= need then
      table.insert(job.slots, { bag = bag, slot = slot, id = id, c = count })
      job.need[id] = need - count
      self:After(0.05, function() BB:PrepareStep() end, "prep")
    else
      local eb, es = findEmptyBagSlot(used)
      if not eb then return self:PrepareFail("ERR_BAGS_FULL") end
      SplitContainerItem(bag, slot, need)
      PickupContainerItem(eb, es)
      table.insert(job.slots, { bag = eb, slot = es, id = id, c = need, pending = true })
      job.need[id] = 0
      self:After(0.5, function() BB:PrepareStep() end, "prep")
    end
    return
  end

  -- 2. Bankfaecher (nur bei geoeffneter Bank)
  if self.bankOpen then
    bag, slot, count = findStack(BB.BANK_LIST, id, used)
    if bag then
      local eb, es = findEmptyBagSlot(used)
      if not eb then return self:PrepareFail("ERR_BAGS_FULL") end
      local take = count
      if count > need then
        take = need
        SplitContainerItem(bag, slot, need)
      else
        PickupContainerItem(bag, slot)
      end
      PickupContainerItem(eb, es)
      table.insert(job.slots, { bag = eb, slot = es, id = id, c = take, pending = true })
      job.need[id] = need - take
      self:After(0.5, function() BB:PrepareStep() end, "prep")
      return
    end
  end

  -- 3. nicht (mehr) vorhanden
  job.missing[id] = need
  job.need[id] = 0
  self:After(0.05, function() BB:PrepareStep() end, "prep")
end

function BB:PrepareDone()
  local job = self.job
  self.job = nil
  if not job then return end
  if BB.Count(job.missing) > 0 then
    for id, n in pairs(job.missing) do
      self:Print(string.format(self.T("MSG_MISSING"), n, self:ColoredName(id)))
    end
    if not self.bankOpen then self:Print(self.T("MSG_OPEN_BANK_FOR_REST")) end
  end
  if getn(job.slots) == 0 then
    self:Print("|cffff4040" .. self.T("ERR_NOTHING_PREPARED") .. "|r")
    if self.UI then self.UI:Refresh() end
    return
  end
  self.prep = { r = job.r, slots = job.slots, idx = 1, missing = job.missing }
  self:Print(string.format(self.T("MSG_PREPARED"), getn(job.slots), job.r.p))
  if self.UI then self.UI:Refresh() end
end

-- ------------------------------------------------------------
-- Postversand: ein Stapel pro Brief (Vanilla erlaubt nur einen Anhang)
-- ------------------------------------------------------------
function BB:MailCod(e)
  if BananaBankDB.cod == false then return 0 end
  if not SetSendMailCOD then return 0 end
  local u = self:GetPrice(e.id)
  if not u or u <= 0 then return 0 end
  return u * e.c
end

-- Wie viele Anhaenge nimmt dieser Client? Vanilla kann einen, OctoWoW
-- und aehnliche Clients mehrere.
function BB:MailSlots()
  if self.mailSlots then return self.mailSlots end
  local n = 0
  for i = 1, 12 do
    if getglobal("SendMailItemButton" .. i) then n = i else break end
  end
  if n < 1 then n = 1 end
  self.mailSlots = n
  return n
end

local function tryClick(index)
  if not ClickSendMailItemButton then return end
  if index then
    pcall(ClickSendMailItemButton, index)
  else
    pcall(ClickSendMailItemButton)
  end
  if CursorHasItem() then
    local btn = getglobal("SendMailItemButton" .. (index or 1))
    if btn and btn.Click then pcall(function() btn:Click() end) end
  end
end

-- haengt einen Stapel an. Gibt false zurueck, wenn der Client ihn nicht nimmt;
-- das Item liegt dann wieder in seinem Fach.
function BB:AttachItem(e, index)
  if CursorHasItem() then ClearCursor() end
  PickupContainerItem(e.bag, e.slot)
  if not CursorHasItem() then return false end
  if self:MailSlots() > 1 then tryClick(index) end
  if CursorHasItem() then tryClick(nil) end
  if CursorHasItem() then
    PickupContainerItem(e.bag, e.slot)
    if CursorHasItem() then ClearCursor() end
    return false
  end
  return true
end

function BB:ClearAttachments()
  if not ClickSendMailItemButton then return end
  for i = 1, self:MailSlots() do
    tryClick(self:MailSlots() > 1 and i or nil)
    if CursorHasItem() then ClearCursor() end
  end
end

function BB:SendNextMail()
  local p = self.prep
  if not p then return end
  if not self.mailOpen then
    self:Print(self.T("ERR_NO_MAILBOX"))
    return
  end
  if p.sending then return end
  local e = p.slots[p.idx]
  if not e then return self:MailDone() end

  local lid = BB.ParseLink(GetContainerItemLink(e.bag, e.slot))
  local _, count = GetContainerItemInfo(e.bag, e.slot)
  if lid ~= e.id or count ~= e.c then
    self.prep = nil
    self:Print("|cffff4040" .. self.T("ERR_SLOT_CHANGED") .. "|r")
    if self.UI then self.UI:Refresh() end
    return
  end
  if GetMoney() < 30 then
    self:Print("|cffff4040" .. self.T("ERR_NO_POSTAGE") .. "|r")
    return
  end

  -- Schritt 1: auf den Reiter Senden wechseln. Der Client nimmt einen Anhang
  -- erst an, wenn dieser Reiter offen ist, und braucht dafuer einen Moment.
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, 2) end
  p.sending = true
  self:After(0.3, function() BB:SendMailStep2() end, "mailstep")
end

function BB:SendMailStep2()
  local p = self.prep
  if not p or not p.sending then return end
  local e = p.slots[p.idx]
  if not e then
    p.sending = false
    return self:MailDone()
  end

  -- so viele Stapel wie der Client erlaubt in einen Brief
  local slots = self:MailSlots()
  local batch = {}
  local last = p.idx + slots - 1
  if last > table.getn(p.slots) then last = table.getn(p.slots) end
  for k = p.idx, last do
    if self:AttachItem(p.slots[k], table.getn(batch) + 1) then
      table.insert(batch, k)
    else
      break
    end
  end

  if table.getn(batch) == 0 then
    p.sending = false
    self:Cancel("automail")
    self:Print("|cffff4040" .. self.T("ERR_ATTACH_FAILED") .. "|r")
    if self.UI then self.UI:Refresh() end
    return
  end

  p.batch = batch
  local cod = 0
  for i = 1, table.getn(batch) do cod = cod + self:MailCod(p.slots[batch[i]]) end
  p.cod = cod
  p.subject = "BananaBank " .. p.r.id .. " (" .. p.idx .. "/" .. table.getn(p.slots) .. ")"
  if SendMailNameEditBox then SendMailNameEditBox:SetText(p.r.p) end
  if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(p.subject) end
  if SetSendMailCOD then pcall(SetSendMailCOD, cod) end
  SendMail(p.r.p, p.subject, string.format(self.T("MAIL_BODY"), p.r.id))
end

function BB:OnMailSent()
  local p = self.prep
  if not p or not p.sending then return end
  p.sending = false
  local r = p.r
  r.sent = r.sent or {}
  local batch = p.batch or { p.idx }
  for i = 1, table.getn(batch) do
    local e = p.slots[batch[i]]
    if e then
      r.sent[e.id] = (r.sent[e.id] or 0) + e.c
      local name, q = self:ItemInfo(e.id)
      self:AddLedger({ k = "out", p = r.p, i = e.id, n = name, c = e.c, q = q,
        m = self:MailCod(e), code = r.id })
    end
  end
  r.u = time()
  p.idx = batch[table.getn(batch)] + 1
  p.batch = nil
  if SetSendMailCOD then pcall(SetSendMailCOD, 0) end
  if p.idx > table.getn(p.slots) then
    self:MailDone()
  elseif BananaBankDB.auto then
    self:After(1.5, function() BB:SendNextMail() end, "automail")
  end
  if self.UI then self.UI:Refresh() end
end

function BB:OnMailFailed()
  local p = self.prep
  if not p or not p.sending then return end
  p.sending = false
  self:Cancel("automail")
  -- haengen die Items noch im Postfenster, zurueck in die Taschen
  local batch = p.batch or { p.idx }
  for i = 1, table.getn(batch) do
    local e = p.slots[batch[i]]
    if e then
      tryClick(self:MailSlots() > 1 and i or nil)
      if CursorHasItem() then
        PickupContainerItem(e.bag, e.slot)
        if CursorHasItem() then ClearCursor() end
      end
    end
  end
  p.batch = nil
  if SetSendMailCOD then pcall(SetSendMailCOD, 0) end
  self:Print("|cffff4040" .. self.T("ERR_MAIL_FAILED") .. "|r")
  if self.UI then self.UI:Refresh() end
end

function BB:MailDone()
  local p = self.prep
  self.prep = nil
  if not p then return end
  local r = p.r
  if self:RequestComplete(r) then
    self:SetStatus(r, "sent")
    self:Print(string.format(self.T("MSG_REQUEST_DONE"), r.id, r.p))
    self:Notify(r, "WHISPER_SENT")
  else
    self:PushRequests({ r })
    self:Print(string.format(self.T("MSG_REQUEST_PARTIAL"), r.id))
  end
  self:ScheduleSnapshot(2)
  if self.UI then self.UI:Refresh() end
end

-- ------------------------------------------------------------
-- Spenden per Post erfassen (Hook auf TakeInboxItem / TakeInboxMoney)
-- ------------------------------------------------------------
BB.SYSTEM_SENDERS = {
  ["Auction House"] = true, ["Auktionshaus"] = true,
  ["The Postmaster"] = true, ["Der Postmeister"] = true, ["Postmaster"] = true,
}

function BB:HasFreeBagSlot()
  return findEmptyBagSlot({}) ~= nil
end

function BB:IdByName(name)
  local stock = self.stockCache or self:GetStock()
  for id, e in pairs(stock) do
    if e.n == name then return id end
  end
  return 0
end

local lastTake = { key = "", t = 0 }

function BB:OnTakeInbox(i, isItem)
  if not self:IsBank() then return end
  local _, _, sender, subject, money, cod, daysLeft, hasItem, _, wasReturned = GetInboxHeaderInfo(i)
  if not sender or (cod and cod > 0) then return end
  if BananaBankDB.banks[sender] or BB.SYSTEM_SENDERS[sender] then return end

  local key = sender .. "|" .. tostring(subject) .. "|" .. tostring(daysLeft) .. "|" .. tostring(isItem)
  if key == lastTake.key and GetTime() - lastTake.t < 2 then return end
  lastTake.key, lastTake.t = key, GetTime()

  if isItem then
    if not hasItem then return end
    local name, _, count, q = GetInboxItem(i)
    if not name or not self:HasFreeBagSlot() then return end
    local kind = "in"
    if wasReturned then kind = "back" end
    self:AddLedger({ k = kind, p = sender, n = name, c = count or 1, q = q or 1, i = self:IdByName(name) })
    self:ScheduleSnapshot(4)
  else
    if not money or money <= 0 then return end
    -- Gold aus einer Nachnahme ist ein Verkaufserloes, keine Spende
    local kind = "gold"
    if subject and string.find(subject, "BananaBank", 1, true) then kind = "cod" end
    self:AddLedger({ k = kind, p = sender, m = money })
    self:ScheduleSnapshot(4)
  end
  if self.UI then self.UI:Refresh() end
end

function BB:HookMail()
  if self.mailHooked then return end
  self.mailHooked = true
  local origItem = TakeInboxItem
  TakeInboxItem = function(i)
    BB:OnTakeInbox(i, true)
    return origItem(i)
  end
  local origMoney = TakeInboxMoney
  TakeInboxMoney = function(i)
    BB:OnTakeInbox(i, false)
    return origMoney(i)
  end
end

-- ------------------------------------------------------------
-- Handel erfassen
-- ------------------------------------------------------------
function BB:TradeShow()
  if not self:IsBank() then
    self.trade = nil
    return
  end
  self.trade = { p = UnitName("NPC") or "?", tin = {}, tout = {}, min = 0, mout = 0 }
end

function BB:TradeCapture()
  local tr = self.trade
  if not tr then return end
  tr.tin, tr.tout = {}, {}
  for i = 1, 6 do
    local name, _, num, q = GetTradeTargetItemInfo(i)
    if name then table.insert(tr.tin, { n = name, c = num or 1, q = q or 1 }) end
    local pname, _, pnum, pq = GetTradePlayerItemInfo(i)
    if pname then table.insert(tr.tout, { n = pname, c = pnum or 1, q = pq or 1 }) end
  end
  tr.min = GetTargetTradeMoney() or 0
  tr.mout = GetPlayerTradeMoney() or 0
end

function BB:TradeCommit()
  local tr = self.trade
  self.trade = nil
  if not tr then return end
  for i = 1, getn(tr.tin) do
    local it = tr.tin[i]
    self:AddLedger({ k = "in", p = tr.p, n = it.n, c = it.c, q = it.q, i = self:IdByName(it.n) })
  end
  for i = 1, getn(tr.tout) do
    local it = tr.tout[i]
    self:AddLedger({ k = "out", p = tr.p, n = it.n, c = it.c, q = it.q, i = self:IdByName(it.n), code = "TRADE" })
  end
  if tr.min > 0 then self:AddLedger({ k = "gold", p = tr.p, m = tr.min }) end
  if tr.mout > 0 then self:AddLedger({ k = "gout", p = tr.p, m = tr.mout }) end
  self:ScheduleSnapshot(3)
  if self.UI then self.UI:Refresh() end
end

function BB:TradeClosed()
  local tok = self.trade
  self:After(3, function()
    if BB.trade == tok then BB.trade = nil end
  end, "tradeclear")
end
