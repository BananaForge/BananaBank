-- BananaBank AH-Verkauf: nicht stapelbare Items (Rezepte, Ruestung ...) belegen je ein Fach.
-- Von jedem bleibt hoechstens eines in der Gildenbank, der Rest wird zum vollen AH-Preis (Gildenpreis mal 2)
-- im Auktionshaus eingestellt, 24 Stunden. Ausnahme: Items mit einem AH-Preis ab 100 Gold bleiben komplett.
-- Die Einnahmen (Post vom Auktionshaus) werden als "AH-Verkauf" ins Buch gebucht (siehe Bank.lua, OnTakeInbox).

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.ahModule = true
UI.AH = { run = nil }

local DURATION = 1440      -- 24 Stunden (der Client rechnet die Laufzeit in Minuten)
local BID_SHARE = 0.9      -- Startgebot: 90 % vom Sofortkaufpreis
local KEEP_DEFAULT, KEEP_GOLD_DEFAULT = 1, 100

function BB:AHKeep() return BananaBankDB.ahKeep or KEEP_DEFAULT end
function BB:AHKeepGold() return BananaBankDB.ahKeepGold or KEEP_GOLD_DEFAULT end

-- Groesster Stapel eines Items: der Client kennt ihn, sonst gelten Rezepte als nicht stapelbar
function BB:MaxStack(id)
  local _, _, _, _, _, _, st = GetItemInfo(id)
  if st and st > 0 then return st end
  local e = self.stockCache and self.stockCache[id]
  if e and (self:ResolveCategory(id, e)) == "recipe" then return 1 end
  return nil
end

-- AH-Preis zum Einstellen: der Gildenpreis ist der halbe AH-Preis
function BB:AHPrice(id)
  local u = self:GetPrice(id)
  if not u or u <= 0 then return nil end
  return u * 2
end

-- Fuer wie viele Fach-Belegungen sorgen nicht stapelbare Items auf diesem Char (laut letztem Scan)?
function BB:SlotHogs()
  local snap = BananaBankDB.snaps[self:Me()]
  local n, kinds = 0, 0
  if not snap then return 0, 0 end
  for id, it in pairs(snap.items) do
    if self:MaxStack(id) == 1 then
      n = n + (it.c or 0)
      kinds = kinds + 1
    end
  end
  return n, kinds
end

-- Kandidaten fuers Auktionshaus: nicht stapelbar, Preis bekannt, mehr da als bleiben soll.
-- { { id =, n =, q =, t =, price =, sell =, bags =, bank = } ... } und der geschaetzte Erloes
function BB:AHCandidates()
  local list, total = {}, 0
  local stock = self:GetStock()
  local bags = self:ScanContainers(BB.BAG_LIST)
  local bank
  if self.bankOpen then bank = self:ScanContainers(BB.BANK_LIST) else bank = BananaBankDB.bankCache[self:Me()] or {} end
  local res = self:GetReserved()
  local keepAll = self:AHKeepGold() * BB.GOLD
  for id, e in pairs(stock) do
    local here = ((bags[id] and bags[id].c) or 0) + ((bank[id] and bank[id].c) or 0)
    if here > 0 and self:MaxStack(id) == 1 then
      local price = self:AHPrice(id)
      if price then
        -- teure Items bleiben komplett, sonst bleibt "keep" Stueck in der Gilde (reserviertes zaehlt nicht mit)
        local keep = (price >= keepAll) and e.c or self:AHKeep()
        local avail = e.c - (res[id] or 0)
        local surplus = avail - keep
        local sell = math.min(here, surplus)
        if sell > 0 then
          table.insert(list, { id = id, n = e.n, q = e.q or 1, t = e.t, price = price, sell = sell,
            bags = math.min(sell, (bags[id] and bags[id].c) or 0) })
          total = total + price * sell
        end
      end
    end
  end
  table.sort(list, function(a, b)
    if a.price ~= b.price then return a.price > b.price end
    return (a.n or "") < (b.n or "")
  end)
  return list, total
end

-- Stuecke, die noch in der Bank liegen und zum Verkauf geholt werden sollen
function BB:AHFetchSlots()
  local out = {}
  if not self.bankOpen then return out end
  local want = {}
  local list = self:AHCandidates()
  for i = 1, getn(list) do want[list[i].id] = list[i].sell - list[i].bags end
  for _, bag in ipairs(BB.BANK_LIST) do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local id = BB.ParseLink(link)
        if id and (want[id] or 0) > 0 then
          want[id] = want[id] - 1
          table.insert(out, { bag = bag, slot = slot, id = id })
        end
      end
    end
  end
  return out
end

-- ------------------------------------------------------------
-- Einstellen
-- ------------------------------------------------------------
-- Ein Stueck aus den Taschen finden
local function findInBags(id)
  for _, bag in ipairs(BB.BAG_LIST) do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link and BB.ParseLink(link) == id then
        local _, _, locked = GetContainerItemInfo(bag, slot)
        if not locked then return bag, slot end
      end
    end
  end
  return nil
end

function UI:AHStart()
  if self.AH.run then return end
  if not BB:IsBank() or not BB:AHOpen() then return end
  local list = BB:AHCandidates()
  local queue = {}
  for i = 1, getn(list) do
    for k = 1, list[i].bags do table.insert(queue, { id = list[i].id, price = list[i].price, n = list[i].n }) end
  end
  if getn(queue) == 0 then return end
  self.AH.run = { queue = queue, idx = 1, tick = 0, posted = 0, failed = 0, value = 0 }
  self:RefreshAHSell()
end

function UI:AHStop(silent)
  local run = self.AH.run
  self.AH.run = nil
  if CursorHasItem() then ClearCursor() end
  if run and not silent then
    BB:Print(string.format(T("AHS_DONE"), run.posted, BB.Money(run.value), run.failed))
  end
  self:RefreshAHSell()
end

-- Ein Stueck einstellen; true = eingestellt, false = nicht moeglich
local function postOne(entry)
  local bag, slot = findInBags(entry.id)
  if not bag then return false end
  if CursorHasItem() then ClearCursor() end
  PickupContainerItem(bag, slot)
  ClickAuctionSellItemButton()
  local name = GetAuctionSellItemInfo and GetAuctionSellItemInfo()
  if not name then
    if CursorHasItem() then ClearCursor() end
    return false
  end
  local buyout = entry.price
  local bid = math.max(1, math.floor(buyout * BID_SHARE))
  local deposit = 0
  if CalculateAuctionDeposit then
    local ok, dep = pcall(CalculateAuctionDeposit, DURATION)
    if ok and dep then deposit = dep end
    if deposit > GetMoney() then
      ClickAuctionSellItemButton()
      if CursorHasItem() then PickupContainerItem(bag, slot) end
      BB:Print("|cffff4040" .. T("AHS_NO_MONEY") .. "|r")
      return nil
    end
  end
  -- wie viele Exemplare waren vorher in der Gilde (fuer die Kontrolle "es bleibt eines")
  local before
  local e = BB.stockCache and BB.stockCache[entry.id]
  if e then before = e.c end
  StartAuction(bid, buyout, DURATION)
  BB:AHLogPost(entry, deposit, before)
  return true
end

-- Gebuehr (Pfand) ins Buch und Eintrag ins Kontrollprotokoll
function BB:AHLogPost(entry, deposit, before)
  local db = BananaBankDB
  db.ahLog = db.ahLog or {}
  table.insert(db.ahLog, { t = time(), id = entry.id, n = entry.n, price = entry.price, dep = deposit, had = before })
  while getn(db.ahLog) > 300 do table.remove(db.ahLog, 1) end
  if deposit > 0 then
    self:AddLedger({ k = "ahfee", p = self:Me(), n = entry.n or "", c = 1, q = 1, m = deposit, code = "" })
  end
end

-- Statistik aus dem Buch (gilt fuer alle Banken): eingestellt, Gebuehren, verkauft, Erloes, Netto
function BB:AHStats()
  local s = { posted = 0, fees = 0, sold = 0, proceeds = 0 }
  for _, e in pairs(BananaBankDB.ledger) do
    if e.k == "ahfee" then
      s.posted = s.posted + (e.c or 1)
      s.fees = s.fees + (e.m or 0)
    elseif e.k == "ah" then
      s.sold = s.sold + 1
      s.proceeds = s.proceeds + (e.m or 0)
    end
  end
  s.net = s.proceeds - s.fees
  return s
end

function BB:PrintAHStats()
  local s = self:AHStats()
  self:Print(string.format(T("AHS_STATS"), s.posted, BB.Money(s.fees), s.sold, BB.Money(s.proceeds)))
  local sign = s.net < 0 and "-" or "+"
  self:Print(string.format(T("AHS_NET"), sign .. BB.Money(math.abs(s.net))))
end

-- Kontrolle am Auktionshaus: eigene Auktionen gegen den Bestand der Gilde. Meldet Items, von denen nichts
-- mehr in der Gilde liegt (alle Exemplare im AH) und zeigt die Laufzeit-Stufe.
function BB:AHCheck()
  if not (BB:IsBank() and BB:AHOpen()) then
    self:Print(T("AHS_CHECK_OPEN"))
    return
  end
  local n = GetNumAuctionItems and GetNumAuctionItems("owner") or 0
  local mine = {}
  local tiers = {}
  for i = 1, n do
    local name, _, count = GetAuctionItemInfo("owner", i)
    if name then
      mine[name] = (mine[name] or 0) + (count or 1)
      if GetAuctionItemTimeLeft then
        local tl = GetAuctionItemTimeLeft("owner", i)
        tiers[tl or 0] = (tiers[tl or 0] or 0) + 1
      end
    end
  end
  local stock = self:GetStock()
  local byName = {}
  for id, e in pairs(stock) do byName[e.n or ""] = (byName[e.n or ""] or 0) + e.c end
  local bad = 0
  self:Print(string.format(T("AHS_CHECK_HEAD"), n))
  for name, c in pairs(mine) do
    local left = byName[name] or 0
    if left == 0 then
      bad = bad + 1
      DEFAULT_CHAT_FRAME:AddMessage("|cffff4040" .. string.format(T("AHS_CHECK_ALL"), name, c) .. "|r")
    end
  end
  if bad == 0 then self:Print(T("AHS_CHECK_OK")) end
  local tl = {}
  for k, v in pairs(tiers) do table.insert(tl, v .. "x " .. k) end
  table.sort(tl)
  if getn(tl) > 0 then self:Print(string.format(T("AHS_CHECK_TIME"), table.concat(tl, ", "))) end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function()
  local run = UI.AH.run
  if not run then return end
  run.tick = run.tick + (arg1 or 0)
  if run.tick < 0.8 then return end
  run.tick = 0
  if not (BB:IsBank() and BB:AHOpen()) then UI:AHStop() return end
  local entry = run.queue[run.idx]
  if not entry then UI:AHStop() return end
  run.idx = run.idx + 1
  local ok = postOne(entry)
  if ok == nil then UI:AHStop() return end
  if ok then
    run.posted = run.posted + 1
    run.value = run.value + entry.price
  else
    run.failed = run.failed + 1
  end
  UI:RefreshAHSell()
end)

-- ------------------------------------------------------------
-- Fenster neben dem Auktionshaus
-- ------------------------------------------------------------
local ROWS = 8

function UI:BuildAHSell()
  if self.ahWin then return end
  local f = CreateFrame("Frame", "BananaBankAHSell", UIParent)
  self.ahWin = f
  f:SetWidth(280)
  f:SetHeight(112 + ROWS * 18 + 44)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() this.moved = true end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.03, 0.045, 0.11, 0.98)
  f:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 1)
  f:Hide()
  local logo = f:CreateTexture(nil, "OVERLAY")
  logo:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  logo:SetWidth(26)
  logo:SetHeight(26)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  local title = self:Font(f, 14, C.gold, UI.FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -14)
  self:Loc(title, "AHS_TITLE")
  f.l1 = self:Font(f, 11, C.text)
  f.l1:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -44)
  f.l1:SetWidth(252)
  f.l1:SetHeight(14)
  f.l2 = self:Font(f, 10, C.muted)
  f.l2:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -60)
  f.l2:SetWidth(252)
  f.l2:SetHeight(26)
  f.l2:SetJustifyV("TOP")
  f.rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetHeight(16)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -90 - (i - 1) * 18)
    r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -90 - (i - 1) * 18)
    r.name = self:Font(r, 10, C.text)
    r.name:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.name:SetWidth(158)
    r.name:SetHeight(12)
    r.val = self:Font(r, 10, C.gold)
    r.val:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.val:SetWidth(88)
    r.val:SetJustifyH("RIGHT")
    f.rows[i] = r
  end
  f.more = self:Font(f, 10, C.muted)
  f.more:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -92 - ROWS * 18)
  f.more:SetWidth(252)
  f.more:SetHeight(12)
  f.go = self:Button(f, 252, 24, "", function()
    if UI.AH.run then UI:AHStop() else UI:AHStart() end
  end, "primary")
  f.go:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
end

function UI:RefreshAHSell()
  if not self.ahWin then return end
  local f = self.ahWin
  if not (BB:IsBank() and BB:AHOpen()) then
    f:Hide()
    return
  end
  local list, total = BB:AHCandidates()
  if getn(list) == 0 and not self.AH.run then
    f:Hide()
    return
  end
  if not f.moved then
    f:ClearAllPoints()
    if AuctionFrame and AuctionFrame.IsVisible and AuctionFrame:IsVisible() then
      f:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", -30, -14)
    else
      f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -260)
    end
  end
  local pieces, inBags = 0, 0
  for i = 1, getn(list) do
    pieces = pieces + list[i].sell
    inBags = inBags + list[i].bags
  end
  f.l1:SetText(string.format(T("AHS_COUNT"), getn(list), pieces, BB.Money(total)))
  local bankLeft = pieces - inBags
  local hint = string.format(T("AHS_RULE"), BB:AHKeep(), BB:AHKeepGold())
  local st = BB:AHStats()
  if st.posted > 0 or st.sold > 0 then
    local sign = st.net < 0 and "-" or "+"
    hint = hint .. " " .. string.format(T("AHS_STATS_LINE"), BB.Money(st.fees), BB.Money(st.proceeds), sign .. BB.Money(math.abs(st.net)))
  end
  if bankLeft > 0 then hint = string.format(T("AHS_IN_BANK"), bankLeft) .. " " .. hint end
  f.l2:SetText(hint)
  for i = 1, ROWS do
    local r = f.rows[i]
    local e = list[i]
    if e then
      local qc = BB.QUALITY_COLOR[e.q or 1] or BB.QUALITY_COLOR[1]
      r.name:SetText((e.sell > 1 and (e.sell .. "x ") or "") .. (e.n or "?"))
      r.name:SetTextColor(qc[1], qc[2], qc[3])
      r.val:SetText(BB.Money(e.price))
      r:Show()
    else
      r:Hide()
    end
  end
  if getn(list) > ROWS then f.more:SetText(string.format(T("AHS_MORE"), getn(list) - ROWS)) else f.more:SetText("") end
  local run = self.AH.run
  if run then
    f.go.fs:SetText(string.format(T("AHS_RUNNING"), run.posted, getn(run.queue)))
    f.go:SetOn(true)
  else
    f.go.fs:SetText(string.format(T("AHS_GO"), inBags))
    f.go:SetOn(inBags > 0)
  end
  f:Show()
end

function UI:OpenAHSell()
  self:BuildAHSell()
  self:RefreshAHSell()
end

local sf = CreateFrame("Frame")
sf:RegisterEvent("AUCTION_HOUSE_SHOW")
sf:RegisterEvent("AUCTION_HOUSE_CLOSED")
sf:RegisterEvent("BAG_UPDATE")
local acc = 0
sf:SetScript("OnEvent", function()
  if event == "AUCTION_HOUSE_SHOW" then
    -- das Hauptmodul setzt BB.ahOpen erst nach diesem Ereignis: spaeter anzeigen
    BB:After(0.5, function() UI:OpenAHSell() end, "ahsell")
  elseif event == "AUCTION_HOUSE_CLOSED" then
    UI:AHStop(true)
    if UI.ahWin then UI.ahWin:Hide() end
  elseif event == "BAG_UPDATE" then
    acc = 0.5
  end
end)
sf:SetScript("OnUpdate", function()
  if acc > 0 then
    acc = acc - (arg1 or 0)
    if acc <= 0 then
      acc = 0
      if UI.ahWin and UI.ahWin:IsShown() then UI:RefreshAHSell() end
    end
  end
end)
