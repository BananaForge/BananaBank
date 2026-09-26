-- BananaBank UI: Reiter Preise

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local floor = math.floor

local PRICE_ROWS = 12
UI.priceModule = true

function UI:BuildPrices(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints(parent)
  p:Hide()
  self.pages.prices = p
  self.price = { filter = "all", page = 1 }
  local P = self.price

  P.info = self:Font(p, 11, C.text)
  P.info:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -2)
  P.info:SetWidth(430)
  P.info:SetHeight(28)
  P.info:SetJustifyV("TOP")

  P.scanBtn = self:Button(p, 130, 22, "BTN_AH_SCAN", function()
    if BB.scan then BB:StopAHScan() else BB:StartAHScan() end
    UI:RefreshPrices()
  end, "primary")
  P.scanBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -140, -2)
  P.cod = self:Check(p, "OPT_COD", function() return BananaBankDB.cod ~= false end, function(v)
    BananaBankDB.cod = v
    UI:Refresh()
  end)
  P.cod:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -6)
  P.cod:SetWidth(132)

  P.chips = {}
  local defs = { { "FILTER_ALL", "all" }, { "PRICE_WITH", "with" }, { "PRICE_WITHOUT", "without" } }
  local prev
  for i = 1, getn(defs) do
    local key = defs[i][2]
    local chip = self:Chip(p, 92, defs[i][1], function()
      P.filter = key
      P.page = 1
      UI:RefreshPrices()
    end)
    chip.key = key
    if prev then chip:SetPoint("LEFT", prev, "RIGHT", 4, 0) else chip:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -32) end
    table.insert(P.chips, chip)
    prev = chip
  end

  local list = self:Panel(p)
  list:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -56)
  list:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 28)
  local cols = { { "COL_ITEM", 14 }, { "COL_BIND", 300 }, { "COL_PRICE", 400 }, { "COL_SOURCE", 512 }, { "COL_DATE", 608 } }
  for i = 1, getn(cols) do
    local h = self:Font(list, 10, C.goldDim)
    h:SetPoint("TOPLEFT", list, "TOPLEFT", cols[i][2], -9)
    self:Loc(h, cols[i][1])
  end
  self:HLine(list, -24, 8, -8, C.brass, 0.8)

  P.rows = {}
  for i = 1, PRICE_ROWS do
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -28 - (i - 1) * 25)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -28 - (i - 1) * 25)
    local zebra = row:CreateTexture(nil, "BACKGROUND")
    zebra:SetAllPoints(row)
    zebra:SetTexture(1, 1, 1, (math.mod(i, 2) == 0) and 0.03 or 0)
    row.ic = self:Slot(row, 22)
    row.ic:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.ic:SetScript("OnEnter", function() if this.id then UI:ItemTooltip(this, this.id) end end)
    row.ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.name = self:Font(row, 11, C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 28, 0)
    row.name:SetWidth(258)
    row.name:SetHeight(13)
    row.bind = self:Font(row, 10, C.muted)
    row.bind:SetPoint("LEFT", row, "LEFT", 292, 0)
    row.bind:SetWidth(100)
    row.price = self:Font(row, 11, C.gold)
    row.price:SetPoint("LEFT", row, "LEFT", 392, 0)
    row.price:SetWidth(112)
    row.src = self:Font(row, 10, C.muted)
    row.src:SetPoint("LEFT", row, "LEFT", 504, 0)
    row.src:SetWidth(94)
    row.date = self:Font(row, 10, C.muted)
    row.date:SetPoint("LEFT", row, "LEFT", 600, 0)
    row.date:SetWidth(72)
    row.edit = self:Button(row, 62, 20, "BTN_PRICE_SET", function(b) UI:ShowPriceDialog(b.row.id) end, "flat")
    row.edit:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.edit.row = row
    table.insert(P.rows, row)
  end
  P.empty = self:Font(list, 12, C.muted)
  P.empty:SetPoint("CENTER", list, "CENTER", 0, 0)
  P.empty:SetJustifyH("CENTER")
  P.empty:SetWidth(420)

  local prevBtn = self:Button(p, 26, 20, "<", function()
    P.page = P.page - 1
    UI:RefreshPrices()
  end, "flat")
  prevBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 2)
  local nextBtn = self:Button(p, 26, 20, ">", function()
    P.page = P.page + 1
    UI:RefreshPrices()
  end, "flat")
  nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 60, 0)
  P.pageFs = self:Font(p, 11, C.text)
  P.pageFs:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
  P.pageFs:SetWidth(52)
  P.pageFs:SetJustifyH("CENTER")
  local legend = self:Font(p, 10, C.muted)
  legend:SetPoint("LEFT", nextBtn, "RIGHT", 12, 0)
  legend:SetWidth(520)
  self:Loc(legend, "PRICE_LEGEND")

  self:BuildPriceDialog()
end

function UI:PriceList()
  local P = self.price
  local stock = BB:GetStock()
  local list = {}
  for id, e in pairs(stock) do
    local u = BB:GetPrice(id)
    local boe = BB:IsBOE(id)
    local take = boe or u
    if take then
      if P.filter == "with" then take = u ~= nil end
      if P.filter == "without" then take = (u == nil) end
    end
    if take then table.insert(list, { id = id, e = e, u = u }) end
  end
  table.sort(list, function(a, b)
    if (a.u or -1) ~= (b.u or -1) then return (a.u or -1) > (b.u or -1) end
    return (a.e.n or "") < (b.e.n or "")
  end)
  return list
end

function UI:RefreshPrices()
  if not self.price then return end
  local P = self.price
  local db = BananaBankDB
  for i = 1, getn(P.chips) do P.chips[i]:SetActive(P.chips[i].key == P.filter) end

  local isBank = BB:IsBank()
  if isBank then P.scanBtn:Show() else P.scanBtn:Hide() end
  if isBank then P.cod:Show() else P.cod:Hide() end
  P.cod.Update()
  if BB.scan then
    P.scanBtn.fs:SetText(T("BTN_AH_STOP"))
    P.info:SetText(string.format(T("PRICE_SCANNING"), BB.scan.idx,
      table.getn(BB.scan.ids), BB:ScanItemName()))
  else
    P.scanBtn.fs:SetText(T("BTN_AH_SCAN"))
    local scan = db.priceScan or {}
    if (scan.ts or 0) > 0 then
      local days = floor((time() - scan.ts) / 86400)
      P.info:SetText(string.format(T("PRICE_INFO"), BB.Date(scan.ts), days,
        scan.items or 0, BB.Count(db.prices)))
    else
      P.info:SetText(T("PRICE_INFO_NONE"))
    end
  end

  local list = self:PriceList()
  local pages = floor((getn(list) - 1) / PRICE_ROWS) + 1
  if pages < 1 then pages = 1 end
  if P.page > pages then P.page = pages end
  if P.page < 1 then P.page = 1 end
  for i = 1, PRICE_ROWS do
    local row = P.rows[i]
    local entry = list[(P.page - 1) * PRICE_ROWS + i]
    if entry then
      local id = entry.id
      row.id = id
      row.ic.id = id
      row.ic.icon:SetTexture(BB.FullTex(entry.e.t))
      row.ic:SetQuality(entry.e.q)
      local qc = BB.QUALITY_COLOR[entry.e.q or 1] or BB.QUALITY_COLOR[1]
      row.name:SetText(entry.e.n .. "  |cff888888x" .. entry.e.c .. "|r")
      row.name:SetTextColor(qc[1], qc[2], qc[3])
      row.bind:SetText(BB:IsBOE(id) and T("BIND_BOE") or "-")
      local u, src, ts, n = BB:GetPrice(id)
      if u then
        row.price:SetText(BB.Money(u))
        if src == "man" then
          row.src:SetText(T("SRC_MANUAL"))
        else
          row.src:SetText(string.format(T("SRC_AH"), n or 0))
        end
        row.date:SetText(BB.Date(ts))
      else
        row.price:SetText("|cffff8000" .. T("PRICE_NONE") .. "|r")
        local raw = BananaBankDB.prices[id]
        if raw and raw.src == "none" then
          row.src:SetText("|cffff8000" .. T("SRC_NOT_FOUND") .. "|r")
          row.date:SetText(BB.Date(raw.ts))
        else
          row.src:SetText(T("SRC_NEVER"))
          row.date:SetText("-")
        end
      end
      if isBank then row.edit:Show() else row.edit:Hide() end
      row:Show()
    else
      row.id = nil
      row:Hide()
    end
  end
  if getn(list) == 0 then
    P.empty:SetText(T("PRICE_EMPTY"))
    P.empty:Show()
  else
    P.empty:Hide()
  end
  P.pageFs:SetText(P.page .. " / " .. pages)
end

-- ------------------------------------------------------------
-- Preis von Hand setzen
-- ------------------------------------------------------------
function UI:BuildPriceDialog()
  local d = CreateFrame("Frame", "BananaBankPriceDialog", UIParent)
  self.priceDialog = d
  d:SetWidth(380)
  d:SetHeight(180)
  d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  d:SetFrameStrata("DIALOG")
  d:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  d:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
  d:EnableMouse(true)
  d:Hide()
  tinsert(UISpecialFrames, "BananaBankPriceDialog")
  local t = self:Font(d, 17, C.gold, UI.FONT_TITLE)
  t:SetPoint("TOP", d, "TOP", 0, -18)
  t:SetJustifyH("CENTER")
  self:Loc(t, "PRICE_DIALOG_TITLE")
  d.item = self:Font(d, 12, C.text)
  d.item:SetPoint("TOP", t, "BOTTOM", 0, -8)
  d.item:SetWidth(330)
  d.item:SetJustifyH("CENTER")
  local hint = self:Font(d, 10, C.muted)
  hint:SetPoint("TOP", d.item, "BOTTOM", 0, -6)
  hint:SetWidth(330)
  hint:SetJustifyH("CENTER")
  self:Loc(hint, "PRICE_DIALOG_HINT")
  -- Gold, Silber, Kupfer einzeln. Ein Dezimalfeld verrechnet sich zu leicht.
  local holder = CreateFrame("Frame", nil, d)
  holder:SetWidth(240)
  holder:SetHeight(24)
  holder:SetPoint("TOP", hint, "BOTTOM", 0, -10)
  d.coins = {}
  local defs = { { "g", "g", 6 }, { "s", "s", 2 }, { "c", "c", 2 } }
  local prev
  for i = 1, getn(defs) do
    local key, letter, maxLen = defs[i][1], defs[i][2], defs[i][3]
    local box = self:EditBox("BananaBankPrice" .. string.upper(key), holder, 54)
    box:SetMaxLetters(maxLen)
    box:SetNumeric(true)
    if prev then
      box:SetPoint("LEFT", prev, "RIGHT", 26, 0)
    else
      box:SetPoint("LEFT", holder, "LEFT", 6, 0)
    end
    local lbl = self:Font(holder, 13, C.text, UI.FONT, "OUTLINE")
    lbl:SetPoint("LEFT", box, "RIGHT", 4, 0)
    lbl:SetText("|cff" .. BB.COIN_COLOR[key] .. letter .. "|r")
    box:SetScript("OnEnterPressed", function()
      UI:ApplyPriceDialog()
      this:ClearFocus()
    end)
    d.coins[key] = box
    prev = box
  end
  -- Tab springt weiter
  d.coins.g:SetScript("OnTabPressed", function() d.coins.s:SetFocus() end)
  d.coins.s:SetScript("OnTabPressed", function() d.coins.c:SetFocus() end)
  d.coins.c:SetScript("OnTabPressed", function() d.coins.g:SetFocus() end)
  local ok = self:Button(d, 110, 24, "BTN_SAVE", function() UI:ApplyPriceDialog() end, "primary")
  ok:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -4, 18)
  local cancel = self:Button(d, 110, 24, "BTN_CLOSE", function() d:Hide() end)
  cancel:SetPoint("BOTTOMLEFT", d, "BOTTOM", 4, 18)
  d.reset = self:Button(d, 224, 20, "BTN_PRICE_RESET", function()
    if d.id then
      BB:ResetPrice(d.id)
      BB:Print(T("MSG_PRICE_RESET"))
    end
    d:Hide()
    UI:Refresh()
  end, "flat")
  d.reset:SetPoint("BOTTOM", d, "BOTTOM", 0, 44)
end

function UI:ShowPriceDialog(id)
  if not id then return end
  local d = self.priceDialog
  d.id = id
  d.item:SetText(BB:ColoredName(id))
  local u, src = BB:GetPrice(id)
  local g, si, c = BB.SplitMoney(u or 0)
  d.coins.g:SetText(u and g or "")
  d.coins.s:SetText(u and si or "")
  d.coins.c:SetText(u and c or "")
  if src == "man" then d.reset:Show() else d.reset:Hide() end
  d:Show()
  d.coins.g:SetFocus()
  d.coins.g:HighlightText()
end

function UI:ApplyPriceDialog()
  local d = self.priceDialog
  if not d.id then return end
  local function val(key)
    local t = d.coins[key]:GetText() or ""
    if t == "" then return 0 end
    local n = tonumber(t)
    if not n or n < 0 then return nil end
    return floor(n)
  end
  local g, s, c = val("g"), val("s"), val("c")
  if not g or not s or not c then
    BB:Print(T("ERR_PRICE_INPUT"))
    return
  end
  local total = g * 10000 + s * 100 + c
  BB:SetPrice(d.id, total, "man")
  BB:Print(string.format(T("MSG_PRICE_SET"), BB:ColoredName(d.id), BB.Money(total)))
  d:Hide()
  self:Refresh()
end
