-- BananaBank UI Teil 9: Einstellungen (Zahnrad) und Hauptbank-Anzeige im Fensterkopf

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.settingsModule = true
UI.set = {}

local GEN_H, GUILD_H, BANK_H = 168, 108, 134

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

  f:SetScript("OnShow", function() UI:RefreshSettings() end)
end

function UI:RefreshSettings()
  local f = self.setWin
  if not f then return end
  local S = self.set
  local isMgr = BB:CanManageQuests()
  local isBank = BB:IsBank()
  local y = -62
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
  if S.cBank then S.cBank.Update() S.cCod.Update() S.cWhisper.Update() end
  if not S.mainFocus then S.main:SetText(BB:MainBank()) end
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
