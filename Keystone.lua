local _, ns = ...

-- The running key: timer, chest thresholds, enemy forces and bosses, read from the
-- challenge mode and scenario APIs, in the spirit of WarpDeplete but smaller.

ns.CHEST_FRACTIONS = { 0.6, 0.8, 1 } -- +3, +2, +1: shares of the time limit

local killTimes = {}     -- [boss name] = elapsed seconds when it was first seen dead
local currentMapID = nil
local completedState = nil

local function Call(fn, ...)
    if not fn then
        return nil
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        return nil
    end
    return unpack(results, 2)
end

local function ElapsedSeconds()
    local _, elapsed = Call(GetWorldElapsedTime, 1)
    return tonumber(elapsed) or 0
end

-- Enemy forces: the criterion with weighted progress. Its quantityString holds the raw
-- count ("231%" or "231"), totalQuantity the count needed; quantity is a percentage.
function ns.ReadForces(info)
    local total = tonumber(info.totalQuantity) or 0
    local current = info.quantityString and tonumber(string.match(info.quantityString, "%d+"))
    if not current then
        current = (tonumber(info.quantity) or 0) * total / 100
    end
    local percent = total > 0 and math.min(current / total * 100, 100) or 0
    if info.completed then
        percent = 100
    end
    return { current = current, total = total, percent = percent, completed = info.completed == true }
end

local function ReadCriteria(elapsed)
    local bosses, forces = {}, nil
    local stepInfo = C_ScenarioInfo and Call(C_ScenarioInfo.GetScenarioStepInfo)
    local count = stepInfo and stepInfo.numCriteria or 0
    for index = 1, count do
        local info = Call(C_ScenarioInfo.GetCriteriaInfo, index)
        if info then
            if info.isWeightedProgress then
                forces = ns.ReadForces(info)
            else
                local name = info.description or ""
                if info.completed and not killTimes[name] then
                    killTimes[name] = elapsed
                end
                table.insert(bosses, { name = name, completed = info.completed == true, time = killTimes[name] })
            end
        end
    end
    return bosses, forces
end

-- The key now, or nil outside of one:
-- { mapName, level, timeLimit, elapsed, deaths, timeLost, bosses, forces, completed }
function ns.GetKeystoneState()
    if completedState then
        return completedState
    end
    if not (C_ChallengeMode and Call(C_ChallengeMode.IsChallengeModeActive)) then
        return nil
    end
    local mapID = Call(C_ChallengeMode.GetActiveChallengeMapID)
    if not mapID then
        return nil
    end
    if mapID ~= currentMapID then
        currentMapID = mapID
        killTimes = {}
    end
    local mapName, _, timeLimit = Call(C_ChallengeMode.GetMapUIInfo, mapID)
    local level = Call(C_ChallengeMode.GetActiveKeystoneInfo)
    local deaths, timeLost = Call(C_ChallengeMode.GetDeathCount)
    local elapsed = ElapsedSeconds()
    local bosses, forces = ReadCriteria(elapsed)
    return {
        mapName = mapName or "",
        level = level or 0,
        timeLimit = timeLimit or 0,
        elapsed = elapsed,
        deaths = deaths or 0,
        timeLost = timeLost or 0,
        bosses = bosses,
        forces = forces or { current = 0, total = 0, percent = 0, completed = false },
        completed = false,
    }
end

-- What the window shows of the timer: the time left before the next chest is lost.
-- { remaining, chest (3, 2, 1 or 0), nextLimit, thresholds = { +3 time, +2 time } }
function ns.TimerView(state)
    local limit = state.timeLimit or 0
    local elapsed = state.elapsed or 0
    local thresholds = {}
    for index, fraction in ipairs(ns.CHEST_FRACTIONS) do
        thresholds[index] = limit * fraction
    end
    local chest, nextLimit = 0, limit
    for index, threshold in ipairs(thresholds) do
        if elapsed <= threshold then
            chest = 4 - index
            nextLimit = threshold
            break
        end
    end
    return {
        remaining = nextLimit - elapsed,
        overall = limit - elapsed,
        chest = chest,
        nextLimit = nextLimit,
        thresholds = thresholds,
    }
end

-- Keeps the final state on screen once the key ends, until the player leaves the dungeon.
ns.OnEvent("CHALLENGE_MODE_COMPLETED", function()
    local state = ns.GetKeystoneState()
    if not state then
        return
    end
    local info = Call(C_ChallengeMode.GetChallengeCompletionInfo)
    if info and tonumber(info.time) then
        state.elapsed = info.time / 1000
    end
    state.completed = true
    state.forces.percent = 100
    completedState = state
end)

local function Clear()
    completedState = nil
    currentMapID = nil
    killTimes = {}
end

ns.OnEvent("CHALLENGE_MODE_START", Clear)
ns.OnEvent("CHALLENGE_MODE_RESET", Clear)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    local inInstance = Call(IsInInstance)
    if not inInstance then
        Clear()
    end
end)
