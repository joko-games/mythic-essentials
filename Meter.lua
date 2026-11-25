local _, ns = ...

-- The group's damage, read from the game's own damage meter (C_DamageMeter). Since
-- Midnight addons no longer see the combat log: the meter is the only source, and in
-- combat its numbers and names are secret (Core.lua, ns.IsSecret).

ns.MAX_ROWS = 5

-- Enum names moved during 12.0's development, so each is looked up under its known names.
local function EnumValue(enumName, names, fallback)
    local enum = Enum and Enum[enumName]
    if enum then
        for _, name in ipairs(names) do
            if enum[name] ~= nil then
                return enum[name]
            end
        end
    end
    return fallback
end

function ns.MeterAvailable()
    return C_DamageMeter ~= nil and C_DamageMeter.GetCombatSessionFromType ~= nil
end

-- The run's damage, from the meter's Overall session: in a key, the whole key so far.
local function ReadSession()
    local sessionType = EnumValue("DamageMeterSessionType", { "Overall" }, 0)
    local meterType = EnumValue("DamageMeterType", { "DamageDone" }, 0)
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
    if ok and type(session) == "table" then
        return session
    end
    return nil
end

-- One row per player, best first (the meter sorts them), at most MAX_ROWS:
-- { class, name, amount, perSecond, isPlayer }. name, amount and perSecond may be secret;
-- class and isPlayer never are.
function ns.GetMeterRows()
    if not ns.MeterAvailable() then
        return {}
    end
    local session = ReadSession()
    local sources = session and session.combatSources
    if type(sources) ~= "table" then
        return {}
    end
    local rows = {}
    for _, source in ipairs(sources) do
        -- Pets and guardians are folded into their owner by the meter; only players carry a class.
        if source.classFilename and source.classFilename ~= "" then
            table.insert(rows, {
                class = source.classFilename,
                name = source.name,
                amount = source.totalAmount,
                perSecond = source.amountPerSecond,
                isPlayer = source.isLocalPlayer == true,
            })
            if #rows >= ns.MAX_ROWS then
                break
            end
        end
    end
    return rows
end

-- The bar of each row, relative to the best: what StatusBar:SetMinMaxValues needs.
-- Secret amounts go to the bar as they are, the client draws them.
function ns.MeterBarRange(rows)
    local top = rows[1] and rows[1].amount
    if top == nil then
        return 0, 1
    end
    if not ns.IsSecret(top) and top <= 0 then
        return 0, 1
    end
    return 0, top
end

-- A name without its realm, when it can be read.
function ns.ShortName(name)
    if name == nil or ns.IsSecret(name) then
        return name
    end
    return (string.gsub(name, "%-.*$", ""))
end
