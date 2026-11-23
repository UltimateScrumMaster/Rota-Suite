-- RotaCore/Minimap.lua — Minimap Button & Quick Access Launcher (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local MinimapModule = {
    button = nil,
    isDragging = false,
}
RotaCore.Minimap = MinimapModule

local RADIUS = 80

--- Updates the button's position around the Minimap edge based on degrees angle.
-- @param angle number Degrees (0 - 360)
function MinimapModule:UpdatePosition(angle)
    if not self.button or not _G.Minimap then return end

    local rad = math.rad(angle or 45)
    local x = math.cos(rad) * RADIUS
    local y = math.sin(rad) * RADIUS

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", _G.Minimap, "CENTER", x, y)

    if _G.RotaCoreDB and _G.RotaCoreDB.settings then
        _G.RotaCoreDB.settings.minimapPos = angle
    end
end

--- Toggles button visibility.
function MinimapModule:SetShown(shown)
    if not self.button then return end
    if shown then
        self.button:Show()
    else
        self.button:Hide()
    end
    if _G.RotaCoreDB and _G.RotaCoreDB.settings then
        _G.RotaCoreDB.settings.showMinimap = shown and true or false
    end
end

--- Initializes the Minimap button frame, textures and interaction scripts.
function MinimapModule:Init()
    if self.button or not _G.CreateFrame or not _G.Minimap then return end

    local btn = _G.CreateFrame("Button", "RotaMinimapButton", _G.Minimap)
    btn:SetSize(32, 32)
    if btn.SetFrameStrata then btn:SetFrameStrata("MEDIUM") end
    if btn.EnableMouse then btn:EnableMouse(true) end
    if btn.SetMovable then btn:SetMovable(true) end

    -- Icon Texture
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_SealOfWisdom")
    btn.icon = icon

    -- Circular Tracking Border Overlay
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -10, 10)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border = border

    if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    if btn.RegisterForDrag then btn:RegisterForDrag("LeftButton") end

    -- Dragging Handler
    btn:SetScript("OnDragStart", function(frame)
        frame.isDragging = true
        frame:SetScript("OnUpdate", function(f)
            if not f.isDragging or not _G.GetCursorPosition or not _G.Minimap then return end
            local cx, cy = _G.GetCursorPosition()
            local scale = _G.Minimap:GetEffectiveScale() or 1
            cx, cy = cx / scale, cy / scale
            local mx, my = _G.Minimap:GetCenter()
            if mx and my then
                local angle = math.deg(math.atan2(cy - my, cx - mx))
                if angle < 0 then angle = angle + 360 end
                MinimapModule:UpdatePosition(angle)
            end
        end)
    end)

    btn:SetScript("OnDragStop", function(frame)
        frame.isDragging = false
        frame:SetScript("OnUpdate", nil)
    end)

    -- Click: el panel de opciones (el mismo de Interfaz > AddOns). Click derecho: el editor de rotaciones.
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if not _G.RotaEditor and _G.LoadAddOn then _G.LoadAddOn("RotaEditor") end
            if _G.RotaEditor and _G.RotaEditor.Toggle then _G.RotaEditor:Toggle() end
        elseif RotaCore.Options and RotaCore.Options.Open then
            RotaCore.Options:Open()
        end
    end)

    btn:SetScript("OnEnter", function(frame)
        if not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        _G.GameTooltip:AddLine("|cFFFFFF00Rota Suite|r — v" .. (RotaCore.version or "1.0.0"), 1, 1, 1)
        local p = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
        local pName = (p and p.meta and p.meta.name) or "Ninguno"
        _G.GameTooltip:AddLine("Rotación: |cFF00FF00" .. pName .. "|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine("|cFFFFFFFFClick:|r Opciones", 0.8, 1, 0.8)
        _G.GameTooltip:AddLine("|cFFFFFFFFClick derecho:|r Editor de rotaciones", 0.8, 1, 0.8)
        _G.GameTooltip:AddLine("|cFF888888Arrastrar: mover por el borde del minimapa|r", 0.6, 0.6, 0.6)
        _G.GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        if _G.GameTooltip and _G.GameTooltip.Hide then
            _G.GameTooltip:Hide()
        end
    end)

    self.button = btn

    -- Restore saved position and visibility
    local savedAngle = 45
    local show = true
    if _G.RotaCoreDB and _G.RotaCoreDB.settings then
        if _G.RotaCoreDB.settings.minimapPos then
            savedAngle = _G.RotaCoreDB.settings.minimapPos
        end
        if _G.RotaCoreDB.settings.showMinimap ~= nil then
            show = _G.RotaCoreDB.settings.showMinimap
        end
    end

    self:UpdatePosition(savedAngle)
    self:SetShown(show)
end

return MinimapModule
