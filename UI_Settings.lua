-- BananaBank UI Teil 9: Einstellungen (Zahnrad) und Hauptbank-Anzeige im Fensterkopf

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.settingsModule = true
UI.set = {}

local GEN_H, GUILD_H, BANK_H = 168, 108, 236
local RULES_H = 424

-- ------------------------------------------------------------
-- Kopf: Zahnrad und "Spenden an: <Hauptbank>"
-- ------------------------------------------------------------
function UI:BuildSettingsButton(parent)
  local b = self:Button(parent, 22, 18, nil, function() UI:ToggleSettings() end, "flat")
  local ic = b:CreateTexture(nil, "OVERLAY")
  ic:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  ic:SetWidth(14)
  ic:SetHeight(14)
  ic:SetPoint("CENTER", b, "CENTER", 0, 0)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("SET_BTN_TIP"), 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function UI:BuildMainBankLabel(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(240)
  b:SetHeight(16)
  b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -40)
  b.fs = self:Font(b, 12, C.gold)
  b.fs:SetPoint("RIGHT", b, "RIGHT", 0, 0)
  b.fs:SetJustifyH("RIGHT")
  b.fs:SetWidth(240)
  b.fs:SetHeight(14)
  b:SetScript("OnClick", function()
    UI:ChatInsert(BB:MainBank())
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("MAIN_TIP"), 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.mainLbl = b
  return b
end

function UI:RefreshMainBank()
  if not self.mainLbl then return end
  self.mainLbl.fs:SetText("|cff9a9cb3" .. T("MAIN_DONATE") .. "|r |cffffd100" .. BB:MainBank() .. "|r")
end

-- ------------------------------------------------------------
-- Einstellungsfenster
-- ------------------------------------------------------------
local function group(f, key)
  local g = CreateFrame("Frame", nil, f)
  g:SetWidth(430)
  local fs = UI:Font(g, 12, C.gold)
  fs:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
  UI:Loc(fs, key)
  UI:HLine(g, -16, 0, 0, C.brass, 0.7)
  return g
end

local function check(g, key, x, y, getter, setter, w)
  local c = UI:Check(g, key, getter, setter)
  c:SetPoint("TOPLEFT", g, "TOPLEFT", x, y)
  c:SetWidth(w or 200)
  return c
end

local function btn(g, key, x, y, w, fn)
  local b = UI:Button(g, w, 20, key, fn, "flat")
  b:SetPoint("TOPLEFT", g, "TOPLEFT", x, y)
  return b
end

function UI:BuildSettings()
  if self.setWin then return end
  local S = self.set
  local f = CreateFrame("Frame", "BananaBankSettings", UIParent)
  self.setWin = f
  f:SetWidth(470)
  f:SetHeight(400)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
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
  tinsert(UISpecialFrames, "BananaBankSettings")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  local title = self:Font(f, 20, C.gold, UI.FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
  self:Loc(title, "SET_TITLE")
  self:GlowLine(f, -50, 20, -20)
  S.tab = "gen"
  S.tabs = {}
  local tdefs = { { "SET_TAB_GEN", "gen" }, { "SET_TAB_RULES", "rules" } }
  for i = 1, getn(tdefs) do
    local key = tdefs[i][2]
    local chip = self:Chip(f, 120, tdefs[i][1], function()
      S.tab = key
      UI:RefreshSettings()
    end)
    chip:SetHeight(22)
    chip:SetPoint("TOPLEFT", f, "TOPLEFT", 26 + (i - 1) * 126, -56)
    chip.key = key
    S.tabs[i] = chip
  end

  -- Allgemein (alle)
  local g = group(f, "SET_SEC_GEN")
  S.gen = g
  g:SetHeight(GEN_H)
  local lang = self:Font(g, 11, C.text)
  lang:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -28)
  self:Loc(lang, "SET_LANG")
  S.langChips = {}
  local ldefs = { { "SET_LANG_AUTO", "auto" }, { "SET_LANG_DE", "deDE" }, { "SET_LANG_EN", "enUS" } }
  for i = 1, getn(ldefs) do
    local code = ldefs[i][2]
    local chip = self:Chip(g, 84, ldefs[i][1], function() UI:SetLanguage(code) end)
    chip.code = code
    chip:SetPoint("TOPLEFT", g, "TOPLEFT", 110 + (i - 1) * 88, -26)
    S.langChips[i] = chip
  end
  S.cMini = check(g, "SET_MINIMAP", 4, -52, function() return not BananaBankDB.minimap.hide end, function(v)
    BananaBankDB.minimap.hide = not v
    if v then UI.minimap:Show() else UI.minimap:Hide() end
  end)
  S.cTrack = check(g, "SET_TRACKER", 230, -52, function() return not BananaBankDB.qtrackerHidden end, function(v)
    if v == (BananaBankDB.qtrackerHidden and true or false) then UI:ToggleQuestTracker() end
  end)
  S.cDebug = check(g, "SET_DEBUG", 4, -74, function() return BananaBankDB.debug and true or false end, function(v)
    BananaBankDB.debug = v and true or nil
  end)
  btn(g, "SET_UNHIDE", 4, -104, 210, function()
    BananaBankDB.hidden = {}
    BB:Print(T("MSG_UNHIDDEN"))
    UI:Refresh()
  end)
  btn(g, "SET_STATUS", 220, -104, 140, function() BB:Status() end)
  btn(g, "SET_SUPPORT", 4, -132, 210, function() UI:ShowThanks() end)

  -- Gilde (Verwalter)
  g = group(f, "SET_SEC_GUILD")
  S.guild = g
  g:SetHeight(GUILD_H)
  local ml = self:Font(g, 11, C.text)
  ml:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -28)
  self:Loc(ml, "SET_MAIN")
  S.main = self:EditBox("BananaBankMainBank", g, 150)
  S.main:SetPoint("TOPLEFT", g, "TOPLEFT", 190, -23)
  S.main:SetMaxLetters(24)
  S.main:SetScript("OnEditFocusGained", function() S.mainFocus = true end)
  S.main:SetScript("OnEditFocusLost", function() S.mainFocus = false end)
  S.main:SetScript("OnEnterPressed", function() BB:SetMainBank(this:GetText()) this:ClearFocus() end)
  local save = self:Button(g, 80, 20, "SET_SAVE", function() BB:SetMainBank(S.main:GetText()) S.main:ClearFocus() end, "primary")
  save:SetPoint("TOPLEFT", g, "TOPLEFT", 346, -24)
  local hint = self:Font(g, 10, C.muted)
  hint:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -50)
  hint:SetWidth(420)
  hint:SetHeight(24)
  hint:SetJustifyV("TOP")
  self:Loc(hint, "SET_MAIN_HINT")
  btn(g, "SET_QLOG", 4, -80, 200, function() BB:PrintQuestLog("") end)
  btn(g, "SET_CREDIT", 210, -80, 210, function() BB:CreditQuestDeliveries() end)

  -- Bank-Char
  g = group(f, "SET_SEC_BANK")
  S.bank = g
  g:SetHeight(BANK_H)
  S.cBank = check(g, "SET_BANKMODE", 4, -26, function() return BB:IsBank() end, function(v)
    BB:SetBank(v)
    UI:RefreshSettings()
  end, 420)
  S.cCod = check(g, "SET_COD", 4, -48, function() return BananaBankDB.cod ~= false end, function(v)
    BananaBankDB.cod = v
  end, 420)
  S.cWhisper = check(g, "SET_WHISPER", 4, -70, function() return BananaBankDB.whisper ~= false end, function(v)
    BananaBankDB.whisper = v
  end, 420)
  btn(g, "SET_SCAN", 4, -98, 100, function() BB:UpdateSnapshot(true) end)
  btn(g, "SET_SYNC", 108, -98, 100, function()
    BB:SendHello()
    BB:Print(T("MSG_SYNC"))
  end)
  btn(g, "SET_AHSCAN", 212, -98, 100, function() BB:StartAHScan() end)
  btn(g, "SET_BOOK", 316, -98, 108, function() UI:OpenBookDialog() end)
  btn(g, "SET_MAILLOG", 4, -124, 200, function() BB:PrintMailLog() end)
  btn(g, "SET_RECON", 210, -124, 214, function() BB:PrintReconcile("") end)
  S.cAuto = check(g, "SET_AUTOBANK", 4, -152, function() return BananaBankDB.autoBank ~= false end, function(v)
    BananaBankDB.autoBank = v
  end, 420)
  local ah = self:Font(g, 10, C.muted)
  ah:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -174)
  ah:SetWidth(420)
  ah:SetHeight(24)
  ah:SetJustifyV("TOP")
  self:Loc(ah, "SET_AUTOBANK_HINT")
  local al = self:Font(g, 11, C.text)
  al:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -208)
  self:Loc(al, "SET_AGE")
  S.age = self:EditBox("BananaBankPriceAge", g, 44)
  S.age:SetPoint("TOPLEFT", g, "TOPLEFT", 290, -203)
  S.age:SetMaxLetters(3)
  S.age:SetNumeric(true)
  local function saveAge()
    local n = tonumber(S.age:GetText())
    if n and n >= 0 and n <= 365 then BananaBankDB.priceMaxAge = math.floor(n) end
    S.ageFocus = false
    S.age:SetText(tostring(BB:PriceMaxAgeDays()))
  end
  S.age:SetScript("OnEditFocusGained", function() S.ageFocus = true end)
  S.age:SetScript("OnEditFocusLost", saveAge)
  S.age:SetScript("OnEnterPressed", function() saveAge() this:ClearFocus() end)
  local ad = self:Font(g, 11, C.muted)
  ad:SetPoint("LEFT", S.age, "RIGHT", 6, 0)
  self:Loc(ad, "SET_AGE_DAYS")

  -- Regeln (Rang und Qualitaet)
  g = group(f, "SET_SEC_RULES")
  S.rules = g
  g:SetHeight(RULES_H)
  S.rlStatus = self:Font(g, 10, C.orange)
  S.rlStatus:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -22)
  S.rlStatus:SetWidth(420)
  S.rlStatus:SetHeight(28)
  S.rlStatus:SetJustifyV("TOP")
  S.rlRows = {}
  local rdefs = { { "req", "RL_REQ" }, { "q2", "RL_Q2" }, { "q3", "RL_Q3" }, { "q4", "RL_Q4" } }
  for i = 1, getn(rdefs) do
    local key = rdefs[i][1]
    local lbl = self:Font(g, 11, C.text)
    lbl:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -60 - (i - 1) * 28)
    self:Loc(lbl, rdefs[i][2])
    local b = self:Button(g, 210, 20, "", function(btn) UI:OpenRankPicker(btn, key) end, "flat")
    b:SetPoint("TOPLEFT", g, "TOPLEFT", 214, -56 - (i - 1) * 28)
    S.rlRows[key] = b
  end
  -- Lagerchars
  local dt = self:Font(g, 11, C.gold)
  dt:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -182)
  self:Loc(dt, "RL_DEPOT_TITLE")
  S.rlDepot = {}
  for i = 1, BB.DEPOT_MAX do
    local row = {}
    local y = -206 - (i - 1) * 26
    row.char = self:Button(g, 170, 20, "", function(btn) UI:OpenDepotCharPicker(btn, i) end, "flat")
    row.char:SetPoint("TOPLEFT", g, "TOPLEFT", 4, y)
    row.kind = self:Button(g, 160, 20, "", function(btn) UI:OpenDepotKindPicker(btn, i) end, "flat")
    row.kind:SetPoint("TOPLEFT", g, "TOPLEFT", 180, y)
    row.del = self:Button(g, 24, 20, "x", function()
      table.remove(S.edit.depots, i)
      S.editDirty = true
      UI:RefreshSettings()
    end, "flat")
    row.del:SetPoint("TOPLEFT", g, "TOPLEFT", 346, y)
    S.rlDepot[i] = row
  end
  S.rlAdd = self:Button(g, 110, 20, "RL_DEPOT_ADD", function()
    S.edit.depots = S.edit.depots or {}
    if getn(S.edit.depots) < BB.DEPOT_MAX then
      table.insert(S.edit.depots, { n = nil, k = "welcome" })
      S.editDirty = true
      UI:RefreshSettings()
    end
  end, "flat")
  S.rlAdd:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -314)
  S.rlHint = self:Font(g, 10, C.muted)
  S.rlHint:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -342)
  S.rlHint:SetWidth(420)
  S.rlHint:SetHeight(36)
  S.rlHint:SetJustifyV("TOP")
  S.rlSave = self:Button(g, 150, 22, "RL_SAVE", function()
    if BB:SaveRules(S.edit or {}) then S.editDirty = false end
    UI:RefreshSettings()
  end, "primary")
  S.rlSave:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -386)

  f:SetScript("OnShow", function() UI:RefreshSettings() end)
end

function UI:RefreshSettings()
  local f = self.setWin
  if not f then return end
  local S = self.set
  local isMgr = BB:CanManageQuests()
  local isBank = BB:IsBank()
  for i = 1, getn(S.tabs) do S.tabs[i]:SetActive(S.tabs[i].key == S.tab) end
  local y = -88
  if S.tab == "rules" then
    S.gen:Hide()
    S.guild:Hide()
    S.bank:Hide()
    S.rules:Show()
    S.rules:ClearAllPoints()
    S.rules:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    y = y - RULES_H - 8
    self:RefreshRulesTab()
    f:SetHeight(-y + 22)
    return
  end
  S.rules:Hide()
  S.gen:Show()
  S.gen:ClearAllPoints()
  S.gen:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
  y = y - GEN_H - 8
  if isMgr then
    S.guild:Show()
    S.guild:ClearAllPoints()
    S.guild:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    y = y - GUILD_H - 8
  else
    S.guild:Hide()
  end
  if isBank or BB:MayBeBank(BB:Me()) then
    S.bank:Show()
    S.bank:ClearAllPoints()
    S.bank:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    y = y - BANK_H - 8
  else
    S.bank:Hide()
  end
  f:SetHeight(-y + 22)
  local lang = BananaBankDB.lang or "auto"
  for i = 1, getn(S.langChips) do S.langChips[i]:SetActive(S.langChips[i].code == lang) end
  S.cMini.Update()
  S.cTrack.Update()
  S.cDebug.Update()
  if S.cBank then S.cBank.Update() S.cCod.Update() S.cWhisper.Update() S.cAuto.Update() end
  if S.age and not S.ageFocus then S.age:SetText(tostring(BB:PriceMaxAgeDays())) end
  if not S.mainFocus then S.main:SetText(BB:MainBank()) end
end

-- Inhalt des Reiters Regeln
function UI:RefreshRulesTab()
  local S = self.set
  local rules = BananaBankDB.rules
  local canEdit = BB:MayBeBank(BB:Me())
  if not S.editDirty then
    S.edit = { depots = BB:DepotList() }
    if rules then
      for i = 1, getn(BB.RULE_KEYS) do
        local sp = rules[BB.RULE_KEYS[i]]
        if sp then S.edit[BB.RULE_KEYS[i]] = { n = sp.n, i = sp.i } end
      end
    end
  end
  if rules then
    S.rlStatus:SetText(string.format(T("RL_STATUS_SAVED"), BB.Date(rules.ts), rules.by or "?"))
    S.rlStatus:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
  else
    S.rlStatus:SetText(T("RL_STATUS_NONE"))
    S.rlStatus:SetTextColor(C.orange[1], C.orange[2], C.orange[3])
  end
  for i = 1, getn(BB.RULE_KEYS) do
    local key = BB.RULE_KEYS[i]
    local b = S.rlRows[key]
    local sp = S.edit[key]
    if sp then
      local _, now, found = BB:RuleRank(sp)
      local text = sp.n
      if now and not found then text = sp.n .. " |cffff9a2e> " .. now .. "|r" end
      b.fs:SetText(text)
    else
      b.fs:SetText(T("RL_PICK"))
    end
    b:SetOn(canEdit)
  end
  local dl = S.edit.depots or {}
  for i = 1, BB.DEPOT_MAX do
    local row = S.rlDepot[i]
    local d = dl[i]
    if d then
      row.char:Show()
      row.kind:Show()
      if canEdit then row.del:Show() else row.del:Hide() end
      row.char.fs:SetText(d.n or T("RL_PICK"))
      row.kind.fs:SetText(T(d.k == "raid" and "DEPOT_RAID" or "DEPOT_WELCOME"))
      row.char:SetOn(canEdit)
      row.kind:SetOn(canEdit)
    else
      row.char:Hide()
      row.kind:Hide()
      row.del:Hide()
    end
  end
  if canEdit and getn(dl) < BB.DEPOT_MAX then S.rlAdd:Show() else S.rlAdd:Hide() end
  S.rlHint:SetText(T(canEdit and "RL_HINT" or "RL_READONLY"))
  if canEdit then S.rlSave:Show() else S.rlSave:Hide() end
end

-- Auswahlmenue: entries = { { label = Text, value = beliebig } }, onPick(value)
function UI:OpenPicker(btn, entries, onPick)
  if not BB:MayBeBank(BB:Me()) then return end
  local m = self.rankMenu
  if not m then
    local catch = CreateFrame("Button", nil, UIParent)
    catch:SetAllPoints(UIParent)
    catch:SetFrameStrata("FULLSCREEN")
    catch:Hide()
    catch:SetScript("OnClick", function() UI:CloseRankPicker() end)
    m = CreateFrame("Frame", nil, UIParent)
    m:SetWidth(210)
    m:SetBackdrop({
      bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    m:SetBackdropColor(0.015, 0.025, 0.06, 1)
    m:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
    m:SetFrameStrata("TOOLTIP")
    m:EnableMouse(true)
    m:Hide()
    m.catch = catch
    m.rows = {}
    for i = 1, 14 do
      local row = CreateFrame("Button", nil, m)
      row:SetHeight(18)
      row:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -6 - (i - 1) * 19)
      row:SetPoint("TOPRIGHT", m, "TOPRIGHT", -6, -6 - (i - 1) * 19)
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetTexture(WHITE)
      hl:SetAllPoints(row)
      hl:SetVertexColor(1, 0.82, 0.3, 0.16)
      row.fs = self:Font(row, 11, { 1, 1, 1 })
      row.fs:SetPoint("LEFT", row, "LEFT", 4, 0)
      row.fs:SetWidth(190)
      row.fs:SetHeight(14)
      row:SetScript("OnClick", function()
        local e = this.entry
        local cb = UI.rankMenu.onPick
        UI:CloseRankPicker()
        if e and cb then cb(e.value) end
      end)
      m.rows[i] = row
    end
    self.rankMenu = m
  end
  m.onPick = onPick
  for i = 1, 14 do
    local row = m.rows[i]
    local e = entries[i]
    row.entry = e
    if e then
      row.fs:SetText(e.label)
      row:Show()
    else
      row:Hide()
    end
  end
  local n = math.min(getn(entries), 14)
  m:SetHeight(12 + n * 19)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
  m.catch:Show()
  m:Show()
end

function UI:OpenRankPicker(btn, key)
  local entries = {}
  local list = BB:RankList()
  for i = 1, getn(list) do table.insert(entries, { label = list[i].n, value = list[i] }) end
  self:OpenPicker(btn, entries, function(rank)
    UI.set.edit = UI.set.edit or {}
    UI.set.edit[key] = { n = rank.n, i = rank.i }
    UI.set.editDirty = true
    UI:RefreshSettings()
  end)
end

-- Lagerchar waehlen: alle Bank-Chars, die das Addon kennt (diese Konten und die Gilde)
function UI:OpenDepotCharPicker(btn, idx)
  local entries = {}
  local names = BB:BankList()
  for i = 1, getn(names) do table.insert(entries, { label = names[i], value = names[i] }) end
  self:OpenPicker(btn, entries, function(name)
    local d = UI.set.edit.depots[idx]
    if d then
      d.n = name
      UI.set.editDirty = true
      UI:RefreshSettings()
    end
  end)
end

function UI:OpenDepotKindPicker(btn, idx)
  local entries = {
    { label = T("DEPOT_WELCOME"), value = "welcome" },
    { label = T("DEPOT_RAID"), value = "raid" },
  }
  self:OpenPicker(btn, entries, function(kind)
    local d = UI.set.edit.depots[idx]
    if d then
      d.k = kind
      UI.set.editDirty = true
      UI:RefreshSettings()
    end
  end)
end

function UI:CloseRankPicker()
  if not self.rankMenu then return end
  self.rankMenu:Hide()
  self.rankMenu.catch:Hide()
end

function UI:ToggleSettings()
  self:BuildSettings()
  local f = self.setWin
  if f:IsVisible() then f:Hide() else f:Show() end
end

-- ------------------------------------------------------------
-- Von Hand buchen
-- ------------------------------------------------------------
function UI:OpenBookDialog()
  local d = self.bookDlg
  if not d then
    d = CreateFrame("Frame", "BananaBankBookDlg", UIParent)
    d:SetWidth(340)
    d:SetHeight(190)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    d:SetFrameStrata("TOOLTIP")
    d:EnableMouse(true)
    d:SetBackdrop({
      bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    d:SetBackdropColor(0.015, 0.025, 0.06, 1)
    d:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
    d:Hide()
    tinsert(UISpecialFrames, "BananaBankBookDlg")
    local t = self:Font(d, 13, C.gold)
    t:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -12)
    self:Loc(t, "SET_BOOK_TITLE")
    local function row(key, y, w, name)
      local l = self:Font(d, 11, C.text)
      l:SetPoint("TOPLEFT", d, "TOPLEFT", 14, y)
      self:Loc(l, key)
      local e = self:EditBox(name, d, w)
      e:SetPoint("TOPLEFT", d, "TOPLEFT", 120, y + 5)
      return e
    end
    d.player = row("SET_BOOK_PLAYER", -42, 180, "BananaBankBookPlayer")
    d.count = row("SET_BOOK_COUNT", -70, 70, "BananaBankBookCount")
    d.count:SetNumeric(true)
    d.item = row("SET_BOOK_ITEM", -98, 190, "BananaBankBookItem")
    d.ok = self:Button(d, 110, 22, "SET_BOOK_GO", function()
      BB:ManualBook(d.player:GetText(), d.count:GetText(), d.item:GetText())
      d:Hide()
      UI:Refresh()
    end, "ok")
    d.ok:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 14)
    d.no = self:Button(d, 90, 22, "PAY_CANCEL", function() d:Hide() end)
    d.no:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 14)
    self.bookDlg = d
  end
  d.player:SetText("")
  d.count:SetText("")
  d.item:SetText("")
  d:Show()
  d.player:SetFocus()
end
