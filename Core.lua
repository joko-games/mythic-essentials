local addonName, ns = ...
local L = ns.L

-- Global handle for inspecting data in game, e.g. /dump MythicEssentials.GetMeterRows()
MythicEssentials = ns

ns.addonName = addonName
ns.ICON = "Interface\\AddOns\\MythicEssentials\\Media\\Icon"

function ns.Print(text)
    print("|cffb366f0Mythic Essentials|r " .. text)
end

-- Game events ---------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

-- An event this client does not know (a name changed between patches) is skipped,
-- rather than stopping the whole file from loading.
function ns.OnEvent(event, handler)
    local handlers = eventHandlers[event]
    if not handlers then
        handlers = {}
        eventHandlers[event] = handlers
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    table.insert(handlers, handler)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(eventHandlers[event]) do
        handler(...)
    end
end)

local debounced = {}

-- Runs fn once after delay, however many times it is requested in between.
function ns.Debounce(key, delay, fn)
    if debounced[key] then
        return
    end
    debounced[key] = true
    C_Timer.After(delay, function()
        debounced[key] = nil
        fn()
    end)
end

-- Secret values ---------------------------------------------------------------

-- Since Midnight, some values (damage numbers and names in combat) are "secret": the
-- addon may hand them to the interface to show, but not read, compare or compute with them.
function ns.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Saved data ----------------------------------------------------------------

local DEFAULTS = {
    shown = true,
    locked = false,
    scale = 1,
    point = nil,          -- { point, relativePoint, x, y } once moved
    minimap = { angle = 200, hidden = false },
}

function ns.LoadSavedData()
    if type(MythicEssentialsDB) ~= "table" then
        MythicEssentialsDB = {}
    end
    local db = MythicEssentialsDB
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do
                    copy[k] = v
                end
                db[key] = copy
            else
                db[key] = value
            end
        end
    end
    ns.db = db
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == addonName then
        ns.LoadSavedData()
    end
end)

-- Formatting ----------------------------------------------------------------

-- "845", "12.3k", "1.25M": short enough for a narrow window.
function ns.FormatNumber(value)
    value = value or 0
    if value >= 1e9 then
        return string.format("%.2fB", value / 1e9)
    elseif value >= 1e6 then
        return string.format("%.2fM", value / 1e6)
    elseif value >= 1e4 then
        return string.format("%.1fk", value / 1e3)
    end
    return string.format("%d", math.floor(value + 0.5))
end

-- A number that may be secret, as text the interface can show: the addon's own format
-- when it can read it, the game's otherwise (its formatters accept secret numbers).
function ns.DisplayNumber(value)
    if value == nil then
        return ""
    end
    if not ns.IsSecret(value) then
        return ns.FormatNumber(value)
    end
    if AbbreviateNumbers then
        local ok, text = pcall(AbbreviateNumbers, value)
        if ok then
            return text
        end
    end
    local ok, text = pcall(string.format, "%.0f", value)
    return ok and text or "?"
end

-- "12:34", or "1:02:03" past an hour. Negative times (over the limit) keep their sign.
function ns.FormatClock(seconds)
    seconds = seconds or 0
    local sign = ""
    if seconds < 0 then
        sign = "-"
        seconds = -seconds
    end
    seconds = math.floor(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60) % 60
    if hours > 0 then
        return string.format("%s%d:%02d:%02d", sign, hours, minutes, seconds % 60)
    end
    return string.format("%s%d:%02d", sign, minutes, seconds % 60)
end

-- Command -------------------------------------------------------------------

SLASH_MYTHICESSENTIALS1 = "/mye"
SLASH_MYTHICESSENTIALS2 = "/mythicessentials"
SlashCmdList.MYTHICESSENTIALS = function(input)
    local command, argument = string.match(string.lower(strtrim(input or "")), "^(%S*)%s*(.-)$")
    if command == "" then
        ns.UI.Toggle()
    elseif command == "lock" then
        ns.UI.SetLocked(not ns.db.locked)
    elseif command == "scale" and tonumber(argument) then
        ns.UI.SetScale(tonumber(argument))
    elseif command == "reset" then
        ns.UI.ResetPosition()
    elseif command == "minimap" then
        ns.UI.ToggleMinimapButton()
    elseif command == "demo" then
        ns.UI.ToggleDemo()
    else
        ns.Print(L["Commands: /mye (show or hide), lock, scale 0.5-2, reset, minimap, demo."])
    end
end

function MythicEssentials_OnAddonCompartmentClick()
    ns.UI.Toggle()
end
