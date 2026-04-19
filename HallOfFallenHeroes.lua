-- Hall of Fallen Heroes — Forgotten Gravestone Addon
-- Right-click a gravestone → URL shown in popup → Ctrl+C to copy → paste in browser
-- Guild-gated: only works for Wicked Demise on Skullcrusher

local ADDON_NAME = "HallOfFallenHeroes"
local SITE_URL   = "https://memoria.irosec.com/q"
local ALLOWED_GUILD = "Wicked Demise"
local ALLOWED_REALM = "Skullcrusher"

local function urlencode(str)
    if not str then return "" end
    str = tostring(str)
    str = str:gsub("([^%w%-%.%_%~ ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return str:gsub(" ", "+")
end

local function parseGravestoneText(text)
    if not text then return nil end
    if not text:find("valiantly slain") then return nil end
    local data = {}
    data.name = text:match("Here lies ([^,\n]+),")
    data.killer = text:match("slain by (.+) in a Tier") or text:match("slain by (.+) in")
    if data.killer then
        data.killer = data.killer:match("^%s*(.-)%s*$")
    else
        data.killer = "Their Overwhelming Confidence"
    end
    data.tier = text:match("Tier (%d+) Delve")
    local timeStr = text:match("[Tt]hey perished at (.+)%.")
    if timeStr then
        timeStr = timeStr:match("^%s*(.-)%s*$")
        local t, period, month, day = timeStr:match("(%d+:%d+) (%a+) on (%a+) (%d+)")
        if t and period and month and day then
            data.timeOfDeath = t .. " " .. period .. " on " .. month .. " " .. day
        else
            data.timeOfDeath = timeStr
        end
    end
    return data
end

local function getLocationName()
    local name, instanceType = GetInstanceInfo()
    if instanceType ~= "none" and name and name ~= "" then return name end
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        local info = C_Map.GetMapInfo(mapID)
        if info then return info.name end
    end
    return nil
end

local function isInAllowedGuild()
    local guildName, _, _, guildRealm = GetGuildInfo("player")
    if not guildName then return false, nil, nil end
    local realm = guildRealm or GetRealmName()
    return (guildName == ALLOWED_GUILD and realm == ALLOWED_REALM), guildName, realm
end

local function buildURL(data, location)
    local playerName  = UnitName("player") or "Unknown"
    local playerRealm = GetRealmName() or "Unknown"
    local gameRegion = "eu"
    if GetCurrentRegionName then
        local rn = GetCurrentRegionName()
        if rn then gameRegion = rn:lower() end
    end
    local params = {
        "n="  .. urlencode(data.name   or ""),
        "k="  .. urlencode(data.killer or ""),
        "by=" .. urlencode(playerName .. "-" .. playerRealm),
        "r="  .. urlencode(gameRegion),
    }
    if data.tier        then table.insert(params, "t=" .. urlencode(data.tier)) end
    if location         then table.insert(params, "l=" .. urlencode(location)) end
    if data.timeOfDeath then table.insert(params, "d=" .. urlencode(data.timeOfDeath)) end
    return SITE_URL .. "?" .. table.concat(params, "&")
end

local popup = nil
local function showURLPopup(url, charName, killer, tier, location)
    if not popup then
        popup = CreateFrame("Frame", "HoFH_Popup", UIParent, "BasicFrameTemplate")
        popup:SetSize(540, 190)
        popup:SetPoint("CENTER")
        popup:SetMovable(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
        popup:SetFrameStrata("DIALOG")

        popup.titleText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        popup.titleText:SetPoint("TOP", popup, "TOP", 0, -8)
        popup.titleText:SetText("|cFFc8a050HALL OF FALLEN HEROES|r")

        popup.info = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        popup.info:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -36)
        popup.info:SetWidth(508)
        popup.info:SetJustifyH("LEFT")

        popup.label = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        popup.label:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -72)
        popup.label:SetText("Paste this URL in your browser to submit the death:")
        popup.label:SetTextColor(0.6, 0.6, 0.6)

        popup.urlBg = popup:CreateTexture(nil, "BACKGROUND")
        popup.urlBg:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -90)
        popup.urlBg:SetSize(512, 28)
        popup.urlBg:SetColorTexture(0.04, 0.06, 0.10, 1)

        popup.editBox = CreateFrame("EditBox", "HoFH_URLBox", popup)
        popup.editBox:SetPoint("TOPLEFT", popup, "TOPLEFT", 18, -93)
        popup.editBox:SetSize(504, 22)
        popup.editBox:SetFontObject(ChatFontNormal)
        popup.editBox:SetTextColor(0.95, 0.82, 0.45)
        popup.editBox:SetAutoFocus(false)
        popup.editBox:SetMultiLine(false)
        popup.editBox:SetMaxLetters(0)
        popup.editBox:EnableMouse(true)
        popup.editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
        popup.editBox:SetScript("OnMouseUp", function(self)
            self:SetFocus()
            self:HighlightText()
        end)

        popup.hint = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        popup.hint:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -128)
        popup.hint:SetTextColor(0.4, 0.8, 0.4)
        popup.hint:SetText("|cFF6dbd6dClick the URL box, then Ctrl+A, Ctrl+C, paste in browser.|r")

        popup.closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        popup.closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, 0)
        popup.closeBtn:SetScript("OnClick", function() popup:Hide() end)
    end

    local infoText = string.format("|cFFc8a050%s|r  slain by |cFFe07870%s|r", charName or "?", killer or "?")
    if tier     then infoText = infoText .. string.format("  |cFFc8a050T%s|r", tier) end
    if location then infoText = infoText .. string.format("  |cFF5a6878%s|r", location) end
    popup.info:SetText(infoText)
    popup.editBox:SetText(url)
    popup:Show()
    popup.editBox:SetFocus()
    popup.editBox:SetCursorPosition(0)
    popup.editBox:HighlightText()
end

local frame = CreateFrame("Frame", ADDON_NAME .. "_Frame")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            -- Silent load — no chat spam
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Silent — do nothing
    elseif event == "GOSSIP_SHOW" then
        -- Guild check first — silently do nothing if not allowed
        if not isInAllowedGuild() then return end
        local gossipText = C_GossipInfo.GetText()
        if not gossipText then return end
        local data = parseGravestoneText(gossipText)
        if not data or not data.name then return end
        local location = getLocationName()
        local url = buildURL(data, location)
        HoFH_LastDeath = { name=data.name, killer=data.killer, tier=data.tier, location=location, time=data.timeOfDeath, url=url }
        showURLPopup(url, data.name, data.killer, data.tier, location)
        print(string.format("|cFFc8a050[HoFH]|r |cFFd4cfc8%s|r slain by |cFFe07870%s|r — click popup URL to submit",
            data.name or "?", data.killer or "?"))
    end
end)

SLASH_HOFH1 = "/hofh"
SLASH_HOFH2 = "/halloffallen"
SlashCmdList["HOFH"] = function(msg)
    -- Gate entire slash command behind guild check
    if not isInAllowedGuild() then
        -- Pretend the command doesn't exist
        return
    end

    msg = strtrim(msg):lower()
    if msg == "last" then
        if HoFH_LastDeath and HoFH_LastDeath.url then
            showURLPopup(HoFH_LastDeath.url, HoFH_LastDeath.name, HoFH_LastDeath.killer, HoFH_LastDeath.tier, HoFH_LastDeath.location)
        else
            print("|cFFc8a050[HoFH]|r No death recorded yet this session.")
        end
    elseif msg == "debug" then
        local t = C_GossipInfo.GetText()
        print("|cFFc8a050[HoFH Debug]|r Gossip text:", t or "NIL")
    else
        print("|cFFc8a050[Hall of Fallen Heroes]|r Commands:")
        print("  /hofh last   — re-show last gravestone URL")
        print("  /hofh debug  — show raw gossip text")
    end
end
