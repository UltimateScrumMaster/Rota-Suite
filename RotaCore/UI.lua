-- RotaCore/UI.lua — Heads-Up Display (HUD) for Next GCD & Off-GCD Actions (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local UI = {
    hudFrame = nil,
    controlsFrame = nil,
    buttonBar = nil,
    mainIcon = nil,
    offIcon = nil,
    cornerIcon = nil,
    mainIconSize = 48,
    dragOverlay = nil,
    controlsDragOverlay = nil,
    isLocked = true,
    throttle = 0.05, -- 20 Hz evaluation rate
    elapsedAccumulator = 0,
    currentMainAction = nil,
    currentOffAction = nil,
}
RotaCore.UI = UI

-- Default fallback texture (blank/transparent or question mark)
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

--- Persists current HUD coordinates in RotaCoreDB
function UI:SavePosition()
    if not UI.hudFrame or not UI.hudFrame.GetPoint then return end
    local point, _, relPoint, x, y = UI.hudFrame:GetPoint()
    if _G.RotaCoreDB then
        if not _G.RotaCoreDB.settings then
            _G.RotaCoreDB.settings = {}
        end
        _G.RotaCoreDB.settings.x = x or 0
        _G.RotaCoreDB.settings.y = y or -120
        _G.RotaCoreDB.settings.hudPosition = {
            point = point or "CENTER",
            relPoint = relPoint or "CENTER",
            x = x or 0,
            y = y or -120,
        }
    end
end

--- Persists current HUD Controls coordinates in RotaCoreDB
function UI:SaveControlsPosition()
    if not UI.controlsFrame or not UI.controlsFrame.GetPoint then return end
    local point, _, relPoint, x, y = UI.controlsFrame:GetPoint()
    if _G.RotaCoreDB then
        if not _G.RotaCoreDB.settings then
            _G.RotaCoreDB.settings = {}
        end
        _G.RotaCoreDB.settings.controlsX = x or 0
        _G.RotaCoreDB.settings.controlsY = y or -60
        _G.RotaCoreDB.settings.hudControlsPosition = {
            point = point or "CENTER",
            relPoint = relPoint or "CENTER",
            x = x or 0,
            y = y or -60,
        }
    end
end

--- Resets position of HUD and Controls frames back to defaults
function UI:ResetPosition()
    local parent = _G.UIParent or nil
    if UI.hudFrame then
        UI.hudFrame:ClearAllPoints()
        UI.hudFrame:SetPoint("CENTER", parent or UI.hudFrame, "CENTER", 0, -120)
        UI:SavePosition()
    end
    if UI.controlsFrame then
        UI.controlsFrame:ClearAllPoints()
        UI.controlsFrame:SetPoint("CENTER", parent or UI.controlsFrame, "CENTER", 0, -60)
        UI:SaveControlsPosition()
    end
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Posición del HUD y Controles restablecida.")
    end
end

--- Configures dragging handlers on a frame so it moves UI.hudFrame
local function SetupDragHandlers(frame)
    if not frame then return end
    if frame.SetMovable then
        frame:SetMovable(true)
    end
    if frame.RegisterForDrag then
        frame:RegisterForDrag("LeftButton")
    end
    frame:SetScript("OnDragStart", function()
        if not UI.isLocked and UI.hudFrame and UI.hudFrame.StartMoving then
            UI.hudFrame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if UI.hudFrame and UI.hudFrame.StopMovingOrSizing then
            UI.hudFrame:StopMovingOrSizing()
        end
        UI:SavePosition()
    end)
end

--- Configures dragging handlers on a frame so it moves UI.controlsFrame
local function SetupControlsDragHandlers(frame)
    if not frame then return end
    if frame.SetMovable then
        frame:SetMovable(true)
    end
    if frame.RegisterForDrag then
        frame:RegisterForDrag("LeftButton")
    end
    frame:SetScript("OnDragStart", function()
        if not UI.isLocked and UI.controlsFrame and UI.controlsFrame.StartMoving then
            UI.controlsFrame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if UI.controlsFrame and UI.controlsFrame.StopMovingOrSizing then
            UI.controlsFrame:StopMovingOrSizing()
        end
        UI:SaveControlsPosition()
    end)
end

--- Toggles or sets the HUD locked status
-- When unlocked, allows moving via hudFrame, mainIcon, offIcon, and dragOverlay.
-- Shows a green semi-transparent box with drag instructions.
function UI:SetLocked(locked)
    UI.isLocked = (locked ~= false)
    if _G.RotaCoreDB and _G.RotaCoreDB.settings then
        _G.RotaCoreDB.settings.locked = UI.isLocked
    end

    if UI.dragOverlay then
        if UI.isLocked then
            UI.dragOverlay:Hide()
        else
            UI.dragOverlay:Show()
        end
    end

    if UI.controlsDragOverlay then
        if UI.isLocked then
            UI.controlsDragOverlay:Hide()
            if UI.controlsDragOverlay.EnableMouse then
                UI.controlsDragOverlay:EnableMouse(false)
            end
        else
            UI.controlsDragOverlay:Show()
            if UI.controlsDragOverlay.EnableMouse then
                UI.controlsDragOverlay:EnableMouse(true)
            end
            if UI.controlsDragOverlay.RegisterForDrag then
                UI.controlsDragOverlay:RegisterForDrag("LeftButton")
            end
        end
    end

    -- When unlocked, disable button mouse clicks so drag is received by controlsDragOverlay
    -- When locked, re-enable button mouse clicks
    local buttonsEnabled = UI.isLocked
    if UI.buildBtn and UI.buildBtn.EnableMouse then
        UI.buildBtn:EnableMouse(buttonsEnabled)
    end
    if UI.aoeBtn and UI.aoeBtn.EnableMouse then
        UI.aoeBtn:EnableMouse(buttonsEnabled)
    end
    if UI.burstBtn and UI.burstBtn.EnableMouse then
        UI.burstBtn:EnableMouse(buttonsEnabled)
    end
    if UI.menuBtn and UI.menuBtn.EnableMouse then
        UI.menuBtn:EnableMouse(buttonsEnabled)
    end

    local enableMouse = not UI.isLocked
    if UI.hudFrame and UI.hudFrame.EnableMouse then
        UI.hudFrame:EnableMouse(enableMouse)
    end
    if UI.mainIcon and UI.mainIcon.frame and UI.mainIcon.frame.EnableMouse then
        UI.mainIcon.frame:EnableMouse(enableMouse)
    end
    if UI.offIcon and UI.offIcon.frame and UI.offIcon.frame.EnableMouse then
        UI.offIcon.frame:EnableMouse(enableMouse)
    end
end

--- Creates an icon frame with texture, cooldown text, and optional keybind label.
local function CreateActionIcon(name, parent, size)
    if not _G.CreateFrame then return nil end

    local frame = _G.CreateFrame("Frame", name, parent)
    frame:SetSize(size, size)

    -- In 3.3.5a, SetBackdrop is directly on the Frame without BackdropTemplate
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0.7) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9) end
    end

    local texture = nil
    if frame.CreateTexture then
        -- ARTWORK, no BACKGROUND: en 3.3.5 el backdrop (negro 0.7) se pinta en BACKGROUND y a veces queda encima del icono
        texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        texture:SetTexture(DEFAULT_ICON)
        if texture.SetDesaturated then texture:SetDesaturated(false) end
        if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
    end

    local cooldown = nil
    if _G.CreateFrame then
        cooldown = _G.CreateFrame("Cooldown", name .. "Cooldown", frame, "CooldownFrameTemplate")
        if cooldown then
            cooldown:SetAllPoints(frame)
            if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
            if cooldown.Hide then cooldown:Hide() end
        end
    end

    local bindText = nil
    if frame.CreateFontString then
        bindText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bindText:SetFontObject(GameFontNormal)
        bindText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    end

    local actionBorder = nil
    if frame.CreateTexture then
        actionBorder = frame:CreateTexture(name .. "ActionBorder", "OVERLAY")
        actionBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
        actionBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
        actionBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        actionBorder:SetBlendMode("ADD")
        if actionBorder.Hide then actionBorder:Hide() end
    end

    SetupDragHandlers(frame)

    return {
        frame = frame,
        texture = texture,
        cooldown = cooldown,
        bindText = bindText,
        actionBorder = actionBorder,
        size = size,
    }
end

--- Creates a compact interactive HUD button with backdrop and border
local function CreateHudButton(name, parent, width, height)
    if not _G.CreateFrame then return nil end
    local btn = _G.CreateFrame("Button", name, parent)
    btn:SetSize(width, height)
    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if btn.SetBackdropColor then btn:SetBackdropColor(0, 0, 0, 0.85) end
        if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9) end
    end
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetFontObject(GameFontNormalSmall or GameFontNormal)
    text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.text = text
    btn:EnableMouse(true)
    return btn
end

--- Cycles AoE mode: AUTO -> OFF -> ON -> AUTO
function UI:CycleAoEMode()
    if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
    if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
    local cur = _G.RotaCoreDB.settings.aoeMode
    local nextMode
    if cur == "AUTO" or cur == nil or (cur == true and _G.RotaCoreDB.settings.autoAoE ~= false) then
        nextMode = "OFF"
    elseif cur == "OFF" or cur == false then
        nextMode = "ON"
    else
        nextMode = "AUTO"
    end
    _G.RotaCoreDB.settings.aoeMode = nextMode
    if nextMode == "AUTO" then
        _G.RotaCoreDB.settings.autoAoE = true
    else
        _G.RotaCoreDB.settings.autoAoE = false
    end
    if RotaCore.State and RotaCore.State.data then
        if nextMode == "OFF" then
            RotaCore.State.data.aoeMode = false
            RotaCore.State.data.isAoE = false
        elseif nextMode == "ON" then
            RotaCore.State.data.aoeMode = true
            RotaCore.State.data.isAoE = true
        end
    end
    UI:UpdateButtonStates()
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        local colorStr = (nextMode == "AUTO" and "|cFF00CCFF") or (nextMode == "ON" and "|cFFFF2222") or "|cFF888888"
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Modo AoE: " .. colorStr .. "[" .. nextMode .. "]|r")
    end
end

--- Toggles Burst mode: ON <-> OFF
function UI:ToggleBurstMode()
    if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
    if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
    local cur = (_G.RotaCoreDB.settings.burstMode ~= false)
    _G.RotaCoreDB.settings.burstMode = not cur
    if RotaCore.State and RotaCore.State.data then
        RotaCore.State.data.burstMode = _G.RotaCoreDB.settings.burstMode
    end
    UI:UpdateButtonStates()
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        local colorStr = _G.RotaCoreDB.settings.burstMode and "|cFFFF8800[ON]|r" or "|cFF888888[OFF]|r"
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Modo Burst: " .. colorStr)
    end
end

--- Sets the Burst display mode: "SIDE", "INLINE", "CORNER"
function UI:SetBurstDisplayMode(mode)
    if not mode then return end
    mode = mode:upper()
    if mode ~= "SIDE" and mode ~= "INLINE" and mode ~= "CORNER" then
        mode = "SIDE"
    end
    if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
    if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
    _G.RotaCoreDB.burstDisplayMode = mode
    _G.RotaCoreDB.settings.burstDisplayMode = mode
    UI:UpdateDisplay(UI.currentMainAction, UI.currentOffAction)
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Modo Visual de Burst: |cFF00CCFF[" .. mode .. "]|r")
    end
end

--- Cycles Burst display mode: SIDE -> INLINE -> CORNER -> SIDE
function UI:CycleBurstDisplayMode()
    local db = _G.RotaCoreDB
    local cur = (db and (db.burstDisplayMode or (db.settings and db.settings.burstDisplayMode))) or "SIDE"
    local nextMode
    if cur == "SIDE" then
        nextMode = "INLINE"
    elseif cur == "INLINE" then
        nextMode = "CORNER"
    else
        nextMode = "SIDE"
    end
    UI:SetBurstDisplayMode(nextMode)
end

--- Sets the mini-icon scale for CORNER mode (0.10 to 0.50)
function UI:SetCornerScale(scale)
    local s = tonumber(scale) or 0.45
    if s > 1.0 then
        s = s / 100
    end
    if s < 0.10 then s = 0.10 end
    if s > 0.50 then s = 0.50 end
    if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
    if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
    _G.RotaCoreDB.cornerScale = s
    _G.RotaCoreDB.settings.cornerScale = s
    UI:UpdateDisplay(UI.currentMainAction, UI.currentOffAction)
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        local pct = math.floor(s * 100 + 0.5)
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Escala mini-icono Burst: |cFF00CCFF[" .. pct .. "%]|r")
    end
end

--- Cycles active Build according to player class:
-- DK: AUTO -> Frost -> UH Morb -> UH DW-SS -> UH 2H -> AUTO
-- Paladin: AUTO (Retribution)
-- Warrior: AUTO -> Fury (18/53) -> Fury OP (20/51) -> Arms (55/8/8) -> AUTO
function UI:CycleBuild()
    if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
    if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end

    local playerClass = "DEATHKNIGHT"
    if _G.UnitClass then
        local _, cls = _G.UnitClass("player")
        if cls then playerClass = cls end
    end

    local cur = RotaCore:GetSelectedBuild()
    local nextBuild = "auto"
    local nextPreset = nil

    local charName = (_G.UnitName and _G.UnitName("player")) or "Unknown"
    local realmName = (_G.GetRealmName and _G.GetRealmName()) or "Unknown"
    local charKey = charName .. " - " .. realmName

    _G.RotaCoreDB.charBuilds = _G.RotaCoreDB.charBuilds or {}
    _G.RotaCoreDB.classBuilds = _G.RotaCoreDB.classBuilds or {}

    local mod = RotaCore.GetClassModule and RotaCore:GetClassModule(playerClass)
    local builds = (mod and mod.builds) or (RotaCore.GetClassBuilds and RotaCore:GetClassBuilds(playerClass))

    if builds and #builds > 0 then
        local curIdx = 1
        for i, b in ipairs(builds) do
            if b.key == cur or b.key:lower() == cur:lower() then
                curIdx = i
                break
            end
        end
        local nextIdx = (curIdx % #builds) + 1
        nextBuild = builds[nextIdx].key
        nextPreset = builds[nextIdx].preset
    end

    _G.RotaCoreDB.settings.selectedBuild = nextBuild
    _G.RotaCoreDB.charBuilds[charKey] = nextBuild
    _G.RotaCoreDB.classBuilds[playerClass] = nextBuild

    if nextBuild == "auto" then
        if mod and mod.detectBuild then
            pcall(mod.detectBuild)
        elseif playerClass == "DEATHKNIGHT" and _G.RotaClass_DK and _G.RotaClass_DK.DetectBuild then
            pcall(function() _G.RotaClass_DK:DetectBuild() end)
        elseif playerClass == "WARRIOR" and _G.RotaClass_WAR and _G.RotaClass_WAR.DetectSpec then
            pcall(function() _G.RotaClass_WAR:DetectSpec() end)
        end
    elseif nextPreset and RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(nextPreset)
    else
        if mod and mod.detectBuild then
            pcall(mod.detectBuild)
        elseif playerClass == "DEATHKNIGHT" and _G.RotaClass_DK and _G.RotaClass_DK.DetectBuild then
            pcall(function() _G.RotaClass_DK:DetectBuild() end)
        elseif playerClass == "WARRIOR" and _G.RotaClass_WAR and _G.RotaClass_WAR.DetectSpec then
            pcall(function() _G.RotaClass_WAR:DetectSpec() end)
        end
    end

    if RotaCore.Options and RotaCore.Options.panel and RotaCore.Options.panel.buildDropDown then
        if _G.UIDropDownMenu_SetSelectedValue then
            _G.UIDropDownMenu_SetSelectedValue(RotaCore.Options.panel.buildDropDown, nextBuild)
        end
    end
    UI:UpdateButtonStates()
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Build " .. playerClass .. ": |cFF00CCFF[" .. nextBuild .. "]|r")
    end
end

--- Updates HUD button texts and colored borders based on state and settings
function UI:UpdateButtonStates()
    local settings = _G.RotaCoreDB and _G.RotaCoreDB.settings
    local state = RotaCore.State and RotaCore.State.data

    -- 1. AoE Tri-State Button
    if UI.aoeBtn and UI.aoeBtn.text then
        local aoeSetting = settings and settings.aoeMode
        if aoeSetting == "OFF" or aoeSetting == false then
            UI.aoeBtn.text:SetText("|cFF55FF55[AoE: OFF (ST)]|r")
            if UI.aoeBtn.SetBackdropBorderColor then
                UI.aoeBtn:SetBackdropBorderColor(0.3, 0.8, 0.3, 0.9)
            end
        elseif aoeSetting == "ON" or (aoeSetting == true and settings and settings.autoAoE == false) then
            UI.aoeBtn.text:SetText("|cFFFF2222[AoE: ON]|r")
            if UI.aoeBtn.SetBackdropBorderColor then
                UI.aoeBtn:SetBackdropBorderColor(1.0, 0.1, 0.1, 0.9)
            end
        else
            local count = state and state.aoeCount or 1
            UI.aoeBtn.text:SetText(string.format("|cFF00CCFF[AoE: AUTO (%d)]|r", count))
            if UI.aoeBtn.SetBackdropBorderColor then
                UI.aoeBtn:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.9)
            end
        end
    end

    -- 2. Burst Toggle Button
    if UI.burstBtn and UI.burstBtn.text then
        local burstActive = (settings and settings.burstMode ~= false)
        if burstActive then
            UI.burstBtn.text:SetText("|cFFFF8800[Burst: ON]|r")
            if UI.burstBtn.SetBackdropBorderColor then
                UI.burstBtn:SetBackdropBorderColor(1.0, 0.55, 0.0, 0.9)
            end
        else
            UI.burstBtn.text:SetText("|cFF888888[Burst: OFF]|r")
            if UI.burstBtn.SetBackdropBorderColor then
                UI.burstBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
            end
        end
    end

    -- 3. Build Selector Button
    if UI.buildBtn and UI.buildBtn.text then
        local playerClass = "DEATHKNIGHT"
        if _G.UnitClass then
            local _, cls = _G.UnitClass("player")
            if cls then playerClass = cls end
        end
        local sel = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or "auto"

        local mod = RotaCore.GetClassModule and RotaCore:GetClassModule(playerClass)
        local builds = (mod and mod.builds) or (RotaCore.GetClassBuilds and RotaCore:GetClassBuilds(playerClass))
        local matchedBuild = nil

        if builds then
            for _, b in ipairs(builds) do
                if b.key == sel or b.key:lower() == sel:lower()
                   or (b.name and b.name:lower() == sel:lower()) then
                    matchedBuild = b
                    break
                end
            end
        end

        -- Clase con una sola spec (Paladin Retri, Sacerdote Shadow): no hay AUTO, siempre esa build
        if not matchedBuild and builds and #builds == 1 then matchedBuild = builds[1] end

        -- Legacy DK alias resolution
        if not matchedBuild and playerClass == "DEATHKNIGHT" then
            if sel == "frost" or sel == "Frost" or sel == "Frost (DW)" then
                for _, b in ipairs(builds or {}) do if b.key == "frost" then matchedBuild = b break end end
            elseif sel == "unholy_morb" or sel == "morb" or sel == "Unholy Morb (DW)" then
                for _, b in ipairs(builds or {}) do if b.key == "unholy_morb" then matchedBuild = b break end end
            elseif sel == "unholy_dw_ss" or sel == "dw_ss" or sel == "dwss" or sel == "ums" then
                for _, b in ipairs(builds or {}) do if b.key == "unholy_dw_ss" then matchedBuild = b break end end
            elseif sel == "unholy_2h" or sel == "unholy" or sel == "Unholy (2H)" or sel == "2h" then
                for _, b in ipairs(builds or {}) do if b.key == "unholy_2h" then matchedBuild = b break end end
            end
        end

        -- Legacy Warrior alias resolution
        if not matchedBuild and playerClass == "WARRIOR" then
            if sel == "fury" or sel == "Fury" or sel == "18/53" then
                for _, b in ipairs(builds or {}) do if b.key == "fury" then matchedBuild = b break end end
            elseif sel == "fury_overpower" or sel == "op" or sel == "overpower" or sel == "20/51" or sel == "fury_op" then
                for _, b in ipairs(builds or {}) do if b.key == "fury_overpower" then matchedBuild = b break end end
            elseif sel == "arms" or sel == "Arms" or sel == "55/8/8" then
                for _, b in ipairs(builds or {}) do if b.key == "arms" then matchedBuild = b break end end
            end
        end

        if matchedBuild and matchedBuild.key ~= "auto" then
            local c = matchedBuild.color or { 1.0, 0.9, 0.0 }
            local rByte = math.floor((c[1] or 1.0) * 255)
            local gByte = math.floor((c[2] or 1.0) * 255)
            local bByte = math.floor((c[3] or 1.0) * 255)
            local hex = string.format("|cFF%02X%02X%02X", rByte, gByte, bByte)
            UI.buildBtn.text:SetText(hex .. "[Build: " .. matchedBuild.name .. "]|r")
            if UI.buildBtn.SetBackdropBorderColor then
                UI.buildBtn:SetBackdropBorderColor(c[1] or 1.0, c[2] or 1.0, c[3] or 1.0, 0.9)
            end
        else
            UI.buildBtn.text:SetText("|cFFFFFF00[Build: AUTO]|r")
            if UI.buildBtn.SetBackdropBorderColor then
                UI.buildBtn:SetBackdropBorderColor(1.0, 0.9, 0.0, 0.9)
            end
        end
    end

    -- 4. Quick Menu Button
    if UI.menuBtn and UI.menuBtn.text then
        UI.menuBtn.text:SetText("|cFFFFFF00[Menú]|r")
    end
end

-- Textos del contador de espera armados una sola vez (el HUD corre a 20 Hz: sin string.format por frame)
local WAIT_TENTHS = {}   -- [0..99] = "0.0" .. "9.9"
for i = 0, 99 do WAIT_TENTHS[i] = string.format("%.1f", i / 10) end
local WAIT_SECONDS = {}  -- [10..99] = "10" .. "99"
for i = 10, 99 do WAIT_SECONDS[i] = tostring(i) end

local function WaitLabel(secs)
    if secs < 10 then return WAIT_TENTHS[math.floor(secs * 10)] or "0.0" end
    return WAIT_SECONDS[math.floor(secs)] or "99"
end
UI.WaitLabel = WaitLabel

--- Initializes the HUD UI frames. Called on ADDON_LOADED.
function UI:Init()
    if UI.hudFrame or not _G.CreateFrame then return end

    local parent = _G.UIParent or nil
    local hud = _G.CreateFrame("Frame", "RotaCoreHUD", parent)
    hud:SetSize(110, 68)
    hud:SetPoint("CENTER", parent or hud, "CENTER", 0, -120)

    -- Enable dragging and screen clamping
    if hud.SetMovable then
        hud:SetMovable(true)
    end
    if hud.SetClampedToScreen then
        hud:SetClampedToScreen(true)
    end
    SetupDragHandlers(hud)

    -- Main Icon (Next GCD Action, 48x48)
    UI.mainIcon = CreateActionIcon("RotaCoreMainIcon", hud, 48)
    if UI.mainIcon and UI.mainIcon.frame then
        UI.mainIcon.frame:SetPoint("TOPLEFT", hud, "TOPLEFT", 0, 0)
        if UI.mainIcon.frame.CreateFontString then
            local alertBadge = UI.mainIcon.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            alertBadge:SetFontObject(GameFontHighlightSmall or GameFontNormalSmall)
            alertBadge:SetPoint("BOTTOM", UI.mainIcon.frame, "TOP", 0, 14)
            alertBadge:SetText("")
            alertBadge:Hide()
            UI.alertBadge = alertBadge

            -- Espera: segundos que faltan para la habilidad que muestra el icono (con la espiral de cooldown)
            local waitCount = UI.mainIcon.frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
            waitCount:SetFontObject(_G.NumberFontNormalLarge or GameFontNormalLarge or GameFontNormal)
            waitCount:SetPoint("CENTER", UI.mainIcon.frame, "CENTER", 0, 0)
            waitCount:SetText("")
            waitCount:Hide()
            UI.waitCount = waitCount

            -- Motivo de la sugerencia (state.reason), debajo del icono. Solo en modo aprendizaje (/rc aprender).
            local reasonText = UI.mainIcon.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            reasonText:SetFontObject(GameFontHighlightSmall or GameFontNormalSmall)
            reasonText:SetPoint("TOPLEFT", UI.mainIcon.frame, "BOTTOMLEFT", 0, -2)
            reasonText:SetJustifyH("LEFT")
            reasonText:SetText("")
            reasonText:Hide()
            UI.reasonText = reasonText
        end
    end

    -- Off Icon (Off-GCD / Next Swing Action, 32x32)
    UI.offIcon = CreateActionIcon("RotaCoreOffIcon", hud, 32)
    if UI.offIcon and UI.offIcon.frame then
        UI.offIcon.frame:SetPoint("LEFT", UI.mainIcon.frame, "RIGHT", 6, -8)
    end

    -- Corner Icon (Mini-icon in BOTTOMRIGHT corner of mainIcon for CORNER mode)
    if UI.mainIcon and UI.mainIcon.frame then
        local cFrame = _G.CreateFrame("Frame", "RotaCoreCornerIcon", UI.mainIcon.frame)
        local initialScale = 0.45
        if _G.RotaCoreDB then
            initialScale = _G.RotaCoreDB.cornerScale or (_G.RotaCoreDB.settings and _G.RotaCoreDB.settings.cornerScale) or 0.45
        end
        if initialScale < 0.10 then initialScale = 0.10 end
        if initialScale > 0.50 then initialScale = 0.50 end
        local cSize = math.floor(48 * initialScale + 0.5)
        cFrame:SetSize(cSize, cSize)
        cFrame:SetPoint("BOTTOMRIGHT", UI.mainIcon.frame, "BOTTOMRIGHT", 0, 0)
        if cFrame.SetFrameLevel and UI.mainIcon.frame.GetFrameLevel then
            cFrame:SetFrameLevel(UI.mainIcon.frame:GetFrameLevel() + 2)
        end

        local cTex = cFrame:CreateTexture(nil, "ARTWORK")
        cTex:SetPoint("TOPLEFT", cFrame, "TOPLEFT", 1, -1)
        cTex:SetPoint("BOTTOMRIGHT", cFrame, "BOTTOMRIGHT", -1, 1)
        cTex:SetTexture(DEFAULT_ICON)

        local cBorder = cFrame:CreateTexture(nil, "OVERLAY")
        cBorder:SetPoint("TOPLEFT", cFrame, "TOPLEFT", -2, 2)
        cBorder:SetPoint("BOTTOMRIGHT", cFrame, "BOTTOMRIGHT", 2, -2)
        cBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        cBorder:SetBlendMode("ADD")
        cBorder:SetVertexColor(0.2, 0.9, 1.0, 1.0)

        if cFrame.Hide then cFrame:Hide() end
        UI.cornerIcon = {
            frame = cFrame,
            texture = cTex,
            border = cBorder,
        }
    end

    -- HUD Badges FontString: Deprecated / Hidden (Replaced by decoupled interactive button bar)
    local badgesText = hud:CreateFontString("RotaCoreHUDSubBadges", "OVERLAY", "GameFontNormalSmall")
    badgesText:SetFontObject(GameFontNormalSmall or GameFontNormal)
    badgesText:SetPoint("TOPLEFT", UI.mainIcon.frame, "BOTTOMLEFT", 0, -4)
    badgesText:SetText("")
    badgesText:Hide()
    UI.badgesText = badgesText

    -- Independent Control Bar for Build, AoE and Burst (RotaCoreHUDControls)
    -- Parented directly to UIParent, 100% decoupled from hudFrame
    local controls = _G.CreateFrame("Frame", "RotaCoreHUDControls", parent)
    controls:SetSize(310, 24)
    if controls.SetFrameStrata then
        controls:SetFrameStrata("MEDIUM")
    end
    if controls.SetClampedToScreen then
        controls:SetClampedToScreen(true)
    end
    if controls.SetMovable then
        controls:SetMovable(true)
    end
    if controls.SetBackdrop then
        controls:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if controls.SetBackdropColor then
            controls:SetBackdropColor(0.08, 0.08, 0.12, 0.85)
        end
        if controls.SetBackdropBorderColor then
            controls:SetBackdropBorderColor(0.35, 0.35, 0.45, 0.9)
        end
    end

    local dbSettings = _G.RotaCoreDB and _G.RotaCoreDB.settings
    local ctrlX = (dbSettings and (dbSettings.controlsX or (dbSettings.hudControlsPosition and dbSettings.hudControlsPosition.x))) or 0
    local ctrlY = (dbSettings and (dbSettings.controlsY or (dbSettings.hudControlsPosition and dbSettings.hudControlsPosition.y))) or -60

    controls:ClearAllPoints()
    controls:SetPoint("CENTER", parent or controls, "CENTER", ctrlX, ctrlY)
    SetupControlsDragHandlers(controls)

    UI.controlsFrame = controls
    UI.buttonBar = controls
    UI.controls = controls

    -- Interactive Control Buttons
    UI.buildBtn = CreateHudButton("RotaCoreHUDBuildBtn", controls, 96, 20)
    if UI.buildBtn then
        UI.buildBtn:SetPoint("LEFT", controls, "LEFT", 2, 0)
        UI.buildBtn:SetScript("OnClick", function() UI:CycleBuild() end)
        UI.buildBtn:SetScript("OnEnter", function(btn)
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                _G.GameTooltip:AddLine("|cFFFFFF00Build de Rotación|r", 1, 1, 1)
                local playerClass = "DEATHKNIGHT"
                if _G.UnitClass then
                    local _, cls = _G.UnitClass("player")
                    if cls then playerClass = cls end
                end
                if playerClass == "DEATHKNIGHT" then
                    _G.GameTooltip:AddLine("Click Izquierdo: Auto -> Frost -> UH Morb (DW) -> UH Morb+SS (DW+SS) -> UH", 0.8, 1, 0.8)
                elseif playerClass == "PALADIN" then
                    _G.GameTooltip:AddLine("Click Izquierdo: Auto (Retribution)", 0.8, 1, 0.8)
                elseif playerClass == "WARRIOR" then
                    _G.GameTooltip:AddLine("Click Izquierdo: Auto -> Fury (18/53) -> Fury OP (20/51) -> Arms (55/8/8)", 0.8, 1, 0.8)
                else
                    _G.GameTooltip:AddLine("Click Izquierdo: Ciclar preset de rotación para tu clase actual", 0.8, 1, 0.8)
                end
                _G.GameTooltip:Show()
            end
        end)
        UI.buildBtn:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
    end

    UI.aoeBtn = CreateHudButton("RotaCoreHUDAoeBtn", controls, 96, 20)
    if UI.aoeBtn then
        UI.aoeBtn:SetPoint("LEFT", UI.buildBtn, "RIGHT", 4, 0)
        UI.aoeBtn:SetScript("OnClick", function() UI:CycleAoEMode() end)
        UI.aoeBtn:SetScript("OnEnter", function(btn)
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                _G.GameTooltip:AddLine("|cFFFFFF00Modo AoE|r", 1, 1, 1)
                _G.GameTooltip:AddLine("Click Izquierdo: Alternar modo AoE (AUTO / ON / OFF)", 0.8, 1, 0.8)
                _G.GameTooltip:Show()
            end
        end)
        UI.aoeBtn:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
    end

    UI.burstBtn = CreateHudButton("RotaCoreHUDBurstBtn", controls, 76, 20)
    if UI.burstBtn then
        UI.burstBtn:SetPoint("LEFT", UI.aoeBtn, "RIGHT", 4, 0)
        if UI.burstBtn.RegisterForClicks then
            UI.burstBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        UI.burstBtn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                UI:CycleBurstDisplayMode()
            else
                UI:ToggleBurstMode()
            end
        end)
        UI.burstBtn:SetScript("OnEnter", function(btn)
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                _G.GameTooltip:AddLine("|cFFFFFF00Modo Burst|r", 1, 1, 1)
                _G.GameTooltip:AddLine("Click Izquierdo: Alternar Burst ON/OFF", 0.8, 1, 0.8)
                _G.GameTooltip:AddLine("Click Derecho: Ciclar modo visual de Burst", 0.8, 0.8, 1)
                _G.GameTooltip:Show()
            end
        end)
        UI.burstBtn:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
    end

    UI.menuBtn = CreateHudButton("RotaCoreHUDMenuBtn", controls, 26, 20)
    if UI.menuBtn then
        UI.menuBtn:SetPoint("LEFT", UI.burstBtn, "RIGHT", 4, 0)
        -- Abre el panel de opciones (el mismo del minimapa y de Interfaz > AddOns)
        UI.menuBtn:SetScript("OnClick", function()
            if RotaCore.Options and RotaCore.Options.Open then RotaCore.Options:Open() end
        end)
        UI.menuBtn:SetScript("OnEnter", function(btn)
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                _G.GameTooltip:AddLine("|cFFFFFF00Opciones|r", 1, 1, 1)
                _G.GameTooltip:AddLine("Click: abrir las opciones de Rota Suite", 0.8, 1, 0.8)
                _G.GameTooltip:Show()
            end
        end)
        UI.menuBtn:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
    end

    UI:UpdateButtonStates()

    -- Semi-transparent green drag overlay for Controls Frame when unlocked
    local cOverlay = _G.CreateFrame("Frame", "RotaCoreHUDControlsDragOverlay", controls)
    cOverlay:SetAllPoints(controls)
    if cOverlay.SetFrameStrata then
        cOverlay:SetFrameStrata("DIALOG")
    end
    if cOverlay.SetBackdrop then
        cOverlay:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if cOverlay.SetBackdropColor then
            cOverlay:SetBackdropColor(0.0, 0.6, 0.0, 0.45)
        end
        if cOverlay.SetBackdropBorderColor then
            cOverlay:SetBackdropBorderColor(0.0, 1.0, 0.0, 0.95)
        end
    end
    local cOverlayText = cOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cOverlayText:SetFontObject(GameFontNormalSmall or GameFontNormal)
    cOverlayText:SetPoint("CENTER", cOverlay, "CENTER", 0, 0)
    cOverlayText:SetText("|cFFFFFF00ARRASTRAR CONTROLES|r")
    SetupControlsDragHandlers(cOverlay)
    UI.controlsDragOverlay = cOverlay

    -- Semi-transparent green drag overlay when unlocked
    local overlay = _G.CreateFrame("Frame", "RotaCoreHUDDragOverlay", hud)
    overlay:SetAllPoints(hud)
    if overlay.SetFrameStrata then
        overlay:SetFrameStrata("DIALOG")
    end
    if overlay.SetBackdrop then
        overlay:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if overlay.SetBackdropColor then
            overlay:SetBackdropColor(0.0, 0.6, 0.0, 0.45)
        end
        if overlay.SetBackdropBorderColor then
            overlay:SetBackdropBorderColor(0.0, 1.0, 0.0, 0.95)
        end
    end
    local overlayText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overlayText:SetFontObject(GameFontNormal)
    overlayText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    overlayText:SetText("|cFFFFFF00ARRASTRAR HUD\n(Click Izq)|r")
    overlayText:SetJustifyH("CENTER")
    SetupDragHandlers(overlay)
    UI.dragOverlay = overlay

    UI.hudFrame = hud

    -- Restore saved position if present
    if _G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.hudPosition then
        local pos = _G.RotaCoreDB.settings.hudPosition
        hud:ClearAllPoints()
        hud:SetPoint(pos.point or "CENTER", _G.UIParent or hud, pos.relPoint or "CENTER", pos.x or 0, pos.y or -120)
    end

    -- Apply initial locked state
    local initialLocked = true
    if _G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.locked ~= nil then
        initialLocked = _G.RotaCoreDB.settings.locked
    end
    UI:SetLocked(initialLocked)

    -- Zero-allocation OnUpdate driver throttled to 20 Hz
    hud:SetScript("OnUpdate", function(_, elapsed)
        UI.elapsedAccumulator = UI.elapsedAccumulator + elapsed
        if UI.elapsedAccumulator >= UI.throttle then
            UI.elapsedAccumulator = 0
            if RotaCore.UpdateAndEvaluate then
                RotaCore:UpdateAndEvaluate()
            end
        end
    end)
end

--- Returns default/fallback spell alias for active class and build when rotation is waiting.
function UI:GetSpecFallbackSpell()
    local curProf = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    local classToken = nil
    local buildType = nil
    if curProf and curProf.meta then
        classToken = curProf.meta.class
        buildType = curProf.meta.buildType or curProf.meta.id
    end
    if not classToken and _G.UnitClass then
        local _, c = _G.UnitClass("player")
        classToken = c
    end

    if RotaCore.GetIdlePreviewAction then
        local modAction = RotaCore:GetIdlePreviewAction(classToken, buildType)
        if modAction then
            return modAction
        end
    end

    if classToken == "DEATHKNIGHT" then
        if buildType == "unholy_morb" or buildType == "dk_unholy_morb_pve" or buildType == "dk_uh_morb" then
            return "DND"
        elseif buildType == "frost" or buildType == "dk_frost_pve" or buildType == "dk_frost" then
            return "OBL"
        elseif buildType == "unholy_dw_ss" or buildType == "dk_unholy_dw_ss_pve" then
            return "SS"
        else
            return "SS"
        end
    elseif classToken == "WARRIOR" then
        if buildType == "arms" or buildType == "war_arms_pve" then
            return "MS"
        else
            return "BT"
        end
    elseif classToken == "PALADIN" then
        return "CS"
    end
    return nil
end

--- Updates HUD textures based on current action aliases.
-- Zero table allocations in hot path.
-- @param mainAction string|nil Action alias for GCD
-- @param offAction string|nil Action alias for Off-GCD
function UI:UpdateDisplay(mainAction, offAction)
    UI.currentMainAction = mainAction
    UI.currentOffAction = offAction

    local db = _G.RotaCoreDB or {}
    local dbSettings = db.settings or db
    local burstDisplayMode = dbSettings.burstDisplayMode or db.burstDisplayMode or "SIDE"
    local cornerScale = dbSettings.cornerScale or db.cornerScale or 0.45
    if cornerScale < 0.10 then cornerScale = 0.10 end
    if cornerScale > 0.50 then cornerScale = 0.50 end

    local hasOffAction = (offAction and offAction ~= "WAIT" and offAction ~= "")
    local offIconPath = nil
    if hasOffAction and RotaCore.Spells then
        local _, _, icon = RotaCore.Spells:GetInfo(offAction)
        offIconPath = icon or DEFAULT_ICON
    end

    local isMainActionActive = (mainAction and mainAction ~= "WAIT" and mainAction ~= "")
    local state = RotaCore.State and RotaCore.State.data
    local hasAttackableTarget = state and (state.hasTarget and state.targetCanAttack and not state.targetIsDead)
    local inCombat = state and state.inCombat

    -- En combate o con objetivo atacable: nunca apagar ni mostrar "?" vacío.
    -- Si no hay acción principal activa, usar fallback de la spec.
    if (hasAttackableTarget or inCombat) and (not isMainActionActive) then
        local fallbackSpell = UI:GetSpecFallbackSpell()
        if fallbackSpell then
            mainAction = fallbackSpell
            isMainActionActive = true
            UI.currentMainAction = fallbackSpell
        end
    end

    local mainIconPath = DEFAULT_ICON
    if isMainActionActive and RotaCore.Spells then
        local _, _, icon = RotaCore.Spells:GetInfo(mainAction)
        mainIconPath = icon or DEFAULT_ICON
    end

    -- HUD e iconos siempre a alpha 1 y brillo total
    if UI.hudFrame and UI.hudFrame.SetAlpha then
        UI.hudFrame:SetAlpha(1.0)
    end

    local function ApplyIconFullBrightness(iconObj)
        if not iconObj then return end
        if iconObj.frame and iconObj.frame.SetAlpha then
            iconObj.frame:SetAlpha(1.0)
        end
        if iconObj.texture then
            if iconObj.texture.SetDesaturated then
                iconObj.texture:SetDesaturated(false)
            end
            if iconObj.texture.SetVertexColor then
                iconObj.texture:SetVertexColor(1, 1, 1, 1)
            end
        end
        if iconObj.cooldown then
            if iconObj.cooldown.SetDrawEdge then
                iconObj.cooldown:SetDrawEdge(false)
            end
            if iconObj.cooldown.Hide then
                iconObj.cooldown:Hide()
            end
        end
    end

    if burstDisplayMode == "CORNER" then
        -- MODO 3: "CORNER" (Mini-icono incrustado en esquina inferior derecha de mainIcon)
        if UI.offIcon and UI.offIcon.frame and UI.offIcon.frame.Hide then
            UI.offIcon.frame:Hide()
        end
        if UI.mainIcon and UI.mainIcon.actionBorder and UI.mainIcon.actionBorder.Hide then
            UI.mainIcon.actionBorder:Hide()
        end

        if UI.mainIcon and UI.mainIcon.texture then
            UI.mainIcon.texture:SetTexture(mainIconPath)
        end
        ApplyIconFullBrightness(UI.mainIcon)

        if UI.cornerIcon and UI.cornerIcon.frame then
            if hasOffAction then
                local sz = math.floor((UI.mainIconSize or 48) * cornerScale + 0.5)
                UI.cornerIcon.frame:SetSize(sz, sz)
                if UI.cornerIcon.texture then
                    UI.cornerIcon.texture:SetTexture(offIconPath)
                end
                ApplyIconFullBrightness(UI.cornerIcon)
                if UI.cornerIcon.border then
                    if UI.cornerIcon.border.SetVertexColor then
                        UI.cornerIcon.border:SetVertexColor(0.2, 0.9, 1.0, 1.0)
                    end
                    if UI.cornerIcon.border.Show then
                        UI.cornerIcon.border:Show()
                    end
                end
                if UI.cornerIcon.frame.Show then
                    UI.cornerIcon.frame:Show()
                end
            else
                if UI.cornerIcon.frame.Hide then
                    UI.cornerIcon.frame:Hide()
                end
            end
        end

    elseif burstDisplayMode == "INLINE" then
        -- MODO 2: "INLINE" (Integrado en el icono principal con borde brillante)
        if UI.offIcon and UI.offIcon.frame and UI.offIcon.frame.Hide then
            UI.offIcon.frame:Hide()
        end
        if UI.cornerIcon and UI.cornerIcon.frame and UI.cornerIcon.frame.Hide then
            UI.cornerIcon.frame:Hide()
        end

        if UI.mainIcon and UI.mainIcon.texture then
            if hasOffAction then
                local isOnNextSwing = (offAction == "HS" or offAction == "CLEAVE"
                    or offAction == "Heroic Strike" or offAction == "Cleave")

                if isOnNextSwing then
                    -- Ataques On-Next-Swing de Guerrero: no tapan el GCD principal, muestran borde dorado brillante
                    UI.mainIcon.texture:SetTexture(mainIconPath)
                    if UI.mainIcon.actionBorder then
                        if UI.mainIcon.actionBorder.SetVertexColor then
                            UI.mainIcon.actionBorder:SetVertexColor(1.0, 0.85, 0.1, 1.0) -- Dorado brillante
                        end
                        if UI.mainIcon.actionBorder.Show then
                            UI.mainIcon.actionBorder:Show()
                        end
                    end
                else
                    -- Off-GCD activo (Blood Tap, UA, Gargoyle, AW, etc.): se muestra directamente en mainIcon con borde cian brillante
                    UI.mainIcon.texture:SetTexture(offIconPath)
                    if UI.mainIcon.actionBorder then
                        if UI.mainIcon.actionBorder.SetVertexColor then
                            UI.mainIcon.actionBorder:SetVertexColor(0.2, 0.9, 1.0, 1.0) -- Cian brillante
                        end
                        if UI.mainIcon.actionBorder.Show then
                            UI.mainIcon.actionBorder:Show()
                        end
                    end
                end
            else
                UI.mainIcon.texture:SetTexture(mainIconPath)
                if UI.mainIcon.actionBorder and UI.mainIcon.actionBorder.Hide then
                    UI.mainIcon.actionBorder:Hide()
                end
            end
        end
        ApplyIconFullBrightness(UI.mainIcon)

    else
        -- MODO 1: "SIDE" (Icono al costado - actual)
        if UI.cornerIcon and UI.cornerIcon.frame and UI.cornerIcon.frame.Hide then
            UI.cornerIcon.frame:Hide()
        end
        if UI.mainIcon and UI.mainIcon.actionBorder and UI.mainIcon.actionBorder.Hide then
            UI.mainIcon.actionBorder:Hide()
        end

        -- Update Main Icon
        if UI.mainIcon and UI.mainIcon.texture then
            UI.mainIcon.texture:SetTexture(mainIconPath)
        end
        ApplyIconFullBrightness(UI.mainIcon)

        -- Update Off Icon
        if UI.offIcon and UI.offIcon.frame then
            if hasOffAction then
                if UI.offIcon.texture then
                    UI.offIcon.texture:SetTexture(offIconPath)
                end
                ApplyIconFullBrightness(UI.offIcon)
                if UI.offIcon.frame.Show then UI.offIcon.frame:Show() end
            else
                -- Prohibido mostrar '?' cuando offKey es nil: ocultar offIcon
                if UI.offIcon.frame.Hide then UI.offIcon.frame:Hide() end
            end
        end
    end

    -- Espera: espiral + segundos sobre el icono grande; motivo (modo aprendizaje) debajo
    state = state or (RotaCore.State and RotaCore.State.data)
    if UI.waitCount and UI.mainIcon then
        local secs = nil
        if state and state.isWaiting and isMainActionActive then
            secs = state.waitTime
            if not secs then
                -- sin dato de la rotacion: cooldown del hechizo o lo que queda de GCD
                local cd = (RotaCore.Spells and RotaCore.Spells.GetCooldownRemaining
                    and RotaCore.Spells:GetCooldownRemaining(mainAction, state.now)) or 0
                local gcd = state.gcdRemains or 0
                secs = (cd > gcd) and cd or gcd
            end
        end
        local cdFrame = UI.mainIcon.cooldown
        if secs and secs > 0.05 then
            UI.waitCount:SetText(WaitLabel(secs))
            UI.waitCount:Show()
            -- la espiral solo se reinicia si cambia el momento en que queda lista (evita que salte cada frame)
            local now = state.now or (_G.GetTime and _G.GetTime()) or 0
            local readyAt = now + secs
            if cdFrame and cdFrame.SetCooldown and (not UI.waitReadyAt or math.abs(readyAt - UI.waitReadyAt) > 0.25) then
                cdFrame:SetCooldown(now, secs)
                UI.waitReadyAt = readyAt
            end
            if cdFrame and cdFrame.Show then cdFrame:Show() end
        else
            UI.waitCount:Hide()
            UI.waitReadyAt = nil
            if cdFrame and cdFrame.Hide then cdFrame:Hide() end
        end
    end
    if UI.reasonText then
        local showReason = _G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.learningMode == true
        local reason = state and state.reason
        if showReason and reason and isMainActionActive then
            UI.reasonText:SetText(reason)
            UI.reasonText:Show()
        else
            UI.reasonText:Hide()
        end
    end

    -- Status Alert Badge (DESARMADO / SILENCIADO / CC CERCANO) — Zero Alpha Reduction
    if UI.alertBadge then
        state = state or (RotaCore.State and RotaCore.State.data)
        if state and state.playerDisarmed then
            UI.alertBadge:SetText("|cFFFF2222[DESARMADO]|r")
            UI.alertBadge:Show()
        elseif state and state.playerSilenced then
            UI.alertBadge:SetText("|cFFFF6600[SILENCIADO]|r")
            UI.alertBadge:Show()
        elseif state and state.ccNearby then
            UI.alertBadge:SetText("|cFFFFFF00[CC CERCANO]|r")
            UI.alertBadge:Show()
        else
            UI.alertBadge:SetText("")
            UI.alertBadge:Hide()
        end
    end

    -- Update Badges Text (Kept updated for query, hidden visually from screen)
    if UI.badgesText and UI.badgesText.SetText then
        state = state or (RotaCore.State and RotaCore.State.data)
        local aoeActive = state and state.aoeMode
        local burstActive = (state and state.burstMode ~= false)

        local buildBadge = "[F]"
        local activeProfile = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
        if activeProfile and activeProfile.meta then
            if activeProfile.meta.shortName then
                buildBadge = activeProfile.meta.shortName
            elseif activeProfile.meta.id == "dk_frost_pve" or activeProfile.meta.buildType == "frost" then
                buildBadge = "[F]"
            elseif activeProfile.meta.id == "dk_unholy_morb_pve" or activeProfile.meta.buildType == "unholy_morb" then
                buildBadge = "[UM]"
            elseif activeProfile.meta.id == "dk_unholy_2h_pve" or activeProfile.meta.id == "dk_unholy_pve" or
                   activeProfile.meta.buildType == "unholy_2h" then
                buildBadge = "[U]"
            end
        elseif _G.RotaClass_DK and _G.RotaClass_DK.detectedBadge then
            buildBadge = _G.RotaClass_DK.detectedBadge
        end

        local aoeStr = aoeActive and "|cFFFF2222[AOE]|r" or "|c33666666[AOE]|r"
        local burstStr = burstActive and "|cFFFF8800[BURST]|r" or "|c33666666[BURST]|r"
        local buildStr = "|cFF00CCFF" .. buildBadge .. "|r"

        UI.badgesText:SetText(aoeStr .. " " .. burstStr .. " " .. buildStr)
        if UI.badgesText.Hide then UI.badgesText:Hide() end
    end

    if UI.aoeBtn then
        UI:UpdateButtonStates()
    end
end

UI.Update = UI.UpdateDisplay
UI.UpdateIcon = UI.UpdateDisplay

return UI