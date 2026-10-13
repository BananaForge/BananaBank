-- BananaBank UI Teil 7: Typ-Filter im Bestand (Rezepte nach Beruf, BOE nach Slot, Materialien)

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.filterModule = true

local ROW_H = 18
local VISIBLE = 14

local function specOf(S)
  return S.type and BB:FindTypeFilter(S.type) or nil
end

-- sichtbare Eintraege (Ueberschriften + Filter) in Menue-Reihenfolge
local function entries()
  return BB.TYPE_FILTERS
end

function UI:RefreshTypeButton()
  local S = self.stock
  if not S or not S.typeBtn then return end
  S.typeBtn:ClearAllPoints()
  if BB:IsBank() then
    S.typeBtn:SetPoint("TOPLEFT", S.typeBtn:GetParent(), "TOPLEFT", 272, -27)
  else
    S.typeBtn:SetPoint("TOPLEFT", S.typeBtn:GetParent(), "TOPLEFT", 126, -27)
  end
  local spec = specOf(S)
  if spec and spec.key ~= "all" then
    local name = T(spec.label)
    if spec.grp then name = T(spec.grp) .. ": " .. name end
    S.typeBtn.fs:SetText(string.format(T("TF_BTN"), name))
    S.typeBtn.fs:SetTextColor(1, 0.95, 0.7)
    S.typeBtn:SetBackdropColor(0.42, 0.30, 0.05, 0.98)
  else
    S.typeBtn.fs:SetText(string.format(T("TF_BTN"), T("TF_ALL")))
    S.typeBtn.fs:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    S.typeBtn:SetBackdropColor(0.05, 0.07, 0.14, 0.95)
  end
end

function UI:BuildTypeButton(p)
  local S = self.stock
  S.type = "all"
  S.typeBtn = self:Button(p, 170, 18, "", function() UI:ToggleTypeMenu() end, "flat")
  S.typeBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 126, -27)
end

function UI:CloseTypeMenu()
  if not self.tmenu then return end
  self.tmenu:Hide()
  self.tmenu.catch:Hide()
end

function UI:RefreshTypeMenu()
  local m = self.tmenu
  if not m then return end
  local list = entries()
  local max = getn(list) - VISIBLE
  if max < 0 then max = 0 end
  if m.offset > max then m.offset = max end
  if m.offset < 0 then m.offset = 0 end
  local S = self.stock
  for i = 1, VISIBLE do
    local row = m.rows[i]
    local e = list[m.offset + i]
    row.entry = e
    if not e then
      row:Hide()
    else
      row:Show()
      if e.header then
        row.fs:SetText(T(e.header))
        row.fs:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        row.fs:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.sel:Hide()
        row.hl:Hide()
      else
        row.fs:SetText(T(e.label))
        row.fs:SetPoint("LEFT", row, "LEFT", e.grp and 18 or 10, 0)
        row.hl:Show()
        if S.type == e.key then
          row.fs:SetTextColor(1, 0.95, 0.7)
          row.sel:Show()
        else
          row.fs:SetTextColor(0.88, 0.90, 0.96)
          row.sel:Hide()
        end
      end
    end
  end
end

function UI:BuildTypeMenu()
  if self.tmenu then return end
  local catch = CreateFrame("Button", nil, UIParent)
  catch:SetAllPoints(UIParent)
  catch:SetFrameStrata("DIALOG")
  catch:Hide()
  catch:SetScript("OnClick", function() UI:CloseTypeMenu() end)
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetWidth(200)
  m:SetHeight(VISIBLE * ROW_H + 12)
  m:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  m:SetBackdropColor(0.015, 0.025, 0.06, 1)
  m:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
  m:SetFrameStrata("FULLSCREEN_DIALOG")
  m:EnableMouse(true)
  m:EnableMouseWheel(true)
  m:SetScript("OnMouseWheel", function()
    m.offset = m.offset - arg1 * 3
    UI:RefreshTypeMenu()
  end)
  m:Hide()
  m.catch = catch
  m.offset = 0
  m.rows = {}
  for i = 1, VISIBLE do
    local row = CreateFrame("Button", nil, m)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -6 - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", m, "TOPRIGHT", -6, -6 - (i - 1) * ROW_H)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function()
      m.offset = m.offset - arg1 * 3
      UI:RefreshTypeMenu()
    end)
    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetTexture(WHITE)
    row.sel:SetAllPoints(row)
    row.sel:SetVertexColor(1, 0.82, 0.26, 0.25)
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetTexture(WHITE)
    row.hl:SetAllPoints(row)
    row.hl:SetVertexColor(1, 0.82, 0.3, 0.14)
    row.fs = self:Font(row, 11, { 1, 1, 1 })
    row.fs:SetWidth(170)
    row.fs:SetHeight(14)
    row:SetScript("OnClick", function()
      local e = this.entry
      if not e or e.header then return end
      PlaySound("igMainMenuOptionCheckBoxOn")
      UI.stock.type = e.key
      UI.stock.page = 1
      UI:CloseTypeMenu()
      UI:RefreshStock()
    end)
    m.rows[i] = row
  end
  self.tmenu = m
end

function UI:ToggleTypeMenu()
  self:BuildTypeMenu()
  local m = self.tmenu
  if m:IsVisible() then
    self:CloseTypeMenu()
    return
  end
  local S = self.stock
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", S.typeBtn, "BOTTOMLEFT", 0, -2)
  m.offset = 0
  -- gewaehlten Eintrag in Sicht scrollen
  local list = entries()
  for i = 1, getn(list) do
    if list[i].key == S.type and i > VISIBLE then m.offset = i - VISIBLE + 2 end
  end
  m.catch:Show()
  m:Show()
  self:RefreshTypeMenu()
end
