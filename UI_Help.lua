-- BananaBank UI Teil 8: Anleitung als Slideshow (Knopf "?" oben rechts)

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.helpModule = true

-- Abschnitte: Mitglieder und Bank/Offiziere. Texte stehen in der Locale als HLP_<sec><n>_T/H/B/F,
-- die Ablauf-Kaesten als HLP_<sec><n>_A1.._A4. Spaeter kann je Slide ein echter Screenshot
-- (Media\help_<sec><n>) ueber BB.HELP_IMG[<sec><n>] eingehaengt werden.
local SECTIONS = {
  { key = "M", count = 7, steps = { 4, 4, 4, 4, 3, 4, 3 } },
  { key = "B", count = 5, steps = { 3, 4, 3, 4, 4 } },
}
BB.HELP_IMG = BB.HELP_IMG or {}

local BOX_W, BOX_H = 118, 56

function UI:BuildHelp()
  if self.helpWin then return end
  local f = CreateFrame("Frame", "BananaBankHelp", UIParent)
  self.helpWin = f
  f:SetWidth(640)
  f:SetHeight(430)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:EnableMouseWheel(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(0.015, 0.025, 0.06, 1)
  f:Hide()
  tinsert(UISpecialFrames, "BananaBankHelp")
  f.sec, f.n = 1, 1

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  f.title = self:Font(f, 20, C.gold, UI.FONT_TITLE)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
  self:Loc(f.title, "HLP_TITLE")
  f.chips = {}
  for i = 1, getn(SECTIONS) do
    local chip = self:Chip(f, 150, "HLP_SEC_" .. SECTIONS[i].key, function()
      f.sec = i
      f.n = 1
      UI:RefreshHelp()
    end)
    chip:SetPoint("TOPLEFT", f, "TOPLEFT", 26 + (i - 1) * 156, -52)
    f.chips[i] = chip
  end
  self:GlowLine(f, -78, 20, -20)

  f.step = self:Font(f, 10, C.muted)
  f.step:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -88)
  f.step:SetWidth(580)
  f.step:SetHeight(12)
  f.head = self:Font(f, 18, C.gold)
  f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -104)
  f.head:SetWidth(580)
  f.head:SetHeight(22)

  -- Bildflaeche: Ablauf-Kaesten oder ein Screenshot
  local art = CreateFrame("Frame", nil, f)
  art:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -134)
  art:SetWidth(584)
  art:SetHeight(130)
  art:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  art:SetBackdropColor(0.06, 0.09, 0.19, 1)
  art:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 0.9)
  f.art = art
  f.img = art:CreateTexture(nil, "ARTWORK")
  f.img:SetPoint("TOPLEFT", art, "TOPLEFT", 4, -4)
  f.img:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", -4, 4)
  f.img:Hide()
  f.boxes = {}
  f.arrows = {}
  for i = 1, 4 do
    local b = CreateFrame("Frame", nil, art)
    b:SetWidth(BOX_W)
    b:SetHeight(BOX_H)
    b:SetBackdrop({
      bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 10,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b:SetBackdropColor(0.10, 0.14, 0.30, 1)
    b:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.9)
    b.num = self:Font(b, 10, C.goldDim)
    b.num:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -5)
    b.num:SetText(i)
    b.fs = self:Font(b, 11, { 1, 1, 1 })
    b.fs:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -17)
    b.fs:SetWidth(BOX_W - 16)
    b.fs:SetHeight(34)
    b.fs:SetJustifyV("TOP")
    f.boxes[i] = b
    local a = self:Font(art, 22, C.gold)
    a:SetText(">")
    f.arrows[i] = a
  end

  f.body = self:Font(f, 12, { 0.88, 0.90, 0.96 })
  f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -276)
  f.body:SetWidth(584)
  f.body:SetHeight(62)
  f.body:SetJustifyV("TOP")
  f.foot = self:Font(f, 11, C.goldDim)
  f.foot:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -344)
  f.foot:SetWidth(584)
  f.foot:SetHeight(28)
  f.foot:SetJustifyV("TOP")

  f.prev = self:Button(f, 110, 24, "HLP_PREV", function() UI:HelpGo(-1) end)
  f.prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 22)
  f.next = self:Button(f, 110, 24, "HLP_NEXT", function() UI:HelpGo(1) end, "primary")
  f.next:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
  f.dots = {}
  for i = 1, 7 do
    local d = CreateFrame("Button", nil, f)
    d:SetWidth(14)
    d:SetHeight(14)
    d.t = d:CreateTexture(nil, "ARTWORK")
    d.t:SetTexture(WHITE)
    d.t:SetWidth(9)
    d.t:SetHeight(9)
    d.t:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.index = i
    d:SetScript("OnClick", function()
      f.n = this.index
      UI:RefreshHelp()
    end)
    f.dots[i] = d
  end
  f:SetScript("OnMouseWheel", function() UI:HelpGo(-arg1) end)
end

function UI:HelpGo(delta)
  local f = self.helpWin
  local sec = SECTIONS[f.sec]
  local n = f.n + delta
  if n < 1 then
    if f.sec > 1 then f.sec = f.sec - 1 n = SECTIONS[f.sec].count else n = 1 end
  elseif n > sec.count then
    if f.sec < getn(SECTIONS) then f.sec = f.sec + 1 n = 1 else n = sec.count end
  end
  f.n = n
  self:RefreshHelp()
end

function UI:RefreshHelp()
  local f = self.helpWin
  if not f then return end
  local sec = SECTIONS[f.sec]
  local n = f.n
  local pre = "HLP_" .. sec.key .. n
  for i = 1, getn(f.chips) do f.chips[i]:SetActive(i == f.sec) end
  f.step:SetText(string.format(T("HLP_STEP"), n, sec.count) .. "  -  " .. T(pre .. "_T"))
  f.head:SetText(T(pre .. "_H"))
  f.body:SetText(T(pre .. "_B"))
  f.foot:SetText(T(pre .. "_F"))
  local img = BB.HELP_IMG[sec.key .. n]
  local cnt = sec.steps[n]
  if img then
    f.img:SetTexture(img)
    f.img:Show()
    for i = 1, 4 do f.boxes[i]:Hide() f.arrows[i]:Hide() end
  else
    f.img:Hide()
    local gap = 22
    local total = cnt * BOX_W + (cnt - 1) * gap
    local x0 = (584 - total) / 2
    for i = 1, 4 do
      local b = f.boxes[i]
      if i <= cnt then
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f.art, "TOPLEFT", x0 + (i - 1) * (BOX_W + gap), -37)
        b.fs:SetText(T(pre .. "_A" .. i))
        b:Show()
      else
        b:Hide()
      end
      local a = f.arrows[i]
      if i < cnt then
        a:ClearAllPoints()
        a:SetPoint("TOPLEFT", f.art, "TOPLEFT", x0 + i * BOX_W + (i - 1) * gap + 5, -52)
        a:Show()
      else
        a:Hide()
      end
    end
  end
  -- Punkte
  local startX = 320 - (sec.count * 16) / 2
  for i = 1, 7 do
    local d = f.dots[i]
    if i <= sec.count then
      d:ClearAllPoints()
      d:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", startX + (i - 1) * 16, 28)
      if i == n then d.t:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1) else d.t:SetVertexColor(0.30, 0.34, 0.50, 1) end
      d:Show()
    else
      d:Hide()
    end
  end
  if f.sec == 1 and n == 1 then f.prev:Hide() else f.prev:Show() end
  if f.sec == getn(SECTIONS) and n == sec.count then f.next:Hide() else f.next:Show() end
end

function UI:ToggleHelp()
  self:BuildHelp()
  local f = self.helpWin
  if f:IsVisible() then f:Hide() return end
  f:Show()
  self:RefreshHelp()
end

function UI:BuildHelpButton(parent)
  local b = self:Button(parent, 22, 18, "?", function() UI:ToggleHelp() end, "flat")
  b.fs:SetTextColor(1, 0.6, 0.18)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("HLP_BTN_TIP"), 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- beim allerersten Oeffnen des Fensters einmal von selbst zeigen
function UI:MaybeShowHelp()
  local db = BananaBankDB
  if not db or db.helpSeen then return end
  db.helpSeen = true
  self:ToggleHelp()
end
