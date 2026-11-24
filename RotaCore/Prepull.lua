-- RotaCore/Prepull.lua — Boton Pre-Pull: arma UNA vez la lista "prepull" de la build
--
-- Al tocarlo, el icono grande muestra la lista prepull del preset (con la etiqueta PRE) hasta lo primero de:
--   1. entrar en combate (el pull);
--   2. que la lista no tenga nada mas para tirar;
--   3. un tope de tiempo (meta.prepullLead + 10 s), para que no quede armado si el pull no llega.
-- Opcional (apagado por defecto, settings.dbmPull): el temporizador de pull de DBM lo arma solo cuando faltan
-- meta.prepullLead segundos. DBM avisa el pull por mensaje de addon (prefijo "D4", texto "PT\t<segundos>").
-- "Armado" no se guarda: un /reload lo apaga. El boton se mueve solo (arrastrandolo), se oculta en combate y
-- despues de terminar el pre-pull, y vuelve al salir de combate. Solo aparece si la build tiene lista prepull.
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Prepull = {
    armed = false,
    armedAt = 0,
    hiddenUntilCombatEnds = false,
    shown = nil,
    EXTRA_TIME = 10,
}
RotaCore.Prepull = Prepull

local function Settings()
    local db = _G.RotaCoreDB
    if not db then return nil end
    db.settings = db.settings or {}
    return db.settings
end

local function ActiveIR()
    return RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
end

--- La build activa tiene lista de pre-pull
function Prepull:Available()
    local b = RotaCore.Profiles and RotaCore.Profiles:GetActiveEvaluator()
    return (b and b.evaluatorPrepull) and true or false
end

function Prepull:Lead()
    local ir = ActiveIR()
    return (ir and ir.meta and ir.meta.prepullLead) or 5
end

function Prepull:Arm()
    if not self:Available() then return end
    self.firstEval = true
    self.armed = true
    self.armedAt = (_G.GetTime and _G.GetTime()) or 0
    self:UpdateButton()
end

function Prepull:Disarm(reason)
    self.armed = false
    -- Termino el pre-pull: el boton se va hasta salir de combate. Si se corto por tiempo (no hubo pull), vuelve ya.
    if reason ~= "timeout" and reason ~= "cancel" then
        self.hiddenUntilCombatEnds = true
        self.hiddenAt = (_G.GetTime and _G.GetTime()) or 0
    end
    self:UpdateButton()
end

--- Llamado por UpdateAndEvaluate antes de la lista principal. Devuelve la habilidad de pre-pull o nil.
function Prepull:Evaluate(state, bundle)
    if not self.armed then return nil end
    if state.inCombat then
        self:Disarm("combat")
        return nil
    end
    if (state.now or 0) - self.armedAt > self:Lead() + self.EXTRA_TIME then
        self:Disarm("timeout")
        return nil
    end
    local act = bundle and bundle.evaluatorPrepull and bundle.evaluatorPrepull(state)
    local first = self.firstEval
    self.firstEval = false
    if not act then
        -- Nada para tirar desde el primer momento (ej. poción en cooldown): avisar y dejar el boton disponible
        if first and _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[RotaCore]|r Pre-Pull: ahora no hay nada para tirar antes del pull.")
        end
        self:Disarm(first and "cancel" or "done")
        return nil
    end
    return act
end

--- Mensaje de addon de DBM con el temporizador de pull (solo con la opcion prendida)
function Prepull:OnAddonMessage(prefix, msg)
    local s = Settings()
    if not s or s.dbmPull ~= true or prefix ~= "D4" or type(msg) ~= "string" then return end
    local secs = msg:match("^PT\t(%d+)")
    if not secs then return end
    secs = tonumber(secs)
    if secs <= 0 then
        self.pullAt = nil -- pull cancelado
        if self.armed then self:Disarm("cancel") end
        return
    end
    self.pullAt = ((_G.GetTime and _G.GetTime()) or 0) + secs
end

--- Mostrar u ocultar el boton segun combate, build y opcion (solo cambia algo si hace falta: sin basura por tick)
function Prepull:Tick(state)
    -- Temporizador de DBM: armar cuando faltan prepullLead segundos para el pull
    local pullAt = self.pullAt
    if pullAt and not self.armed and not state.inCombat and (state.now or 0) >= pullAt - self:Lead() then
        self.pullAt = nil
        if self:Available() then
            self.hiddenUntilCombatEnds = false
            self:Arm()
        end
    end
    local btn = self.button
    if not btn then return end
    -- Se tiro todo y el pull no llego: el boton vuelve solo pasado el tope de tiempo
    if self.hiddenUntilCombatEnds and not state.inCombat and (state.now or 0) - (self.hiddenAt or 0) > self:Lead() + self.EXTRA_TIME then
        self.hiddenUntilCombatEnds = false
    end
    local s = Settings()
    local want = (not s or s.showPrepull ~= false) and self:Available() and not state.inCombat
        and not self.hiddenUntilCombatEnds
    if want ~= self.shown then
        self.shown = want
        if want then btn:Show() else btn:Hide() end
    end
end

function Prepull:UpdateButton()
    local btn = self.button
    if not btn or not btn.label then return end
    if self.armed then
        btn.label:SetText("|cFF00FF00Pre-Pull: activo|r")
        if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(0.2, 1, 0.2, 1) end
    else
        btn.label:SetText("Pre-Pull")
        if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(0.5, 0.5, 0.55, 1) end
    end
end

function Prepull:SavePosition()
    local btn, s = self.button, Settings()
    if not btn or not s or not btn.GetPoint then return end
    local point, _, relPoint, x, y = btn:GetPoint()
    s.prepullPos = { point = point, relPoint = relPoint, x = x, y = y }
end

function Prepull:ResetPosition()
    local btn, s = self.button, Settings()
    if s then s.prepullPos = nil end
    if btn then
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", _G.UIParent, "CENTER", 0, -40)
    end
end

function Prepull:ShowTooltip()
    if not _G.GameTooltip or not self.button then return end
    local ir = ActiveIR()
    local note = ir and ir.meta and ir.meta.prepullNote
    _G.GameTooltip:SetOwner(self.button, "ANCHOR_TOP")
    _G.GameTooltip:AddLine("|cFFFFFF00Pre-Pull|r", 1, 1, 1)
    _G.GameTooltip:AddLine(string.format("Empezá unos %d s antes del pull.", self:Lead()), 1, 1, 1)
    if note then _G.GameTooltip:AddLine(note, 0.8, 1, 0.8, true) end
    _G.GameTooltip:AddLine("Click: muestra la rotación de pre-pull en el icono grande, una vez. Otro click la cancela. "
        .. "Se corta sola si el pull no llega en unos segundos.", 0.8, 0.8, 0.8, true)
    _G.GameTooltip:AddLine("Arrastrar: mover el botón.", 0.6, 0.6, 0.6)
    _G.GameTooltip:Show()
end

function Prepull:Init()
    if self.button or not _G.CreateFrame then return end
    local btn = _G.CreateFrame("Button", "RotaPrepullButton", _G.UIParent)
    btn:SetSize(110, 26)
    if btn.SetFrameStrata then btn:SetFrameStrata("MEDIUM") end
    if btn.SetMovable then btn:SetMovable(true) end
    if btn.SetClampedToScreen then btn:SetClampedToScreen(true) end
    if btn.EnableMouse then btn:EnableMouse(true) end
    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        btn:SetBackdropColor(0.15, 0.15, 0.18, 0.95)
    end
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.label = label

    local s = Settings()
    local pos = s and s.prepullPos
    btn:ClearAllPoints()
    if pos and pos.point then
        btn:SetPoint(pos.point, _G.UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        btn:SetPoint("CENTER", _G.UIParent, "CENTER", 0, -40)
    end

    if btn.RegisterForDrag then btn:RegisterForDrag("LeftButton") end
    btn:SetScript("OnDragStart", function(f)
        f.moved = true -- el click que llega al soltar despues de arrastrar no arma el pre-pull
        if f.StartMoving then f:StartMoving() end
    end)
    btn:SetScript("OnDragStop", function(f)
        if f.StopMovingOrSizing then f:StopMovingOrSizing() end
        Prepull:SavePosition()
    end)
    btn:SetScript("OnClick", function(f)
        if f and f.moved then
            f.moved = nil
            return
        end
        if Prepull.armed then Prepull:Disarm("cancel") else Prepull:Arm() end
    end)
    btn:SetScript("OnEnter", function() Prepull:ShowTooltip() end)
    btn:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)

    -- Al salir de combate el boton vuelve; mensajes de DBM para el temporizador de pull (opcional)
    btn:RegisterEvent("PLAYER_REGEN_ENABLED")
    btn:RegisterEvent("CHAT_MSG_ADDON")
    btn:SetScript("OnEvent", function(_, event, prefix, msg)
        if event == "CHAT_MSG_ADDON" then
            Prepull:OnAddonMessage(prefix, msg)
            return
        end
        Prepull.hiddenUntilCombatEnds = false
        Prepull.pullAt = nil
    end)

    self.button = btn
    self.shown = nil
    btn:Hide()
    self:UpdateButton()
end

return Prepull
