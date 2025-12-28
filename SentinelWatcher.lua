DEFAULT_CHAT_FRAME:AddMessage("SentinelWatcher: Loading...", 0, 1, 0)

-- Saved variables
SentinelWatcher_Locked = SentinelWatcher_Locked or false

-- Tooltip for scanning
local scanner = CreateFrame("GameTooltip", "SentinelWatcherScanner", nil, "GameTooltipTemplate")
scanner:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Get buff/debuff name from tooltip
local function GetAuraName(unit, index, isDebuff)
    scanner:ClearLines()
    if isDebuff then
        scanner:SetUnitDebuff(unit, index)
    else
        scanner:SetUnitBuff(unit, index)
    end
    local text = SentinelWatcherScannerTextLeft1:GetText()
    return text
end

-- Create main frame
local f = CreateFrame("Frame", "SentinelWatcherFrame", UIParent)
f:SetWidth(250)
f:SetHeight(120)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
})
f:SetBackdropColor(0, 0, 0, 0.9)
f:SetMovable(true)
f:EnableMouse(false)
f:Hide()

-- Create top bar
local bar = CreateFrame("Frame", nil, f)
bar:SetHeight(20)
bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
bar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
})
bar:SetBackdropColor(0.2, 0.2, 0.2, 1)

-- Title text
local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("CENTER", bar, "CENTER", 0, 0)
title:SetText("Sentinel Watcher")

-- Make bar draggable
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", function()
    if not SentinelWatcher_Locked then 
        f:StartMoving() 
    end
end)
bar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
end)

-- Lock checkbox
local lock = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
lock:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
lock:SetWidth(20)
lock:SetHeight(20)
lock:SetScript("OnClick", function()
    SentinelWatcher_Locked = lock:GetChecked()
end)
lock:SetChecked(SentinelWatcher_Locked)

-- Create display lines (raid icon + text)
local lines = {}
local icons = {}
for i = 1, 4 do
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -20 - (i * 20))
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    icon:Hide()
    icons[i] = icon
    
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    t:SetText("")
    lines[i] = t
end

-- Raid icon coords
local ICON_COORDS = {
    [1] = {0, 0.25, 0, 0.25},
    [2] = {0.25, 0.5, 0, 0.25},
    [3] = {0.5, 0.75, 0, 0.25},
    [4] = {0.75, 1, 0, 0.25},
    [5] = {0, 0.25, 0.25, 0.5},
    [6] = {0.25, 0.5, 0.25, 0.5},
    [7] = {0.5, 0.75, 0.25, 0.5},
    [8] = {0.75, 1, 0.25, 0.5}
}

-- Sentinel buff list with kill order
local BUFFS = {
    ["Thorns"] = 5,
    ["Thunderclap"] = 6,
    ["Shadow Storm"] = 9,
    ["Periodic Shadow Storm"] = 9,
    ["Mana Burn"] = 8,
    ["Periodic Mana Burn"] = 8,
    ["Mortal Strike"] = 7,
    ["Knock Away"] = 4,
    ["Periodic Knock Away"] = 4,
    ["Fire and Arcane Reflect"] = 1,
    ["Shadow and Frost Reflect"] = 2,
    ["Mending"] = 3
}

-- Mob database
local mobDB = {}

-- Get sentinel buff from unit
local function GetSentinelBuff(unit)
    -- Check buffs
    local i = 1
    while UnitBuff(unit, i) do
        local name = GetAuraName(unit, i, false)
        if name and BUFFS[name] then
            return "(" .. BUFFS[name] .. ") " .. name
        end
        i = i + 1
        if i > 32 then break end
    end
    
    -- Check debuffs (after Detect Magic)
    local hasDetectMagic = false
    i = 1
    while UnitDebuff(unit, i) do
        local name = GetAuraName(unit, i, true)
        if name then
            if name == "Detect Magic" or name == "Detect Greater Magic" then
                hasDetectMagic = true
            end
            if BUFFS[name] then
                return "(" .. BUFFS[name] .. ") " .. name
            end
        end
        i = i + 1
        if i > 32 then break end
    end
    
    -- If has detect magic but no buff found
    if hasDetectMagic then
        return "Detected"
    end
    
    return nil
end

-- Is sentinel check
local function IsSentinel(name)
    return name == "Anubisath Sentinel" or name == "Anubisath Defender"
end

-- Check unit and update database
local function CheckUnit(unit)
    if not UnitExists(unit) then return end
    
    local name = UnitName(unit)
    if not name or not IsSentinel(name) then return end
    
    local mark = GetRaidTargetIndex(unit)
    if not mark then return end
    
    local buff = GetSentinelBuff(unit)
    
    mobDB[mark] = {
        name = name,
        buff = buff or "Need Detect Magic",
        lastSeen = GetTime()
    }
end

-- Scan all units
local function ScanUnits()
    CheckUnit("target")
    CheckUnit("mouseover")
    CheckUnit("pet")
    CheckUnit("pettarget")
    
    if GetNumRaidMembers() > 0 then
        for i = 1, 40 do
            CheckUnit("raid" .. i)
            CheckUnit("raid" .. i .. "target")
            CheckUnit("raid" .. i .. "pet")
            CheckUnit("raid" .. i .. "pettarget")
        end
    else
        for i = 1, 4 do
            CheckUnit("party" .. i)
            CheckUnit("party" .. i .. "target")
            CheckUnit("party" .. i .. "pet")
            CheckUnit("party" .. i .. "pettarget")
        end
    end
end

-- Update display
local function UpdateDisplay()
    -- Clean old entries
    local now = GetTime()
    for mark, data in pairs(mobDB) do
        if now - data.lastSeen > 60 then
            mobDB[mark] = nil
        end
    end
    
    local displayCount = 0
    for mark = 1, 8 do
        if mobDB[mark] then
            displayCount = displayCount + 1
            
            local coords = ICON_COORDS[mark]
            if coords then
                icons[displayCount]:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                icons[displayCount]:Show()
            end
            
            lines[displayCount]:SetText(mobDB[mark].buff)
            
            if displayCount >= 4 then break end
        end
    end
    
    for i = displayCount + 1, 4 do
        icons[i]:Hide()
        lines[i]:SetText("")
    end
    
    if displayCount > 0 then
        if not f:IsShown() then f:Show() end
    else
        if f:IsShown() then
            lines[1]:SetText("No marked sentinels")
        end
    end
end

-- Check if player is in AQ40
local function IsInAQ40()
    local zone = GetRealZoneText()
    return zone == "Temple of Ahn'Qiraj" or zone == "Ahn'Qiraj"
end

-- Zone change handler
local function OnZoneChanged()
    if IsInAQ40() then
        f:Show()
        UpdateDisplay()
    end
end

-- Events
f:RegisterEvent("RAID_TARGET_UPDATE")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        OnZoneChanged()
    else
        ScanUnits()
    end
end)

-- Update timer
local elapsed = 0
f:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 0.5 then
        elapsed = 0
        ScanUnits()
        UpdateDisplay()
    end
end)

-- Slash commands
SLASH_SENTINELWATCHER1 = "/sentinelwatcher"
SLASH_SENTINELWATCHER2 = "/sw"

SlashCmdList["SENTINELWATCHER"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "show" then
        f:Show()
        UpdateDisplay()
    elseif msg == "hide" then
        f:Hide()
    elseif msg == "clear" then
        mobDB = {}
        UpdateDisplay()
        DEFAULT_CHAT_FRAME:AddMessage("SentinelWatcher: Cache cleared")
    else
        if f:IsShown() then
            f:Hide()
        else
            f:Show()
            UpdateDisplay()
        end
    end
end

DEFAULT_CHAT_FRAME:AddMessage("SentinelWatcher: Ready! /sw show to start", 0, 1, 0)

-- Auto-show if already in AQ40
OnZoneChanged()
