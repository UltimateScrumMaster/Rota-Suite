-- RotaClass_MAG/RotaClass_MAG.lua — Mage State Provider, Build Detection & Evaluators (WoW 3.3.5a)
-- Specs: Arcane, Fire, Frost.
-- Fuente: guias de Wowhead WotLK + cambios de Rebuffed (docs/REBUFFED.md).
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_MAG = {
    detectedBuild = "arcane",
    detectedPresetId = "mag_arcane_pve",
    detectedSpecName = "Arcane",
    detectedBadge = "[ARC]",
    abCasts = 0,      -- Arcane Blast lanzados desde el ultimo Arcane Missiles
    abProcAt = nil,   -- en que Arcane Blast aparecio Missile Barrage
}
_G.RotaClass_MAG = RotaClass_MAG

local function SN(id, fallback)
    return (_G.GetSpellInfo and _G.GetSpellInfo(id)) or fallback
end

-- Hechizos: alias -> { nombre ingles, ID de rango maximo }
local SPELLS = {
    AB = { "Arcane Blast", 42897 },        AM = { "Arcane Missiles", 42846 },   ABAR = { "Arcane Barrage", 44781 },
    AP = { "Arcane Power", 12042 },        POM = { "Presence of Mind", 12043 }, IV = { "Icy Veins", 12472 },
    MI = { "Mirror Image", 55342 },        EVO = { "Evocation", 12051 },        FB = { "Fireball", 42833 },
    FFB = { "Frostfire Bolt", 47610 },     PYRO = { "Pyroblast", 42891 },       LB = { "Living Bomb", 55360 },
    SCORCH = { "Scorch", 42859 },          COMB = { "Combustion", 11129 },      FROSTBOLT = { "Frostbolt", 42842 },
    DF = { "Deep Freeze", 44572 },         WE = { "Summon Water Elemental", 31687 },
    BLIZZ = { "Blizzard", 42940 },         FS = { "Flamestrike", 42926 },       AE = { "Arcane Explosion", 42921 },
    TW = { "Time Warp", 80353 },           BW = { "Blast Wave", 42945 },        DB = { "Dragon's Breath", 42950 },
    FBLAST = { "Fire Blast", 42873 },
}

-- Nombres localizados de auras
local NAME = {
    ABSTACK = SN(36032, "Arcane Blast"),   MB = SN(44401, "Missile Barrage"),   HOT = SN(48108, "Hot Streak"),
    BF = SN(57761, "Fireball!"),           FOF = SN(44544, "Fingers of Frost"), AP = SN(12042, "Arcane Power"),
    IV = SN(12472, "Icy Veins"),           LB = SN(55360, "Living Bomb"),       ISCORCH = SN(22959, "Improved Scorch"),
    SHADOWM = SN(17800, "Shadow Mastery"), WCHILL = SN(12579, "Winter's Chill"), FIRESTARTER = SN(54741, "Firestarter"),
    AB_CAST = SN(42897, "Arcane Blast"),   AM_CAST = SN(42846, "Arcane Missiles"),
}

local function MagHas(state, alias)
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
    if not MagHas(state, alias) then return false end
    local cd = Cd(state, alias)
    if cd ~= nil then return cd <= (((state and state.gcdRemains) or 0) + 0.1) end
    return (state.spellReady and state.spellReady(alias)) and true or false
end

local function Var(state, name, default)
    local v = state.vars and state.vars[name]
    if v == nil then return default end
    return v
end

-- Talentos: puntos por arbol (1 Arcane, 2 Fire, 3 Frost)
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

-- Recorre auras de una unidad y devuelve restante + stacks de un nombre
local function ScanAuras(mag, now, unit, fn)
    if not fn then return end
    for i = 1, 40 do
        local name, _, _, count, _, _, expT, caster = fn(unit, i)
        if not name then break end
        local rem = (expT and expT > 0) and (expT - now) or 999
        if rem < 0 then rem = 0 end
        if unit == "player" then
            if name == NAME.ABSTACK then mag.abStacks = count or 1
            elseif name == NAME.MB then mag.missileBarrage = rem
            elseif name == NAME.HOT then mag.hotStreak = rem
            elseif name == NAME.BF then mag.brainFreeze = rem
            elseif name == NAME.FOF then mag.fingersOfFrost, mag.fofStacks = rem, count or 1
            elseif name == NAME.AP then mag.arcanePower = rem
            elseif name == NAME.IV then mag.icyVeins = rem
            elseif name == NAME.FIRESTARTER then mag.firestarter = rem end
        else
            if name == NAME.LB and caster == "player" then mag.livingBomb = rem
            elseif name == NAME.ISCORCH or name == NAME.SHADOWM or name == NAME.WCHILL then
                if rem > mag.critDebuff then mag.critDebuff = rem end
            end
        end
    end
end

-- Provider de estado (cada update; state.mag se aloca una sola vez)
local function UpdateMageState(state, _)
    local mag = state.mag
    if not mag then
        mag = {}
        state.mag = mag
    end
    local now = state.now or (_G.GetTime and _G.GetTime()) or 0
    mag.abStacks, mag.missileBarrage, mag.hotStreak, mag.brainFreeze = 0, 0, 0, 0
    mag.fingersOfFrost, mag.fofStacks, mag.arcanePower, mag.icyVeins = 0, 0, 0, 0
    mag.livingBomb, mag.critDebuff, mag.firestarter = 0, 0, 0

    -- Arcane Blast es un debuff en el jugador en 3.3.5: se revisan buffs y debuffs
    ScanAuras(mag, now, "player", _G.UnitBuff)
    ScanAuras(mag, now, "player", _G.UnitDebuff)
    if state.hasTarget ~= false then ScanAuras(mag, now, "target", _G.UnitDebuff) end

    mag.hasPet = (_G.UnitExists and _G.UnitExists("pet")) and true or false
    mag.moving = (_G.GetUnitSpeed and (_G.GetUnitSpeed("player") or 0) > 0) and true or false
    -- Arcane Blast lanzados (contados por evento; sin eventos, los stacks del debuff)
    mag.abCasts = math.max(RotaClass_MAG.abCasts, mag.abStacks)
    if mag.missileBarrage > 0 then
        if not RotaClass_MAG.abProcAt then RotaClass_MAG.abProcAt = mag.abCasts end
    else
        RotaClass_MAG.abProcAt = nil
    end
    mag.abProcAt = RotaClass_MAG.abProcAt
end

-- ARCANE (Wowhead, "Better Rotation")
-- Arcane Blast hasta Missile Barrage. Con el proc: Arcane Missiles despues del 4.o Arcane Blast; si el proc salio en el
-- 4.o o mas tarde, despues del siguiente. Sin proc, Arcane Missiles despues del 6.o. Evocation sin mana.
-- En movimiento: Arcane Barrage. AoE: Blizzard (var aoeSpell; Arcane Explosion en movimiento o al final del pack)
local function MageAoE(state)
    local spell = Var(state, "aoeSpell", "BLIZZ")
    if MagHas(state, spell) then return spell end
    return nil
end

function RotaClass_MAG.EvaluateArcane(state)
    local mag = state.mag
    local mana = state.powerPct or 100
    if mag.moving and Ready(state, "ABAR") then return "ABAR" end
    if state.aoeMode then
        local a = MageAoE(state)
        if a then return a end
    end
    if mana < Var(state, "evocationMana", 15) and Ready(state, "EVO") then return "EVO" end
    local casts = mag.abCasts
    if mag.missileBarrage > 0 then
        local procAt = RotaClass_MAG.abProcAt or casts
        local need = procAt >= 4 and procAt + 1 or 4
        if casts >= need then return "AM" end
    end
    if casts >= 6 then return "AM" end
    return "AB"
end

function RotaClass_MAG.EvaluateArcaneOff(state)
    local mag = state.mag
    if state.burstMode == false or not state.inCombat then return nil end
    if Ready(state, "AP") then return "AP" end
    if mag.abStacks >= 3 and Ready(state, "POM") then return "POM" end
    if Ready(state, "IV") then return "IV" end
    if Ready(state, "MI") then return "MI" end
    if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
    if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    return nil
end

-- FIRE (Wowhead)
-- Pyroblast (Hot Streak) > Living Bomb (dejarla explotar) > Fireball / Frostfire Bolt. En movimiento: Fire Blast.
-- Scorch solo si nadie pone el debuff de critico (var scorch, apagada: la guia no lo usa).
-- AoE: Living Bomb > Flamestrike con Firestarter > Blast Wave > Dragon's Breath > Flamestrike
function RotaClass_MAG.EvaluateFire(state)
    local mag = state.mag
    local gcd = state.gcdRemains or 0
    if state.aoeMode then
        if mag.livingBomb <= gcd and MagHas(state, "LB") then return "LB" end
        if mag.firestarter > gcd and MagHas(state, "FS") then return "FS" end
        if Ready(state, "BW") then return "BW" end
        if Ready(state, "DB") then return "DB" end
        if MagHas(state, "FS") then return "FS" end
    end
    if mag.hotStreak > gcd and MagHas(state, "PYRO") then return "PYRO" end
    if mag.livingBomb <= gcd and MagHas(state, "LB") then return "LB" end
    if mag.moving and Ready(state, "FBLAST") then return "FBLAST" end
    if Var(state, "scorch", 0) == 1 and mag.critDebuff <= gcd + 2 and MagHas(state, "SCORCH") then return "SCORCH" end
    if Var(state, "filler", "FB") == "FFB" and MagHas(state, "FFB") then return "FFB" end
    return "FB"
end

function RotaClass_MAG.EvaluateFireOff(state)
    local mag = state.mag
    if state.burstMode == false or not state.inCombat then return nil end
    -- Combustion despues de renovar Living Bomb (no gastarla en el ultimo tick)
    if mag.livingBomb > 6 and Ready(state, "COMB") then return "COMB" end
    if Ready(state, "MI") then return "MI" end
    if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
    if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    return nil
end

-- FROST (Wowhead: con Fingers of Frost, Frostbolt, Frostbolt y Deep Freeze con la ultima carga)
-- Water Elemental (sin mascota) > Deep Freeze (ultima carga de Fingers of Frost) > Frostfire Bolt (Brain Freeze) > Frostbolt
-- En movimiento: Fire Blast. AoE: Blizzard
function RotaClass_MAG.EvaluateFrost(state)
    local mag = state.mag
    local gcd = state.gcdRemains or 0
    if state.inCombat and not mag.hasPet and Ready(state, "WE") then return "WE" end
    if state.aoeMode and MagHas(state, "BLIZZ") then return "BLIZZ" end
    if mag.fingersOfFrost > gcd and mag.fofStacks <= 1 and Ready(state, "DF") then return "DF" end
    if mag.brainFreeze > gcd and MagHas(state, "FFB") then return "FFB" end
    if mag.moving and Ready(state, "FBLAST") then return "FBLAST" end
    return "FROSTBOLT"
end

function RotaClass_MAG.EvaluateFrostOff(state)
    if state.burstMode == false or not state.inCombat then return nil end
    if Ready(state, "IV") then return "IV" end
    if Ready(state, "MI") then return "MI" end
    if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
    if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
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

RotaClass_MAG.Evaluate = {
    arcane = Wrap(RotaClass_MAG.EvaluateArcane, "AB"),
    fire = Wrap(RotaClass_MAG.EvaluateFire, "FB"),
    frost = Wrap(RotaClass_MAG.EvaluateFrost, "FROSTBOLT"),
}

if RotaCore.State and RotaCore.State.data then
    local sd = RotaCore.State.data
    sd.evaluateMagArcane = RotaClass_MAG.Evaluate.arcane
    sd.evaluateMagArcaneOff = RotaClass_MAG.EvaluateArcaneOff
    sd.evaluateMagFire = RotaClass_MAG.Evaluate.fire
    sd.evaluateMagFireOff = RotaClass_MAG.EvaluateFireOff
    sd.evaluateMagFrost = RotaClass_MAG.Evaluate.frost
    sd.evaluateMagFrostOff = RotaClass_MAG.EvaluateFrostOff
end

-- Deteccion de build: arbol con mas puntos. Override con la build elegida por el PJ.
local BUILDS = {
    arcane = { "mag_arcane_pve", "Arcane", "[ARC]" },
    fire = { "mag_fire_pve", "Fire", "[FIRE]" },
    frost = { "mag_frost_pve", "Frost", "[FROST]" },
}

function RotaClass_MAG:DetectBuild()
    ScanTalents()
    local key = "arcane"
    if tabPoints[2] > tabPoints[1] and tabPoints[2] >= tabPoints[3] then
        key = "fire"
    elseif tabPoints[3] > tabPoints[1] and tabPoints[3] > tabPoints[2] then
        key = "frost"
    end
    local b = BUILDS[key]
    RotaClass_MAG.detectedBuild = key
    RotaClass_MAG.detectedPresetId = b[1]
    RotaClass_MAG.detectedSpecName = b[2]
    RotaClass_MAG.detectedBadge = b[3]

    local sel = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or "auto"
    local active = BUILDS[sel] and BUILDS[sel][1] or b[1]

    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(active)
    end
    return key, active, b[2]
end

RotaClass_MAG.UpdateState = UpdateMageState

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "MAGE",
        addonName = "RotaClass_MAG",
        classColor = { r = 0.41, g = 0.8, b = 0.94 },
        builds = {
            { key = "auto", name = "AUTO", color = {1.0, 0.9, 0.0} },
            { key = "arcane", name = "Arcane", color = {0.7, 0.5, 1.0}, preset = "mag_arcane_pve" },
            { key = "fire", name = "Fire", color = {1.0, 0.45, 0.1}, preset = "mag_fire_pve" },
            { key = "frost", name = "Frost", color = {0.4, 0.8, 1.0}, preset = "mag_frost_pve" },
        },
        detectBuild = function() return RotaClass_MAG:DetectBuild() end,
        getIdlePreviewAction = function(buildKey)
            if buildKey == "fire" then return "FB" end
            if buildKey == "frost" then return "FROSTBOLT" end
            return "AB"
        end,
        stateProvider = UpdateMageState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("MAGE", UpdateMageState)
end

if _G.CreateFrame and not RotaClass_MAG.eventFrame then
    local f = _G.CreateFrame("Frame", "RotaClass_MAG_EventFrame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event, unit, spellName)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit ~= "player" then return end
            if spellName == NAME.AB_CAST then
                RotaClass_MAG.abCasts = RotaClass_MAG.abCasts + 1
            elseif spellName == NAME.AM_CAST then
                RotaClass_MAG.abCasts, RotaClass_MAG.abProcAt = 0, nil
            end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            RotaClass_MAG.abCasts, RotaClass_MAG.abProcAt = 0, nil
            return
        end
        RotaClass_MAG:DetectBuild()
    end)
    RotaClass_MAG.eventFrame = f
end

return RotaClass_MAG
