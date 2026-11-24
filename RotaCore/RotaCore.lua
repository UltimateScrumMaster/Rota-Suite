-- RotaCore/RotaCore.lua — Addon Lifecycle, Event Dispatch & Main Evaluation Pipeline (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

RotaCore.version = "1.0.0"
RotaCore.activeEvaluator = nil

RotaCore.classModules = RotaCore.classModules or {}

--- "Nombre - Reino" del PJ, o nil si el cliente todavia no lo sabe (ADDON_LOADED en login frio).
function RotaCore:GetCharKey()
    local name = _G.UnitName and _G.UnitName("player")
    if not name or name == "" or name == "Unknown" then return nil end
    return name .. " - " .. ((_G.GetRealmName and _G.GetRealmName()) or "Unknown")
end

--- Build elegida por este PJ ("auto" si nunca eligio). settings.selectedBuild es de toda la cuenta: no usarla para leer.
function RotaCore:GetSelectedBuild()
    local db = _G.RotaCoreDB
    local key = self:GetCharKey()
    if db and key and db.charBuilds and db.charBuilds[key] then
        return db.charBuilds[key]
    end
    return "auto"
end

RotaCore.AoERange = RotaCore.AoERange or {
    DEATHKNIGHT = 34368, -- ~8 yd
    PALADIN     = 34368, -- ~8 yd
    WARRIOR     = 34368, -- ~8 yd
    ROGUE       = 34368, -- ~8 yd
    SHAMAN      = 34368, -- ~8 yd (Elemental: usar AoE manual)
    WARLOCK     = 34368, -- ~8 yd (caster: usar AoE manual)
    MAGE        = 34368, -- ~8 yd (caster: usar AoE manual)
    PRIEST      = 34368, -- ~8 yd (caster: usar AoE manual)
    HUNTER      = 34368, -- ~8 yd (a distancia: usar AoE manual)
    DRUID       = 34368, -- ~8 yd (Balance: usar AoE manual)
}

--- Registers a class module adhering to the RotaClass contract.
-- @param def table Module definition table
function RotaCore:RegisterClassModule(def)
    if not def or not def.class then return end
    self.classModules = self.classModules or {}
    self.classModules[def.class] = def

    if def.stateProvider and self.State and self.State.RegisterProvider then
        self.State:RegisterProvider(def.class, def.stateProvider)
    end
end

--- Retrieves the registered class module for a given class token.
-- @param classToken string|nil Player class token (e.g. "ROGUE", "DEATHKNIGHT")
-- @return table|nil
function RotaCore:GetClassModule(classToken)
    local token = classToken
    if not token and _G.UnitClass then
        local _, c = _G.UnitClass("player")
        token = c
    end
    if not token then return nil end
    return self.classModules and self.classModules[token]
end

--- Retrieves available builds for a given class token.
-- @param classToken string|nil
-- @return table Array of build definition tables
function RotaCore:GetClassBuilds(classToken)
    local mod = self:GetClassModule(classToken)
    if mod and mod.builds and #mod.builds > 0 then
        return mod.builds
    end
    return { { key = "auto", name = "AUTO", color = { 1.0, 0.9, 0.0 } } }
end

--- Retrieves idle preview action alias from the registered class module.
-- @param classToken string|nil
-- @param buildKey string|nil
-- @return string|nil
function RotaCore:GetIdlePreviewAction(classToken, buildKey)
    local mod = self:GetClassModule(classToken)
    if mod and mod.getIdlePreviewAction then
        local act = mod.getIdlePreviewAction(buildKey)
        if act then return act end
    end
    return nil
end

--- Retrieves class color from registered module or RAID_CLASS_COLORS.
-- @param classToken string|nil
-- @return table { r = number, g = number, b = number }
function RotaCore:GetClassColor(classToken)
    local mod = self:GetClassModule(classToken)
    if mod and mod.classColor then
        return mod.classColor
    end
    local token = classToken
    if not token and _G.UnitClass then
        local _, c = _G.UnitClass("player")
        token = c
    end
    if token and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[token] then
        return _G.RAID_CLASS_COLORS[token]
    end
    return { r = 1.0, g = 1.0, b = 1.0 }
end

function RotaCore:StartAoETrace(seconds)
    local duration = tonumber(seconds) or 10
    if duration <= 0 then duration = 10 end
    if duration > 60 then duration = 60 end

    if not self.traceFrame and _G.CreateFrame then
        self.traceFrame = _G.CreateFrame("Frame", "RotaCoreTraceFrame")
    end
    if not self.traceFrame then return end

    local samples = {}
    local elapsedTotal = 0
    local sampleTimer = 0.5
    table.insert(samples, string.format("=== ROTACORE AOE TRACE (duration=%.1fs) ===", duration))
    table.insert(samples, "time | plates | log | swing | count | source | aoeMode | isAoE | mainAction")

    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cFF00FF00[RotaCore]|r Iniciando AoE Trace por %.1fs... mantente en combate.", duration))
    end

    self.traceFrame:SetScript("OnUpdate", function(_, dt)
        elapsedTotal = elapsedTotal + dt
        sampleTimer = sampleTimer + dt
        if sampleTimer >= 0.5 then
            sampleTimer = sampleTimer - 0.5
            local st = RotaCore.State and RotaCore.State.data
            local pCount = st and st.aoePlateCount or 0
            local lCount = st and st.aoeLogCount or 0
            local sCount = st and st.aoeSwingCount or 0
            local aCount = st and st.aoeCount or 1
            local aSrc = st and st.aoeSource or "none"
            local aMode = st and st.aoeMode
            local isAoE = st and st.isAoE
            local mainAct = RotaCore.lastMainAction or (st and st.suggestedMain) or "None"

            local sample = string.format("+%.1fs | %d | %d | %d | %d | %s | %s | %s | %s",
                elapsedTotal, pCount, lCount, sCount, aCount, aSrc, tostring(aMode), tostring(isAoE), tostring(mainAct))
            table.insert(samples, sample)
        end

        if elapsedTotal >= duration then
            self.traceFrame:SetScript("OnUpdate", nil)
            local resultText = table.concat(samples, "\n")
            local copied = RotaCore.Compat and RotaCore.Compat.CopyToClipboard and RotaCore.Compat.CopyToClipboard(resultText)
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                if copied then
                    _G.DEFAULT_CHAT_FRAME:AddMessage(string.format(
                        "|cFF00FF00[RotaCore]|r AoE Trace completado (%d muestras). Copiado al portapapeles.", #samples - 2))
                else
                    _G.DEFAULT_CHAT_FRAME:AddMessage(string.format(
                        "|cFF00FF00[RotaCore]|r AoE Trace completado (%d muestras):", #samples - 2))
                    for i = 1, #samples do
                        _G.DEFAULT_CHAT_FRAME:AddMessage(samples[i])
                    end
                end
            end
        end
    end)
end

-- Slash command handler registered immediately at top of file
local function HandleSlashCmd(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S+)")
    if cmd == "status" then
        local p = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
        local pName = (p and p.meta and p.meta.name) or "None"
        if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Perfil Activo: " .. pName .. " (v" .. RotaCore.version .. ")")
            local st = RotaCore.State and RotaCore.State.data
            local dbSettings = _G.RotaCoreDB and _G.RotaCoreDB.settings
            local aoeModeSetting = dbSettings and dbSettings.aoeMode
            if (aoeModeSetting == "AUTO" or aoeModeSetting == nil) and (not st or not st.nameplatesActive) then
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[RotaCore]|r (nameplates enemigas desactivadas: AoE AUTO usando modo clásico)")
            end
        end
    elseif cmd == "edit" then
        if not _G.RotaEditor and _G.LoadAddOn then
            _G.LoadAddOn("RotaEditor")
        end
        if _G.RotaEditor and _G.RotaEditor.Toggle then
            _G.RotaEditor:Toggle()
        elseif _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RotaCore]|r RotaEditor no pudo cargarse.")
        end
    elseif cmd == "aprender" or cmd == "motivo" then
        _G.RotaCoreDB = _G.RotaCoreDB or {}
        _G.RotaCoreDB.settings = _G.RotaCoreDB.settings or {}
        local on = _G.RotaCoreDB.settings.learningMode ~= true
        _G.RotaCoreDB.settings.learningMode = on
        if RotaCore.Options and RotaCore.Options.panel and RotaCore.Options.panel.learningCb then
            RotaCore.Options.panel.learningCb:SetChecked(on)
        end
        if _G.DEFAULT_CHAT_FRAME then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Modo aprendizaje (motivo debajo del icono): "
                .. (on and "ON" or "OFF"))
        end
    elseif cmd == "lock" then
        if RotaCore.UI and not RotaCore.UI.hudFrame and RotaCore.UI.Init then
            pcall(function() RotaCore.UI:Init() end)
        end
        local locked = true
        if _G.RotaCoreDB and _G.RotaCoreDB.settings then
            _G.RotaCoreDB.settings.locked = not _G.RotaCoreDB.settings.locked
            locked = _G.RotaCoreDB.settings.locked
        end
        if RotaCore.UI and RotaCore.UI.SetLocked then
            RotaCore.UI:SetLocked(locked)
        elseif RotaCore.UI and RotaCore.UI.hudFrame then
            RotaCore.UI.hudFrame:EnableMouse(not locked)
        end
        if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r HUD " .. (locked and "Bloqueado" or "Desbloqueado para mover"))
        end
    elseif cmd == "reset" then
        if RotaCore.UI and not RotaCore.UI.hudFrame and RotaCore.UI.Init then
            pcall(function() RotaCore.UI:Init() end)
        end
        if RotaCore.UI and RotaCore.UI.ResetPosition then
            RotaCore.UI:ResetPosition()
        elseif RotaCore.UI and RotaCore.UI.hudFrame then
            RotaCore.UI.hudFrame:ClearAllPoints()
            RotaCore.UI.hudFrame:SetPoint("CENTER", _G.UIParent or RotaCore.UI.hudFrame, "CENTER", 0, -120)
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Posición del HUD restablecida al centro.")
            end
        end
    elseif cmd == "burst" then
        if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
        if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
        local cur = (_G.RotaCoreDB.settings.burstMode ~= false)
        _G.RotaCoreDB.settings.burstMode = not cur
        if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            local statusStr = _G.RotaCoreDB.settings.burstMode and "|cFFFF8800ACTIVADO|r" or "|cFFFF0000DESACTIVADO|r"
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Modo Burst: " .. statusStr)
        end
    elseif cmd == "burstmode" then
        local sub = (msg or ""):match("^%s*%S+%s+(%S+)")
        if sub and RotaCore.UI and RotaCore.UI.SetBurstDisplayMode then
            RotaCore.UI:SetBurstDisplayMode(sub)
        elseif RotaCore.UI and RotaCore.UI.CycleBurstDisplayMode then
            RotaCore.UI:CycleBurstDisplayMode()
        end
    elseif cmd == "burstscale" then
        local sub = (msg or ""):match("^%s*%S+%s+(%S+)")
        if sub and RotaCore.UI and RotaCore.UI.SetCornerScale then
            RotaCore.UI:SetCornerScale(sub)
        end
    elseif cmd == "aoe" then
        if RotaCore.UI and RotaCore.UI.CycleAoEMode then
            RotaCore.UI:CycleAoEMode()
        else
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
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                local colorStr = (nextMode == "AUTO" and "|cFF00CCFF") or (nextMode == "ON" and "|cFFFF2222") or "|cFF888888"
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Modo AoE: " .. colorStr .. "[" .. nextMode .. "]|r")
            end
        end
    elseif cmd == "aoefusion" then
        local sub = (msg or ""):match("^%s*%S+%s+(%S+)")
        if sub then
            sub = sub:lower()
            if sub == "union" or sub == "confirm" or sub == "plates" or sub == "classic" then
                if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
                _G.RotaCoreDB.aoeFusion = sub
                if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                    _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Fusión AoE configurada en: |cFFFFFF00" .. sub .. "|r")
                end
            else
                if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                    _G.DEFAULT_CHAT_FRAME:AddMessage(
                        "|cFFFF8800[RotaCore]|r Modo de fusión no válido. Usa: union | confirm | plates | classic")
                end
            end
        else
            local cur = (_G.RotaCoreDB and _G.RotaCoreDB.aoeFusion) or "union"
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                _G.DEFAULT_CHAT_FRAME:AddMessage(
                    "|cFF00FF00[RotaCore]|r Modo actual de fusión AoE: |cFFFFFF00" .. cur
                    .. "|r (opciones: union | confirm | plates | classic)")
            end
        end
    elseif cmd == "aoetrace" then
        local sub = (msg or ""):match("^%s*%S+%s+(%S+)")
        local sec = tonumber(sub) or 10
        RotaCore:StartAoETrace(sec)
    elseif cmd == "build" then
        local sub = (msg or ""):match("^%s*%S+%s+(%S+)")
        local playerClass = "DEATHKNIGHT"
        if _G.UnitClass then
            local _, cls = _G.UnitClass("player")
            if cls then playerClass = cls end
        end
        if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
        if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
        _G.RotaCoreDB.charBuilds = _G.RotaCoreDB.charBuilds or {}
        _G.RotaCoreDB.classBuilds = _G.RotaCoreDB.classBuilds or {}
        local charName = (_G.UnitName and _G.UnitName("player")) or "Unknown"
        local realmName = (_G.GetRealmName and _G.GetRealmName()) or "Unknown"
        local charKey = charName .. " - " .. realmName

        if sub then
            sub = sub:lower()
            local bChoice = "auto"
            local matchedPreset = nil
            local mod = RotaCore:GetClassModule(playerClass)
            local builds = (mod and mod.builds) or RotaCore:GetClassBuilds(playerClass)

            for _, b in ipairs(builds) do
                if b.key:lower() == sub or b.name:lower() == sub then
                    bChoice = b.key
                    matchedPreset = b.preset
                    break
                end
            end

            if bChoice == "auto" and sub ~= "auto" then
                if playerClass == "DEATHKNIGHT" then
                    if sub == "frost" or sub == "f" then bChoice = "frost"
                    elseif sub == "morb" or sub == "um" or sub == "unholy_morb" then bChoice = "unholy_morb"
                    elseif sub == "ums" or sub == "morbss" or sub == "dwss" or sub == "unholy_dw_ss" then bChoice = "unholy_dw_ss"
                    elseif sub == "unholy" or sub == "2h" or sub == "u" or sub == "unholy_2h" then bChoice = "unholy_2h" end
                elseif playerClass == "WARRIOR" then
                    if sub == "fury" or sub == "f" or sub == "18/53" then bChoice = "fury"
                    elseif sub == "op" or sub == "overpower" or sub == "fury_op"
                        or sub == "20/51" or sub == "fury_overpower" then
                        bChoice = "fury_overpower"
                    elseif sub == "arms" or sub == "a" or sub == "55/8/8" then bChoice = "arms" end
                elseif playerClass == "ROGUE" then
                    if sub == "assa" or sub == "mutilate" or sub == "mut" or sub == "assassination" then bChoice = "assassination"
                    elseif sub == "combat" or sub == "c" then bChoice = "combat"
                    elseif sub == "sub" or sub == "hemo" or sub == "subtlety" then bChoice = "subtlety"
                    elseif sub == "dance" or sub == "dagger" or sub == "subtlety_dagger" then bChoice = "subtlety_dagger" end
                end
                for _, b in ipairs(builds) do
                    if b.key == bChoice then
                        matchedPreset = b.preset
                        break
                    end
                end
            end

            _G.RotaCoreDB.settings.selectedBuild = bChoice
            _G.RotaCoreDB.charBuilds[charKey] = bChoice
            _G.RotaCoreDB.classBuilds[playerClass] = bChoice

            if bChoice == "auto" then
                if mod and mod.detectBuild then
                    mod.detectBuild()
                elseif _G.RotaClass_DK and _G.RotaClass_DK.DetectBuild then
                    _G.RotaClass_DK:DetectBuild()
                elseif _G.RotaClass_WAR and _G.RotaClass_WAR.DetectSpec then
                    _G.RotaClass_WAR:DetectSpec()
                end
            elseif matchedPreset and RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
                RotaCore.Profiles:SetActiveProfile(matchedPreset)
            else
                if mod and mod.detectBuild then
                    mod.detectBuild()
                elseif _G.RotaClass_DK and _G.RotaClass_DK.DetectBuild then
                    _G.RotaClass_DK:DetectBuild()
                elseif _G.RotaClass_WAR and _G.RotaClass_WAR.DetectSpec then
                    _G.RotaClass_WAR:DetectSpec()
                end
            end
            if RotaCore.UI and RotaCore.UI.UpdateButtonStates then
                RotaCore.UI:UpdateButtonStates()
            end
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                local bName = _G.RotaCoreDB.settings.selectedBuild or "auto"
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Build " .. playerClass .. " configurada en: " .. bName)
            end
        else
            if RotaCore.UI and RotaCore.UI.CycleBuild then
                RotaCore.UI:CycleBuild()
            end
        end
    elseif cmd == "prepull" then
        local Prepull = RotaCore.Prepull
        if Prepull and Prepull:Available() then
            if Prepull.armed then Prepull:Disarm("cancel") else Prepull:Arm() end
        elseif _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[RotaCore]|r Esta build no tiene rotación de pre-pull.")
        end
    elseif cmd == "options" or cmd == "help" or cmd == "tutorial" then
        if _G.InterfaceOptionsFrame_OpenToCategory and RotaCore.optionsPanel then
            _G.InterfaceOptionsFrame_OpenToCategory(RotaCore.optionsPanel)
            _G.InterfaceOptionsFrame_OpenToCategory(RotaCore.optionsPanel)
        elseif _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Abre ESC -> Interfaz -> pestaña AddOns -> Rota Suite")
        end
    elseif cmd == "probe" or cmd == "scan" then
        if not _G.RotaProbe and _G.LoadAddOn then
            _G.LoadAddOn("RotaProbe")
        end
        if _G.RotaProbe and _G.RotaProbe.Show then
            _G.RotaProbe:Show()
        elseif _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RotaCore]|r Usa /rotaprobe scan o /rotaprobe show.")
        end
    elseif cmd == "dump" or cmd == "debug" then
        local p = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
        local pName = (p and p.meta and p.meta.name) or "None"
        local pId = (p and p.meta and p.meta.id) or "None"
        local pBuild = (p and p.meta and (p.meta.buildType or p.meta.id)) or "None"

        local playerClass = "Unknown"
        if _G.UnitClass then
            local _, c = _G.UnitClass("player")
            if c then playerClass = c end
        end

        local charName = (_G.UnitName and _G.UnitName("player")) or "Unknown"
        local realmName = (_G.GetRealmName and _G.GetRealmName()) or "Unknown"
        local charKey = charName .. " - " .. realmName

        local db = _G.RotaCoreDB
        local charBuild = db and db.charBuilds and db.charBuilds[charKey] or "None"
        local charProf = db and db.charProfiles and db.charProfiles[charKey] or "None"

        local st = RotaCore.State and RotaCore.State.data
        local aoeMode = st and st.aoeMode
        local isAoE = st and st.isAoE
        local aoeCount = st and st.aoeCount or 1
        local npActive = st and st.nameplatesActive
        local npCount = st and st.nameplatesCount or 0

        local pSil = st and st.playerSilenced
        local pDis = st and st.playerDisarmed
        local tSil = st and st.targetSilenced
        local tCtrl = st and st.targetControlled
        local ccNear = st and st.ccNearby

        local mainAct = RotaCore.lastMainAction or (st and st.suggestedMain) or "None"
        local offAct = RotaCore.lastOffAction or (st and st.suggestedOff) or "None"

        local tInfo = {}
        if _G.GetNumTalentTabs and _G.GetTalentTabInfo then
            local numTabs = _G.GetNumTalentTabs() or 3
            for tab = 1, numTabs do
                local tName, _, pts = _G.GetTalentTabInfo(tab)
                table.insert(tInfo, string.format("%s:%d", tName or ("Tab" .. tab), pts or 0))
            end
        end
        local talentsStr = table.concat(tInfo, ", ")

        local Compat = RotaCore.Compat
        local compatStr = string.format("NP:%s, CC:%s, Sil:%s, Dis:%s, Clip:%s, BaseCD:%s",
            tostring(Compat and Compat.hasNameplates),
            tostring(Compat and Compat.hasCC),
            tostring(Compat and Compat.hasSilence),
            tostring(Compat and Compat.hasDisarm),
            tostring(Compat and Compat.hasClipboard),
            tostring(Compat and Compat.hasSpellBaseCD))

        local aoeBtn = (db and db.settings and db.settings.aoeMode) or "AUTO"
        local inCombat = st and st.inCombat or false
        local hasTarget = st and st.hasTarget or false
        local targetCanAttack = st and st.targetCanAttack or false
        local aoeFusion = (db and db.aoeFusion) or "union"
        local aoePlateCount = st and st.aoePlateCount or 0
        local aoeLogCount = st and st.aoeLogCount or 0
        local aoeSwingCount = st and st.aoeSwingCount or 0
        local aoeSource = st and st.aoeSource or "none"

        local aoeThreshold = (playerClass == "WARRIOR") and 2 or 3
        local autoActive = st and st.autoAoeActive or false
        local lastDrop = st and st.lastAoeDropTime or 0
        local dropElapsed = (lastDrop > 0 and st and st.now) and (st.now - lastDrop) or 0

        local npReason = (st and st.api and st.api.nameplatesReason) or "none"
        local npScanInc = st and st.nameplatesScanIncomplete or false
        local showEnemiesCVar = (_G.GetCVar and _G.GetCVar("nameplateShowEnemies")) or "unknown"
        local rangeItem = (RotaCore.AoERange and RotaCore.AoERange[playerClass]) or 34368

        local nowTime = (st and st.now) or (_G.GetTime and _G.GetTime()) or 0
        local aoeAge = (st and st.lastAoeUpdate and st.lastAoeUpdate > 0) and (nowTime - st.lastAoeUpdate) or 0
        local tickCount = (st and st.tickCount) or 0

        local dumpLines = {
            string.format("[RotaCore Dump v%s]", RotaCore.version or "1.0.0"),
            string.format("Char: %s | Class: %s", charKey, playerClass),
            string.format("Profile: %s (%s) | Build: %s | Talents: [%s]", pName, pId, pBuild, talentsStr),
            string.format("DB: charBuild=%s, charProfile=%s, aoeFusion=%s", tostring(charBuild), tostring(charProf), aoeFusion),
            string.format("AoE: button=%s, fusion=%s, plates=%d, log=%d, swing=%d, aoeCount=%d, source=%s",
                tostring(aoeBtn), aoeFusion, aoePlateCount, aoeLogCount, aoeSwingCount, aoeCount, aoeSource),
            string.format("State: aoeMode=%s, isAoE=%s, aoeCount=%d (NameplatesActive=%s, Count=%d)",
                tostring(aoeMode), tostring(isAoE), aoeCount, tostring(npActive), npCount),
            string.format("Combat: inCombat=%s, hasTarget=%s, targetCanAttack=%s",
                tostring(inCombat), tostring(hasTarget), tostring(targetCanAttack)),
            string.format("Hysteresis: threshold=%d, autoActive=%s, dropTime=%.1f, dropElapsed=%.1fs",
                aoeThreshold, tostring(autoActive), lastDrop, dropElapsed),
            string.format("Nameplates: showEnemies=%s, scanIncomplete=%s, AoERange=%s",
                tostring(showEnemiesCVar), tostring(npScanInc), tostring(rangeItem)),
            string.format("Engine: ticks=%d, aoeRefreshAge=%.2fs",
                tickCount, aoeAge),
            string.format("Actions: main=%s, off=%s", tostring(mainAct), tostring(offAct)),
            string.format("Flags: pSil=%s, pDis=%s, tSil=%s, tCtrl=%s, ccNear=%s",
                tostring(pSil), tostring(pDis), tostring(tSil), tostring(tCtrl), tostring(ccNear)),
            string.format("APIs: %s (NPReason=%s)", compatStr, tostring(npReason)),
        }
        if showEnemiesCVar == "0" then
            table.insert(dumpLines, "Warning: nameplates enemigas desactivadas")
        end
        local fullDump = table.concat(dumpLines, "\n")
        local copied = Compat and Compat.CopyToClipboard and Compat.CopyToClipboard(fullDump)
        if copied then
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Volcado de estado copiado al portapapeles.")
            end
        else
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                for i = 1, #dumpLines do
                    _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r " .. dumpLines[i])
                end
            end
        end
    elseif cmd == "apitest" then
        local sub = (msg or ""):match("^%s*%S+%s+(%S+)")
        if sub and sub:lower() == "plates" then
            local playerClass = "DEATHKNIGHT"
            if _G.UnitClass then
                local _, c = _G.UnitClass("player")
                if c then playerClass = c end
            end
            local meleeSpell = 49921
            if playerClass == "PALADIN" then
                meleeSpell = 35395
            elseif playerClass == "WARRIOR" then
                meleeSpell = 772
            end

            local lines = { "=== ROTACORE APITEST PLATES ===" }
            table.insert(lines, "idx | token | GUID6 | name | canAtk | dead | combat | isTgt | spell | item5 | item8 | interact | counted")

            local cntTotal, cntAttackable, cntAlive, cntCombat = 0, 0, 0, 0
            local cntItem5, cntItem8, cntInteract, cntCounted = 0, 0, 0, 0
            local seenGUIDs = {}

            for i = 1, 40 do
                local token = "nameplate" .. i
                if _G.UnitExists and _G.UnitExists(token) then
                    cntTotal = cntTotal + 1
                    local guid = _G.UnitGUID and _G.UnitGUID(token)
                    local guid6 = guid and tostring(guid):sub(-6) or "none"
                    local uName = (_G.UnitName and _G.UnitName(token)) or "Unknown"

                    local canAtk = (_G.UnitCanAttack and _G.UnitCanAttack("player", token)) or false
                    if canAtk then cntAttackable = cntAttackable + 1 end

                    local isDead = (_G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost(token))
                        or (_G.UnitIsDead and _G.UnitIsDead(token)) or false
                    if not isDead then cntAlive = cntAlive + 1 end

                    local inCombat = (_G.UnitAffectingCombat and _G.UnitAffectingCombat(token)) or false
                    if inCombat then cntCombat = cntCombat + 1 end

                    local isTgt = (_G.UnitIsUnit and _G.UnitIsUnit(token, "target")) or false

                    local spVal = _G.IsSpellInRange and _G.IsSpellInRange(meleeSpell, token)
                    local it5Val = _G.IsItemInRange and _G.IsItemInRange(37727, token)
                    if it5Val == 1 then cntItem5 = cntItem5 + 1 end

                    local it8Val = _G.IsItemInRange and _G.IsItemInRange(34368, token)
                    if it8Val == 1 then cntItem8 = cntItem8 + 1 end

                    local intVal = _G.CheckInteractDistance and _G.CheckInteractDistance(token, 3)
                    if intVal == 1 or intVal == true then cntInteract = cntInteract + 1 end

                    local inRange = false
                    if it8Val == 1 then
                        inRange = true
                    elseif it8Val == 0 then
                        inRange = false
                    elseif intVal == 1 or intVal == true then
                        inRange = true
                    end

                    local countedStr = "Y"
                    if isDead then
                        countedStr = "N (dead)"
                    elseif not canAtk then
                        countedStr = "N (friendly)"
                    elseif not inCombat then
                        countedStr = "N (out of combat)"
                    elseif not inRange then
                        countedStr = "N (out of range)"
                    elseif guid and seenGUIDs[guid] then
                        countedStr = "N (duplicate GUID)"
                    else
                        if guid then seenGUIDs[guid] = true end
                        cntCounted = cntCounted + 1
                    end

                    table.insert(lines, string.format("%d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s",
                        i, token, tostring(guid6), tostring(uName), tostring(canAtk), tostring(isDead),
                        tostring(inCombat), tostring(isTgt), tostring(spVal), tostring(it5Val),
                        tostring(it8Val), tostring(intVal), countedStr))
                end
            end

            -- Target evaluation line
            if _G.UnitExists and _G.UnitExists("target") then
                local tSp = _G.IsSpellInRange and _G.IsSpellInRange(meleeSpell, "target")
                local tIt5 = _G.IsItemInRange and _G.IsItemInRange(37727, "target")
                local tIt8 = _G.IsItemInRange and _G.IsItemInRange(34368, "target")
                local tInt = _G.CheckInteractDistance and _G.CheckInteractDistance("target", 3)
                table.insert(lines, string.format("target | spell=%s | item5=%s | item8=%s | interact=%s",
                    tostring(tSp), tostring(tIt5), tostring(tIt8), tostring(tInt)))
            else
                table.insert(lines, "target | no target")
            end

            local st = RotaCore.State and RotaCore.State.data
            local pCnt = st and st.aoePlateCount or 0
            local lCnt = st and st.aoeLogCount or 0
            local sCnt = st and st.aoeSwingCount or 0
            local aCnt = st and st.aoeCount or 1
            local aSrc = st and st.aoeSource or "none"

            table.insert(lines, string.format(
                "Summary: total=%d / attackable=%d / alive=%d / combat=%d / inRange(i5=%d, i8=%d, int=%d) / counted=%d"
                .. " | plateCount=%d, logCount=%d, swingCount=%d, fused=%d, source=%s",
                cntTotal, cntAttackable, cntAlive, cntCombat, cntItem5, cntItem8, cntInteract, cntCounted,
                pCnt, lCnt, sCnt, aCnt, aSrc))

            -- Dump keys of first 2 frames of GetNamePlates()
            local Compat = RotaCore.Compat
            if Compat and Compat.GetNamePlates then
                local plates = Compat.GetNamePlates()
                if type(plates) == "table" then
                    table.insert(lines, string.format("GetNamePlates() total frames: %d", #plates))
                    for fIdx = 1, math.min(2, #plates) do
                        local fr = plates[fIdx]
                        table.insert(lines, string.format("Frame #%d (type=%s):", fIdx, type(fr)))
                        if type(fr) == "table" then
                            for k, v in pairs(fr) do
                                local vType = type(v)
                                if vType == "string" or vType == "number" or vType == "boolean" then
                                    table.insert(lines, string.format("  [%s] (%s) = %s", tostring(k), vType, tostring(v)))
                                else
                                    table.insert(lines, string.format("  [%s] (%s)", tostring(k), vType))
                                end
                            end
                        end
                    end
                end
            end

            local report = table.concat(lines, "\n")
            local copied = Compat and Compat.CopyToClipboard and Compat.CopyToClipboard(report)
            if copied then
                if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                    _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Informe apitest plates copiado al portapapeles.")
                end
            else
                if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                    for i = 1, #lines do
                        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r " .. lines[i])
                    end
                end
            end
        else
            local lines = { "=== ROTACORE REBUFFED API TEST ===" }
        -- C_NamePlate
        if _G.C_NamePlate then
            local npType = type(_G.C_NamePlate)
            local getPlatesType = type(_G.C_NamePlate.GetNamePlates)
            local getUnitPlateType = type(_G.C_NamePlate.GetNamePlateForUnit)
            table.insert(lines, string.format("C_NamePlate: %s (GetNamePlates=%s, GetNamePlateForUnit=%s)",
                npType, getPlatesType, getUnitPlateType))
            if getPlatesType == "function" then
                local ok, plates = pcall(_G.C_NamePlate.GetNamePlates)
                if ok and type(plates) == "table" then
                    local count = #plates
                    local firstInfo = "none"
                    if count > 0 then
                        local first = plates[1]
                        local fType = type(first)
                        if fType == "string" then
                            firstInfo = string.format("token string '%s'", first)
                        elseif fType == "table" then
                            local tok = first.namePlateUnitToken or (first.unitFrame and first.unitFrame.unit) or first.unit or "frame"
                            firstInfo = string.format("frame table with token '%s'", tostring(tok))
                        else
                            firstInfo = fType
                        end
                    end
                    table.insert(lines, string.format("  GetNamePlates() -> count=%d, first=[%s]", count, firstInfo))
                else
                    table.insert(lines, string.format("  GetNamePlates() error or non-table: %s", tostring(plates)))
                end
            end
        else
            table.insert(lines, "C_NamePlate: NOT FOUND (nil)")
        end

        -- UnitIsControlled
        if _G.UnitIsControlled then
            local pCtrl = tostring(_G.UnitIsControlled("player"))
            local tCtrl = (_G.UnitExists and _G.UnitExists("target")) and tostring(_G.UnitIsControlled("target")) or "no target"
            table.insert(lines, string.format("UnitIsControlled: function -> player=%s, target=%s", pCtrl, tCtrl))
        else
            table.insert(lines, "UnitIsControlled: NOT FOUND (nil)")
        end

        -- UnitIsSilenced
        if _G.UnitIsSilenced then
            local pSil = tostring(_G.UnitIsSilenced("player"))
            local tSil = (_G.UnitExists and _G.UnitExists("target")) and tostring(_G.UnitIsSilenced("target")) or "no target"
            table.insert(lines, string.format("UnitIsSilenced: function -> player=%s, target=%s", pSil, tSil))
        else
            table.insert(lines, "UnitIsSilenced: NOT FOUND (nil)")
        end

        -- UnitIsDisarmed
        if _G.UnitIsDisarmed then
            local pDis = tostring(_G.UnitIsDisarmed("player"))
            local tDis = (_G.UnitExists and _G.UnitExists("target")) and tostring(_G.UnitIsDisarmed("target")) or "no target"
            table.insert(lines, string.format("UnitIsDisarmed: function -> player=%s, target=%s", pDis, tDis))
        else
            table.insert(lines, "UnitIsDisarmed: NOT FOUND (nil)")
        end

        -- CopyToClipboard
        if _G.CopyToClipboard then
            table.insert(lines, "CopyToClipboard: function (AVAILABLE)")
        else
            table.insert(lines, "CopyToClipboard: NOT FOUND (nil)")
        end

        -- GetSpellBaseCooldown
        if _G.GetSpellBaseCooldown then
            local testSpellId = 49938
            local ok, raw = pcall(_G.GetSpellBaseCooldown, testSpellId)
            if ok and type(raw) == "number" then
                local norm, _, cdUnit = nil, nil, nil
                if RotaCore.Compat and RotaCore.Compat.GetSpellBaseCooldown then
                    norm, _, cdUnit = RotaCore.Compat.GetSpellBaseCooldown(testSpellId)
                end
                table.insert(lines, string.format("GetSpellBaseCooldown: function -> spell %d (DnD): raw=%s, normalized=%.1fs (%s)",
                    testSpellId, tostring(raw), norm or 0, cdUnit or "unknown"))
            else
                table.insert(lines, string.format("GetSpellBaseCooldown: function -> returned %s", tostring(raw)))
            end
        else
            table.insert(lines, "GetSpellBaseCooldown: NOT FOUND (nil)")
        end

        -- QueueInteract
        if _G.QueueInteract then
            table.insert(lines, "QueueInteract: function (present, but discarded by policy)")
        else
            table.insert(lines, "QueueInteract: NOT FOUND (nil)")
        end

        table.insert(lines, "===================================")
        local report = table.concat(lines, "\n")
        local copied = RotaCore.Compat and RotaCore.Compat.CopyToClipboard and RotaCore.Compat.CopyToClipboard(report)
        if copied then
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Informe de API copiado al portapapeles. ¡Pégalo con agy!")
            end
        else
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                for i = 1, #lines do
                    _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r " .. lines[i])
                end
            end
        end
    end
    else
        if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Rota Suite — Comandos]|r")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc edit|r — Abrir el editor de rotaciones")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc options|r — Abrir las opciones")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc prepull|r — Armar o cancelar el pre-pull (sirve en una macro)")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc burst|r — Alternar Modo Burst (CDs largos)")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc burstmode <side|inline|corner>|r — Modo visual de Burst")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc burstscale <10..50>|r — Tamaño del mini-icono en modo Corner")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc aoe|r — Alternar Modo AoE manual")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc aoefusion <union|confirm|plates|classic>|r — Modo de fusión AoE")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc aoetrace [segundos]|r — Muestreo en tiempo real de señales AoE")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc build <auto|frost|morb|ums|unholy>|r — Forzar build")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc lock|r — Bloquear / Desbloquear movimiento del HUD")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc aprender|r — Modo aprendizaje: motivo de cada sugerencia")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc reset|r — Centrar iconos en pantalla")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc status|r — Ver perfil activo y estado general")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc dump|r — Copiar volcado de diagnóstico al portapapeles")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rc apitest [plates]|r — Diagnóstico y test de API Rebuffed")
            _G.DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/rotaprobe scan / show|r — Diagnóstico y escáner de servidor custom")
        end
    end
end
-- Los botones del panel de Opciones llaman a los mismos comandos que /rc
RotaCore.HandleSlashCmd = HandleSlashCmd

if _G.SlashCmdList then
    _G.SLASH_ROTACORE1 = "/rotacore"
    _G.SLASH_ROTACORE2 = "/rc"
    _G.SLASH_ROTA1 = "/rota"
    _G.SlashCmdList["ROTACORE"] = HandleSlashCmd
    _G.SlashCmdList["ROTA"] = HandleSlashCmd

    _G.SLASH_ROTACOREAOEFUSION1 = "/aoefusion"
    _G.SlashCmdList["ROTACOREAOEFUSION"] = function(msg)
        HandleSlashCmd("aoefusion " .. (msg or ""))
    end

    _G.SLASH_ROTACOREAOETRACE1 = "/aoetrace"
    _G.SlashCmdList["ROTACOREAOETRACE"] = function(msg)
        HandleSlashCmd("aoetrace " .. (msg or ""))
    end
end

-- Pre-allocated event listener frame
local eventFrame = nil
if _G.CreateFrame then
    eventFrame = _G.CreateFrame("Frame", "RotaCoreEventFrame")
end

--- Loads or selects an appropriate class preset without crashing.
local function LoadClassPreset()
    if not _G.UnitClass then return end
    local _, classToken = _G.UnitClass("player")
    if not classToken then return end
    -- Sin nombre de PJ no se sabe que build cargar; PLAYER_LOGIN vuelve a llamar.
    if not RotaCore:GetCharKey() then return end

    -- Load corresponding class module if available and not yet loaded
    local classModuleMap = {
        DEATHKNIGHT = "RotaClass_DK",
        PALADIN     = "RotaClass_PAL",
        WARRIOR     = "RotaClass_WAR",
        ROGUE       = "RotaClass_ROG",
        SHAMAN      = "RotaClass_SHA",
        WARLOCK     = "RotaClass_WL",
        MAGE        = "RotaClass_MAG",
        PRIEST      = "RotaClass_PRI",
        HUNTER      = "RotaClass_HUN",
        DRUID       = "RotaClass_DRU",
    }
    local classAddon = classModuleMap[classToken]
    if classAddon and _G.LoadAddOn and not _G[classAddon] then
        pcall(function() _G.LoadAddOn(classAddon) end)
    end

    local mod = RotaCore:GetClassModule(classToken)
    -- En ADDON_LOADED de RotaCore el modulo de clase todavia no cargo: sin su lista de builds la build guardada
    -- parece invalida y se pisaba con "auto". PLAYER_LOGIN vuelve a llamar con el modulo ya registrado.
    if not mod then return end
    local builds = mod.builds or RotaCore:GetClassBuilds(classToken)

    local charName = (_G.UnitName and _G.UnitName("player")) or "Unknown"
    local realmName = (_G.GetRealmName and _G.GetRealmName()) or "Unknown"
    local charKey = charName .. " - " .. realmName

    local db = _G.RotaCoreDB
    if db then
        db.classProfiles = db.classProfiles or {}
        db.charProfiles = db.charProfiles or {}
        db.classBuilds = db.classBuilds or {}
        db.charBuilds = db.charBuilds or {}
        db.settings = db.settings or {}
    end

    -- Validate and retrieve build specific to this character and class
    local savedBuild = db and db.charBuilds[charKey]
    local isValidBuild = false
    if savedBuild == "auto" then
        isValidBuild = true
    elseif savedBuild then
        for _, b in ipairs(builds) do
            if b.key == savedBuild then
                isValidBuild = true
                break
            end
        end
    end
    if not isValidBuild then
        savedBuild = "auto"
    end

    -- Call detectBuild on module or legacy fallback
    local detectedKey, detectedPreset
    if mod and mod.detectBuild then
        local ok, k, p = pcall(mod.detectBuild)
        if ok then
            detectedKey = k
            detectedPreset = p
        end
    elseif classToken == "DEATHKNIGHT" and _G.RotaClass_DK and _G.RotaClass_DK.DetectBuild then
        local ok, k, p = pcall(function() return _G.RotaClass_DK:DetectBuild() end)
        if ok then detectedKey, detectedPreset = k, p end
    elseif classToken == "WARRIOR" and _G.RotaClass_WAR and _G.RotaClass_WAR.DetectSpec then
        local ok, _, pid, bkey = pcall(function() return _G.RotaClass_WAR:DetectSpec() end)
        if ok then detectedKey, detectedPreset = bkey, pid end
    end

    -- Validar que savedBuild coincida con los talentos reales del jugador (ej. DK)
    if classToken == "DEATHKNIGHT" and detectedKey and (savedBuild == "frost" or savedBuild ~= "auto") then
        local unholyPts = (_G.RotaClass_DK and _G.RotaClass_DK.unholyPoints) or 0
        local frostPts = (_G.RotaClass_DK and _G.RotaClass_DK.frostPoints) or 0
        if (savedBuild == "frost" and unholyPts >= 50 and frostPts < 31)
           or (savedBuild:find("unholy") and frostPts >= 50 and unholyPts < 31) then
            savedBuild = detectedKey
            if db then
                if db.settings then db.settings.selectedBuild = savedBuild end
                if db.charBuilds then db.charBuilds[charKey] = savedBuild end
                if db.classBuilds then db.classBuilds[classToken] = savedBuild end
                if db.charProfiles then db.charProfiles[charKey] = detectedPreset end
                if db.classProfiles then db.classProfiles[classToken] = detectedPreset end
            end
            if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile and detectedPreset then
                RotaCore.Profiles:SetActiveProfile(detectedPreset)
            end
        end
    end

    if db and db.settings then
        db.settings.selectedBuild = savedBuild
    end
    if db and db.charBuilds then
        db.charBuilds[charKey] = savedBuild
    end
    if db and db.classBuilds then
        db.classBuilds[classToken] = savedBuild
    end

    local curProfile = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    local classMismatch = (not curProfile) or (not curProfile.meta) or (curProfile.meta.class ~= classToken)

    if classMismatch then
        if RotaCore.Profiles then
            RotaCore.Profiles.activeProfile = nil
            RotaCore.Profiles.activeEvaluator = nil
            RotaCore.activeEvaluator = nil
        end

        local savedProfileId = db and (db.charProfiles[charKey] or db.classProfiles[classToken])
        local candidateIR
        if savedProfileId and RotaCore.Profiles then
            if RotaCore.Profiles.GetProfile then
                candidateIR = RotaCore.Profiles:GetProfile(savedProfileId)
            else
                candidateIR = RotaCore.Profiles:GetPreset(savedProfileId)
            end
        end
        local classMatches = candidateIR and candidateIR.meta and candidateIR.meta.class == classToken
        if classMatches and (savedBuild ~= "auto" or classToken == "PALADIN") then
            RotaCore.Profiles:SetActiveProfile(candidateIR)
        else
            local buildMatchedPreset = nil
            if savedBuild ~= "auto" then
                for _, b in ipairs(builds) do
                    if b.key == savedBuild and b.preset then
                        buildMatchedPreset = b.preset
                        break
                    end
                end
            end

            if buildMatchedPreset and RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
                RotaCore.Profiles:SetActiveProfile(buildMatchedPreset)
            elseif detectedPreset and RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
                RotaCore.Profiles:SetActiveProfile(detectedPreset)
            elseif classToken == "PALADIN" then
                local palProf = (savedProfileId and candidateIR) or "pal_retribution_pve"
                RotaCore.Profiles:SetActiveProfile(palProf)
            else
                for id, preset in pairs(RotaCore.Profiles and RotaCore.Profiles.presets or {}) do
                    if preset.meta and preset.meta.class == classToken then
                        RotaCore.Profiles:SetActiveProfile(id)
                        break
                    end
                end
            end
        end
    else
        if savedBuild == "auto" then
            if detectedPreset and RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
                RotaCore.Profiles:SetActiveProfile(detectedPreset)
            end
        else
            for _, b in ipairs(builds) do
                if b.key == savedBuild and b.preset then
                    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
                        RotaCore.Profiles:SetActiveProfile(b.preset)
                    end
                    break
                end
            end
        end
    end

    if RotaCore.UI and RotaCore.UI.UpdateButtonStates then
        pcall(function() RotaCore.UI:UpdateButtonStates() end)
    end
end
RotaCore.LoadClassPreset = LoadClassPreset

--- Safe initialization sequence: guarantees HUD initialization and class preset load
-- without aborting if any single submodule encounters an error.
function RotaCore:Init()
    -- 1. Profiles database restore
    if RotaCore.Profiles and RotaCore.Profiles.InitDB then
        pcall(function() RotaCore.Profiles:InitDB() end)
    end

    -- 2. HUD Initialization
    if RotaCore.UI and RotaCore.UI.Init then
        pcall(function() RotaCore.UI:Init() end)
    end

    -- 3. Class Preset Loading
    pcall(LoadClassPreset)

    -- 4. Submodules (Minimap & Options)
    if RotaCore.Minimap and RotaCore.Minimap.Init then
        pcall(function() RotaCore.Minimap:Init() end)
    end

    if RotaCore.Options and RotaCore.Options.Init then
        pcall(function() RotaCore.Options:Init() end)
    end

    if RotaCore.Prepull and RotaCore.Prepull.Init then
        pcall(function() RotaCore.Prepull:Init() end)
    end
end

-- Builds elegidas sin un hechizo de talento que necesitan (meta.requires): aviso una vez por build y sesion
local warnedRequires = {}
local function CheckRequires(ir, state)
    local meta = ir and ir.meta
    local id = meta and (meta.v1Of or meta.id)
    if not id or warnedRequires[id] or not meta.requires or state.inCombat ~= true then return end
    warnedRequires[id] = true
    local missing = nil
    for _, alias in ipairs(meta.requires) do
        if not (state.hasSpell and state.hasSpell(alias)) then
            local s = ir.spells and ir.spells[alias]
            local name = (s and s.name) or alias
            missing = missing and (missing .. ", " .. name) or name
        end
    end
    if missing and _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[RotaCore]|r La build " .. tostring(meta.name or id)
            .. " necesita " .. missing .. " y no lo tenes aprendido (talento): esa parte de la rotacion no se va a pedir. "
            .. "Revisa la build elegida en Opciones.")
    end
end
RotaCore.CheckRequires = CheckRequires

--- Primary evaluation cycle: Updates State and invokes active evaluators.
-- 0 KB/s garbage generation in hot-path.
-- @param now number|nil
-- @return string|nil mainAction, string|nil offAction
function RotaCore:UpdateAndEvaluate(now)
    if _G.UnitClass then
        local _, playerClass = _G.UnitClass("player")
        local curProf = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
        if playerClass and (not curProf or not curProf.meta or curProf.meta.class ~= playerClass) then
            LoadClassPreset()
        end
    end

    local state = RotaCore.State:Update(now)
    local evalBundle = RotaCore.Profiles and RotaCore.Profiles:GetActiveEvaluator()

    local mainAction = nil
    local offAction = nil

    if evalBundle then
        CheckRequires(RotaCore.Profiles:GetActiveProfile(), state)
        -- Cada evaluacion arranca sin "esperando" ni motivo: el HUD los muestra tal cual quedan
        state.isWaiting = false
        state.reason = nil
        state.waitTime = nil
        -- Pre-Pull armado: el icono grande muestra la lista prepull hasta el pull (RotaCore/Prepull.lua)
        local Prepull = RotaCore.Prepull
        if Prepull and Prepull.armed then mainAction = Prepull:Evaluate(state, evalBundle) end
        if not mainAction and evalBundle.evaluatorMain then
            mainAction = evalBundle.evaluatorMain(state)
        end
        if evalBundle.evaluatorOff then
            offAction = evalBundle.evaluatorOff(state)
        end
    end

    if RotaCore.Prepull then RotaCore.Prepull:Tick(state) end
    RotaCore.lastMainAction = mainAction
    RotaCore.lastOffAction = offAction
    if RotaCore.Snapshot then RotaCore.Snapshot:AfterEvaluate(state, mainAction, offAction) end

    if RotaCore.UI and RotaCore.UI.UpdateDisplay then
        RotaCore.UI:UpdateDisplay(mainAction, offAction)
    end

    return mainAction, offAction
end

--- Addon event dispatcher
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "RotaCore" then
            RotaCore:Init()
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if RotaCore.UI and not RotaCore.UI.hudFrame and RotaCore.UI.Init then
            pcall(function() RotaCore.UI:Init() end)
        end
        if RotaCore.Spells and RotaCore.Spells.ScanSpellBook then
            pcall(function() RotaCore.Spells:ScanSpellBook() end)
        end
        if RotaCore.State and RotaCore.State.ScanTalentsAndGlyphs then
            pcall(function() RotaCore.State:ScanTalentsAndGlyphs() end)
        end
        pcall(LoadClassPreset)
        if RotaCore.UI and RotaCore.UI.UpdateButtonStates then
            pcall(function() RotaCore.UI:UpdateButtonStates() end)
        end
    elseif event == "SPELLS_CHANGED" then
        if RotaCore.Spells and RotaCore.Spells.ScanSpellBook then
            pcall(function() RotaCore.Spells:ScanSpellBook() end)
        end
    elseif event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if RotaCore.State and RotaCore.State.ScanTalentsAndGlyphs then
            pcall(function() RotaCore.State:ScanTalentsAndGlyphs() end)
        end
        if event == "ACTIVE_TALENT_GROUP_CHANGED" then
            local newGroup = ...
            if RotaCore.Profiles and RotaCore.Profiles.OnTalentGroupChanged then
                pcall(function() RotaCore.Profiles:OnTalentGroupChanged(newGroup) end)
            end
        end
        pcall(LoadClassPreset)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if RotaCore.State and RotaCore.State.data then
            RotaCore.State.data.inCombat = true
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if RotaCore.State and RotaCore.State.data then
            RotaCore.State.data.inCombat = false
        end
        local eval = RotaCore.Profiles and RotaCore.Profiles:GetActiveEvaluator()
        if eval and eval.resetSequences then
            pcall(eval.resetSequences)
        end
    end
end

if eventFrame then
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", OnEvent)
end

return RotaCore
