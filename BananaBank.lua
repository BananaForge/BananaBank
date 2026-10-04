-- BananaBank Einstieg: Events und Befehle

local BB = BananaBank
local started = false

-- Hello erst senden, wenn die Gildenliste da ist und den Bank-Rang zeigt
function BB:TryHello(n)
  if self:Ready() then
    self:SendHello()
  elseif n < 12 then
    self:RequestRoster()
    self:After(5, function() BB:TryHello(n + 1) end, "hello")
  end
end

local ev = CreateFrame("Frame", "BananaBankEvents")
local EVENTS = {
  "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON",
  "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE", "PLAYERBANKSLOTS_CHANGED", "PLAYER_MONEY",
  "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED",
  "TRADE_SHOW", "TRADE_CLOSED", "TRADE_ACCEPT_UPDATE", "TRADE_TARGET_ITEM_CHANGED",
  "TRADE_PLAYER_ITEM_CHANGED", "TRADE_MONEY_CHANGED", "UI_INFO_MESSAGE",
  "AUCTION_ITEM_LIST_UPDATE", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_SHOW",
  "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE",
}
for i = 1, table.getn(EVENTS) do ev:RegisterEvent(EVENTS[i]) end

ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 ~= "BananaBank" then return end
    BB:InitDB()
    BB:ApplyLanguage()
    BB:HookMail()
    math.randomseed(time())

  elseif event == "PLAYER_ENTERING_WORLD" then
    if started then return end
    started = true
    BB.UI:Init()
    BB.UI:BuildMinimap()
    BB:Print(string.format(BB.T("MSG_LOADED"), BB.VERSION))
    BB:CheckModules()
    BB:RequestRoster()
    BB:After(6, function() BB:RequestRoster() end, "roster")
    BB:After(5, function() BB:QuestTick() end, "questbase")
    BB:After(12, function() BB:TryHello(1) end, "hello")

  elseif event == "CHAT_MSG_ADDON" then
    BB:OnAddonMessage(arg1, arg2, arg3, arg4)

  elseif event == "BANKFRAME_OPENED" then
    BB.bankOpen = true
    if BB:IsBank() then BB:ScheduleSnapshot(1) end
    BB.UI:Refresh()

  elseif event == "BANKFRAME_CLOSED" then
    -- Scan vor dem Schliessen-Flag, damit der Bankinhalt noch lesbar ist
    if BB:IsBank() and BB.bankOpen then BB:UpdateSnapshot(false) end
    BB.bankOpen = false
    if BB:IsBank() then BB:ScheduleSnapshot(1) end
    BB.UI:Refresh()

  elseif event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED" then
    if BB:IsBank() and BB.bankOpen and not BB.job then BB:ScheduleSnapshot(3) end
    if BB.UI.page == "bank" then BB:After(0.5, function() BB.UI:Refresh() end, "bagrefresh") end

  elseif event == "PLAYER_MONEY" then
    if BB:IsBank() then
      local snap = BananaBankDB.snaps[BB:Me()]
      if snap then snap.gold = GetMoney() end
    end

  elseif event == "MAIL_SHOW" then
    BB.mailOpen = true
    BB.UI:Refresh()

  elseif event == "MAIL_CLOSED" then
    BB.mailOpen = false
    BB:Cancel("automail")
    BB.UI:Refresh()

  elseif event == "MAIL_SEND_SUCCESS" then
    BB:OnMailSent()

  elseif event == "MAIL_FAILED" then
    BB:OnMailFailed()

  elseif event == "TRADE_SHOW" then
    BB:TradeShow()

  elseif event == "TRADE_ACCEPT_UPDATE" or event == "TRADE_TARGET_ITEM_CHANGED"
      or event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_MONEY_CHANGED" then
    BB:TradeCapture()

  elseif event == "UI_INFO_MESSAGE" then
    if arg1 == ERR_TRADE_COMPLETE and BB.trade then BB:TradeCommit() end

  elseif event == "TRADE_CLOSED" then
    BB:TradeClosed()

  elseif event == "AUCTION_ITEM_LIST_UPDATE" then
    BB:OnAuctionUpdate()

  elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
    BB:ReadRoster()
    BB.UI:Refresh()

  elseif event == "AUCTION_HOUSE_SHOW" then
    BB.ahOpen = true
    BB.UI:Refresh()

  elseif event == "AUCTION_HOUSE_CLOSED" then
    BB.ahOpen = false
    if BB.scan then BB:StopAHScan() end
  end
end)

-- ------------------------------------------------------------
-- Befehle
-- ------------------------------------------------------------
SLASH_BANANABANK1 = "/bb"
SLASH_BANANABANK2 = "/bananabank"
SlashCmdList["BANANABANK"] = function(msg)
  msg = msg or ""
  -- Rangnamen brauchen die Gross-/Kleinschreibung, deshalb rest im Original
  local _, _, rawCmd, rest = string.find(msg, "^(%S*)%s*(.-)$")
  local cmd = string.lower(rawCmd or "")
  rest = rest or ""
  local restLower = string.lower(rest)
  if cmd == "" or cmd == "show" then
    BB.UI:Toggle()
  elseif cmd == "setbank" then
    BB:SetBank(true)
  elseif cmd == "removebank" then
    BB:SetBank(false)
  elseif cmd == "scan" then
    if BB:IsBank() then BB:UpdateSnapshot(true) else BB:Print(BB.T("ERR_NOT_BANK")) end
  elseif cmd == "quests" or cmd == "quest" then
    BB.UI:Init()
    BB.UI.frame:Show()
    BB.UI:ShowPage("quests")
  elseif cmd == "tracker" then
    BB.UI:ToggleQuestTracker()
  elseif cmd == "questlog" then
    BB:PrintQuestLog(rest)
  elseif cmd == "status" then
    BB:Status()
  elseif cmd == "unhide" then
    BananaBankDB.hidden = {}
    BB:Print(BB.T("MSG_UNHIDDEN"))
    BB.UI:Refresh()
  elseif cmd == "ahscan" then
    BB:StartAHScan()
  elseif cmd == "prices" or cmd == "preise" then
    BB.UI:Init()
    BB.UI.frame:Show()
    BB.UI:ShowPage("prices")
  elseif cmd == "sync" then
    if not BB:Ready() then BB:Print("|cffff4040" .. string.format(BB.T("ERR_RANK_MISSING"), BB.BANK_RANK_LABEL) .. "|r") return end
    BB:SendHello()
    BB:Print(BB.T("MSG_SYNC"))
  elseif cmd == "lang" then
    if restLower == "de" then BB.UI:SetLanguage("deDE")
    elseif restLower == "en" then BB.UI:SetLanguage("enUS")
    else BB.UI:SetLanguage("auto") end
  elseif cmd == "minimap" then
    BananaBankDB.minimap.hide = not BananaBankDB.minimap.hide
    if BananaBankDB.minimap.hide then BB.UI.minimap:Hide() else BB.UI.minimap:Show() end
  elseif cmd == "debug" then
    BananaBankDB.debug = not BananaBankDB.debug
    BB:Print("Debug: " .. (BananaBankDB.debug and "an/on" or "aus/off"))
  elseif cmd == "support" or cmd == "spenden" then
    BB.UI:ShowThanks()
  else
    BB:Print(BB.T("HELP"))
  end
end
