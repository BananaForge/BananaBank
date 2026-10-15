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

-- ------------------------------------------------------------
-- Bestand im Auktionshaus-Stil: Kategorienbaum links, Ergebnisse nach Kategorien, Symbol- oder Listenansicht
-- ------------------------------------------------------------
local FONT = UI.FONT
local ICON, GAPX = 24, 3
local PER_ROW = 12
local V_ROW_H = 26
local V_ROWS = 12
local TREE_H = 18
local TREE_ROWS = 17

local function groupKey(entry)
  local k = entry.k or "other"
  if k == "recipe" or k == "boe" or k == "trade" then return k .. ":" .. (entry.s or "other") end
  return k
end

-- Reihenfolge der Gruppen in der Ergebnisliste
local GROUP_ORDER, GROUP_INDEX
local function groupOrder()
  if GROUP_ORDER then return GROUP_ORDER end
  GROUP_ORDER = {}
  local mats = { "cloth", "leather", "herb", "ore" }
  for i = 1, getn(mats) do table.insert(GROUP_ORDER, mats[i]) end
  for i = 1, getn(BB.TRADE_SUBS) do table.insert(GROUP_ORDER, "trade:" .. BB.TRADE_SUBS[i]) end
  table.insert(GROUP_ORDER, "trade:other")
  for i = 1, getn(BB.BOE_SUBS) do table.insert(GROUP_ORDER, "boe:" .. BB.BOE_SUBS[i]) end
  table.insert(GROUP_ORDER, "boe:other")
  for i = 1, getn(BB.RECIPE_SUBS) do table.insert(GROUP_ORDER, "recipe:" .. BB.RECIPE_SUBS[i]) end
  table.insert(GROUP_ORDER, "recipe:other")
  local rest = { "potion", "bag", "other" }
  for i = 1, getn(rest) do table.insert(GROUP_ORDER, rest[i]) end
  GROUP_INDEX = {}
  for i = 1, getn(GROUP_ORDER) do GROUP_INDEX[GROUP_ORDER[i]] = i end
  return GROUP_ORDER
end

local function groupLabel(key)
  local _, _, k, sub = string.find(key, "^(%a+):(%a+)$")
  if k == "recipe" then return T("TF_H_RECIPES") .. "  -  " .. T("SUB_" .. string.upper(sub)) end
  if k == "boe" then return T("TF_H_BOE") .. "  -  " .. T("SUB_" .. string.upper(sub)) end
  if k == "trade" then return T("CAT_TRADE") .. "  -  " .. T("SUB_" .. string.upper(sub)) end
  return BB:CatName(key)
end

-- Baum: oberste Ebene, Rezepte und BOE klappen ihre Unterpunkte auf
local function treeNodes(cur)
  local out = {}
  local list = BB.TYPE_FILTERS
  for i = 1, getn(list) do
    local e = list[i]
    if e.key and not e.grp then
      local isParent = (e.key == "rec" or e.key == "boe" or e.key == "mat")
      table.insert(out, { key = e.key, label = e.label, depth = 0, parent = isParent })
      if isParent then
        local open = (cur == e.key) or (string.sub(cur or "", 1, string.len(e.key) + 1) == e.key .. ":")
        if open then
          for j = 1, getn(list) do
            if list[j].key and list[j].grp and string.sub(list[j].key, 1, string.len(e.key) + 1) == e.key .. ":" then
              table.insert(out, { key = list[j].key, label = list[j].label, depth = 1 })
            end
          end
        end
      end
    end
  end
  return out
end

local function smallSlot(parent)
  local s = UI:Slot(parent, ICON)
  s.count:SetFont(FONT, 9, "OUTLINE")
  s.badge:SetFont(FONT, 8, "OUTLINE")
  s.res:SetFont(FONT, 8, "OUTLINE")
  s.glow:SetWidth(32)
  s.glow:SetHeight(32)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s:SetScript("OnClick", function() UI:OnSlotClick(this, arg1) end)
  s:SetScript("OnEnter", function() UI:OnSlotEnter(this) end)
  s:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return s
end

function UI:BuildStockView(p)
  local S = self.stock
  S.treeOffset = 0

  -- Ansichtswahl
  S.viewChips = {}
  local vdefs = { { "SV_ICONS", "icons" }, { "SV_LIST", "list" } }
  for i = 1, getn(vdefs) do
    local key = vdefs[i][2]
    local chip = self:Chip(p, 74, vdefs[i][1], function()
      S.view = key
      UI:RefreshStock()
    end)
    chip.key = key
    chip:SetPoint("TOPLEFT", p, "TOPLEFT", 280 + (i - 1) * 78, -27)
    S.viewChips[i] = chip
  end

  -- Kategorienbaum
  local tree = self:Panel(p, 132, 0)
  tree:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -52)
  tree:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 26)
  tree:EnableMouseWheel(true)
  tree:SetScript("OnMouseWheel", function()
    S.treeOffset = S.treeOffset - arg1 * 3
    UI:RefreshTree()
  end)
  S.tree = tree
  S.treeRows = {}
  for i = 1, TREE_ROWS do
    local b = CreateFrame("Button", nil, tree)
    b:SetHeight(TREE_H - 1)
    b:SetPoint("TOPLEFT", tree, "TOPLEFT", 4, -5 - (i - 1) * TREE_H)
    b:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -4, -5 - (i - 1) * TREE_H)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function()
      S.treeOffset = S.treeOffset - arg1 * 3
      UI:RefreshTree()
    end)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetTexture(WHITE)
    b.sel:SetAllPoints(b)
    b.sel:SetVertexColor(1, 0.82, 0.26, 0.28)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetAllPoints(b)
    hl:SetVertexColor(1, 0.82, 0.3, 0.14)
    b.fs = self:Font(b, 11, { 0.88, 0.90, 0.96 })
    b.fs:SetHeight(14)
    b:SetScript("OnClick", function()
      if not this.node then return end
      PlaySound("igMainMenuOptionCheckBoxOn")
      if S.type == this.node.key and this.node.parent then S.type = "all" else S.type = this.node.key end
      UI:RefreshStock()
    end)
    S.treeRows[i] = b
  end

  -- Ergebnisfeld
  local res = self:Panel(p, 0, 0)
  res:SetPoint("TOPLEFT", p, "TOPLEFT", 138, -52)
  res:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -238, 26)
  S.resPanel = res
  local sf = CreateFrame("ScrollFrame", "BananaBankStockScroll", res, "FauxScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", res, "TOPLEFT", 0, -3)
  sf:SetPoint("BOTTOMRIGHT", res, "BOTTOMRIGHT", -26, 3)
  sf:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(V_ROW_H, function() UI:RefreshStockView() end) end)
  sf.offset = 0
  S.sf = sf
  local function wheel()
    local sb = getglobal("BananaBankStockScrollScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * V_ROW_H * 2) end
  end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", wheel)
  res:EnableMouseWheel(true)
  res:SetScript("OnMouseWheel", wheel)

  S.vrows = {}
  for i = 1, V_ROWS do
    local r = CreateFrame("Frame", nil, res)
    r:SetHeight(V_ROW_H)
    r:SetPoint("TOPLEFT", res, "TOPLEFT", 6, -4 - (i - 1) * V_ROW_H)
    r:SetPoint("TOPRIGHT", res, "TOPRIGHT", -28, -4 - (i - 1) * V_ROW_H)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", wheel)
    r.hfs = self:Font(r, 12, C.gold)
    r.hfs:SetPoint("LEFT", r, "LEFT", 2, -2)
    r.hfs:SetWidth(330)
    r.hfs:SetHeight(14)
    r.hline = r:CreateTexture(nil, "ARTWORK")
    r.hline:SetTexture(WHITE)
    r.hline:SetHeight(1)
    r.hline:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 2)
    r.hline:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 2)
    r.hline:SetVertexColor(C.brass[1], C.brass[2], C.brass[3], 0.6)
    r.slots = {}
    for j = 1, PER_ROW do
      local s = smallSlot(r)
      s:SetPoint("LEFT", r, "LEFT", (j - 1) * (ICON + GAPX), 0)
      r.slots[j] = s
    end
    -- Listenzeile: Klickflaeche ueber die ganze Zeile
    r.lbtn = CreateFrame("Button", nil, r)
    r.lbtn:SetAllPoints(r)
    r.lbtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.lbtn:SetScript("OnClick", function() UI:OnSlotClick(this, arg1) end)
    r.lbtn:SetScript("OnEnter", function() UI:OnSlotEnter(this) end)
    r.lbtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.lbtn:EnableMouseWheel(true)
    r.lbtn:SetScript("OnMouseWheel", wheel)
    local lhl = r.lbtn:CreateTexture(nil, "HIGHLIGHT")
    lhl:SetTexture(WHITE)
    lhl:SetAllPoints(r.lbtn)
    lhl:SetVertexColor(1, 0.82, 0.3, 0.12)
    r.lname = self:Font(r, 11, C.text)
    r.lname:SetPoint("LEFT", r, "LEFT", ICON + 8, 0)
    r.lname:SetWidth(168)
    r.lname:SetHeight(13)
    r.lcnt = self:Font(r, 11, C.gold)
    r.lcnt:SetPoint("LEFT", r, "LEFT", ICON + 182, 0)
    r.lcnt:SetWidth(58)
    r.lcnt:SetJustifyH("RIGHT")
    r.lprice = self:Font(r, 10, C.muted)
    r.lprice:SetPoint("LEFT", r, "LEFT", ICON + 244, 0)
    r.lprice:SetWidth(76)
    r.lprice:SetJustifyH("RIGHT")
    S.vrows[i] = r
  end
  S.empty = self:Font(res, 13, C.muted)
  S.empty:SetPoint("CENTER", res, "CENTER", -10, 0)
  S.empty:SetJustifyH("CENTER")
  S.empty:SetWidth(320)
end

function UI:RefreshTree()
  local S = self.stock
  if not S or not S.treeRows then return end
  local nodes = treeNodes(S.type)
  local max = getn(nodes) - TREE_ROWS
  if max < 0 then max = 0 end
  if S.treeOffset > max then S.treeOffset = max end
  if S.treeOffset < 0 then S.treeOffset = 0 end
  for i = 1, TREE_ROWS do
    local b = S.treeRows[i]
    local n = nodes[S.treeOffset + i]
    b.node = n
    if not n then
      b:Hide()
    else
      b:Show()
      local on = (S.type == n.key)
      b.fs:ClearAllPoints()
      b.fs:SetPoint("LEFT", b, "LEFT", 4 + n.depth * 12, 0)
      b.fs:SetWidth(112 - n.depth * 12)
      local label = T(n.label)
      if n.parent then
        local open = (S.type == n.key) or (string.sub(S.type or "", 1, string.len(n.key) + 1) == n.key .. ":")
        label = (open and "- " or "+ ") .. label
      end
      b.fs:SetText(label)
      if on then
        b.fs:SetTextColor(1, 0.95, 0.7)
        b.sel:Show()
      else
        b.fs:SetTextColor(0.88, 0.90, 0.96)
        b.sel:Hide()
      end
    end
  end
end

local function fillSlot(s, entry, basket)
  s.id = entry.id
  s.icon:SetTexture(BB.FullTex(entry.e.t))
  s:SetQuality(entry.e.q)
  if entry.avail > 0 then s.icon:SetVertexColor(1, 1, 1) else s.icon:SetVertexColor(0.35, 0.35, 0.35) end
  s.count:SetText(entry.avail > 1 and entry.avail or (entry.avail == 1 and "" or "0"))
  if entry.res > 0 then s.res:SetText(entry.res) else s.res:SetText("") end
  if basket[entry.id] then s.badge:SetText("x" .. basket[entry.id]) else s.badge:SetText("") end
  s:Show()
end

-- Zeilen der Ergebnisliste: Ueberschriften, Symbolzeilen oder Listenzeilen
local function buildRows(list, view)
  groupOrder()
  local groups, keys = {}, {}
  for i = 1, getn(list) do
    local key = groupKey(list[i])
    if not GROUP_INDEX[key] then key = "other" end
    if not groups[key] then groups[key] = {} table.insert(keys, key) end
    table.insert(groups[key], list[i])
  end
  table.sort(keys, function(a, b) return GROUP_INDEX[a] < GROUP_INDEX[b] end)
  local rows = {}
  for i = 1, getn(keys) do
    local g = groups[keys[i]]
    table.sort(g, function(a, b)
      if (a.e.q or 1) ~= (b.e.q or 1) then return (a.e.q or 1) > (b.e.q or 1) end
      return (a.e.n or "") < (b.e.n or "")
    end)
    table.insert(rows, { head = groupLabel(keys[i]) .. "  |cff9a9cb3(" .. getn(g) .. ")|r" })
    if view == "list" then
      for j = 1, getn(g) do table.insert(rows, { item = g[j] }) end
    else
      local j = 1
      while j <= getn(g) do
        local line = {}
        for k = j, math.min(j + PER_ROW - 1, getn(g)) do table.insert(line, g[k]) end
        table.insert(rows, { items = line })
        j = j + PER_ROW
      end
    end
  end
  return rows
end

function UI:RefreshStockView(list)
  local S = self.stock
  if not S or not S.vrows then return end
  if list then S.lastList = list else list = S.lastList or {} end
  -- Ansichtswahl: bei Mitgliedern ohne Bankwahl weiter links
  for i = 1, getn(S.viewChips) do
    S.viewChips[i]:SetActive(S.viewChips[i].key == S.view)
    S.viewChips[i]:ClearAllPoints()
    S.viewChips[i]:SetPoint("TOPLEFT", S.viewChips[i]:GetParent(), "TOPLEFT", (BB:IsBank() and 280 or 126) + (i - 1) * 78, -27)
  end
  if S.type ~= "all" and not BB:FindTypeFilter(S.type) then S.type = "all" end
  self:RefreshTree()
  -- bei geaenderten Suchkriterien wieder nach oben
  local sig = table.concat({ tostring(S.bank), tostring(S.type), S.filter, S.search, tostring(S.onlyAvail), S.view }, "|")
  if S.sig ~= sig then
    S.sig = sig
    local sb = getglobal("BananaBankStockScrollScrollBar")
    if sb then sb:SetValue(0) end
    S.sf.offset = 0
  end
  local rows = buildRows(list, S.view)
  local offset = 0
  S.busy = true
  if FauxScrollFrame_Update then FauxScrollFrame_Update(S.sf, getn(rows), V_ROWS, V_ROW_H) end
  offset = (FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(S.sf)) or S.sf.offset or 0
  S.busy = false
  local basket = BananaBankDB.basket
  for i = 1, V_ROWS do
    local r = S.vrows[i]
    local d = rows[offset + i]
    r.hfs:Hide()
    r.hline:Hide()
    r.lbtn:Hide()
    r.lname:SetText("")
    r.lcnt:SetText("")
    r.lprice:SetText("")
    for j = 1, PER_ROW do r.slots[j].id = nil r.slots[j]:Hide() end
    r.lbtn.id = nil
    if d then
      r:Show()
      if d.head then
        r.hfs:SetText(d.head)
        r.hfs:Show()
        r.hline:Show()
      elseif d.items then
        for j = 1, getn(d.items) do fillSlot(r.slots[j], d.items[j], basket) end
      else
        local e = d.item
        fillSlot(r.slots[1], e, basket)
        r.lbtn.id = e.id
        r.lbtn:Show()
        local qc = BB.QUALITY_COLOR[e.e.q or 1] or BB.QUALITY_COLOR[1]
        r.lname:SetText(e.e.n or "?")
        r.lname:SetTextColor(qc[1], qc[2], qc[3])
        local txt = tostring(e.avail)
        if e.res > 0 then txt = txt .. " |cffff8000(" .. e.res .. ")|r" end
        r.lcnt:SetText(txt)
        local u = BB:GetPrice(e.id)
        if u then r.lprice:SetText(BB.Money(u)) end
      end
    else
      r:Hide()
    end
  end
end
