local _, ns = ...
local L = ns.L
local UI = ns.UI

-- A button on the edge of the minimap, with the addon's icon. Its look and geometry
-- follow LibDBIcon, as in Trading Essentials, without embedding the library.
local TEXTURE_BORDER = 136430 -- Interface\Minimap\MiniMap-TrackingBorder
local TEXTURE_BACKGROUND = 136467 -- Interface\Minimap\UI-Minimap-Background
local TEXTURE_HIGHLIGHT = 136477 -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight
local EDGE_OFFSET = 5

local button = nil
local dragging = false

local function PlaceAt(angle)
    local radians = math.rad(angle)
    local radiusX = Minimap:GetWidth() / 2 + EDGE_OFFSET
    local radiusY = Minimap:GetHeight() / 2 + EDGE_OFFSET
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radiusX, math.sin(radians) * radiusY)
end

-- The cursor comes in screen pixels and the minimap's center in its own scale.
local function FollowCursor()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
    ns.db.minimap.angle = angle
    PlaceAt(angle)
end

local function ShowTooltip(self)
    if dragging then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Mythic Essentials")
    GameTooltip:AddLine(L["Left-click: show or hide the window"], 1, 1, 1)
    GameTooltip:AddLine(L["Right-click: lock or unlock the window"], 1, 1, 1)
    GameTooltip:AddLine(L["Drag: move this icon"], 1, 1, 1)
    GameTooltip:AddLine(L["/mye minimap: hide this icon"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function CreateButton()
    button = CreateFrame("Button", "MythicEssentialsMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFixedFrameStrata(true)
    button:SetFrameLevel(8)
    button:SetFixedFrameLevel(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(TEXTURE_HIGHLIGHT)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetTexture(TEXTURE_BORDER)
    border:SetPoint("TOPLEFT", button, "TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture(TEXTURE_BACKGROUND)
    background:SetPoint("CENTER", button, "CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture(ns.ICON)
    icon:SetPoint("CENTER", button, "CENTER")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            UI.SetLocked(not ns.db.locked)
        else
            UI.Toggle()
        end
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(self)
        dragging = true
        GameTooltip:Hide()
        self:LockHighlight()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        dragging = false
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)
end

function UI.ToggleMinimapButton()
    local settings = ns.db.minimap
    settings.hidden = not settings.hidden
    if button then
        button:SetShown(not settings.hidden)
    end
    if settings.hidden then
        ns.Print(L["Minimap icon hidden. Type /mye minimap to bring it back."])
    end
end

ns.OnEvent("PLAYER_LOGIN", function()
    CreateButton()
    PlaceAt(ns.db.minimap.angle)
    button:SetShown(not ns.db.minimap.hidden)
end)
