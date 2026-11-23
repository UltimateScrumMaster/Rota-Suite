-- RotaClass_SHA/RotaClass_SHA.lua — Shaman State Provider, Build Detection & Evaluators (WoW 3.3.5a)
-- Specs: Elemental, Enhancement. Restoration no tiene rotacion de dano: se trata como Elemental.
-- Fuente: guias de Wowhead WotLK + cambios de Rebuffed (docs/REBUFFED.md).
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_SHA = {
    detectedBuild = "elemental",
    detectedPresetId = "sha_elemental_pve",
    detectedSpecName = "Elemental",
    detectedBadge = "[ELE]",
}
_G.RotaClass_SHA = RotaClass_SHA

local function SN(id, fallback)
    return (_G.GetSpellInfo and _G.GetSpellInfo(id)) or fallback
end

-- Hechizos: alias -> { nombre ingles, ID de rango maximo }
local SPELLS = {
    LB = { "Lightning Bolt", 49238 },       CL = { "Chain Lightning", 49271 },   LVB = { "Lava Burst", 60043 },
    FS = { "Flame Shock", 49233 },          ES = { "Earth Shock", 49231 },       TS = { "Thunderstorm", 59159 },
    EM = { "Elemental Mastery", 16166 },    FET = { "Fire Elemental Totem", 2894 },
    TOW = { "Totem of Wrath", 57722 },      MAGMA = { "Magma Totem", 58734 },    FN = { "Fire Nova", 61657 },
    SS = { "Stormstrike", 17364 },          LL = { "Lava Lash", 60103 },         FSPIRIT = { "Feral Spirit", 51533 },
    SR = { "Shamanistic Rage", 30823 },     LS = { "Lightning Shield", 49281 },  WS = { "Water Shield", 57960 },
    FTW = { "Flametongue Weapon", 58790 },  WFW = { "Windfury Weapon", 58804 },  FRS = { "Frost Shock", 49236 },
}

-- Nombres localizados de auras
local NAME = {
    MAELSTROM = SN(53817, "Maelstrom Weapon"),  LS = SN(49281, "Lightning Shield"),
    WS = SN(57960, "Water Shield"),             FS = SN(49233, "Flame Shock"),
    EM = SN(16166, "Elemental Mastery"),        CC = SN(16246, "Clearcasting"),
    FET = SN(2894, "Fire Elemental Totem"),     MAGMA = SN(58734, "Magma Totem"),
}

local function ShaHas(state, alias)
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
    if not ShaHas(state, alias) then return false end
    local cd = Cd(state, alias)
    if cd ~= nil then return cd <= (((state and state.gcdRemains) or 0) + 0.1) end
    return (state.spellReady and state.spellReady(alias)) and true or false
end

local function Var(state, name, default)
    local v = state.vars and state.vars[name]
    if v == nil then return default end
    return v
end

-- Talentos: puntos por arbol (1 Elemental, 2 Enhancement, 3 Restoration)
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

-- Provider de estado (cada update; state.sha se aloca una sola vez)
local function UpdateShamanState(state, _)
    local sha = state.sha
    if not sha then
        sha = {}
        state.sha = sha
    end
    local now = state.now or (_G.GetTime and _G.GetTime()) or 0

    local mael, ls, ws, em, cc = 0, 0, 0, 0, 0
    if _G.UnitBuff then
        for i = 1, 40 do
            local name, _, _, count, _, _, expT = _G.UnitBuff("player", i)
            if not name then break end
            local rem = (expT and expT > 0) and (expT - now) or 999
            if rem < 0 then rem = 0 end
            if name == NAME.MAELSTROM then mael = count or 1
            elseif name == NAME.LS then ls = rem
            elseif name == NAME.WS then ws = rem
            elseif name == NAME.EM then em = rem
            elseif name == NAME.CC then cc = rem end
        end
    end
    sha.maelstrom, sha.lightningShield, sha.waterShield = mael, ls, ws
    sha.elementalMastery, sha.clearcasting = em, cc

    local fs = 0
    if _G.UnitDebuff and state.hasTarget ~= false then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT, caster = _G.UnitDebuff("target", i)
            if not name then break end
            if name == NAME.FS and caster == "player" then
                fs = (expT and expT > 0) and (expT - now) or 0
                if fs < 0 then fs = 0 end
                break
            end
        end
    end
    sha.flameShock = fs

    -- Totem de fuego (slot 1)
    local fireName, fireRem = nil, 0
    if _G.GetTotemInfo then
        local have, tName, start, dur = _G.GetTotemInfo(1)
        if have and tName and tName ~= "" then
            fireName = tName
            fireRem = (start or 0) + (dur or 0) - now
            if fireRem < 0 then fireRem = 0 end
        end
    end
    sha.fireTotem = fireName
    sha.fireTotemRemaining = fireRem
    sha.fireElemental = (fireName == NAME.FET)
    sha.magma = (fireName == NAME.MAGMA)

    -- Imbues de arma
    local hasMH, hasOH = false, false
    if _G.GetWeaponEnchantInfo then
        local mh, _, _, oh = _G.GetWeaponEnchantInfo()
        hasMH, hasOH = mh and true or false, oh and true or false
    end
    sha.mainImbue, sha.offImbue = hasMH, hasOH
    sha.dualWield = (_G.OffhandHasWeapon and _G.OffhandHasWeapon()) and true or false
    sha.moving = (_G.GetUnitSpeed and (_G.GetUnitSpeed("player") or 0) > 0) and true or false
end

-- ELEMENTAL (Wowhead)
-- ST: Flame Shock (caido) > Lava Burst (con Flame Shock) > Thunderstorm (mana) > Totem of Wrath > Lightning Bolt
-- En movimiento: Flame Shock si esta caido, si no Frost Shock.
-- AoE: Magma Totem > Fire Nova > Chain Lightning > Flame Shock > Lava Burst > Thunderstorm > Lightning Bolt
function RotaClass_SHA.EvaluateElemental(state)
    local sha = state.sha
    local gcd = state.gcdRemains or 0
    local mana = state.powerPct or 100

    if sha.moving then
        if sha.flameShock <= gcd and Ready(state, "ES") and ShaHas(state, "FS") then return "FS" end
        if Ready(state, "ES") and ShaHas(state, "FRS") then return "FRS" end
    end

    if state.aoeMode then
        if not sha.fireTotem and Ready(state, "MAGMA") then return "MAGMA" end
        if sha.fireTotem and not sha.fireElemental and Ready(state, "FN") then return "FN" end
        if Ready(state, "CL") then return "CL" end
        if sha.flameShock <= gcd and Ready(state, "ES") and ShaHas(state, "FS") then return "FS" end
        if sha.flameShock > gcd + 1.5 and Ready(state, "LVB") then return "LVB" end
        if mana < Var(state, "thunderstormMana", 60) and Ready(state, "TS") then return "TS" end
        return "LB"
    end

    if sha.flameShock <= gcd and Ready(state, "ES") and ShaHas(state, "FS") then return "FS" end
    -- Lava Burst solo si Flame Shock sigue arriba cuando termine el casteo (~1.5 s)
    if sha.flameShock > gcd + 1.5 and Ready(state, "LVB") then return "LVB" end
    if mana < Var(state, "thunderstormMana", 60) and Ready(state, "TS") then return "TS" end
    if state.inCombat and not sha.fireTotem and Ready(state, "TOW") then return "TOW" end
    return "LB"
end
function RotaClass_SHA.EvaluateElementalOff(state)
    local sha = state.sha
    if sha.waterShield <= 0 and sha.lightningShield <= 0 and Ready(state, "WS") then return "WS" end
    if not state.inCombat then
        if not sha.mainImbue and ShaHas(state, "FTW") then return "FTW" end
        return nil
    end
    if state.burstMode ~= false then
        if Ready(state, "EM") then return "EM" end
        if Var(state, "fireElemental", 1) == 1 and not sha.fireElemental and Ready(state, "FET") then return "FET" end
        if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
        if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    end
    return nil
end

-- ENHANCEMENT (Wowhead)
-- Maelstrom 5 > Stormstrike > Flame Shock (caido) > Magma Totem > Lightning Shield > Earth Shock > Fire Nova > Lava Lash
-- AoE: Magma Totem > Fire Nova > Maelstrom 5 (Chain Lightning) > Stormstrike > el resto igual
function RotaClass_SHA.EvaluateEnhancement(state)
    local sha = state.sha
    local gcd = state.gcdRemains or 0
    local maelMin = Var(state, "maelstromMin", 5)

    if state.aoeMode then
        if not sha.fireTotem and Ready(state, "MAGMA") then return "MAGMA" end
        if sha.fireTotem and not sha.fireElemental and Ready(state, "FN") then return "FN" end
    end

    if sha.maelstrom >= maelMin then
        if state.aoeMode and Ready(state, "CL") then return "CL" end
        return "LB"
    end

    if Ready(state, "SS") then return "SS" end
    local shockReady = Ready(state, "ES")
    if shockReady and sha.flameShock <= gcd and ShaHas(state, "FS") then return "FS" end
    if state.inCombat and not sha.fireTotem and Ready(state, "MAGMA") then return "MAGMA" end
    if sha.lightningShield <= 0 and ShaHas(state, "LS") then return "LS" end
    if shockReady then return "ES" end
    if sha.fireTotem and not sha.fireElemental and Ready(state, "FN") then return "FN" end
    if Ready(state, "LL") then return "LL" end
    return nil
end

function RotaClass_SHA.EvaluateEnhancementOff(state)
    local sha = state.sha
    if not state.inCombat then
        if not sha.mainImbue and ShaHas(state, "WFW") then return "WFW" end
        if sha.dualWield and not sha.offImbue and ShaHas(state, "FTW") then return "FTW" end
        return nil
    end
    -- Wowhead: Shamanistic Rage a CD (shamanisticRageMana = 100); bajar el valor para guardarla para mana
    if (state.powerPct or 100) <= Var(state, "shamanisticRageMana", 100) and Ready(state, "SR") then return "SR" end
    if state.burstMode ~= false then
        if Ready(state, "FSPIRIT") then return "FSPIRIT" end
        if Var(state, "fireElemental", 1) == 1 and not sha.fireElemental and Ready(state, "FET") then return "FET" end
        if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
        if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    end
    return nil
end

-- Evaluadores publicos: nunca devuelven nil
local function Wrap(fn, fallback)
    return function(state)
        state.isWaiting = false
        local a = fn(state)
        if a then return a end
        state.isWaiting = true
        return fallback
    end
end

RotaClass_SHA.Evaluate = {
    elemental = Wrap(RotaClass_SHA.EvaluateElemental, "LB"),
    enhancement = Wrap(RotaClass_SHA.EvaluateEnhancement, "SS"),
}

if RotaCore.State and RotaCore.State.data then
    local sd = RotaCore.State.data
    sd.evaluateShaElemental = RotaClass_SHA.Evaluate.elemental
    sd.evaluateShaElementalOff = RotaClass_SHA.EvaluateElementalOff
    sd.evaluateShaEnhancement = RotaClass_SHA.Evaluate.enhancement
    sd.evaluateShaEnhancementOff = RotaClass_SHA.EvaluateEnhancementOff
end

-- Deteccion de build: arbol con mas puntos. Override con la build elegida por el PJ.
function RotaClass_SHA:DetectBuild()
    ScanTalents()
    local key, presetId, specName, badge
    if tabPoints[2] > tabPoints[1] and tabPoints[2] >= tabPoints[3] then
        key, presetId, specName, badge = "enhancement", "sha_enhancement_pve", "Enhancement", "[ENH]"
    else
        key, presetId, specName, badge = "elemental", "sha_elemental_pve", "Elemental", "[ELE]"
    end
    RotaClass_SHA.detectedBuild = key
    RotaClass_SHA.detectedPresetId = presetId
    RotaClass_SHA.detectedSpecName = specName
    RotaClass_SHA.detectedBadge = badge

    local sel = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or "auto"
    local active = presetId
    if sel == "elemental" then active = "sha_elemental_pve"
    elseif sel == "enhancement" then active = "sha_enhancement_pve" end

    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(active)
    end
    return key, active, specName
end

RotaClass_SHA.UpdateState = UpdateShamanState

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "SHAMAN",
        addonName = "RotaClass_SHA",
        classColor = { r = 0.0, g = 0.44, b = 0.87 },
        builds = {
            { key = "auto", name = "AUTO", color = {1.0, 0.9, 0.0} },
            { key = "elemental", name = "Elemental", color = {0.2, 0.6, 1.0}, preset = "sha_elemental_pve" },
            { key = "enhancement", name = "Enhancement", color = {0.4, 0.8, 1.0}, preset = "sha_enhancement_pve" },
        },
        detectBuild = function() return RotaClass_SHA:DetectBuild() end,
        getIdlePreviewAction = function(buildKey)
            if buildKey == "enhancement" then return "SS" end
            return "LB"
        end,
        stateProvider = UpdateShamanState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("SHAMAN", UpdateShamanState)
end

if _G.CreateFrame and not RotaClass_SHA.eventFrame then
    local f = _G.CreateFrame("Frame", "RotaClass_SHA_EventFrame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:SetScript("OnEvent", function() RotaClass_SHA:DetectBuild() end)
    RotaClass_SHA.eventFrame = f
end

return RotaClass_SHA
