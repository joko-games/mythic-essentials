local _, ns = ...
local L = ns.L

-- The window: a small, movable frame. From the top: the key (title, timer, timer bar
-- with the chest marks, enemy forces, bosses) while one runs, the group's DPS, and the
-- consumables missing. Every part is laid out again on each refresh, so the window is
-- only as tall as what it shows.

local UI = {}
ns.UI = UI

local WIDTH = 190
local PAD = 4
local ROW_HEIGHT = 14
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local REFRESH_SECONDS = 0.5

-- Chest colours: +3, +2, +1, over time.
local CHEST_COLORS = {
    [3] = { 0.3, 0.85, 1 },
    [2] = { 0.35, 0.9, 0.35 },
    [1] = { 1, 0.82, 0.2 },
    [0] = { 1, 0.3, 0.3 },
}

local frame, ticker
local demo = false
local parts = {}

-- Helpers ---------------------------------------------------------------------

function UI.ClassColor(class)
    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(class)
        if color then
            return color.r, color.g, color.b
        end
    end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end
    return 0.6, 0.6, 0.6
end

local function ColoredName(name, class)
    local r, g, b = UI.ClassColor(class)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, ns.ShortName(name) or "?")
end

local function Text(parent, font, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

local function Bar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0.08)
    return bar
end

-- Values that may be secret go to the client through pcall: if a call refuses one,
-- the bar keeps its last value rather than breaking the refresh.
local function SetBar(bar, minValue, maxValue, value)
    pcall(bar.SetMinMaxValues, bar, minValue, maxValue)
    pcall(bar.SetValue, bar, value)
end

local function Place(region, y, height)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
    if height then
        region:SetHeight(height)
    end
    region:Show()
    return y + (height or region:GetHeight())
end

-- Building ----------------------------------------------------------------------

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint()
    ns.db.point = { point, relativePoint, x, y }
end

local function StartMoving()
    if not ns.db.locked then
        frame:StartMoving()
    end
end

local function StopMoving()
    frame:StopMovingOrSizing()
    SavePosition()
end

-- Rows and buttons take the mouse for their tooltips; dragging them moves the window.
local function PassDrag(region)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", StartMoving)
    region:SetScript("OnDragStop", StopMoving)
end

local function CreateKeyParts()
    parts.title = Text(frame, "GameFontNormalSmall")
    parts.title:SetHeight(ROW_HEIGHT)

    -- Timer line: time left before the next chest is lost, the chest, deaths.
    local timerLine = CreateFrame("Frame", nil, frame)
    timerLine:SetHeight(18)
    parts.timerLine = timerLine
    parts.remaining = Text(timerLine, "GameFontNormalLarge")
    parts.remaining:SetPoint("LEFT")
    parts.chest = Text(timerLine, "GameFontNormal")
    parts.chest:SetPoint("LEFT", parts.remaining, "RIGHT", 4, 0)
    parts.clock = Text(timerLine, "GameFontHighlightSmall", "RIGHT")
    parts.clock:SetPoint("RIGHT")

    parts.timerBar = Bar(frame, 6)
    parts.marks = {}
    for index = 1, 2 do
        local mark = parts.timerBar:CreateTexture(nil, "OVERLAY")
        mark:SetColorTexture(1, 1, 1, 0.9)
        mark:SetSize(1, 8)
        parts.marks[index] = mark
    end

    parts.forcesBar = Bar(frame, 12)
    parts.forcesBar:SetStatusBarColor(0.55, 0.3, 0.85)
    parts.forcesText = Text(parts.forcesBar, "GameFontHighlightSmall", "CENTER")
    parts.forcesText:SetAllPoints()
    parts.deaths = Text(parts.forcesBar, "GameFontHighlightSmall", "RIGHT")
    parts.deaths:SetPoint("RIGHT", -2, 0)

    parts.bosses = {}
end

local function BossLine(index)
    local line = parts.bosses[index]
    if not line then
        line = CreateFrame("Frame", nil, frame)
        line:SetHeight(12)
        line.name = Text(line, "GameFontHighlightSmall")
        line.name:SetPoint("LEFT")
        line.name:SetPoint("RIGHT", -36, 0)
        line.time = Text(line, "GameFontHighlightSmall", "RIGHT")
        line.time:SetPoint("RIGHT")
        parts.bosses[index] = line
    end
    return line
end

local function ShowRowTooltip(row)
    local data = row.data
    if not data then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    local r, g, b = UI.ClassColor(data.class)
    pcall(GameTooltip.SetText, GameTooltip, ns.ShortName(data.name) or "?", r, g, b)
    pcall(GameTooltip.AddDoubleLine, GameTooltip, L["DPS"], ns.DisplayNumber(data.perSecond), 0.8, 0.8, 0.8, 1, 1, 1)
    pcall(GameTooltip.AddDoubleLine, GameTooltip, L["Damage"], ns.DisplayNumber(data.amount), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:Show()
end

local function CreateMeterRows()
    parts.rows = {}
    for index = 1, ns.MAX_ROWS do
        local row = Bar(frame, ROW_HEIGHT)
        row.rank = Text(row, "GameFontHighlightSmall")
        row.rank:SetPoint("LEFT", 3, 0)
        row.value = Text(row, "GameFontHighlightSmall", "RIGHT")
        row.value:SetPoint("RIGHT", -3, 0)
        row:EnableMouse(true)
        PassDrag(row)
        row:SetScript("OnEnter", ShowRowTooltip)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        parts.rows[index] = row
    end
    parts.noData = Text(frame, "GameFontDisableSmall", "CENTER")
    parts.noData:SetHeight(ROW_HEIGHT)
end

local function ShowMissingTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(button.label)
    for _, player in ipairs(button.players or {}) do
        GameTooltip:AddLine(ColoredName(player.name, player.class))
    end
    GameTooltip:Show()
end

local function CreateConsumableParts()
    local line = CreateFrame("Frame", nil, frame)
    line:SetHeight(ROW_HEIGHT)
    parts.consumables = line
    parts.missingButtons = {}
    local labels = { flask = L["No flask"], food = L["No food"] }
    local previous
    for _, kind in ipairs(ns.CONSUMABLES) do
        local button = CreateFrame("Button", nil, line)
        button:SetHeight(ROW_HEIGHT)
        button.label = labels[kind]
        PassDrag(button)
        button.text = Text(button, "GameFontHighlightSmall")
        button.text:SetPoint("LEFT")
        button:SetScript("OnEnter", ShowMissingTooltip)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        parts.missingButtons[kind] = button
        button.previous = previous
        previous = button
    end
end

local function CreateWindow()
    frame = CreateFrame("Frame", "MythicEssentialsWindow", UIParent)
    frame:SetWidth(WIDTH)
    frame:SetHeight(40)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    PassDrag(frame)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.55)

    CreateKeyParts()
    CreateMeterRows()
    CreateConsumableParts()

    UI.ApplyPosition()
    frame:SetScale(ns.db.scale)
end

-- Data for /mye demo: a key and a group, to place the window outside a dungeon.
local function DemoData()
    local state = {
        mapName = L["Demo dungeon"], level = 12, timeLimit = 1980, elapsed = 1104,
        deaths = 3, timeLost = 15,
        forces = { current = 231, total = 340, percent = 67.9 },
        bosses = {
            { name = "First Boss", completed = true, time = 402 },
            { name = "Second Boss", completed = true, time = 951 },
            { name = "Third Boss", completed = false },
        },
    }
    local rows = {
        { class = "MAGE", name = "Mage", amount = 9.1e7, perSecond = 1.52e6 },
        { class = "DEMONHUNTER", name = "Demon Hunter", amount = 8.4e7, perSecond = 1.41e6 },
        { class = "EVOKER", name = "Evoker", amount = 7.0e7, perSecond = 1.17e6 },
        { class = "WARRIOR", name = "Warrior", amount = 4.2e7, perSecond = 7.0e5 },
        { class = "PRIEST", name = "Priest", amount = 1.1e7, perSecond = 1.8e5 },
    }
    local missing = {
        flask = { { name = "Warrior", class = "WARRIOR" }, { name = "Priest", class = "PRIEST" } },
        food = { { name = "Evoker", class = "EVOKER" } },
    }
    return state, rows, missing
end

-- Refresh -------------------------------------------------------------------------

local function LayoutKey(state, y)
    local view = ns.TimerView(state)
    local color = CHEST_COLORS[view.chest]

    parts.title:SetText(string.format("+%d  %s", state.level, state.mapName))
    y = Place(parts.title, y, ROW_HEIGHT)

    local remaining = state.completed and (state.timeLimit - state.elapsed) or view.remaining
    parts.remaining:SetText(ns.FormatClock(remaining))
    parts.remaining:SetTextColor(color[1], color[2], color[3])
    parts.chest:SetText(view.chest > 0 and ("+" .. view.chest) or "")
    parts.chest:SetTextColor(color[1], color[2], color[3])
    parts.clock:SetText(ns.FormatClock(state.elapsed) .. " / " .. ns.FormatClock(state.timeLimit))
    y = Place(parts.timerLine, y, 18)

    y = Place(parts.timerBar, y + 1, 6)
    SetBar(parts.timerBar, 0, math.max(state.timeLimit, 1), math.min(state.elapsed, state.timeLimit))
    parts.timerBar:SetStatusBarColor(color[1], color[2], color[3])
    local barWidth = WIDTH - 2 * PAD
    for index, mark in ipairs(parts.marks) do
        local share = ns.CHEST_FRACTIONS[index]
        mark:ClearAllPoints()
        mark:SetPoint("CENTER", parts.timerBar, "LEFT", barWidth * share, 0)
    end

    local forces = state.forces
    y = Place(parts.forcesBar, y + 3, 12)
    SetBar(parts.forcesBar, 0, 100, forces.percent)
    parts.forcesText:SetText(string.format("%.1f%%", forces.percent))
    parts.deaths:SetText(state.deaths > 0 and string.format("%d |cffff5555(-%ds)|r", state.deaths, state.timeLost) or "")

    y = y + 2
    for index, boss in ipairs(state.bosses) do
        local line = BossLine(index)
        line.name:SetText(boss.name)
        if boss.completed then
            line.name:SetTextColor(0.5, 0.5, 0.5)
            line.time:SetText(boss.time and ns.FormatClock(boss.time) or "|cff55ff55OK|r")
        else
            line.name:SetTextColor(1, 1, 1)
            line.time:SetText("")
        end
        y = Place(line, y, 12)
    end
    for index = #state.bosses + 1, #parts.bosses do
        parts.bosses[index]:Hide()
    end
    return y + 4
end

local function HideKey()
    parts.title:Hide()
    parts.timerLine:Hide()
    parts.timerBar:Hide()
    parts.forcesBar:Hide()
    for _, line in ipairs(parts.bosses) do
        line:Hide()
    end
end

local function LayoutMeter(rows, y)
    if #rows == 0 then
        parts.noData:SetText(ns.MeterAvailable() and L["No damage yet."] or L["Damage meter unavailable."])
        y = Place(parts.noData, y, ROW_HEIGHT)
    else
        parts.noData:Hide()
    end
    local minValue, maxValue = ns.MeterBarRange(rows)
    for index, row in ipairs(parts.rows) do
        local data = rows[index]
        row.data = data
        if data then
            local r, g, b = UI.ClassColor(data.class)
            row:SetStatusBarColor(r, g, b, 0.85)
            SetBar(row, minValue, maxValue, data.amount)
            row.rank:SetText(data.isPlayer and ("|cffffffff" .. index .. " <|r") or index)
            row.value:SetText(ns.DisplayNumber(data.perSecond))
            y = Place(row, y, ROW_HEIGHT) + 1
        else
            row:Hide()
        end
    end
    return y
end

local function LayoutConsumables(missing, y)
    local any = false
    local previous
    for _, kind in ipairs(ns.CONSUMABLES) do
        local button = parts.missingButtons[kind]
        local players = missing[kind] or {}
        button.players = players
        button:ClearAllPoints()
        if #players > 0 then
            any = true
            button.text:SetText(string.format("|cffff7755%s: %d|r", button.label, #players))
            button:SetWidth(button.text:GetStringWidth() + 2)
            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", 10, 0)
            else
                button:SetPoint("LEFT", parts.consumables, "LEFT", 0, 0)
            end
            button:Show()
            previous = button
        else
            button:Hide()
        end
    end
    if any then
        y = Place(parts.consumables, y + 1, ROW_HEIGHT)
    else
        parts.consumables:Hide()
    end
    return y
end

function UI.Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    local state, rows, missing
    if demo then
        state, rows, missing = DemoData()
    else
        state, rows, missing = ns.GetKeystoneState(), ns.GetMeterRows(), ns.missing
    end
    local y = PAD
    if state then
        y = LayoutKey(state, y)
    else
        HideKey()
    end
    y = LayoutMeter(rows, y)
    y = LayoutConsumables(missing, y)
    frame:SetHeight(y + PAD - 1)
end

-- Showing, moving, scaling ---------------------------------------------------------

local function StartTicker()
    if not ticker then
        ticker = C_Timer.NewTicker(REFRESH_SECONDS, UI.Refresh)
    end
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

function UI.SetShown(shown)
    ns.db.shown = shown
    if not frame then
        return
    end
    frame:SetShown(shown)
    if shown then
        StartTicker()
        UI.Refresh()
    else
        StopTicker()
    end
end

function UI.Toggle()
    UI.SetShown(not ns.db.shown)
end

function UI.ToggleDemo()
    demo = not demo
    if demo and not ns.db.shown then
        UI.SetShown(true)
    end
    UI.Refresh()
    ns.Print(demo and L["Demo on: /mye demo again to turn it off."] or L["Demo off."])
end

function UI.SetLocked(locked)
    ns.db.locked = locked
    ns.Print(locked and L["Window locked."] or L["Window unlocked: drag it to move it."])
end

function UI.SetScale(scale)
    scale = math.max(0.5, math.min(2, scale))
    ns.db.scale = scale
    if frame then
        frame:SetScale(scale)
    end
end

function UI.ApplyPosition()
    frame:ClearAllPoints()
    local point = ns.db.point
    if point then
        frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60)
    end
end

function UI.ResetPosition()
    ns.db.point = nil
    ns.db.scale = 1
    if frame then
        frame:SetScale(1)
        UI.ApplyPosition()
    end
end

ns.OnEvent("PLAYER_LOGIN", function()
    CreateWindow()
    UI.SetShown(ns.db.shown)
end)

local function RefreshSoon()
    ns.Debounce("refresh", 0.1, UI.Refresh)
end

for _, event in ipairs({
    "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    "SCENARIO_CRITERIA_UPDATE", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
}) do
    ns.OnEvent(event, RefreshSoon)
end
