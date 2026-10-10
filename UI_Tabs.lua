-- BananaBank UI Teil 2: Anfragen, Buch, Bank-Reiter, Versandhelfer am Briefkasten

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local floor = math.floor

local function itemSummary(items, maxLen)
  local ids = {}
  for id in pairs(items) do table.insert(ids, id) end
  table.sort(ids)
  local parts = {}
  for i = 1, getn(ids) do
    table.insert(parts, items[ids[i]] .. "x " .. (BB:ItemInfo(ids[i])))
  end
  local s = table.concat(parts, ", ")
  if maxLen and string.len(s) > maxLen then s = string.sub(s, 1, maxLen - 3) .. "..." end
  return s
end
UI.ItemSummary = itemSummary

local function statusText(st)
  return T("STATUS_" .. string.upper(st))
end

-- ------------------------------------------------------------
-- Reiter Anfragen
-- ------------------------------------------------------------
local REQ_ROWS = 11

function UI:BuildRequests(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints(parent)
  p:Hide()
  self.pages.requests = p
  self.req = { filter = "open", page = 1 }
  local R = self.req

  R.chips = {}
  local defs = { { "FILTER_OPEN", "open" }, { "FILTER_MINE", "mine" }, { "FILTER_ALL", "all" } }
  local prev
  for i = 1, getn(defs) do
    local key = defs[i][2]
    local chip = self:Chip(p, 80, defs[i][1], function()
      R.filter = key
      R.page = 1
      UI:RefreshRequests()
    end)
    chip.key = key
    if prev then chip:SetPoint("LEFT", prev, "RIGHT", 4, 0) else chip:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -2) end
    table.insert(R.chips, chip)
    prev = chip
  end
  R.info = self:Font(p, 11, C.muted)
  R.info:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -5)
  R.info:SetJustifyH("RIGHT")

  local list = self:Panel(p)
  list:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -26)
  list:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 28)

  local cols = { { "COL_STATUS", 10 }, { "COL_CODE", 108 }, { "COL_PLAYER", 178 }, { "COL_ITEMS", 290 }, { "COL_DATE", 596 } }
  for i = 1, getn(cols) do
    local h = self:Font(list, 10, C.goldDim)
    h:SetPoint("TOPLEFT", list, "TOPLEFT", cols[i][2], -9)
    self:Loc(h, cols[i][1])
  end
  self:HLine(list, -24, 8, -8, C.brass, 0.8)

  R.rows = {}
  for i = 1, REQ_ROWS do
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(27)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -28 - (i - 1) * 28)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -6, -28 - (i - 1) * 28)
    local zebra = row:CreateTexture(nil, "BACKGROUND")
    zebra:SetAllPoints(row)
    zebra:SetTexture(1, 1, 1, (math.mod(i, 2) == 0) and 0.03 or 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetTexture(1, 0.82, 0.3, 0.08)

    local pill = CreateFrame("Frame", nil, row)
    pill:SetWidth(88)
    pill:SetHeight(18)
    pill:SetPoint("LEFT", row, "LEFT", 2, 0)
    pill:SetBackdrop(UI.BACKDROP_PANEL)
    row.pill = pill
    row.pillFs = self:Font(pill, 10, C.text)
    row.pillFs:SetPoint("CENTER", pill, "CENTER", 0, 0)
    row.pillFs:SetJustifyH("CENTER")

    row.code = self:Font(row, 11, C.gold)
    row.code:SetPoint("LEFT", row, "LEFT", 102, 0)
    row.player = self:Font(row, 11, C.text)
    row.player:SetPoint("LEFT", row, "LEFT", 172, 0)
    row.player:SetWidth(108)
    row.player:SetHeight(13)
    row.items = self:Font(row, 11, C.text)
    row.items:SetPoint("LEFT", row, "LEFT", 284, 0)
    row.items:SetWidth(300)
    row.items:SetHeight(13)
    row.date = self:Font(row, 10, C.muted)
    row.date:SetPoint("LEFT", row, "LEFT", 590, 0)

    row.action = self:Button(row, 64, 20, "", function(b) UI:OnRequestAction(b.row) end, "flat")
    row.action:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.action.row = row

    row:SetScript("OnEnter", function() UI:RequestTooltip(this) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(R.rows, row)
  end
  R.empty = self:Font(list, 12, C.muted)
  R.empty:SetPoint("CENTER", list, "CENTER", 0, 0)
  R.empty:SetJustifyH("CENTER")

  local prevBtn = self:Button(p, 26, 20, "<", function()
    R.page = R.page - 1
    UI:RefreshRequests()
  end, "flat")
  prevBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 2)
  local nextBtn = self:Button(p, 26, 20, ">", function()
    R.page = R.page + 1
    UI:RefreshRequests()
  end, "flat")
  nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 60, 0)
  R.pageFs = self:Font(p, 11, C.text)
  R.pageFs:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
  R.pageFs:SetWidth(52)
  R.pageFs:SetJustifyH("CENTER")
  local legend = self:Font(p, 10, C.muted)
  legend:SetPoint("LEFT", nextBtn, "RIGHT", 12, 0)
  self:Loc(legend, "REQ_LEGEND")
end

function UI:RequestList()
  local R = self.req
  local me = BB:Me()
  local list = {}
  for _, r in pairs(BananaBankDB.reqs) do
    local st = BB:ReqState(r)
    local ok = true
    if R.filter == "open" then ok = (st == "open" or st == "confirmed") end
    if R.filter == "mine" then ok = (r.p == me) end
    if ok then table.insert(list, r) end
  end
  table.sort(list, function(a, b) return (a.ts or 0) > (b.ts or 0) end)
  return list
end

function UI:RefreshRequests()
  if not self.req then return end
  local R = self.req
  for i = 1, getn(R.chips) do R.chips[i]:SetActive(R.chips[i].key == R.filter) end
  local list = self:RequestList()
  local pages = floor((getn(list) - 1) / REQ_ROWS) + 1
  if pages < 1 then pages = 1 end
  if R.page > pages then R.page = pages end
  if R.page < 1 then R.page = 1 end
  local me = BB:Me()
  local isBank = BB:IsBank()
  local openCount = 0
  for _, r in pairs(BananaBankDB.reqs) do
    if BB:IsActive(r) then openCount = openCount + 1 end
  end
  R.info:SetText(string.format(T("REQ_INFO"), openCount))
  for i = 1, REQ_ROWS do
    local row = R.rows[i]
    local r = list[(R.page - 1) * REQ_ROWS + i]
    row.r = r
    if r then
      local st = BB:ReqState(r)
      local sc = UI.STATUS_COLOR[st] or C.muted
      row.pill:SetBackdropColor(sc[1] * 0.35, sc[2] * 0.35, sc[3] * 0.35, 0.95)
      row.pill:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.9)
      row.pillFs:SetText(statusText(st))
      row.pillFs:SetTextColor(sc[1], sc[2], sc[3])
      row.code:SetText(r.id)
      row.player:SetText(r.p)
      if r.p == me then row.player:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) else row.player:SetTextColor(C.text[1], C.text[2], C.text[3]) end
      row.items:SetText(itemSummary(r.items, 58))
      row.date:SetText(BB.Date(r.ts))
      row.actionKind = nil
      if isBank and (st == "open" or st == "confirmed") then
        row.actionKind = "open"
        row.action.fs:SetText(T("BTN_OPEN"))
      elseif r.p == me and st == "open" then
        row.actionKind = "cancel"
        row.action.fs:SetText(T("BTN_CANCEL"))
      elseif r.p == me and (st == "open" or st == "confirmed" or st == "sent") then
        row.actionKind = "code"
        row.action.fs:SetText(T("BTN_CODE"))
      end
      if row.actionKind then row.action:Show() else row.action:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
  if getn(list) == 0 then
    R.empty:SetText(T("REQ_EMPTY"))
    R.empty:Show()
  else
    R.empty:Hide()
  end
  R.pageFs:SetText(R.page .. " / " .. pages)
end

function UI:OnRequestAction(row)
  local r = row.r
  if not r then return end
  if row.actionKind == "open" then
    self.bank.current = r
    self:ShowPage("bank")
  elseif row.actionKind == "cancel" then
    BB:SetStatus(r, "cancelled")
    BB:Print(string.format(T("MSG_CANCELLED"), r.id))
  elseif row.actionKind == "code" then
    self:ShowExport(r)
  end
end

function UI:RequestTooltip(row)
  local r = row.r
  if not r then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(string.format(T("TT_REQUEST"), r.id, r.p), C.gold[1], C.gold[2], C.gold[3])
  local ids = {}
  for id in pairs(r.items) do table.insert(ids, id) end
  table.sort(ids)
  for i = 1, getn(ids) do
    local id = ids[i]
    local sent = (r.sent and r.sent[id]) or 0
    local right = r.items[id] .. "x"
    if sent > 0 then right = sent .. "/" .. r.items[id] .. " " .. T("TT_SENT") end
    GameTooltip:AddDoubleLine(BB:ColoredName(id), right, 1, 1, 1, 0.9, 0.9, 0.9)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(statusText(BB:ReqState(r)) .. "  -  " .. BB.Date(r.u), 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

-- ------------------------------------------------------------
-- Reiter Buch
-- ------------------------------------------------------------
local TOP_ROWS, RECENT_ROWS = 12, 12

local function makeListPanel(ui, parent, w, key)
  local pnl = ui:Panel(parent, w, 0)
  local t = ui:Font(pnl, 14, C.gold, UI.FONT_TITLE)
  t:SetPoint("TOPLEFT", pnl, "TOPLEFT", 12, -10)
  ui:Loc(t, key)
  ui:HLine(pnl, -30, 10, -10, C.brass, 0.9)
  pnl.rows = {}
  return pnl
end

function UI:BuildLedger(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints(parent)
  p:Hide()
  self.pages.ledger = p
  self.led = { page = 1 }
  local Lg = self.led

  Lg.totals = self:Font(p, 11, C.text)
  Lg.totals:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -4)
  Lg.totals:SetWidth(600)
  Lg.sumBtn = self:Button(p, 120, 18, "MW_BTN_TOTALS", function() UI:OpenTotalsWindow("in") end, "primary")
  Lg.sumBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -2)

  local function topPanel(key, x, w, color, mode)
    local pnl = makeListPanel(self, p, w, key)
    pnl:SetPoint("TOPLEFT", p, "TOPLEFT", x, -24)
    pnl:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", x, 0)
    for i = 1, TOP_ROWS do
      local row = CreateFrame("Button", nil, pnl)
      row:SetHeight(24)
      row:SetPoint("TOPLEFT", pnl, "TOPLEFT", 10, -36 - (i - 1) * 25)
      row:SetPoint("TOPRIGHT", pnl, "TOPRIGHT", -10, -36 - (i - 1) * 25)
      -- Klick oeffnet das Mitglieder-Fenster mit allen Spenden bzw. Entnahmen
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetTexture(UI.WHITE)
      hl:SetAllPoints(row)
      hl:SetVertexColor(1, 0.82, 0.3, 0.10)
      row.mode = mode
      row:SetScript("OnClick", function()
        if this.who then
          PlaySound("igMainMenuOptionCheckBoxOn")
          UI:OpenMemberWindow(this.who, this.mode)
        end
      end)
      row:SetScript("OnEnter", function()
        if not this.who then return end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(this.who, C.gold[1], C.gold[2], C.gold[3])
        GameTooltip:AddLine(T("MW_CLICK"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.rank = self:Font(row, 12, C.goldDim, UI.FONT_TITLE)
      row.rank:SetPoint("LEFT", row, "LEFT", 0, 0)
      row.rank:SetWidth(22)
      row.name = self:Font(row, 11, C.text)
      row.name:SetPoint("LEFT", row, "LEFT", 24, 0)
      row.name:SetWidth(96)
      row.name:SetHeight(13)
      row.val = self:Font(row, 11, color)
      row.val:SetPoint("RIGHT", row, "RIGHT", 0, 0)
      row.val:SetJustifyH("RIGHT")
      local bar = row:CreateTexture(nil, "BACKGROUND")
      bar:SetTexture(UI.WHITE)
      bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 24, 1)
      bar:SetHeight(2)
      bar:SetVertexColor(color[1], color[2], color[3], 0.35)
      row.bar = bar
      table.insert(pnl.rows, row)
    end
    pnl.empty = self:Font(pnl, 11, C.muted)
    pnl.empty:SetPoint("TOPLEFT", pnl, "TOPLEFT", 14, -42)
    pnl.empty:SetWidth(w - 28)
    self:Loc(pnl.empty, "LEDGER_EMPTY")
    return pnl
  end
  Lg.inPanel = topPanel("LEDGER_TOP_IN", 0, 234, C.green, "in")
  Lg.outPanel = topPanel("LEDGER_TOP_OUT", 240, 234, C.orange, "out")

  local rp = makeListPanel(self, p, 0, "LEDGER_RECENT")
  rp:SetPoint("TOPLEFT", p, "TOPLEFT", 480, -24)
  rp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  for i = 1, RECENT_ROWS do
    local row = CreateFrame("Frame", nil, rp)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", rp, "TOPLEFT", 10, -36 - (i - 1) * 25)
    row:SetPoint("TOPRIGHT", rp, "TOPRIGHT", -10, -36 - (i - 1) * 25)
    row:EnableMouse(true)
    row.tag = self:Font(row, 13, C.green, UI.FONT, "OUTLINE")
    row.tag:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.tag:SetWidth(12)
    row.txt = self:Font(row, 10, C.text)
    row.txt:SetPoint("LEFT", row, "LEFT", 14, 5)
    row.txt:SetWidth(222)
    row.txt:SetHeight(12)
    row.sub = self:Font(row, 9, C.muted)
    row.sub:SetPoint("LEFT", row, "LEFT", 14, -6)
    row.sub:SetWidth(222)
    row:SetScript("OnEnter", function()
      local e = this.e
      if not e then return end
      if e.i and e.i > 0 then
        UI:ItemTooltip(this, e.i, { { T("TT_BOOKED"), BB.Date(e.t) } })
      end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(rp.rows, row)
  end
  rp.empty = self:Font(rp, 11, C.muted)
  rp.empty:SetPoint("TOPLEFT", rp, "TOPLEFT", 14, -42)
  rp.empty:SetWidth(230)
  self:Loc(rp.empty, "LEDGER_EMPTY")
  local nextBtn = self:Button(rp, 22, 18, ">", function()
    Lg.page = Lg.page + 1
    UI:RefreshLedger()
  end, "flat")
  nextBtn:SetPoint("TOPRIGHT", rp, "TOPRIGHT", -8, -8)
  local prevBtn = self:Button(rp, 22, 18, "<", function()
    Lg.page = Lg.page - 1
    UI:RefreshLedger()
  end, "flat")
  prevBtn:SetPoint("RIGHT", nextBtn, "LEFT", -40, 0)
  Lg.pageFs = self:Font(rp, 10, C.text)
  Lg.pageFs:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
  Lg.pageFs:SetWidth(36)
  Lg.pageFs:SetJustifyH("CENTER")
  Lg.recent = rp
end

local function fillTop(pnl, list)
  local maxC = 1
  if list[1] then maxC = math.max(list[1].c, 1) end
  for i = 1, TOP_ROWS do
    local row = pnl.rows[i]
    local t = list[i]
    if t then
      row.rank:SetText(i .. ".")
      row.who = t.p
      row.name:SetText(t.p)
      local v = t.c .. " " .. T("UNIT_ITEMS")
      if t.m > 0 then v = v .. "  " .. BB.Money(t.m) end
      row.val:SetText(v)
      row.bar:SetWidth(math.max(2, 180 * t.c / maxC))
      row:Show()
    else
      row.who = nil
      row:Hide()
    end
  end
  if list[1] then pnl.empty:Hide() else pnl.empty:Show() end
end

local KIND_TAG = { out = "-", gout = "-", ["in"] = "+", gold = "+", back = "<", cod = "$" }

function UI:RefreshLedger()
  if not self.led then return end
  local Lg = self.led
  local ins = BB:LedgerTotals("in")
  local outs = BB:LedgerTotals("out")
  fillTop(Lg.inPanel, ins)
  fillTop(Lg.outPanel, outs)
  local ti, tm, to = 0, 0, 0
  for i = 1, getn(ins) do
    ti = ti + ins[i].c
    tm = tm + ins[i].m
  end
  for i = 1, getn(outs) do to = to + outs[i].c end
  local paid, openCod = BB:CodTotal()
  local txt = string.format(T("LEDGER_TOTALS"), ti, BB.Money(tm), to, BB.Count(BananaBankDB.ledger))
  if paid > 0 or openCod > 0 then
    txt = txt .. "      " .. string.format(T("LEDGER_COD"), BB.Money(paid), BB.Money(openCod))
  end
  Lg.totals:SetText(txt)

  local list = BB:LedgerSorted()
  local pages = floor((getn(list) - 1) / RECENT_ROWS) + 1
  if pages < 1 then pages = 1 end
  if Lg.page > pages then Lg.page = pages end
  if Lg.page < 1 then Lg.page = 1 end
  Lg.pageFs:SetText(Lg.page .. "/" .. pages)
  for i = 1, RECENT_ROWS do
    local row = Lg.recent.rows[i]
    local e = list[(Lg.page - 1) * RECENT_ROWS + i]
    row.e = e
    if e then
      local tag = KIND_TAG[e.k] or "?"
      row.tag:SetText(tag)
      local col = C.green
      if tag == "-" then col = C.orange elseif tag == "<" then col = C.muted end
      row.tag:SetTextColor(col[1], col[2], col[3])
      local what
      if e.k == "gold" or e.k == "gout" or e.k == "cod" then
        what = BB.Money(e.m)
      else
        local qc = BB.QUALITY_COLOR[e.q or 1] or BB.QUALITY_COLOR[1]
        what = e.c .. "x |cff" .. qc[4] .. e.n .. "|r"
      end
      row.txt:SetText(e.p .. ": " .. what)
      local sub = BB.Date(e.t) .. "  " .. T("KIND_" .. string.upper(e.k))
      local qq = e.code ~= "" and BananaBankDB.quests[e.code]
      if qq then
        sub = sub .. "  |cffffd100" .. qq.title .. "|r"
      elseif e.code ~= "" and e.code ~= "TRADE" then
        sub = sub .. "  " .. e.code
      end
      row.sub:SetText(sub)
      row:Show()
    else
      row:Hide()
    end
  end
  if list[1] then Lg.recent.empty:Hide() else Lg.recent.empty:Show() end
end

-- ------------------------------------------------------------
-- Reiter Bank (nur Bank-Char)
-- ------------------------------------------------------------
local BANK_ROWS = 8

function UI:BuildBank(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints(parent)
  p:Hide()
  self.pages.bank = p
  self.bank = {}
  local Bk = self.bank

  local left = self:Panel(p, 480, 0)
  left:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
  local lt = self:Font(left, 14, C.gold, UI.FONT_TITLE)
  lt:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -10)
  self:Loc(lt, "BANK_REDEEM_TITLE")
  local codeBox = self:EditBox("BananaBankCodeInput", left, 330)
  codeBox:SetMaxLetters(0)
  codeBox:SetPoint("TOPLEFT", left, "TOPLEFT", 18, -34)
  codeBox:SetScript("OnEnterPressed", function()
    UI:CheckCode()
    this:ClearFocus()
  end)
  Bk.codeBox = codeBox
  local ph = self:Font(codeBox, 11, C.muted)
  ph:SetPoint("LEFT", codeBox, "LEFT", 2, 0)
  self:Loc(ph, "BANK_CODE_PLACEHOLDER")
  codeBox:SetScript("OnTextChanged", function()
    if (this:GetText() or "") == "" then ph:Show() else ph:Hide() end
  end)
  local check = self:Button(left, 100, 22, "BTN_CHECK", function() UI:CheckCode() end, "primary")
  check:SetPoint("LEFT", codeBox, "RIGHT", 8, 0)

  Bk.head = self:Font(left, 13, C.text)
  Bk.head:SetPoint("TOPLEFT", left, "TOPLEFT", 14, -64)
  Bk.head:SetWidth(452)
  Bk.head:SetHeight(16)
  self:HLine(left, -84, 10, -10, C.brass, 0.8)
  local cols = { { "COL_ITEM", 14 }, { "COL_WANTED", 262 }, { "COL_SENT", 330 }, { "COL_HERE", 400 } }
  for i = 1, getn(cols) do
    local h = self:Font(left, 10, C.goldDim)
    h:SetPoint("TOPLEFT", left, "TOPLEFT", cols[i][2], -90)
    self:Loc(h, cols[i][1])
  end
  Bk.rows = {}
  for i = 1, BANK_ROWS do
    local row = CreateFrame("Frame", nil, left)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -104 - (i - 1) * 26)
    row:SetPoint("TOPRIGHT", left, "TOPRIGHT", -12, -104 - (i - 1) * 26)
    row.ic = self:Slot(row, 22)
    row.ic:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.ic:SetScript("OnEnter", function() if this.id then UI:ItemTooltip(this, this.id) end end)
    row.ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.name = self:Font(row, 11, C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 28, 0)
    row.name:SetWidth(210)
    row.name:SetHeight(13)
    row.want = self:Font(row, 12, C.text)
    row.want:SetPoint("LEFT", row, "LEFT", 256, 0)
    row.sent = self:Font(row, 12, C.green)
    row.sent:SetPoint("LEFT", row, "LEFT", 324, 0)
    row.here = self:Font(row, 12, C.text)
    row.here:SetPoint("LEFT", row, "LEFT", 394, 0)
    table.insert(Bk.rows, row)
  end
  Bk.hint = self:Font(left, 12, C.muted)
  Bk.hint:SetPoint("TOPLEFT", left, "TOPLEFT", 16, -110)
  Bk.hint:SetWidth(440)
  self:Loc(Bk.hint, "BANK_HINT")

  Bk.confirm = self:Button(left, 106, 24, "BTN_CONFIRM", function()
    BB:ConfirmRequest(Bk.current)
    UI:Refresh()
  end, "ok")
  Bk.confirm:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 12, 40)
  Bk.reject = self:Button(left, 106, 24, "BTN_REJECT", function()
    BB:RejectRequest(Bk.current)
    UI:Refresh()
  end, "danger")
  Bk.reject:SetPoint("LEFT", Bk.confirm, "RIGHT", 6, 0)
  Bk.fetch = self:Button(left, 110, 24, "BTN_FETCH", function()
    BB:StartPrepare(Bk.current)
    UI:Refresh()
  end)
  Bk.fetch:SetPoint("LEFT", Bk.reject, "RIGHT", 6, 0)
  Bk.send = self:Button(left, 118, 24, "BTN_SEND", function()
    BB:SendNextMail()
    UI:Refresh()
  end, "primary")
  Bk.send:SetPoint("LEFT", Bk.fetch, "RIGHT", 6, 0)
  Bk.auto = self:Check(left, "OPT_AUTO_MAIL", function() return BananaBankDB.auto end, function(v) BananaBankDB.auto = v end)
  Bk.auto:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 14, 14)
  Bk.whisper = self:Check(left, "OPT_WHISPER", function() return BananaBankDB.whisper ~= false end, function(v) BananaBankDB.whisper = v end)
  Bk.whisper:SetPoint("LEFT", Bk.auto, "RIGHT", 60, 0)
  Bk.status = self:Font(left, 11, C.gold)
  Bk.status:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 14, 70)
  Bk.status:SetWidth(452)

  -- rechte Spalte: Bank-Einstellungen
  local right = self:Panel(p, 0, 0)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
  right:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  local rt = self:Font(right, 14, C.gold, UI.FONT_TITLE)
  rt:SetPoint("TOPLEFT", right, "TOPLEFT", 12, -10)
  self:Loc(rt, "BANK_SETTINGS_TITLE")
  self:HLine(right, -30, 10, -10, C.brass, 0.9)
  Bk.info = self:Font(right, 11, C.text)
  Bk.info:SetPoint("TOPLEFT", right, "TOPLEFT", 14, -40)
  Bk.info:SetWidth(232)
  Bk.info:SetHeight(120)
  Bk.info:SetJustifyV("TOP")
  Bk.rankFs = self:Font(right, 10, C.muted)
  Bk.rankFs:SetPoint("TOPLEFT", right, "TOPLEFT", 14, -142)
  Bk.rankFs:SetWidth(232)
  Bk.rankFs:SetHeight(24)
  Bk.rankFs:SetJustifyV("TOP")
  local scanY = -170
  local scan = self:Button(right, 236, 24, "BTN_SCAN_SEND", function()
    BB:UpdateSnapshot(true)
    BB:Print(T("MSG_SNAPSHOT_SENT"))
  end, "primary")
  scan:SetPoint("TOPLEFT", right, "TOPLEFT", 12, scanY)
  local sync = self:Button(right, 236, 22, "BTN_SYNC", function()
    BB:SendHello()
    BB:Print(T("MSG_SYNC"))
  end)
  sync:SetPoint("TOPLEFT", scan, "BOTTOMLEFT", 0, -6)
  local unhide = self:Button(right, 236, 22, "BTN_UNHIDE", function()
    BananaBankDB.hidden = {}
    BB:Print(T("MSG_UNHIDDEN"))
    UI:Refresh()
  end)
  unhide:SetPoint("TOPLEFT", sync, "BOTTOMLEFT", 0, -6)
  local remove = self:Button(right, 236, 22, "BTN_REMOVE_BANK", function() BB:SetBank(false) end, "danger")
  remove:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 12, 14)
  local tip = self:Font(right, 10, C.muted)
  tip:SetPoint("BOTTOMLEFT", remove, "TOPLEFT", 2, 10)
  tip:SetWidth(232)
  self:Loc(tip, "BANK_TIP")
end

function UI:CheckCode()
  local Bk = self.bank
  local parsed, err = BB:ParseCode(Bk.codeBox:GetText())
  if not parsed then
    Bk.current = nil
    Bk.error = err
    self:Refresh()
    return
  end
  Bk.error = nil
  Bk.current = BB:ImportRequest(parsed)
  Bk.codeBox:SetText("")
  self:Refresh()
end

function UI:RefreshBank()
  if not self.bank then return end
  local Bk = self.bank
  local r = Bk.current
  if r and not BananaBankDB.reqs[r.id] then r = nil end
  Bk.current = r

  local banks = {}
  for name in pairs(BananaBankDB.banks) do table.insert(banks, name) end
  table.sort(banks)
  local snap = BananaBankDB.snaps[BB:Me()]
  Bk.info:SetText(string.format(T("BANK_INFO"),
    BB:Me(), table.concat(banks, ", "),
    snap and BB.Date(snap.ts) or "-",
    snap and BB.Count(snap.items) or 0,
    BB.Money(GetMoney()),
    BB.bankOpen and T("YES") or T("NO"),
    BB.mailOpen and T("YES") or T("NO")))

  if BB:MayBeBank(BB:Me()) then
    Bk.rankFs:SetText(string.format(T("BANK_RANK_OK"), BB.BANK_RANK_LABEL))
    Bk.rankFs:SetTextColor(C.green[1], C.green[2], C.green[3])
  else
    Bk.rankFs:SetText(string.format(T("BANK_RANK_BAD"), BB.BANK_RANK_LABEL))
    Bk.rankFs:SetTextColor(C.red[1], C.red[2], C.red[3])
  end

  if not r then
    for i = 1, BANK_ROWS do Bk.rows[i]:Hide() end
    if Bk.error then Bk.head:SetText("|cffff5040" .. T(Bk.error) .. "|r") else Bk.head:SetText(T("BANK_NO_REQUEST")) end
    Bk.hint:Show()
    Bk.confirm:SetOn(false)
    Bk.reject:SetOn(false)
    Bk.fetch:SetOn(false)
    Bk.send:SetOn(false)
    Bk.send.fs:SetText(T("BTN_SEND"))
    Bk.status:SetText("")
    return
  end
  Bk.hint:Hide()
  local st = BB:ReqState(r)
  local sc = UI.STATUS_COLOR[st] or C.muted
  Bk.head:SetText(string.format(T("BANK_REQ_HEAD"), r.id, r.p) .. "  |cff" ..
    string.format("%02x%02x%02x", sc[1] * 255, sc[2] * 255, sc[3] * 255) .. statusText(st) .. "|r")

  local ids = {}
  for id in pairs(r.items) do table.insert(ids, id) end
  table.sort(ids)
  local shortage = false
  for i = 1, BANK_ROWS do
    local row = Bk.rows[i]
    local id = ids[i]
    if id then
      local n, q, t = BB:ItemInfo(id)
      row.ic.id = id
      row.ic.icon:SetTexture(BB.FullTex(t))
      row.ic:SetQuality(q)
      local qc = BB.QUALITY_COLOR[q or 1] or BB.QUALITY_COLOR[1]
      row.name:SetText(n)
      row.name:SetTextColor(qc[1], qc[2], qc[3])
      local want = r.items[id]
      local sent = (r.sent and r.sent[id]) or 0
      local here = BB:LocalCount(id)
      row.want:SetText(want)
      row.sent:SetText(sent)
      row.here:SetText(here)
      if here < want - sent then
        row.here:SetTextColor(C.red[1], C.red[2], C.red[3])
        shortage = true
      else
        row.here:SetTextColor(C.green[1], C.green[2], C.green[3])
      end
      row:Show()
    else
      row:Hide()
    end
  end

  local p = BB.prep
  local prepHere = p and p.r == r
  Bk.confirm:SetOn(st == "open")
  Bk.reject:SetOn(st == "open" or st == "confirmed" or st == "expired")
  Bk.fetch:SetOn(st == "confirmed" and not BB.job)
  Bk.send:SetOn(prepHere and BB.mailOpen and not p.sending)
  if prepHere then
    Bk.send.fs:SetText(string.format(T("BTN_SEND_N"), p.idx, getn(p.slots)))
  else
    Bk.send.fs:SetText(T("BTN_SEND"))
  end

  local status
  if BB.job and BB.job.r == r then status = T("BANK_ST_FETCHING")
  elseif prepHere and not BB.mailOpen then status = T("BANK_ST_GO_MAILBOX")
  elseif prepHere then
    status = string.format(T("BANK_ST_READY"), getn(p.slots) - p.idx + 1)
    local codSum = 0
    for i = p.idx, getn(p.slots) do codSum = codSum + BB:MailCod(p.slots[i]) end
    if codSum > 0 then status = status .. "  " .. string.format(T("BANK_ST_COD"), BB.Money(codSum)) end
  elseif st == "confirmed" and not BB.bankOpen then status = T("BANK_ST_GO_BANK")
  elseif st == "confirmed" then status = T("BANK_ST_FETCH")
  elseif st == "open" then status = shortage and T("BANK_ST_SHORT") or T("BANK_ST_CONFIRM")
  elseif st == "sent" then status = T("BANK_ST_DONE")
  else status = "" end
  Bk.status:SetText(status)
end

-- ------------------------------------------------------------
-- Versandhelfer am Briefkasten
-- ------------------------------------------------------------
function UI:BuildMailHelper()
  if not MailFrame then return end
  local m = CreateFrame("Frame", "BananaBankMailHelper", MailFrame)
  self.mail = m
  m:SetWidth(230)
  m:SetHeight(150)
  m:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", -34, -14)
  m:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 7, right = 7, top = 7, bottom = 7 },
  })
  m:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.97)
  m:Hide()
  local logo = m:CreateTexture(nil, "OVERLAY")
  logo:SetTexture(UI.MEDIA .. "Logo64")
  logo:SetWidth(44)
  logo:SetHeight(44)
  logo:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -8)
  local t = self:Font(m, 16, C.gold, UI.FONT_TITLE)
  t:SetPoint("TOPLEFT", m, "TOPLEFT", 60, -14)
  t:SetText("BananaBank")
  m.line1 = self:Font(m, 11, C.text)
  m.line1:SetPoint("TOPLEFT", m, "TOPLEFT", 60, -34)
  m.line1:SetWidth(160)
  m.line1:SetHeight(13)
  m.line2 = self:Font(m, 10, C.muted)
  m.line2:SetPoint("TOPLEFT", m, "TOPLEFT", 14, -64)
  m.line2:SetWidth(204)
  m.line2:SetHeight(28)
  m.line2:SetJustifyV("TOP")
  m.send = self:Button(m, 204, 24, "BTN_SEND", function()
    BB:SendNextMail()
    UI:Refresh()
  end, "primary")
  m.send:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 13, 32)
  m.auto = self:Check(m, "OPT_AUTO_MAIL", function() return BananaBankDB.auto end, function(v) BananaBankDB.auto = v end)
  m.auto:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 14, 12)
end

function UI:RefreshMailHelper()
  local m = self.mail
  if not m then return end
  if not BB:BankActive() or not BB.mailOpen then
    m:Hide()
    return
  end
  local p = BB.prep
  local confirmed = 0
  for _, r in pairs(BananaBankDB.reqs) do
    if BB:ReqState(r) == "confirmed" then confirmed = confirmed + 1 end
  end
  if not p and confirmed == 0 then
    m:Hide()
    return
  end
  m:Show()
  m.auto.Update()
  if p then
    local e = p.slots[p.idx]
    m.line1:SetText(string.format(T("MAIL_TO"), p.r.p))
    if e then
      local txt = string.format(T("MAIL_NEXT"), p.idx, getn(p.slots), e.c, BB:ColoredName(e.id))
      local cod = BB:MailCod(e)
      if cod > 0 then txt = txt .. "\n" .. string.format(T("MAIL_COD"), BB.Money(cod)) end
      m.line2:SetText(txt)
    else
      m.line2:SetText("")
    end
    m.send.fs:SetText(string.format(T("BTN_SEND_N"), p.idx, getn(p.slots)))
    m.send:SetOn(not p.sending and e ~= nil)
  else
    m.line1:SetText(string.format(T("MAIL_CONFIRMED_N"), confirmed))
    m.line2:SetText(T("MAIL_FETCH_FIRST"))
    m.send.fs:SetText(T("BTN_SEND"))
    m.send:SetOn(false)
  end
end
