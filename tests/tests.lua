-- The test suite. Returns true when a test failed.

local Mock = dofile("tests/wow_mock.lua")

local FILES = {
    "Locales/frFR.lua", "Locales.lua", "Core.lua", "Meter.lua", "Keystone.lua", "Consumables.lua",
    "UI/Window.lua", "UI/MinimapButton.lua",
}

local tests, failures = {}, 0

local function test(name, fn)
    table.insert(tests, { name = name, fn = fn })
end

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end

-- A fresh client and addon, logged in.
local function setup()
    Mock.Reset()
    MythicEssentialsDB = nil
    local ns = Mock.LoadAddon(FILES)
    Mock.Fire("ADDON_LOADED", "MythicEssentials")
    Mock.Fire("PLAYER_LOGIN")
    return ns, Mock.world
end

local function source(class, amount, fields)
    fields = fields or {}
    fields.classFilename = class
    fields.name = fields.name or class
    fields.totalAmount = amount
    fields.amountPerSecond = fields.amountPerSecond or amount / 100
    return fields
end

local function key(w, fields)
    w.key = {
        mapID = 500, name = "Test Hold", timeLimit = 1800, level = 10, elapsed = 600,
        deaths = 0, timeLost = 0,
        criteria = {
            { description = "Boss One", completed = false },
            { description = "Boss Two", completed = false },
            { description = "Enemy Forces", isWeightedProgress = true, quantity = 50,
              quantityString = "170%", totalQuantity = 340, completed = false },
        },
    }
    for k, v in pairs(fields or {}) do
        w.key[k] = v
    end
    return w.key
end

-- Formatting ----------------------------------------------------------------------

test("numbers are short", function()
    local ns = setup()
    eq(ns.FormatNumber(845.4), "845")
    eq(ns.FormatNumber(12345), "12.3k")
    eq(ns.FormatNumber(1250000), "1.25M")
    eq(ns.FormatNumber(2.5e9), "2.50B")
end)

test("a secret number is shown through the game's formatter", function()
    local ns = setup()
    eq(ns.DisplayNumber(Mock.Secret(5)), "S5")
    eq(ns.DisplayNumber(1500000), "1.50M")
    eq(ns.DisplayNumber(nil), "")
end)

test("clock", function()
    local ns = setup()
    eq(ns.FormatClock(65), "1:05")
    eq(ns.FormatClock(3723), "1:02:03")
    eq(ns.FormatClock(-30), "-0:30")
end)

-- Meter -----------------------------------------------------------------------------

test("meter rows: players only, best first, at most five, the run's damage", function()
    local ns, w = setup()
    w.meter = { combatSources = {
        source("MAGE", 900, { isLocalPlayer = true }),
        source(nil, 800),
        source("ROGUE", 700),
        source("PRIEST", 600),
        source("WARRIOR", 500),
        source("HUNTER", 400),
        source("DRUID", 300),
    } }
    local rows = ns.GetMeterRows()
    eq(#rows, 5)
    eq(rows[1].class, "MAGE")
    eq(rows[1].isPlayer, true)
    eq(rows[2].class, "ROGUE")
    eq(rows[2].isPlayer, false)
    eq(rows[5].class, "HUNTER")
    eq(w.meterRequest[1], Enum.DamageMeterSessionType.Overall)
    eq(w.meterRequest[2], Enum.DamageMeterType.DamageDone)
    local minValue, maxValue = ns.MeterBarRange(rows)
    eq(minValue, 0)
    eq(maxValue, 900)
end)

test("meter rows survive secret values", function()
    local ns, w = setup()
    w.meter = { combatSources = {
        { classFilename = "MAGE", name = Mock.Secret("Jaina"), totalAmount = Mock.Secret(900),
          amountPerSecond = Mock.Secret(9) },
    } }
    local rows = ns.GetMeterRows()
    eq(#rows, 1)
    eq(issecretvalue(rows[1].amount), true)
    local _, maxValue = ns.MeterBarRange(rows)
    eq(issecretvalue(maxValue), true)
    eq(issecretvalue(ns.ShortName(rows[1].name)), true)
    ns.UI.Refresh()
end)

test("no meter, no rows", function()
    local ns, w = setup()
    eq(#ns.GetMeterRows(), 0)
    w.meter = { combatSources = {} }
    eq(#ns.GetMeterRows(), 0)
    local saved = C_DamageMeter
    C_DamageMeter = nil
    eq(#ns.GetMeterRows(), 0)
    eq(ns.MeterAvailable(), false)
    C_DamageMeter = saved
end)

test("realm is left out of names", function()
    local ns = setup()
    eq(ns.ShortName("Jaina-Hyjal"), "Jaina")
    eq(ns.ShortName("Thrall"), "Thrall")
end)

-- Keystone ----------------------------------------------------------------------------

test("no key outside of challenge mode", function()
    local ns = setup()
    eq(ns.GetKeystoneState(), nil)
end)

test("key state: forces from the raw count, bosses in order", function()
    local ns, w = setup()
    key(w)
    local state = ns.GetKeystoneState()
    eq(state.mapName, "Test Hold")
    eq(state.level, 10)
    eq(state.forces.current, 170)
    eq(state.forces.total, 340)
    eq(state.forces.percent, 50)
    eq(#state.bosses, 2)
    eq(state.bosses[1].name, "Boss One")
    eq(state.bosses[1].completed, false)
end)

test("forces fall back on the percentage", function()
    local ns = setup()
    local forces = ns.ReadForces({ quantity = 25, totalQuantity = 200 })
    eq(forces.current, 50)
    eq(forces.percent, 25)
    eq(ns.ReadForces({ quantityString = "400%", totalQuantity = 340 }).percent, 100)
end)

test("a boss's kill time is the timer when it is first seen dead", function()
    local ns, w = setup()
    local k = key(w)
    ns.GetKeystoneState()
    k.criteria[1].completed = true
    k.elapsed = 700
    eq(ns.GetKeystoneState().bosses[1].time, 700)
    k.elapsed = 800
    eq(ns.GetKeystoneState().bosses[1].time, 700)
end)

test("timer view: the next chest and the time left for it", function()
    local ns = setup()
    local view = ns.TimerView({ timeLimit = 1800, elapsed = 600 })
    eq(view.chest, 3)
    eq(view.remaining, 1080 - 600)
    eq(view.thresholds[1], 1080)
    eq(view.thresholds[2], 1440)
    view = ns.TimerView({ timeLimit = 1800, elapsed = 1200 })
    eq(view.chest, 2)
    eq(view.remaining, 240)
    view = ns.TimerView({ timeLimit = 1800, elapsed = 1500 })
    eq(view.chest, 1)
    eq(view.remaining, 300)
    view = ns.TimerView({ timeLimit = 1800, elapsed = 1900 })
    eq(view.chest, 0)
    eq(view.remaining, -100)
end)

test("a completed key stays shown until the next one", function()
    local ns, w = setup()
    key(w)
    w.completionTime = 1500000
    Mock.Fire("CHALLENGE_MODE_COMPLETED")
    w.key = nil
    local state = ns.GetKeystoneState()
    eq(state.completed, true)
    eq(state.elapsed, 1500)
    eq(state.forces.percent, 100)
    Mock.Fire("CHALLENGE_MODE_START")
    eq(ns.GetKeystoneState(), nil)
end)

-- Consumables ------------------------------------------------------------------------

local function group(w)
    w.units.player = { name = "Me", class = "MAGE", auras = { { "Flask of Power", 1 }, { "Well Fed", 136000 } } }
    w.units.party1 = { name = "Tank", class = "WARRIOR", auras = { { "Well Fed", 136000 } } }
    w.units.party2 = { name = "Heal", class = "PRIEST", auras = { { "Some Buff", 2 } } }
    w.units.party3 = { name = "Far", class = "ROGUE", visible = false, auras = {} }
    w.units.party4 = { name = "Gone", class = "DRUID", connected = false, auras = {} }
end

test("buffs are recognised by name or icon", function()
    local ns = setup()
    eq(ns.ClassifyBuff("Flask of Alchemical Chaos", 1), "flask")
    eq(ns.ClassifyBuff("Fleeting Phial of Something", 1), "flask")
    eq(ns.ClassifyBuff("Hearty Well Fed", 1), "food")
    eq(ns.ClassifyBuff("Anything", 136000), "food")
    eq(ns.ClassifyBuff("Power Word: Fortitude", 1), nil)
    eq(ns.ClassifyBuff(nil, nil), nil)
end)

test("buffs in French", function()
    Mock.locale = "frFR"
    local ns = setup()
    eq(ns.ClassifyBuff("Flacon de chaos alchimique", 1), "flask")
    eq(ns.ClassifyBuff("Bien nourri", 1), "food")
    eq(ns.L["No flask"], "Sans flacon")
    Mock.locale = nil
end)

test("missing consumables list who, and skip who cannot be seen", function()
    local ns, w = setup()
    group(w)
    eq(ns.ScanConsumables(), true)
    eq(#ns.missing.flask, 2)
    eq(ns.missing.flask[1].name, "Tank")
    eq(ns.missing.flask[2].name, "Heal")
    eq(ns.missing.flask[2].class, "PRIEST")
    eq(#ns.missing.food, 1)
    eq(ns.missing.food[1].name, "Heal")
end)

test("everyone ready: nothing missing", function()
    local ns, w = setup()
    w.units.player = { name = "Me", class = "MAGE", auras = { { "Flask of Power", 1 }, { "Well Fed", 136000 } } }
    ns.ScanConsumables()
    eq(#ns.missing.flask, 0)
    eq(#ns.missing.food, 0)
end)

test("no scan in combat, the last result stays", function()
    local ns, w = setup()
    group(w)
    ns.ScanConsumables()
    w.inCombat = true
    w.units.party1.auras = {}
    eq(ns.ScanConsumables(), false)
    eq(#ns.missing.food, 1)
end)

test("secret auras leave the player out", function()
    local ns, w = setup()
    w.units.player = { name = "Me", class = "MAGE", auras = { { Mock.Secret("Flask"), 1 } } }
    ns.ScanConsumables()
    eq(#ns.missing.flask, 0)
end)

test("aura changes rescan after a short delay", function()
    local ns, w = setup()
    group(w)
    Mock.timers = {}
    Mock.Fire("UNIT_AURA", "party1")
    Mock.Fire("UNIT_AURA", "party2")
    Mock.Fire("UNIT_AURA", "target")
    eq(#Mock.timers, 1)
    Mock.RunTimers()
    eq(#ns.missing.flask, 2)
end)

-- Window --------------------------------------------------------------------------------

test("the window refreshes with a key, rows and missing consumables", function()
    local ns, w = setup()
    key(w, { deaths = 2, timeLost = 10 })
    w.meter = { combatSources = { source("MAGE", 900), source("ROGUE", 700) } }
    group(w)
    ns.ScanConsumables()
    ns.UI.Refresh()
    ns.UI.ToggleDemo()
    ns.UI.ToggleDemo()
    eq(MythicEssentialsWindow:IsShown(), true)
end)

test("commands", function()
    local ns = setup()
    SlashCmdList.MYTHICESSENTIALS("")
    eq(ns.db.shown, false)
    eq(MythicEssentialsWindow:IsShown(), false)
    SlashCmdList.MYTHICESSENTIALS("")
    eq(ns.db.shown, true)
    SlashCmdList.MYTHICESSENTIALS("lock")
    eq(ns.db.locked, true)
    SlashCmdList.MYTHICESSENTIALS("scale 5")
    eq(ns.db.scale, 2)
    SlashCmdList.MYTHICESSENTIALS("reset")
    eq(ns.db.scale, 1)
    eq(ns.db.point, nil)
    SlashCmdList.MYTHICESSENTIALS("minimap")
    eq(ns.db.minimap.hidden, true)
    SlashCmdList.MYTHICESSENTIALS("help")
    eq(string.find(Mock.printed[#Mock.printed], "Commands", 1, true) ~= nil, true)
    MythicEssentials_OnAddonCompartmentClick()
    eq(ns.db.shown, false)
end)

test("saved data keeps what was saved and fills the rest", function()
    Mock.Reset()
    MythicEssentialsDB = { scale = 1.5, minimap = { angle = 10, hidden = true } }
    local ns = Mock.LoadAddon(FILES)
    Mock.Fire("ADDON_LOADED", "MythicEssentials")
    eq(ns.db.scale, 1.5)
    eq(ns.db.minimap.angle, 10)
    eq(ns.db.shown, true)
    eq(ns.db.locked, false)
end)

-- Run -----------------------------------------------------------------------

-- The mock replaces print to capture the addon's chat lines, so the results use io.write.
for _, entry in ipairs(tests) do
    local ok, message = pcall(entry.fn)
    if ok then
        io.write("ok   ", entry.name, "\n")
    else
        failures = failures + 1
        io.write("FAIL ", entry.name, "\n     ", tostring(message), "\n")
    end
end
io.write(string.format("%d tests, %d failed\n", #tests, failures))
return failures > 0
