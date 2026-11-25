-- A small stand-in for the WoW client, enough to run the addon outside the game. The
-- logic (Core, Meter, Keystone, Consumables) is checked against it in detail; the
-- window is built and refreshed on frames that accept any call, which checks that its
-- code runs, not how it looks (that is checked in game).
--
-- The world is a table the tests fill. Mock.Reset() empties it.

local Mock = {}

local world

function Mock.Reset()
    world = {
        now = 1000,
        inCombat = false,
        inInstance = true,
        meter = nil,       -- the session C_DamageMeter returns, or nil
        key = nil,         -- { mapID, name, timeLimit, level, elapsed, deaths, timeLost, criteria = { info, ... } }
        units = {},        -- [unit] = { name, class, connected, visible, auras = { { name, icon }, ... } }
    }
    Mock.world = world
    Mock.timers = {}
    Mock.printed = {}
    Mock.frames = {}
end

-- Secret values: a wrapper the addon may pass on but not read. Lua refuses to compare
-- or compute with a table, as the client refuses with a secret.
local secretMeta = { __tostring = function() return "<secret>" end }
function Mock.Secret(value)
    return setmetatable({ value = value }, secretMeta)
end
function issecretvalue(value)
    return getmetatable(value) == secretMeta
end
function AbbreviateNumbers(value)
    if issecretvalue(value) then
        return "S" .. tostring(value.value)
    end
    return tostring(value)
end

-- Frames: any method exists and does nothing, except the few the addon reads back.
local function NewObject(kind)
    local object = { kind = kind, shown = true, scripts = {}, events = {} }
    local methods = {
        RegisterEvent = function(self, event) self.events[event] = true end,
        SetScript = function(self, name, fn) self.scripts[name] = fn end,
        GetScript = function(self, name) return self.scripts[name] end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetShown = function(self, shown) self.shown = shown and true or false end,
        IsShown = function(self) return self.shown end,
        SetText = function(self, text) self.text = text end,
        GetText = function(self) return rawget(self, "text") end,
        SetHeight = function(self, height) self.height = height end,
        GetHeight = function(self) return rawget(self, "height") or 10 end,
        GetWidth = function() return 140 end,
        GetStringWidth = function() return 40 end,
        GetCenter = function() return 100, 100 end,
        GetEffectiveScale = function() return 1 end,
        GetPoint = function() return "CENTER", nil, "CENTER", 10, 20 end,
        SetValue = function(self, value)
            if issecretvalue(value) then
                value = value.value
            end
            self.barValue = value
        end,
        CreateTexture = function() return NewObject("Texture") end,
        CreateFontString = function() return NewObject("FontString") end,
    }
    return setmetatable(object, {
        __index = function(_, key)
            return methods[key] or function() end
        end,
    })
end

function CreateFrame(kind, name)
    local frame = NewObject(kind)
    table.insert(Mock.frames, frame)
    if name then
        _G[name] = frame
    end
    if not Mock.eventFrame then
        Mock.eventFrame = frame
    end
    return frame
end

UIParent = NewObject("Frame")
Minimap = NewObject("Frame")
GameTooltip = NewObject("GameTooltip")

function Mock.Fire(event, ...)
    local handler = Mock.eventFrame.scripts.OnEvent
    if Mock.eventFrame.events[event] then
        handler(Mock.eventFrame, event, ...)
    end
end

C_Timer = {
    After = function(_, fn)
        table.insert(Mock.timers, fn)
    end,
    NewTicker = function()
        return { Cancel = function() end }
    end,
}

function Mock.RunTimers()
    local timers = Mock.timers
    Mock.timers = {}
    for _, fn in ipairs(timers) do
        fn()
    end
end

function GetLocale()
    return Mock.locale or "enUS"
end

function GetTime()
    return world.now
end

function strtrim(text)
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

SlashCmdList = {}

function print(...)
    table.insert(Mock.printed, table.concat({ ... }, " "))
end

function InCombatLockdown()
    return world.inCombat
end

function IsInInstance()
    return world.inInstance, world.inInstance and "party" or "none"
end

function GetCursorPosition()
    return 0, 0
end

RAID_CLASS_COLORS = setmetatable({}, {
    __index = function() return { r = 0.5, g = 0.5, b = 0.5 } end,
})

-- Damage meter ----------------------------------------------------------------

Enum = {
    DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 },
    DamageMeterType = { DamageDone = 0, Dps = 1 },
}

C_DamageMeter = {
    GetCombatSessionFromType = function(sessionType, meterType)
        world.meterRequest = { sessionType, meterType }
        return world.meter
    end,
}

-- Challenge mode and scenario -----------------------------------------------------

C_ChallengeMode = {
    IsChallengeModeActive = function() return world.key ~= nil end,
    GetActiveChallengeMapID = function() return world.key and world.key.mapID end,
    GetMapUIInfo = function(mapID)
        local key = world.key
        if key and key.mapID == mapID then
            return key.name, mapID, key.timeLimit
        end
    end,
    GetActiveKeystoneInfo = function() return world.key and world.key.level end,
    GetDeathCount = function() return world.key.deaths or 0, world.key.timeLost or 0 end,
    GetChallengeCompletionInfo = function() return { time = world.completionTime } end,
}

function GetWorldElapsedTime(timerID)
    return timerID, world.key and world.key.elapsed or 0, 1
end

C_ScenarioInfo = {
    GetScenarioStepInfo = function()
        return { numCriteria = world.key and #world.key.criteria or 0 }
    end,
    GetCriteriaInfo = function(index)
        return world.key and world.key.criteria[index]
    end,
}

-- Units and auras --------------------------------------------------------------------

local function Unit(unit)
    return world.units[unit]
end

function UnitExists(unit)
    return Unit(unit) ~= nil
end

function UnitIsConnected(unit)
    return Unit(unit) ~= nil and Unit(unit).connected ~= false
end

function UnitIsVisible(unit)
    return Unit(unit) ~= nil and Unit(unit).visible ~= false
end

function UnitName(unit)
    return Unit(unit) and Unit(unit).name
end

function UnitClass(unit)
    local class = Unit(unit) and Unit(unit).class
    return class, class
end

C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index)
        local data = Unit(unit)
        local aura = data and data.auras and data.auras[index]
        if not aura then
            return nil
        end
        return { name = aura[1], icon = aura[2] }
    end,
}

function Mock.LoadAddon(files)
    local ns = {}
    Mock.eventFrame = nil
    for _, path in ipairs(files) do
        local chunk = assert(loadfile(path))
        chunk("MythicEssentials", ns)
    end
    return ns
end

Mock.Reset()

return Mock
