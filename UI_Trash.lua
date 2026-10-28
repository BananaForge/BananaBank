-- BananaBank: Trash-Anzeige und -Verkauf (nur auf Bank-Chars)
-- * Tooltip-Hinweis und Muenz-Symbol an Taschen- und Bankfach-Items
-- * Fenster am Haendler: Vorschau und "Trash verkaufen"
-- * Knopf an der Bank: "Trash holen" (legt Trash aus den Bankfaechern in die Taschen)
-- * Erloes wird als "Trash income" im Buch gebucht

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.trashModule = true
UI.TS = { merchant = false, running = nil }

local COIN = "Interface\\Icons\\INV_Misc_Coin_01"

-- ------------------------------------------------------------
-- Tooltip
-- ------------------------------------------------------------
local function addTrashLines(tt, id, count)
  if not id or not BB:IsTrash(id) then return end
  local v = BB:VendorValue(id) or 0
  tt:AddLine(T("TRASH_TT"), 1, 0.42, 0.33)
  tt:AddLine(string.format(T("TRASH_TT2"), BB.Money(v), BB.Money(v * (count or 1))), 0.85, 0.85, 0.85)
  tt:Show()
end

local function hookTooltip()
  if UI.trashTipHooked or not GameTooltip then return end
  UI.trashTipHooked = true
  local origBag = GameTooltip.SetBagItem
  if origBag then
    GameTooltip.SetBagItem = function(self, bag, slot)
      local a, b = origBag(self, bag, slot)
      local ok = pcall(function()
        local link = GetContainerItemLink(bag, slot)
        if link then
          local _, count = GetContainerItemInfo(bag, slot)
          addTrashLines(self, BB.ParseLink(link), count)
        end
      end)
      return a, b
    end
  end
  local origInv = GameTooltip.SetInventoryItem
  if origInv then
    GameTooltip.SetInventoryItem = function(self, unit, slot)
      local a, b, c = origInv(self, unit, slot)
      if unit == "player" and slot and slot > 23 then
        pcall(function()
          local link = GetInventoryItemLink(unit, slot)
          if link then addTrashLines(self, BB.ParseLink(link), GetInventoryItemCount and GetInventoryItemCount(unit, slot)) end
        end)
      end
      return a, b, c
    end
  end
end

-- ------------------------------------------------------------
-- Muenz-Symbol an Items (Taschen und Bankfaecher)
-- ------------------------------------------------------------
local function markButton(button, bag, slot)
  if not button then return end
  local show = false
  if BB:IsBank() then
    local link = GetContainerItemLink(bag, slot)
    if link then
      local id = BB.ParseLink(link)
      show = id and BB:IsTrash(id) and true or false
    end
  end
  if show and not button.bbCoin then
    local t = button:CreateTexture(nil, "OVERLAY")
    t:SetTexture(COIN)
    t:SetWidth(14)
    t:SetHeight(14)
    t:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.bbCoin = t
  end
  if button.bbCoin then
    if show then button.bbCoin:Show() else button.bbCoin:Hide() end
  end
end

local function hookBags()
  if UI.trashBagHooked then return end
  UI.trashBagHooked = true
  if ContainerFrame_Update then
    local orig = ContainerFrame_Update
    ContainerFrame_Update = function(frame)
      orig(frame)
      pcall(function()
        local name = frame:GetName()
        local bag = frame:GetID()
        for i = 1, (frame.size or 0) do
          local b = getglobal(name .. "Item" .. i)
          if b then markButton(b, bag, b:GetID()) end
        end
      end)
    end
  end
  if BankFrameItemButton_Update then
    local origBank = BankFrameItemButton_Update
    BankFrameItemButton_Update = function(button)
      origBank(button)
      pcall(function() markButton(button, -1, button:GetID()) end)
    end
  end
end

-- offene Taschen und die Bank neu zeichnen (nach Aenderung der Grenze, nach dem Verkauf)
function UI:TrashRefreshMarks()
  pcall(function()
    for i = 1, 13 do
      local f = getglobal("ContainerFrame" .. i)
      if f and f:IsShown() and ContainerFrame_Update then ContainerFrame_Update(f) end
    end
    if BankFrame and BankFrame:IsShown() and BankFrameItemButton_Update then
      for i = 1, 24 do
        local b = getglobal("BankFrameItem" .. i)
        if b then BankFrameItemButton_Update(b) end
      end
    end
  end)
end

-- ------------------------------------------------------------
-- Fenster am Haendler
-- ------------------------------------------------------------
function UI:BuildTrashWindow()
  if self.trashWin or not MerchantFrame then return end
  local f = CreateFrame("Frame", "BananaBankTrash", MerchantFrame)
  self.trashWin = f
  f:SetWidth(232)
  f:SetHeight(150)
  f:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", -30, -14)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 7, right = 7, top = 7, bottom = 7 },
  })
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.97)
  f:Hide()
  local logo = f:CreateTexture(nil, "OVERLAY")
  logo:SetTexture(COIN)
  logo:SetWidth(26)
  logo:SetHeight(26)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
  local title = self:Font(f, 14, C.gold, UI.FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 44, -14)
  self:Loc(title, "TRASH_TITLE")
  f.l1 = self:Font(f, 11, C.text)
  f.l1:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -46)
  f.l1:SetWidth(204)
  f.l1:SetHeight(14)
  f.l2 = self:Font(f, 12, C.gold)
  f.l2:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -62)
  f.l2:SetWidth(204)
  f.l2:SetHeight(15)
  f.l3 = self:Font(f, 10, C.muted)
  f.l3:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -80)
  f.l3:SetWidth(204)
  f.l3:SetHeight(26)
  f.l3:SetJustifyV("TOP")
  f.sell = self:Button(f, 204, 24, "TRASH_SELL", function() UI:TrashSellStart() end, "primary")
  f.sell:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 36)
  f.prev = self:Button(f, 204, 20, "TRASH_PREVIEW", function() UI:TrashPreview() end)
  f.prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
end

function UI:RefreshTrashWindow()
  local f = self.trashWin
  if not f then return end
  if not (self.TS.merchant and BB:IsBank()) then
    f:Hide()
    return
  end
  f:Show()
  local plan, total = BB:TrashPlan()
  local items = 0
  for i = 1, getn(plan) do items = items + plan[i].c end
  f.l1:SetText(string.format(T("TRASH_COUNT"), getn(plan), items))
  f.l2:SetText(string.format(T("TRASH_INCOME"), BB.Money(total)))
  local sbank, ibank = BB:TrashInBank()
  f.l3:SetText(string.format(T("TRASH_LIMIT"), BB.Money(BB:TrashMax())) .. (sbank > 0 and ("\n" .. string.format(T("TRASH_IN_BANK"), sbank, ibank)) or ""))
  if self.TS.running then
    f.sell.fs:SetText(T("TRASH_RUNNING"))
    f.sell:SetOn(false)
  else
    f.sell.fs:SetText(T("TRASH_SELL"))
    f.sell:SetOn(getn(plan) > 0)
  end
  f.prev:SetOn(getn(plan) > 0)
end

function UI:TrashPreview()
  local plan, total = BB:TrashPlan()
  BB:Print(string.format(T("TRASH_PREVIEW_HEAD"), getn(plan), BB.Money(total)))
  local shown = 0
  for i = 1, getn(plan) do
    if shown < 15 then
      local p = plan[i]
      DEFAULT_CHAT_FRAME:AddMessage("  " .. p.c .. "x " .. BB:ColoredName(p.id) .. "  " .. BB.Money(p.v * p.c))
      shown = shown + 1
    end
  end
  if getn(plan) > shown then DEFAULT_CHAT_FRAME:AddMessage("  ... +" .. (getn(plan) - shown)) end
end

-- ------------------------------------------------------------
-- Verkauf
-- ------------------------------------------------------------
function UI:TrashSellStart()
  if self.TS.running or not self.TS.merchant or not BB:IsBank() then return end
  local plan = BB:TrashPlan()
  if getn(plan) == 0 then return end
  self.TS.running = { list = plan, idx = 1, income = 0, stacks = 0, items = 0, tick = 0 }
  self:RefreshTrashWindow()
end

function UI:TrashSellFinish(aborted)
  local run = self.TS.running
  self.TS.running = nil
  if run and run.income > 0 then
    -- als "Trash income" im Buch
    BB:AddLedger({ k = "trash", p = "Trash income", m = run.income, n = BB:Me(), c = run.items })
    BB:Print(string.format(T("TRASH_DONE"), run.stacks, run.items, BB.Money(run.income)))
    BB:ScheduleSnapshot(3)
  elseif aborted then
    BB:Print(T("TRASH_ABORT"))
  end
  self:TrashRefreshMarks()
  self:Refresh()
  self:RefreshTrashWindow()
end

local sellFrame = CreateFrame("Frame")
sellFrame:SetScript("OnUpdate", function()
  local run = UI.TS.running
  if not run then return end
  run.tick = run.tick + (arg1 or 0)
  if run.tick < 0.12 then return end
  run.tick = 0
  if not UI.TS.merchant then return UI:TrashSellFinish(true) end
  local p = run.list[run.idx]
  if not p then return UI:TrashSellFinish(false) end
  run.idx = run.idx + 1
  local link = GetContainerItemLink(p.bag, p.slot)
  if not link then return end
  local id = BB.ParseLink(link)
  local _, count = GetContainerItemInfo(p.bag, p.slot)
  if id ~= p.id or (count or 1) ~= p.c then return end
  if not BB:IsTrash(id) then return end
  if CursorHasItem() then ClearCursor() end
  UseContainerItem(p.bag, p.slot)
  run.income = run.income + p.v * p.c
  run.stacks = run.stacks + 1
  run.items = run.items + p.c
end)

-- ------------------------------------------------------------
-- Knopf an der Bank: Trash aus den Bankfaechern in die Taschen holen
-- ------------------------------------------------------------
function UI:BuildTrashFetchButton()
  if self.trashFetch or not BankFrame then return end
  local b = self:Button(BankFrame, 130, 20, "", function() UI:TrashFetchStart() end)
  b:SetPoint("TOPRIGHT", BankFrame, "TOPRIGHT", -50, -14)
  b:Hide()
  self.trashFetch = b
end

function UI:RefreshTrashFetch()
  local b = self.trashFetch
  if not b then return end
  if not (BB:IsBank() and BB.bankOpen) then
    b:Hide()
    return
  end
  local stacks, items = BB:TrashInBank()
  if stacks == 0 then
    b:Hide()
    return
  end
  b.fs:SetText(string.format(T("TRASH_FETCH"), stacks))
  b:SetOn(not self.TS.fetching)
  b:Show()
end

function UI:TrashFetchStart()
  if self.TS.fetching or not BB.bankOpen then return end
  local list = {}
  for _, bag in ipairs(BB.BANK_LIST) do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local id = BB.ParseLink(link)
        if id and BB:IsTrash(id) then table.insert(list, { bag = bag, slot = slot, id = id }) end
      end
    end
  end
  if getn(list) == 0 then return end
  self.TS.fetching = { list = list, idx = 1, tick = 0, moved = 0 }
  self:RefreshTrashFetch()
end

local fetchFrame = CreateFrame("Frame")
fetchFrame:SetScript("OnUpdate", function()
  local run = UI.TS.fetching
  if not run then return end
  run.tick = run.tick + (arg1 or 0)
  if run.tick < 0.2 then return end
  run.tick = 0
  local done = false
  if not BB.bankOpen then
    done = true
  elseif not BB:HasFreeBagSlot() then
    BB:Print("|cffff4040" .. T("ERR_BAGS_FULL") .. "|r")
    done = true
  else
    local p = run.list[run.idx]
    if not p then
      done = true
    else
      run.idx = run.idx + 1
      local link = GetContainerItemLink(p.bag, p.slot)
      if link and BB.ParseLink(link) == p.id then
        if CursorHasItem() then ClearCursor() end
        UseContainerItem(p.bag, p.slot)
        run.moved = run.moved + 1
      end
    end
  end
  if done then
    UI.TS.fetching = nil
    if run.moved > 0 then BB:Print(string.format(T("TRASH_FETCHED"), run.moved)) end
    UI:RefreshTrashFetch()
    UI:TrashRefreshMarks()
  end
end)

-- ------------------------------------------------------------
-- Ereignisse
-- ------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:RegisterEvent("MERCHANT_UPDATE")
ev:RegisterEvent("BANKFRAME_OPENED")
ev:RegisterEvent("BANKFRAME_CLOSED")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
local acc = 0
ev:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    hookTooltip()
    hookBags()
  elseif event == "MERCHANT_SHOW" then
    UI.TS.merchant = true
    UI:BuildTrashWindow()
    UI:RefreshTrashWindow()
  elseif event == "MERCHANT_CLOSED" then
    UI.TS.merchant = false
    if UI.TS.running then UI:TrashSellFinish(true) end
    UI:RefreshTrashWindow()
  elseif event == "MERCHANT_UPDATE" then
    UI:RefreshTrashWindow()
  elseif event == "BANKFRAME_OPENED" then
    UI:BuildTrashFetchButton()
    UI:RefreshTrashFetch()
  elseif event == "BANKFRAME_CLOSED" then
    UI.TS.fetching = nil
    UI:RefreshTrashFetch()
  elseif event == "BAG_UPDATE" then
    acc = 0.3
  end
end)
ev:SetScript("OnUpdate", function()
  if acc > 0 then
    acc = acc - (arg1 or 0)
    if acc <= 0 then
      acc = 0
      if UI.TS.merchant then UI:RefreshTrashWindow() end
      if BB.bankOpen then UI:RefreshTrashFetch() end
    end
  end
end)
