-- RotaClass_WL/RotaClass_WL.lua — Warlock State Provider, Build Detection & Evaluators (WoW 3.3.5a)
-- Specs: Affliction, Demonology, Destruction.
-- Fuente: guias de Wowhead WotLK + cambios de Rebuffed (docs/REBUFFED.md).
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_WL = {
    detectedBuild = "affliction",
    detectedPresetId = "wl_affliction_pve",
    detectedSpecName = "Affliction",
    detectedBadge = "[AFF]",
}
_G.RotaClass_WL = RotaClass_WL

local function SN(id, fallback)
    return (_G.GetSpellInfo and _G.GetSpellInfo(id)) or fallback
end

-- Hechizos: alias -> { nombre ingles, ID de rango maximo }
local SPELLS = {
    SB = { "Shadow Bolt", 47809 },          HAUNT = { "Haunt", 59164 },           CORR = { "Corruption", 47813 },
    UA = { "Unstable Affliction", 47843 },  COA = { "Curse of Agony", 47864 },    COD = { "Curse of Doom", 47867 },
    COE = { "Curse of the Elements", 47865 }, DSOUL = { "Drain Soul", 47855 },    LT = { "Life Tap", 57946 },
    IMM = { "Immolate", 47811 },            INC = { "Incinerate", 47838 },        CONF = { "Conflagrate", 17962 },
    CB = { "Chaos Bolt", 59172 },           SF = { "Soul Fire", 47825 },          SEED = { "Seed of Corruption", 47836 },
    META = { "Metamorphosis", 47241 },      DE = { "Demonic Empowerment", 47193 }, IA = { "Immolation Aura", 50589 },
    SFURY = { "Shadowfury", 47847 },
}

-- Nombres localizados de auras y hechizos (para comparar con UnitBuff/UnitDebuff/UnitCastingInfo)
local NAME = {
    HAUNT = SN(59164, "Haunt"),             CORR = SN(47813, "Corruption"),       UA = SN(47843, "Unstable Affliction"),
    COA = SN(47864, "Curse of Agony"),      COD = SN(47867, "Curse of Doom"),     COE = SN(47865, "Curse of the Elements"),
    IMM = SN(47811, "Immolate"),            LTBUFF = SN(63321, "Life Tap"),       MOLTEN = SN(71165, "Molten Core"),
    DECI = SN(63167, "Decimation"),         META = SN(47241, "Metamorphosis"),    BACKDRAFT = SN(54277, "Backdraft"),
    SHADOWM = SN(17800, "Shadow Mastery"),  SB = SN(47809, "Shadow Bolt"),        DSOUL = SN(47855, "Drain Soul"),
    STRANCE = SN(17941, "Shadow Trance"),
}

-- Tiempo de casteo real en segundos desde GetSpellInfo (refleja celeridad y procs en 3.3.5a; 0 si instantaneo o mock)
local function SpellCastSec(id)
    if not _G.GetSpellInfo then return 0 end
    local _, _, _, _, _, _, ct = _G.GetSpellInfo(id)
    if ct and ct > 0 then return ct / 1000 end
    return 0
end

local function WlHas(state, alias)
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
    if not WlHas(state, alias) then return false end
    local cd = Cd(state, alias)
    if cd ~= nil then return cd <= (((state and state.gcdRemains) or 0) + 0.1) end
    return (state.spellReady and state.spellReady(alias)) and true or false
end

local function Var(state, name, default)
    local v = state.vars and state.vars[name]
    if v == nil then return default end
    return v
end

-- Talentos: puntos por arbol (1 Affliction, 2 Demonology, 3 Destruction) y Abrazo de la Muerte
local tabPoints = { 0, 0, 0 }
local hasDeathsEmbrace = nil -- nil = talentos sin nombres reales (mock); true/false = escaneado
local corrExecGUIDs = {}     -- [targetGUID] = true si ya se casteo Corrupcion manual con objetivo <= 35%

local function ScanTalents()
    tabPoints[1], tabPoints[2], tabPoints[3] = 0, 0, 0
    local foundDE = nil
    if not _G.GetTalentInfo then return end
    for tab = 1, 3 do
        local sum = 0
        local n = (_G.GetNumTalents and _G.GetNumTalents(tab)) or 0
        for idx = 1, n do
            local name, _, _, _, rank = _G.GetTalentInfo(tab, idx)
            sum = sum + (rank or 0)
            if tab == 1 and name then
                local lower = string.lower(name)
                if lower:find("death's embrace", 1, true) or lower:find("abrazo de la muerte", 1, true) then
                    foundDE = (rank or 0) > 0
                end
            end
        end
        if _G.GetTalentTabInfo then
            local _, _, spent = _G.GetTalentTabInfo(tab)
            if type(spent) == "number" and spent > sum then sum = spent end
        end
        tabPoints[tab] = sum
    end
    hasDeathsEmbrace = foundDE
end

function RotaClass_WL.ResetCorrExecute()
    for k in pairs(corrExecGUIDs) do corrExecGUIDs[k] = nil end
end

local function OnSpellcastSucceeded(unit, spellName)
    if unit ~= "player" or spellName ~= NAME.CORR then return end
    local guid = _G.UnitGUID and _G.UnitGUID("target")
    if not guid then return end
    local hp = 100
    if _G.UnitHealth and _G.UnitHealthMax then
        local mx = _G.UnitHealthMax("target") or 0
        if mx > 0 then hp = (_G.UnitHealth("target") or 0) / mx * 100 end
    end
    if hp <= 35 then
        corrExecGUIDs[guid] = true
    else
        corrExecGUIDs[guid] = nil
    end
end

-- Provider de estado (cada update; state.wl se aloca una sola vez)
local function UpdateWarlockState(state, _)
    local wl = state.wl
    if not wl then
        wl = {}
        state.wl = wl
    end
    local now = state.now or (_G.GetTime and _G.GetTime()) or 0

    local lt, molten, deci, meta, bd, trance = 0, 0, 0, 0, 0, 0
    if _G.UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT = _G.UnitBuff("player", i)
            if not name then break end
            local rem = (expT and expT > 0) and (expT - now) or 999
            if rem < 0 then rem = 0 end
            if name == NAME.LTBUFF then lt = rem
            elseif name == NAME.MOLTEN then molten = rem
            elseif name == NAME.DECI then deci = rem
            elseif name == NAME.META then meta = rem
            elseif name == NAME.BACKDRAFT then bd = rem
            elseif name == NAME.STRANCE then trance = rem end
        end
    end
    wl.lifeTapBuff, wl.moltenCore, wl.decimation, wl.metamorphosis, wl.backdraft = lt, molten, deci, meta, bd
    wl.shadowTrance = trance

    -- DoTs propios; Curse of the Elements cuenta de cualquiera (un solo debuff por objetivo)
    local haunt, corr, ua, coa, cod, coe, imm, sm = 0, 0, 0, 0, 0, 0, 0, 0
    if _G.UnitDebuff and state.hasTarget ~= false then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT, caster = _G.UnitDebuff("target", i)
            if not name then break end
            local rem = (expT and expT > 0) and (expT - now) or 999
            if rem < 0 then rem = 0 end
            if name == NAME.COE then coe = rem
            elseif name == NAME.SHADOWM then sm = rem
            elseif caster == "player" then
                if name == NAME.HAUNT then haunt = rem
                elseif name == NAME.CORR then corr = rem
                elseif name == NAME.UA then ua = rem
                elseif name == NAME.COA then coa = rem
                elseif name == NAME.COD then cod = rem
                elseif name == NAME.IMM then imm = rem end
            end
        end
    end
    wl.haunt, wl.corruption, wl.ua, wl.immolate = haunt, corr, ua, imm
    wl.coa, wl.cod, wl.coe = coa, cod, coe
    wl.shadowMastery = sm

    local hp = 100
    if _G.UnitHealth and _G.UnitHealthMax then
        local mx = _G.UnitHealthMax("target") or 0
        if mx > 0 then hp = (_G.UnitHealth("target") or 0) / mx * 100 end
    end
    wl.targetHealthPct = hp
    wl.isBoss = (_G.UnitClassification and _G.UnitClassification("target") == "worldboss") and true or false
    wl.hasPet = (_G.UnitExists and _G.UnitExists("pet")) and true or false
    local tGuid = (_G.UnitGUID and state.hasTarget ~= false) and _G.UnitGUID("target") or nil
    if tGuid and corr <= 0 and corrExecGUIDs[tGuid] then
        corrExecGUIDs[tGuid] = nil
    end
    wl.corrExecDone = (tGuid and corrExecGUIDs[tGuid]) and true or false

    -- Casteo / canalizacion en curso (UnitCastingInfo / UnitChannelInfo en 3.3.5a: tiempos en ms)
    local castName, castRem = nil, 0
    if _G.UnitCastingInfo then
        local cName, _, _, _, _, endMs = _G.UnitCastingInfo("player")
        if cName and endMs then
            castName = cName
            castRem = (endMs / 1000) - now
            if castRem < 0 then castRem = 0 end
        end
    end
    local channeling, chanName = false, nil
    if not castName and _G.UnitChannelInfo then
        local hName, _, _, _, _, endMs = _G.UnitChannelInfo("player")
        if hName and endMs and (endMs / 1000) > now then
            channeling = true
            chanName = hName
        end
    end
    wl.castName, wl.castRem = castName, castRem
    wl.channeling, wl.chanName = channeling, chanName

    -- Tiempos de casteo reales con celeridad y procs (fallback a base si GetSpellInfo no devuelve castTime)
    local ctUA = SpellCastSec(47843)
    local ctHaunt = SpellCastSec(59164)
    local ctSB = SpellCastSec(47809)
    if ctUA <= 0 then
        ctUA = 1.5
        if ctHaunt <= 0 then ctHaunt = 1.5 end
        if ctSB <= 0 then ctSB = (trance > 0) and 0 or 2.5 end
    else
        if ctHaunt <= 0 then ctHaunt = ctUA end
    end
    local effGcd = (state.gcdDuration and state.gcdDuration > 0) and state.gcdDuration or ctUA
    if effGcd < 1.0 then effGcd = 1.0 elseif effGcd > 1.5 then effGcd = 1.5 end
    wl.uaCast, wl.hauntCast, wl.sbCast, wl.effGcd = ctUA, ctHaunt, ctSB, effGcd

    -- Proyeccion al final del casteo/GCD actual (en canalizacion no se proyecta el canal entero)
    local t0 = state.gcdRemains or 0
    if castRem > t0 then t0 = castRem end
    wl.nextFree = t0

    local castingUA = (castName == NAME.UA)
    local castingHaunt = (castName == NAME.HAUNT)
    local castingSB = (castName == NAME.SB)
    wl.castingUA, wl.castingHaunt, wl.castingSB = castingUA, castingHaunt, castingSB

    wl.projLT = (lt > t0) and (lt - t0) or 0
    wl.projSM = castingSB and 30 or ((sm > t0) and (sm - t0) or 0)
    wl.projCorr = ((castingSB or castingHaunt) and corr > t0) and 18 or ((corr > t0) and (corr - t0) or 0)
    wl.projUA = castingUA and 15 or ((ua > t0) and (ua - t0) or 0)
    wl.projCoa = (coa > t0) and (coa - t0) or 0
    wl.projCod = (cod > t0) and (cod - t0) or 0
    wl.projCoe = (coe > t0) and (coe - t0) or 0
    wl.projHaunt = castingHaunt and 12 or ((haunt > t0) and (haunt - t0) or 0)
end

-- Maldicion a mantener. var curse: "auto" (Doom en bosses, Agony en el resto), "doom", "agony", "elements"
-- Devuelve el alias a castear o nil si ya esta puesta
local function CurseNeeded(state, wl, defaultCurse)
    local curse = Var(state, "curse", defaultCurse)
    local gcd = state.gcdRemains or 0
    if curse == "elements" then
        if wl.coe <= gcd and WlHas(state, "COE") then return "COE" end
        return nil
    end
    if curse == "auto" then curse = wl.isBoss and "doom" or "agony" end
    if curse == "doom" and WlHas(state, "COD") then
        if wl.cod <= gcd and Ready(state, "COD") then return "COD" end
        return nil
    end
    if wl.coa <= gcd and WlHas(state, "COA") then return "COA" end
    return nil
end

-- Life Tap: mantener el buff del glifo (var glyphLifeTap = 1) y recuperar mana debajo de lifeTapMana
-- Glyph of Life Tap: puesto (toggle en Opciones, RotaCore/Glyphs.lua) y var glyphLifeTap sin apagar
local function LifeTapGlyph(state)
    if Var(state, "glyphLifeTap", 1) ~= 1 then return false end
    local G = RotaCore.Glyphs
    return (G and G:On(RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile(), "lifetap")) and true or false
end

local function LifeTapNeeded(state, wl)
    if not WlHas(state, "LT") then return false end
    if (state.powerPct or 100) < Var(state, "lifeTapMana", 15) then return true end
    return LifeTapGlyph(state) and state.inCombat and wl.lifeTapBuff <= (state.gcdRemains or 0)
end

-- Shadow Mastery (Improved Shadow Bolt): Shadow Bolt si nadie tiene el debuff puesto (var shadowMastery = 1)
local function ShadowMasteryNeeded(state, wl)
    return Var(state, "shadowMastery", 1) == 1 and wl.shadowMastery <= (state.gcdRemains or 0) + 2
        and WlHas(state, "SB")
end

-- AFFLICTION (Wowhead)
-- Life Tap > Shadow Mastery > Corruption > Unstable Affliction > Curse > Haunt > Drain Soul (< 25%) > Shadow Bolt
-- AoE: Seed of Corruption
function RotaClass_WL.EvaluateAffliction(state)
    local wl = state.wl
    local gcd = state.gcdRemains or 0
    if state.aoeMode and WlHas(state, "SEED") then return "SEED" end

    if LifeTapNeeded(state, wl) then return "LT" end
    if ShadowMasteryNeeded(state, wl) then return "SB" end
    if wl.corruption <= gcd and WlHas(state, "CORR") then return "CORR" end
    -- Unstable Affliction tiene 1.5 s de casteo: renovar si se cae antes de que termine
    if wl.ua <= gcd + 1.5 and WlHas(state, "UA") then return "UA" end
    local c = CurseNeeded(state, wl, "agony")
    if c then return c end
    if wl.haunt <= gcd + 1.5 and Ready(state, "HAUNT") then return "HAUNT" end
    if wl.targetHealthPct <= 25 and WlHas(state, "DSOUL") then return "DSOUL" end
    return "SB"
end

-- DEMONOLOGY (Wowhead)
-- Life Tap > Shadow Mastery > Curse > Corruption > Immolate > Soul Fire (Decimation) > Incinerate (Molten Core) > Shadow Bolt
-- AoE: Immolation Aura (en Metamorphosis) > Seed of Corruption
function RotaClass_WL.EvaluateDemonology(state)
    local wl = state.wl
    local gcd = state.gcdRemains or 0
    if state.aoeMode then
        if wl.metamorphosis > 0 and Ready(state, "IA") then return "IA" end
        if WlHas(state, "SEED") then return "SEED" end
    end

    if LifeTapNeeded(state, wl) then return "LT" end
    if ShadowMasteryNeeded(state, wl) then return "SB" end
    local c = CurseNeeded(state, wl, "auto")
    if c then return c end
    if wl.corruption <= gcd and WlHas(state, "CORR") then return "CORR" end
    if wl.immolate <= gcd + 2 and WlHas(state, "IMM") then return "IMM" end
    if wl.decimation > gcd and WlHas(state, "SF") then return "SF" end
    if wl.moltenCore > gcd and WlHas(state, "INC") then return "INC" end
    return "SB"
end

-- DESTRUCTION (Wowhead)
-- Life Tap > Curse > Immolate > Conflagrate > Chaos Bolt > Incinerate | AoE: Shadowfury > Seed of Corruption
function RotaClass_WL.EvaluateDestruction(state)
    local wl = state.wl
    local gcd = state.gcdRemains or 0
    if state.aoeMode then
        if Ready(state, "SFURY") then return "SFURY" end
        if WlHas(state, "SEED") then return "SEED" end
    end

    if LifeTapNeeded(state, wl) then return "LT" end
    local c = CurseNeeded(state, wl, "auto")
    if c then return c end
    if wl.immolate <= gcd + 2 and WlHas(state, "IMM") then return "IMM" end
    if wl.immolate > gcd and Ready(state, "CONF") then return "CONF" end
    if Ready(state, "CB") then return "CB" end
    return "INC"
end

-- Off-GCD / burst comun; Demonology suma Metamorphosis y Demonic Empowerment
local function BurstOff(state)
    if state.burstMode == false or not state.inCombat then return nil end
    if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
    if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    return nil
end

function RotaClass_WL.EvaluateDemonologyOff(state)
    local wl = state.wl
    if state.inCombat and wl.hasPet and Ready(state, "DE") then return "DE" end
    if state.burstMode ~= false and state.inCombat and wl.metamorphosis <= 0 and Ready(state, "META") then
        return "META"
    end
    return BurstOff(state)
end

RotaClass_WL.EvaluateAfflictionOff = BurstOff
RotaClass_WL.EvaluateDestructionOff = BurstOff

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

RotaClass_WL.Evaluate = {
    affliction = Wrap(RotaClass_WL.EvaluateAffliction, "SB"),
    demonology = Wrap(RotaClass_WL.EvaluateDemonology, "SB"),
    destruction = Wrap(RotaClass_WL.EvaluateDestruction, "INC"),
}

if RotaCore.State and RotaCore.State.data then
    local sd = RotaCore.State.data
    sd.evaluateWlAffliction = RotaClass_WL.Evaluate.affliction
    sd.evaluateWlAfflictionOff = RotaClass_WL.EvaluateAfflictionOff
    sd.evaluateWlDemonology = RotaClass_WL.Evaluate.demonology
    sd.evaluateWlDemonologyOff = RotaClass_WL.EvaluateDemonologyOff
    sd.evaluateWlDestruction = RotaClass_WL.Evaluate.destruction
    sd.evaluateWlDestructionOff = RotaClass_WL.EvaluateDestructionOff
end

-- Deteccion de build: arbol con mas puntos. Override con la build elegida por el PJ.
local BUILDS = {
    affliction = { "wl_affliction_pve", "Affliction", "[AFF]" },
    demonology = { "wl_demonology_pve", "Demonology", "[DEMO]" },
    destruction = { "wl_destruction_pve", "Destruction", "[DEST]" },
}

function RotaClass_WL:DetectBuild()
    ScanTalents()
    local key = "affliction"
    if tabPoints[2] > tabPoints[1] and tabPoints[2] >= tabPoints[3] then
        key = "demonology"
    elseif tabPoints[3] > tabPoints[1] and tabPoints[3] > tabPoints[2] then
        key = "destruction"
    end
    local b = BUILDS[key]
    RotaClass_WL.detectedBuild = key
    RotaClass_WL.detectedPresetId = b[1]
    RotaClass_WL.detectedSpecName = b[2]
    RotaClass_WL.detectedBadge = b[3]

    local sel = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or "auto"
    local active = BUILDS[sel] and BUILDS[sel][1] or b[1]

    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(active)
    end
    return key, active, b[2]
end

-- Helpers de Affliction con proyeccion de casteo, tiempo real con celeridad y tiempo de vuelo de Poseer
local function AffReadyAt(state, wl, alias)
    if not WlHas(state, alias) then return false end
    if alias == "HAUNT" and wl.castingHaunt then return false end
    local cd = Cd(state, alias)
    if cd ~= nil then return cd <= (wl.nextFree or 0) + 0.1 end
    return (state.spellReady and state.spellReady(alias)) and true or false
end

local function AffLifeTapNeeded(state, wl)
    if not WlHas(state, "LT") then return false end
    if (state.powerPct or 100) < Var(state, "lifeTapMana", 15) then return true end
    return LifeTapGlyph(state) and state.inCombat and wl.projLT <= 0
end

local function AffShadowMasteryNeeded(state, wl)
    return Var(state, "shadowMastery", 1) == 1 and wl.projSM <= (wl.sbCast or 2.5) + 0.5
        and WlHas(state, "SB")
end

-- Corrupcion en Affliction: si se cayo, o 1 vez manual al <= 35% para congelar Abrazo de la Muerte (+12%)
-- var corrExecute: "boss" (solo jefes, por defecto), "all" (todos los objetivos), "off" (apagado)
local function AffCorrNeeded(state, wl)
    if not WlHas(state, "CORR") then return false end
    if wl.projCorr <= 0 then return true end
    if wl.corrExecDone or hasDeathsEmbrace == false then return false end
    if wl.targetHealthPct > 35 then return false end
    local mode = Var(state, "corrExecute", "boss")
    if mode == "off" or mode == 0 or mode == false then return false end
    if mode == "all" or wl.isBoss then
        state.reason = "Renovar Corrupcion <= 35% (Abrazo de la Muerte +12%)"
        return true
    end
    return false
end

local function AffCurseNeeded(state, wl, defaultCurse)
    local curse = Var(state, "curse", defaultCurse)
    if curse == "elements" then
        if wl.projCoe <= 0 and WlHas(state, "COE") then return "COE" end
        return nil
    end
    if curse == "auto" then curse = wl.isBoss and "doom" or "agony" end
    if curse == "doom" and WlHas(state, "COD") then
        if wl.projCod <= 0 and AffReadyAt(state, wl, "COD") then return "COD" end
        return nil
    end
    if wl.projCoa <= 0 and WlHas(state, "COA") then return "COA" end
    return nil
end

local function AffHauntNeeded(state, wl)
    local travel = Var(state, "hauntTravel", 0.8)
    return wl.projHaunt <= (wl.hauntCast or 1.5) + travel and AffReadyAt(state, wl, "HAUNT")
end

-- Revisa antes de castear `candidate` si su duracion haria caer algo de mayor prioridad.
-- Debuffs sin ticks (Life Tap, Shadow Mastery, Poseer): se renuevan antes.
-- UA (DoT con ticks, sin Pandemic en 3.3.5a): nunca se corta el ultimo tick; si falta poco (<= uaWaitMax), espera.
local function AffBefore(state, wl, candidate)
    if candidate == "DSOUL" and wl.channeling and wl.chanName == NAME.DSOUL then
        return nil
    end
    local g = wl.effGcd or 1.5
    local dur = g
    local isFiller = false
    if candidate == "UA" then
        dur = (wl.uaCast and wl.uaCast > g) and wl.uaCast or g
    elseif candidate == "HAUNT" then
        dur = (wl.hauntCast and wl.hauntCast > g) and wl.hauntCast or g
    elseif candidate == "SB" then
        dur = (wl.sbCast and wl.sbCast > g) and wl.sbCast or g
        isFiller = true
    elseif candidate == "DSOUL" then
        dur = (wl.uaCast or 1.5) * 2
        isFiller = true
    end

    if LifeTapGlyph(state) and state.inCombat and WlHas(state, "LT") and wl.projLT <= dur then
        state.reason = "Renovar Life Tap antes de castear"
        return "LT"
    end
    if candidate ~= "UA" and candidate ~= "SB" and Var(state, "shadowMastery", 1) == 1
        and WlHas(state, "SB") and wl.projSM <= dur + (wl.sbCast or 2.5) then
        state.reason = "Renovar Shadow Mastery antes de castear"
        return "SB"
    end
    if isFiller then
        local travel = Var(state, "hauntTravel", 0.8)
        if AffReadyAt(state, wl, "HAUNT") and wl.projHaunt <= dur + (wl.hauntCast or 1.5) + travel then
            state.reason = "Renovar Poseer antes de rellenar"
            return "HAUNT"
        end
        local uaCast = wl.uaCast or 1.5
        local uaGap = wl.projUA - uaCast
        local maxWait = Var(state, "uaWaitMax", 0.5)
        if candidate == "SB" and (wl.sbCast or 0) <= 0 and maxWait > 0.25 then
            maxWait = 0.25
        end
        if WlHas(state, "UA") and uaGap > 0 and uaGap <= maxWait then
            state.isWaiting = true
            state.waitTime = (wl.nextFree or 0) + uaGap
            state.reason = "Esperar para renovar UA sin cortar el ultimo tick"
            return "UA"
        end
    end
    return nil
end

-- Funciones del Brujo para las reglas del preset (ver RotaClass_WL/Presets.lua)
if RotaCore.Sandbox and RotaCore.Sandbox.AddHelper then
    local Sandbox = RotaCore.Sandbox
    --- maldicion a poner (var "curse": auto / doom / agony / elements), o nil si ya esta
    Sandbox:AddHelper("curse", function(default)
        local st = Sandbox.current
        return CurseNeeded(st, st.wl, default)
    end)
    --- Life Tap hace falta: poco mana, o se cae el buff de Glyph of Life Tap en combate (var glyphLifeTap)
    Sandbox:AddHelper("lifeTapNeeded", function()
        local st = Sandbox.current
        return LifeTapNeeded(st, st.wl)
    end)
    --- falta Shadow Mastery en el objetivo y nadie mas lo pone (var shadowMastery)
    Sandbox:AddHelper("shadowMasteryNeeded", function()
        local st = Sandbox.current
        return ShadowMasteryNeeded(st, st.wl)
    end)
    --- versiones con proyeccion de casteo y lookahead para Affliction
    Sandbox:AddHelper("affLifeTapNeeded", function()
        local st = Sandbox.current
        return AffLifeTapNeeded(st, st.wl)
    end)
    Sandbox:AddHelper("affShadowMasteryNeeded", function()
        local st = Sandbox.current
        return AffShadowMasteryNeeded(st, st.wl)
    end)
    Sandbox:AddHelper("affCorrNeeded", function()
        local st = Sandbox.current
        return AffCorrNeeded(st, st.wl)
    end)
    Sandbox:AddHelper("affCurse", function(default)
        local st = Sandbox.current
        return AffCurseNeeded(st, st.wl, default)
    end)
    Sandbox:AddHelper("affHauntNeeded", function()
        local st = Sandbox.current
        return AffHauntNeeded(st, st.wl)
    end)
    Sandbox:AddHelper("affBefore", function(candidate)
        local st = Sandbox.current
        return AffBefore(st, st.wl, candidate)
    end)
end

RotaClass_WL.UpdateState = UpdateWarlockState

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "WARLOCK",
        addonName = "RotaClass_WL",
        classColor = { r = 0.58, g = 0.51, b = 0.79 },
        builds = {
            { key = "auto", name = "AUTO", color = {1.0, 0.9, 0.0} },
            { key = "affliction", name = "Affliction", color = {0.5, 0.9, 0.3}, preset = "wl_affliction_pve" },
            { key = "demonology", name = "Demonology", color = {0.6, 0.4, 0.9}, preset = "wl_demonology_pve" },
            { key = "destruction", name = "Destruction", color = {1.0, 0.4, 0.2}, preset = "wl_destruction_pve" },
        },
        detectBuild = function() return RotaClass_WL:DetectBuild() end,
        getIdlePreviewAction = function(buildKey)
            if buildKey == "destruction" then return "INC" end
            return "SB"
        end,
        stateProvider = UpdateWarlockState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("WARLOCK", UpdateWarlockState)
end

if _G.CreateFrame and not RotaClass_WL.eventFrame then
    local f = _G.CreateFrame("Frame", "RotaClass_WL_EventFrame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event, unit, spellName)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            OnSpellcastSucceeded(unit, spellName)
        elseif event == "PLAYER_REGEN_ENABLED" then
            RotaClass_WL.ResetCorrExecute()
        else
            RotaClass_WL:DetectBuild()
        end
    end)
    RotaClass_WL.eventFrame = f
end

return RotaClass_WL
