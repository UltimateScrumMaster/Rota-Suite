-- RotaClass_DRU/RotaClass_DRU.lua — Druid State Provider, Build Detection & Evaluators (WoW 3.3.5a)
-- Specs: Balance, Feral (gato). Restoration se trata como Balance. Sin bearweaving ni rotacion de oso.
-- Fuentes: guias de Wowhead WotLK + Rebuffed (Glyph of Omen of Clarity).
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_DRU = {
    detectedBuild = "balance",
    detectedPresetId = "dru_balance_pve",
    detectedSpecName = "Balance",
    detectedBadge = "[BAL]",
    lastEclipse = nil,   -- "lunar" | "solar": despues de un Eclipse se sigue con el mismo hechizo
}
_G.RotaClass_DRU = RotaClass_DRU

local function SN(id, fallback)
    return (_G.GetSpellInfo and _G.GetSpellInfo(id)) or fallback
end

-- Hechizos: alias -> { nombre ingles, ID de rango maximo }
local SPELLS = {
    WRATH = { "Wrath", 48461 },             SF = { "Starfire", 48465 },           MF = { "Moonfire", 48463 },
    IS = { "Insect Swarm", 48468 },         FF = { "Faerie Fire", 770 },          FFF = { "Faerie Fire (Feral)", 16857 },
    STARFALL = { "Starfall", 53201 },       FON = { "Force of Nature", 33831 },   HURRICANE = { "Hurricane", 48467 },
    MOONKIN = { "Moonkin Form", 24858 },    CAT = { "Cat Form", 768 },            SR = { "Savage Roar", 52610 },
    RIP = { "Rip", 49800 },                 RAKE = { "Rake", 48574 },             MANGLE = { "Mangle (Cat)", 48566 },
    SHRED = { "Shred", 48572 },             SWIPE = { "Swipe (Cat)", 62078 },     TF = { "Tiger's Fury", 50213 },
    BERSERK = { "Berserk", 50334 },
}

-- En 3.3.5 los dos Eclipse se llaman "Eclipse": se distinguen por ID
local ECLIPSE_SOLAR, ECLIPSE_LUNAR = 48517, 48518

local NAME = {
    MOONKIN = SN(24858, "Moonkin Form"),    CAT = SN(768, "Cat Form"),            SR = SN(52610, "Savage Roar"),
    CC = SN(16870, "Clearcasting"),         BERSERK = SN(50334, "Berserk"),       IS = SN(48468, "Insect Swarm"),
    MF = SN(48463, "Moonfire"),             FF = SN(770, "Faerie Fire"),          FFF = SN(16857, "Faerie Fire (Feral)"),
    RIP = SN(49800, "Rip"),                 RAKE = SN(48574, "Rake"),             MANGLE_CAT = SN(48566, "Mangle (Cat)"),
    MANGLE_BEAR = SN(48564, "Mangle (Bear)"), TRAUMA = SN(46857, "Trauma"),
    LUNAR = SN(ECLIPSE_LUNAR, "Eclipse"),
}

local function DruHas(state, alias)
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
    if not DruHas(state, alias) then return false end
    local cd = Cd(state, alias)
    if cd ~= nil then return cd <= (((state and state.gcdRemains) or 0) + 0.1) end
    return (state.spellReady and state.spellReady(alias)) and true or false
end

local function Var(state, name, default)
    local v = state.vars and state.vars[name]
    if v == nil then return default end
    return v
end

-- Talentos: puntos por arbol (1 Balance, 2 Feral, 3 Restoration)
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

local function Rem(expT, now)
    local r = (expT and expT > 0) and (expT - now) or 999
    return r > 0 and r or 0
end

-- Provider de estado (cada update; state.dru se aloca una sola vez)
local function UpdateDruidState(state, _)
    local dru = state.dru
    if not dru then
        dru = {}
        state.dru = dru
    end
    local now = state.now or (_G.GetTime and _G.GetTime()) or 0

    local moonkin, cat, sr, cc, berserk, solar, lunar = false, false, 0, 0, 0, 0, 0
    if _G.UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT, _, _, _, sid = _G.UnitBuff("player", i)
            if not name then break end
            if sid == ECLIPSE_SOLAR then solar = Rem(expT, now)
            elseif sid == ECLIPSE_LUNAR then lunar = Rem(expT, now)
            elseif name == NAME.MOONKIN then moonkin = true
            elseif name == NAME.CAT then cat = true
            elseif name == NAME.SR then sr = Rem(expT, now)
            elseif name == NAME.CC then cc = Rem(expT, now)
            elseif name == NAME.BERSERK then berserk = Rem(expT, now) end
        end
    end
    dru.moonkin, dru.cat, dru.savageRoar, dru.clearcasting, dru.berserk = moonkin, cat, sr, cc, berserk
    dru.solar, dru.lunar = solar, lunar
    if lunar > 0 then RotaClass_DRU.lastEclipse = "lunar" elseif solar > 0 then RotaClass_DRU.lastEclipse = "solar" end

    local is, mf, ff, rip, rake, mangle = 0, 0, 0, 0, 0, 0
    if _G.UnitDebuff and state.hasTarget ~= false then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT, caster = _G.UnitDebuff("target", i)
            if not name then break end
            local r = Rem(expT, now)
            -- Faerie Fire y Mangle/Trauma sirven de cualquiera
            if name == NAME.FF or name == NAME.FFF then
                if r > ff then ff = r end
            elseif name == NAME.MANGLE_CAT or name == NAME.MANGLE_BEAR or name == NAME.TRAUMA then
                if r > mangle then mangle = r end
            elseif caster == "player" then
                if name == NAME.IS then is = r
                elseif name == NAME.MF then mf = r
                elseif name == NAME.RIP then rip = r
                elseif name == NAME.RAKE then rake = r end
            end
        end
    end
    dru.insectSwarm, dru.moonfire, dru.faerieFire = is, mf, ff
    dru.rip, dru.rake, dru.mangle = rip, rake, mangle

    dru.energy = (_G.UnitPower and _G.UnitPower("player", 3)) or 0
    dru.cp = (_G.GetComboPoints and _G.GetComboPoints("player", "target")) or 0
    dru.moving = (_G.GetUnitSpeed and (_G.GetUnitSpeed("player") or 0) > 0) and true or false
    dru.lastEclipse = RotaClass_DRU.lastEclipse
end

-- BALANCE
-- Moonkin Form > Faerie Fire > Insect Swarm (dejarlo caer; no en los ultimos 5 s de Lunar) > Force of Nature / Starfall
-- (fuera de Eclipse, Burst) > Starfire en Lunar / Wrath en Solar; sin Eclipse, el hechizo del ultimo Eclipse.
-- En movimiento: Moonfire. AoE: Starfall > Hurricane.
function RotaClass_DRU.EvaluateBalance(state)
    local dru = state.dru
    local gcd = state.gcdRemains or 0
    local inEclipse = dru.lunar > 0 or dru.solar > 0

    if not dru.moonkin and DruHas(state, "MOONKIN") then return "MOONKIN" end
    if state.aoeMode then
        if Ready(state, "STARFALL") then return "STARFALL" end
        if DruHas(state, "HURRICANE") then return "HURRICANE" end
    end
    if dru.faerieFire <= gcd and DruHas(state, "FF") then return "FF" end
    if dru.moving then
        if dru.insectSwarm <= gcd and DruHas(state, "IS") then return "IS" end
        if dru.moonfire <= gcd and DruHas(state, "MF") then return "MF" end
    end
    if dru.insectSwarm <= gcd and not (dru.lunar > 0 and dru.lunar < 5) and DruHas(state, "IS") then return "IS" end
    if state.burstMode ~= false and state.inCombat and not inEclipse then
        if Ready(state, "FON") then return "FON" end
        if Ready(state, "STARFALL") then return "STARFALL" end
    end
    if dru.lunar > 0 then return "SF" end
    if dru.solar > 0 then return "WRATH" end
    -- Fuera de Eclipse: seguir con el hechizo del ultimo Eclipse para "pescar" el siguiente
    if RotaClass_DRU.lastEclipse == "lunar" then return "SF" end
    return "WRATH"
end

function RotaClass_DRU.EvaluateBalanceOff(state)
    local dru = state.dru
    if state.burstMode == false or not state.inCombat then return nil end
    -- Guantes y racial al empezar un Eclipse Lunar
    if dru.lunar > 10 then
        if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
        if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    end
    return nil
end

-- FERAL (gato), guia de Wowhead WotLK:
-- Cat Form > Savage Roar (1+ CP, caido) > Shred con Clearcasting > Rip (5 CP, caido) > Rake (caido) > Mangle (caido)
-- > Faerie Fire (Feral) si el objetivo no tiene Faerie Fire > Shred si sobra energia para renovar todo a tiempo;
-- si no, juntar energia para lo que se cae. Los sangrados no se renuevan antes de que caigan (se pierde el ultimo tick).
-- Ferocious Bite no entra. Sin bearweaving.
-- AoE: Savage Roar > Rake (sin CP) > Swipe (Cat).
-- Rebuffed: con Glyph of Omen of Clarity, Faerie Fire (Feral) da Clearcasting: se usa en vez de esperar energia.
local COST = { SR = 25, RIP = 30, RAKE = 35, MANGLE = 35, SHRED = 42, SWIPE = 45 }
local ENERGY_PER_SEC = 10
local GLYPH_OMEN = "Glyph of Omen of Clarity"

-- Despues de gastar `spend`, ¿llega la energia para renovar algo que cae en `rem` segundos?
local function Affords(energy, spend, rem, cost, half)
    if half then cost = cost / 2 end
    return energy - spend + rem * ENERGY_PER_SEC >= cost
end

-- Mostrar `alias` esperando energia: espiral con los segundos que faltan
local function PoolFor(state, alias, energy, cost, half)
    if half then cost = cost / 2 end
    if energy < cost then
        state.isWaiting = true
        state.waitTime = (cost - energy) / ENERGY_PER_SEC
    end
    return alias
end

function RotaClass_DRU.EvaluateFeral(state)
    local dru = state.dru
    local gcd = state.gcdRemains or 0
    local cp, energy = dru.cp, dru.energy
    local half = dru.berserk > 0 -- Berserk: todo cuesta la mitad

    if not dru.cat and DruHas(state, "CAT") then return "CAT" end
    if cp >= 1 and dru.savageRoar <= gcd and DruHas(state, "SR") then
        state.reason = "Savage Roar caido"
        return PoolFor(state, "SR", energy, COST.SR, half)
    end

    if state.aoeMode then
        if cp == 0 and Var(state, "aoeRake", 1) == 1 and dru.rake <= gcd and DruHas(state, "RAKE") then
            state.reason = "Rake: 1 CP para Savage Roar"
            return PoolFor(state, "RAKE", energy, COST.RAKE, half)
        end
        if DruHas(state, "SWIPE") then
            if dru.clearcasting > gcd then return "SWIPE" end
            return PoolFor(state, "SWIPE", energy, COST.SWIPE, half)
        end
    end

    if dru.clearcasting > gcd and DruHas(state, "SHRED") then
        state.reason = "Clearcasting: Shred gratis"
        return "SHRED"
    end
    if cp >= 5 and dru.rip <= gcd and DruHas(state, "RIP") then
        state.reason = "5 CP y Rip caido"
        return PoolFor(state, "RIP", energy, COST.RIP, half)
    end
    if dru.rake <= gcd and DruHas(state, "RAKE") then
        state.reason = "Rake caido"
        return PoolFor(state, "RAKE", energy, COST.RAKE, half)
    end
    if dru.mangle <= gcd and DruHas(state, "MANGLE") then
        state.reason = "Mangle caido"
        return PoolFor(state, "MANGLE", energy, COST.MANGLE, half)
    end
    if Var(state, "maintainFF", 1) == 1 and dru.faerieFire <= gcd and Ready(state, "FFF") then
        state.reason = "Objetivo sin Faerie Fire"
        return "FFF"
    end

    -- Shred solo si despues alcanza la energia para renovar lo que se cae (no se renueva antes de que caiga)
    local spend = half and COST.SHRED / 2 or COST.SHRED
    local poolAlias, poolRem = nil, 999
    if cp >= 1 and DruHas(state, "SR") and not Affords(energy, spend, dru.savageRoar, COST.SR, half) then
        poolAlias, poolRem = "SR", dru.savageRoar
    end
    if cp >= 5 and dru.rip < poolRem and DruHas(state, "RIP") and not Affords(energy, spend, dru.rip, COST.RIP, half) then
        poolAlias, poolRem = "RIP", dru.rip
    end
    if dru.rake < poolRem and DruHas(state, "RAKE") and not Affords(energy, spend, dru.rake, COST.RAKE, half) then
        poolAlias, poolRem = "RAKE", dru.rake
    end
    if dru.mangle < poolRem and DruHas(state, "MANGLE") and not Affords(energy, spend, dru.mangle, COST.MANGLE, half) then
        poolAlias, poolRem = "MANGLE", dru.mangle
    end

    if poolAlias or energy < spend then
        -- Rebuffed: el glifo convierte Faerie Fire (Feral) en un Shred gratis mientras se junta energia
        local glyphs = state.glyphs
        if glyphs and glyphs[GLYPH_OMEN] and Ready(state, "FFF") then
            state.reason = "Glyph of Omen of Clarity: Faerie Fire da Clearcasting"
            return "FFF"
        end
    end
    if poolAlias then
        state.isWaiting = true
        state.waitTime = poolRem - gcd
        state.reason = "Juntando energia: se cae pronto"
        return poolAlias
    end
    return PoolFor(state, "SHRED", energy, COST.SHRED, half)
end

-- Funciones del Druida para las reglas del preset (ver RotaClass_DRU/Presets.lua)
if RotaCore.Sandbox and RotaCore.Sandbox.AddHelper then
    local Sandbox = RotaCore.Sandbox
    --- energia que cuesta una habilidad de gato (SR, RIP, RAKE, MANGLE, SHRED, SWIPE); con Berserk, la mitad
    Sandbox:AddHelper("catCost", function(alias)
        local st = Sandbox.current
        local c = COST[alias] or 0
        if st.dru.berserk > 0 then c = c / 2 end
        return c
    end)
    --- mostrar la habilidad; si falta energia, "esperando" con los segundos que faltan
    Sandbox:AddHelper("poolFor", function(alias)
        local st = Sandbox.current
        return PoolFor(st, alias, st.dru.energy, COST[alias] or 0, st.dru.berserk > 0)
    end)
    --- despues de un Shred, ¿alcanza la energia para renovar algo que cae en `rem` segundos?
    Sandbox:AddHelper("shredLeavesFor", function(rem, alias)
        local st = Sandbox.current
        local half = st.dru.berserk > 0
        local spend = half and COST.SHRED / 2 or COST.SHRED
        return Affords(st.dru.energy, spend, rem, COST[alias] or 0, half)
    end)
end

function RotaClass_DRU.EvaluateFeralOff(state)
    local dru = state.dru
    if not state.inCombat or not dru.cat then return nil end
    -- Tiger's Fury con menos de 40 de energia (King of the Jungle devuelve 60); no se puede durante Berserk
    if dru.energy < 40 and dru.berserk <= 0 and Ready(state, "TF") then return "TF" end
    if state.burstMode ~= false then
        local tf = Cd(state, "TF") or 0
        if tf >= 15 and Ready(state, "BERSERK") then return "BERSERK" end
        if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
        if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    end
    return nil
end

-- Evaluadores publicos: nunca devuelven nil
RotaClass_DRU.Evaluate = {
    balance = function(state)
        state.isWaiting = false
        return RotaClass_DRU.EvaluateBalance(state) or "WRATH"
    end,
    feral = function(state)
        state.isWaiting = false
        return RotaClass_DRU.EvaluateFeral(state) or "SHRED"
    end,
}

if RotaCore.State and RotaCore.State.data then
    local sd = RotaCore.State.data
    sd.evaluateDruBalance = RotaClass_DRU.Evaluate.balance
    sd.evaluateDruBalanceOff = RotaClass_DRU.EvaluateBalanceOff
    sd.evaluateDruFeral = RotaClass_DRU.Evaluate.feral
    sd.evaluateDruFeralOff = RotaClass_DRU.EvaluateFeralOff
end

-- Deteccion de build: Feral si el arbol Feral tiene mas puntos; si no, Balance.
local BUILDS = {
    balance = { "dru_balance_pve", "Balance", "[BAL]" },
    feral = { "dru_feral_pve", "Feral", "[FER]" },
}

function RotaClass_DRU:DetectBuild()
    ScanTalents()
    local key = "balance"
    if tabPoints[2] > tabPoints[1] and tabPoints[2] >= tabPoints[3] then key = "feral" end
    local b = BUILDS[key]
    RotaClass_DRU.detectedBuild = key
    RotaClass_DRU.detectedPresetId = b[1]
    RotaClass_DRU.detectedSpecName = b[2]
    RotaClass_DRU.detectedBadge = b[3]

    local sel = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or "auto"
    local active = BUILDS[sel] and BUILDS[sel][1] or b[1]

    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(active)
    end
    return key, active, b[2]
end

RotaClass_DRU.UpdateState = UpdateDruidState

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "DRUID",
        addonName = "RotaClass_DRU",
        classColor = { r = 1.0, g = 0.49, b = 0.04 },
        builds = {
            { key = "auto", name = "AUTO", color = {1.0, 0.9, 0.0} },
            { key = "balance", name = "Balance", color = {0.4, 0.6, 1.0}, preset = "dru_balance_pve" },
            { key = "feral", name = "Feral", color = {1.0, 0.6, 0.2}, preset = "dru_feral_pve" },
        },
        detectBuild = function() return RotaClass_DRU:DetectBuild() end,
        getIdlePreviewAction = function(buildKey)
            if buildKey == "feral" then return "SHRED" end
            return "WRATH"
        end,
        stateProvider = UpdateDruidState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("DRUID", UpdateDruidState)
end

if _G.CreateFrame and not RotaClass_DRU.eventFrame then
    local f = _G.CreateFrame("Frame", "RotaClass_DRU_EventFrame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            RotaClass_DRU.lastEclipse = nil   -- fuera de combate se arranca de nuevo con Wrath
            return
        end
        RotaClass_DRU:DetectBuild()
    end)
    RotaClass_DRU.eventFrame = f
end

return RotaClass_DRU
