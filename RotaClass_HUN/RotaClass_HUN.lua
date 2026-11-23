-- RotaClass_HUN/RotaClass_HUN.lua — Hunter State Provider, Build Detection & Evaluators (WoW 3.3.5a)
-- Specs: Beast Mastery, Marksmanship, Survival.
-- Fuentes: guias de Wowhead WotLK + Rebuffed (Trap Launcher: Explosive Trap).
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_HUN = {
    detectedBuild = "marksmanship",
    detectedPresetId = "hun_marksmanship_pve",
    detectedSpecName = "Marksmanship",
    detectedBadge = "[MM]",
}
_G.RotaClass_HUN = RotaClass_HUN

local function SN(id, fallback)
    return (_G.GetSpellInfo and _G.GetSpellInfo(id)) or fallback
end

-- Hechizos: alias -> { nombre ingles, ID de rango maximo }
-- shortcut: el ID de Trap Launcher: Explosive Trap (Rebuffed) no esta confirmado; se busca por nombre primero.
local SPELLS = {
    KS = { "Kill Shot", 61006 },            KC = { "Kill Command", 34026 },       MULTI = { "Multi-Shot", 49048 },
    SERPENT = { "Serpent Sting", 49001 },   ARCANE = { "Arcane Shot", 49045 },    STEADY = { "Steady Shot", 49052 },
    AIMED = { "Aimed Shot", 49050 },        CHIMERA = { "Chimera Shot", 53209 },  ES = { "Explosive Shot", 60053 },
    BA = { "Black Arrow", 63672 },          SILENCE = { "Silencing Shot", 34490 }, BW = { "Bestial Wrath", 19574 },
    RF = { "Rapid Fire", 3045 },            READY = { "Readiness", 23989 },       VOLLEY = { "Volley", 58434 },
    TRAP = { "Trap Launcher: Explosive Trap", 82939 },
    DRAGONHAWK = { "Aspect of the Dragonhawk", 61847 }, VIPER = { "Aspect of the Viper", 34074 },
}

local NAME = {
    SERPENT = SN(49001, "Serpent Sting"),   DRAGONHAWK = SN(61847, "Aspect of the Dragonhawk"),
    VIPER = SN(34074, "Aspect of the Viper"), LNL = SN(56453, "Lock and Load"),
}

local function HunHas(state, alias)
    if state and state.hasSpell then
        local s = state.hasSpell(alias)
        if s ~= nil then return s and true or false end
    end
    local info = SPELLS[alias]
    if info and _G.GetSpellCooldown then
        return _G.GetSpellCooldown(SN(info[2], info[1])) ~= nil
    end
    return false
end

-- Cooldown real: nil = no conocido | 0 = listo (o solo GCD) | n = segundos
local function Cd(state, alias)
    local info = SPELLS[alias]
    if not info or not _G.GetSpellCooldown then return nil end
    local s, d = _G.GetSpellCooldown(SN(info[2], info[1]))
    if s == nil then s, d = _G.GetSpellCooldown(info[2]) end
    if s == nil then return nil end
    if s == 0 or not d or d <= 1.5 then return 0 end
    local now = (state and state.now) or (_G.GetTime and _G.GetTime()) or 0
    local rem = (s + d) - now
    return rem > 0 and rem or 0
end

local function Ready(state, alias)
    if not HunHas(state, alias) then return false end
    local cd = Cd(state, alias)
    if cd ~= nil then return cd <= (((state and state.gcdRemains) or 0) + 0.1) end
    return (state.spellReady and state.spellReady(alias)) and true or false
end

local function Var(state, name, default)
    local v = state.vars and state.vars[name]
    if v == nil then return default end
    return v
end

-- Talentos: puntos por arbol (1 Beast Mastery, 2 Marksmanship, 3 Survival)
local tabPoints = { 0, 0, 0 }
local function ScanTalents()
    tabPoints[1], tabPoints[2], tabPoints[3] = 0, 0, 0
    if not _G.GetTalentInfo then return end
    for tab = 1, 3 do
        local sum = 0
        local n = (_G.GetNumTalents and _G.GetNumTalents(tab)) or 0
        for idx = 1, n do
            local _, _, _, _, rank = _G.GetTalentInfo(tab, idx)
            sum = sum + (rank or 0)
        end
        if _G.GetTalentTabInfo then
            local _, _, spent = _G.GetTalentTabInfo(tab)
            if type(spent) == "number" and spent > sum then sum = spent end
        end
        tabPoints[tab] = sum
    end
end

-- Provider de estado (cada update; state.hun se aloca una sola vez)
local function UpdateHunterState(state, _)
    local hun = state.hun
    if not hun then
        hun = {}
        state.hun = hun
    end
    local now = state.now or (_G.GetTime and _G.GetTime()) or 0

    local hawk, viper, lnl = false, false, 0
    if _G.UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT = _G.UnitBuff("player", i)
            if not name then break end
            if name == NAME.DRAGONHAWK then hawk = true
            elseif name == NAME.VIPER then viper = true
            elseif name == NAME.LNL then
                lnl = (expT and expT > 0) and (expT - now) or 999
                if lnl < 0 then lnl = 0 end
            end
        end
    end
    hun.dragonhawk, hun.viper, hun.lockAndLoad = hawk, viper, lnl

    local serpent = 0
    if _G.UnitDebuff and state.hasTarget ~= false then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT, caster = _G.UnitDebuff("target", i)
            if not name then break end
            if name == NAME.SERPENT and caster == "player" then
                serpent = (expT and expT > 0) and (expT - now) or 999
                if serpent < 0 then serpent = 0 end
                break
            end
        end
    end
    hun.serpentSting = serpent

    local hp = 100
    if _G.UnitHealth and _G.UnitHealthMax then
        local mx = _G.UnitHealthMax("target") or 0
        if mx > 0 then hp = (_G.UnitHealth("target") or 0) / mx * 100 end
    end
    hun.targetHealthPct = hp
end

-- AoE comun: Trap Launcher: Explosive Trap > Multi-Shot > Volley
local function HunterAoE(state)
    if Ready(state, "TRAP") then return "TRAP" end
    if Ready(state, "MULTI") then return "MULTI" end
    if HunHas(state, "VOLLEY") then return "VOLLEY" end
    return nil
end

local function KillShot(state, hun)
    return hun.targetHealthPct <= 20 and Ready(state, "KS")
end

-- BEAST MASTERY
-- Kill Shot (<= 20%) > Multi-Shot (si sobra mana) > Serpent Sting > Arcane Shot > Steady Shot
function RotaClass_HUN.EvaluateBeastMastery(state)
    local hun = state.hun
    local gcd = state.gcdRemains or 0
    if state.aoeMode then
        local a = HunterAoE(state)
        if a then return a end
    end
    if KillShot(state, hun) then return "KS" end
    if (state.powerPct or 100) >= Var(state, "multiShotMana", 40) and Ready(state, "MULTI") then return "MULTI" end
    if hun.serpentSting <= gcd and HunHas(state, "SERPENT") then return "SERPENT" end
    if Var(state, "arcaneShot", 1) == 1 and Ready(state, "ARCANE") then return "ARCANE" end
    return "STEADY"
end

-- MARKSMANSHIP
-- Kill Shot (<= 20%) > Serpent Sting > Chimera Shot (con Serpent Sting puesto) > Aimed Shot
-- > Trap Launcher: Explosive Trap > Arcane Shot > Steady Shot
function RotaClass_HUN.EvaluateMarksmanship(state)
    local hun = state.hun
    local gcd = state.gcdRemains or 0
    if state.aoeMode then
        local a = HunterAoE(state)
        if a then return a end
    end
    if KillShot(state, hun) then return "KS" end
    if hun.serpentSting <= gcd and HunHas(state, "SERPENT") then return "SERPENT" end
    if hun.serpentSting > gcd and Ready(state, "CHIMERA") then return "CHIMERA" end
    if Ready(state, "AIMED") then return "AIMED" end
    if Var(state, "explosiveTrap", 1) == 1 and Ready(state, "TRAP") then return "TRAP" end
    if Var(state, "arcaneShot", 1) == 1 and Ready(state, "ARCANE") then return "ARCANE" end
    return "STEADY"
end

-- SURVIVAL
-- Kill Shot (<= 20%) > Explosive Shot > Trap Launcher: Explosive Trap > Serpent Sting (solo si se cayo) > Black Arrow
-- > Aimed Shot > Steady Shot. Wowhead: Kill Shot, Explosive Shot y Explosive Trap van antes de reponer Serpent Sting.
-- Arcane Shot no: comparte CD con Explosive Shot.
function RotaClass_HUN.EvaluateSurvival(state)
    local hun = state.hun
    local gcd = state.gcdRemains or 0
    if state.aoeMode then
        local a = HunterAoE(state)
        if a then return a end
    end
    if KillShot(state, hun) then return "KS" end
    if Ready(state, "ES") then return "ES" end
    -- Explosive Trap rinde mas que Black Arrow si el boss no se mueve (comparten CD)
    if Var(state, "explosiveTrap", 1) == 1 and Ready(state, "TRAP") then return "TRAP" end
    if hun.serpentSting <= gcd and HunHas(state, "SERPENT") then return "SERPENT" end
    if Ready(state, "BA") then return "BA" end
    if Ready(state, "AIMED") then return "AIMED" end
    return "STEADY"
end

-- Off-GCD comun: aspecto, Kill Command y cooldowns
local function AspectOff(state, hun)
    local mana = state.powerPct or 100
    if hun.viper then
        if mana >= Var(state, "viperExitMana", 70) and HunHas(state, "DRAGONHAWK") then return "DRAGONHAWK" end
        return nil
    end
    if state.inCombat and mana < Var(state, "viperMana", 10) and HunHas(state, "VIPER") then return "VIPER" end
    if not hun.dragonhawk and HunHas(state, "DRAGONHAWK") then return "DRAGONHAWK" end
    return nil
end

local function CommonOff(state)
    local hun = state.hun
    local a = AspectOff(state, hun)
    if a then return a end
    if not state.inCombat then return nil end
    if Ready(state, "KC") then return "KC" end
    if state.burstMode ~= false then
        if Ready(state, "RF") then return "RF" end
        if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
        if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    end
    return nil
end

function RotaClass_HUN.EvaluateBeastMasteryOff(state)
    local a = AspectOff(state, state.hun)
    if a then return a end
    if state.inCombat and state.burstMode ~= false and Ready(state, "BW") then return "BW" end
    return CommonOff(state)
end

function RotaClass_HUN.EvaluateMarksmanshipOff(state)
    local a = CommonOff(state)
    if a then return a end
    if not state.inCombat then return nil end
    if Ready(state, "SILENCE") then return "SILENCE" end
    -- Readiness con Rapid Fire y Chimera Shot gastados (resetea ambos y el trap)
    if state.burstMode ~= false and Ready(state, "READY") then
        local rf, ch = Cd(state, "RF") or 0, Cd(state, "CHIMERA") or 0
        if rf > 30 and ch > 2 then return "READY" end
    end
    return nil
end

RotaClass_HUN.EvaluateSurvivalOff = CommonOff

-- Evaluadores publicos: nunca devuelven nil
local function Wrap(fn)
    return function(state)
        state.isWaiting = false
        return fn(state) or "STEADY"
    end
end

RotaClass_HUN.Evaluate = {
    beast_mastery = Wrap(RotaClass_HUN.EvaluateBeastMastery),
    marksmanship = Wrap(RotaClass_HUN.EvaluateMarksmanship),
    survival = Wrap(RotaClass_HUN.EvaluateSurvival),
}

if RotaCore.State and RotaCore.State.data then
    local sd = RotaCore.State.data
    sd.evaluateHunBeastMastery = RotaClass_HUN.Evaluate.beast_mastery
    sd.evaluateHunBeastMasteryOff = RotaClass_HUN.EvaluateBeastMasteryOff
    sd.evaluateHunMarksmanship = RotaClass_HUN.Evaluate.marksmanship
    sd.evaluateHunMarksmanshipOff = RotaClass_HUN.EvaluateMarksmanshipOff
    sd.evaluateHunSurvival = RotaClass_HUN.Evaluate.survival
    sd.evaluateHunSurvivalOff = RotaClass_HUN.EvaluateSurvivalOff
end

-- Deteccion de build: arbol con mas puntos. Override con la build elegida por el PJ.
local BUILDS = {
    beast_mastery = { "hun_beast_mastery_pve", "Beast Mastery", "[BM]" },
    marksmanship = { "hun_marksmanship_pve", "Marksmanship", "[MM]" },
    survival = { "hun_survival_pve", "Survival", "[SV]" },
}

function RotaClass_HUN:DetectBuild()
    ScanTalents()
    local key = "marksmanship"
    if tabPoints[1] > tabPoints[2] and tabPoints[1] >= tabPoints[3] then
        key = "beast_mastery"
    elseif tabPoints[3] > tabPoints[2] and tabPoints[3] > tabPoints[1] then
        key = "survival"
    end
    local b = BUILDS[key]
    RotaClass_HUN.detectedBuild = key
    RotaClass_HUN.detectedPresetId = b[1]
    RotaClass_HUN.detectedSpecName = b[2]
    RotaClass_HUN.detectedBadge = b[3]

    local sel = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or "auto"
    local active = BUILDS[sel] and BUILDS[sel][1] or b[1]

    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(active)
    end
    return key, active, b[2]
end

RotaClass_HUN.UpdateState = UpdateHunterState

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "HUNTER",
        addonName = "RotaClass_HUN",
        classColor = { r = 0.67, g = 0.83, b = 0.45 },
        builds = {
            { key = "auto", name = "AUTO", color = {1.0, 0.9, 0.0} },
            { key = "beast_mastery", name = "Beast Mastery", color = {0.9, 0.6, 0.2}, preset = "hun_beast_mastery_pve" },
            { key = "marksmanship", name = "Marksmanship", color = {0.4, 0.8, 0.4}, preset = "hun_marksmanship_pve" },
            { key = "survival", name = "Survival", color = {0.8, 0.8, 0.3}, preset = "hun_survival_pve" },
        },
        detectBuild = function() return RotaClass_HUN:DetectBuild() end,
        getIdlePreviewAction = function() return "STEADY" end,
        stateProvider = UpdateHunterState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("HUNTER", UpdateHunterState)
end

if _G.CreateFrame and not RotaClass_HUN.eventFrame then
    local f = _G.CreateFrame("Frame", "RotaClass_HUN_EventFrame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:SetScript("OnEvent", function() RotaClass_HUN:DetectBuild() end)
    RotaClass_HUN.eventFrame = f
end

return RotaClass_HUN
