local _, ns = ...

-- Who in the group has no flask, and who has not eaten. Buffs are read out of combat
-- only: in combat they may be secret, and the check matters before the pull anyway.
-- The last result is kept through combat.

ns.CONSUMABLES = { "flask", "food" }

-- Buffs are recognised by name, in the client's language, so that a new expansion's
-- flasks and food count without a list of spell IDs. Food buffs also share an icon.
local KEYWORDS = {
    enUS = { flask = { "flask", "phial" }, food = { "well fed" } },
    enGB = { flask = { "flask", "phial" }, food = { "well fed" } },
    frFR = { flask = { "flacon", "fiole" }, food = { "bien nourri" } },
    deDE = { flask = { "fläschchen", "phiole" }, food = { "satt" } },
    esES = { flask = { "frasco", "vial" }, food = { "bien alimentado" } },
    esMX = { flask = { "frasco", "vial" }, food = { "bien alimentado" } },
    itIT = { flask = { "tonico", "fiala" }, food = { "ben nutrito" } },
    ptBR = { flask = { "frasco" }, food = { "bem alimentado" } },
    ruRU = { flask = { "настой", "фиал" }, food = { "сытость" } },
    koKR = { flask = { "영약" }, food = { "포만감" } },
    zhCN = { flask = { "合剂" }, food = { "进食充分" } },
    zhTW = { flask = { "精煉藥劑" }, food = { "充分進食" } },
}
local FOOD_ICON = 136000 -- Interface\Icons\Spell_Misc_Food, the "Well Fed" icon

local function Keywords()
    return KEYWORDS[GetLocale()] or KEYWORDS.enUS
end

-- Which consumables a buff is: "flask", "food" or nil.
function ns.ClassifyBuff(name, icon)
    if icon == FOOD_ICON then
        return "food"
    end
    if type(name) ~= "string" then
        return nil
    end
    local lower = string.lower(name)
    for _, kind in ipairs(ns.CONSUMABLES) do
        for _, word in ipairs(Keywords()[kind]) do
            if string.find(lower, word, 1, true) then
                return kind
            end
        end
    end
    return nil
end

local function GroupUnits()
    local units = { "player" }
    for index = 1, 4 do
        local unit = "party" .. index
        if UnitExists(unit) then
            table.insert(units, unit)
        end
    end
    return units
end

-- The consumables a unit has, or nil when it cannot be told (out of sight, offline,
-- or a value the client keeps secret).
local function UnitConsumables(unit)
    if not UnitIsConnected(unit) or (unit ~= "player" and not UnitIsVisible(unit)) then
        return nil
    end
    local found = {}
    for index = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not ok then
            return nil
        end
        if not aura then
            break
        end
        if ns.IsSecret(aura.name) or ns.IsSecret(aura.icon) then
            return nil
        end
        local kind = ns.ClassifyBuff(aura.name, aura.icon)
        if kind then
            found[kind] = true
        end
    end
    return found
end

ns.missing = { flask = {}, food = {} }

-- Fills ns.missing: for each consumable, the names of the players without it.
function ns.ScanConsumables()
    if InCombatLockdown() then
        return false
    end
    local missing = {}
    for _, kind in ipairs(ns.CONSUMABLES) do
        missing[kind] = {}
    end
    for _, unit in ipairs(GroupUnits()) do
        local found = UnitConsumables(unit)
        if found then
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            for _, kind in ipairs(ns.CONSUMABLES) do
                if not found[kind] then
                    table.insert(missing[kind], { name = name, class = class })
                end
            end
        end
    end
    ns.missing = missing
    return true
end

local function RequestScan()
    ns.Debounce("consumables", 0.5, function()
        if ns.ScanConsumables() and ns.UI and ns.UI.Refresh then
            ns.UI.Refresh()
        end
    end)
end

ns.OnEvent("UNIT_AURA", function(unit)
    if unit == "player" or (type(unit) == "string" and string.match(unit, "^party%d$")) then
        RequestScan()
    end
end)
ns.OnEvent("GROUP_ROSTER_UPDATE", RequestScan)
ns.OnEvent("PLAYER_ENTERING_WORLD", RequestScan)
ns.OnEvent("PLAYER_REGEN_ENABLED", RequestScan)
