-- RotaClass_PAL/RotaClass_PAL.lua — Retribution Paladin State Provider & FCFS Engine (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_PAL = {}
_G.RotaClass_PAL = RotaClass_PAL

-- Safe spell check helper for Paladin
local function PalHasSpell(state, spellOrId)
    if not spellOrId then return false end
    if state and state.hasSpell then
        return state.hasSpell(spellOrId)
    end
    if RotaCore.Spells and RotaCore.Spells.HasSpell then
        return RotaCore.Spells:HasSpell(spellOrId)
    end
    if _G.GetSpellCooldown then
        return _G.GetSpellCooldown(spellOrId) ~= nil
    end
    return false
end

RotaClass_PAL.HasSpell = function(selfOrSpell, spell)
    local target = (spell ~= nil) and spell or selfOrSpell
    return PalHasSpell(nil, target)
end
RotaClass_PAL.hasSpell = RotaClass_PAL.HasSpell

-- Cooldown real de un hechizo por nombre o ID.
-- Devuelve: nil = el cliente no conoce el hechizo | 0 = listo (o solo GCD) | n = segundos restantes
local function ApiCooldown(name, id, now)
    if not _G.GetSpellCooldown then return nil end
    local s, d = _G.GetSpellCooldown(name)
    if s == nil and id then s, d = _G.GetSpellCooldown(id) end
    if s == nil then return nil end
    if s == 0 or not d or d <= 1.5 then return 0 end
    local rem = (s + d) - now
    if rem < 0 then rem = 0 end
    return rem
end

-- Pre-allocated static seal list to check
local SEAL_NAMES = {
    "Seal of Vengeance",
    "Seal of Corruption",
    "Seal of Command",
    "Seal of Righteousness",
    "Seal of Wisdom",
    "Seal of Light",
    "Seal of Justice",
}

local JUDGEMENT_SPELLS = {
    { alias = "JUDGEMENT", name = "Judgement of Wisdom", id = 53408 },
    { alias = "JOW", name = "Judgement of Wisdom", id = 53408 },
    { alias = "JOL", name = "Judgement of Light", id = 20271 },
    { alias = "JOJ", name = "Judgement of Justice", id = 53407 },
}

-- Judgement: seguimiento propio del ultimo casteo y anti-traba
local JUDGEMENT_LOCKOUT = 8      -- cooldown minimo real de Judgement (10s base, 8s con talentos)
local STALL_SECONDS = 2.5        -- si se sugiere tanto tiempo sin que lo castees, se oculta un rato
local STALL_SUPPRESS = 4
local lastJudge = 0
local jShownSince = nil
local jLastSeen = 0
local jSuppressUntil = 0

if _G.CreateFrame and not RotaClass_PAL.judgeFrame then
    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    f:SetScript("OnEvent", function(_, _, _, subEvent, srcGUID, _, _, _, _, _, _, spellName)
        if subEvent ~= "SPELL_CAST_SUCCESS" or not spellName then return end
        if srcGUID ~= _G.UnitGUID("player") then return end
        if string.find(spellName, "^Judgement") or string.find(spellName, "^Juicio") then
            lastJudge = _G.GetTime()
        end
    end)
    RotaClass_PAL.judgeFrame = f
end

local function GetAvailableJudgement(state)
    local now = (state and state.now) or (_G.GetTime and _G.GetTime()) or 0

    -- anti-traba: si se sugirio mucho tiempo y nunca se casteo, ocultar un momento
    if now < jSuppressUntil then
        jShownSince = nil
        return nil
    end

    -- Judgement necesita un Sello activo
    local pal = state and state.pal
    if pal and pal.hasSeal == false then
        jShownSince = nil
        return nil
    end

    local preferred = nil
    local cdRem = 0
    local anyKnown = false
    local anyApi = false

    for i = 1, #JUDGEMENT_SPELLS do
        local j = JUDGEMENT_SPELLS[i]
        local aliasKnown = PalHasSpell(state, j.alias)
        local apiCd = ApiCooldown(j.name, j.id, now)
        if aliasKnown or apiCd ~= nil or PalHasSpell(state, j.name) or PalHasSpell(state, j.id) then
            anyKnown = true
            if not preferred then preferred = j.alias end
            if apiCd ~= nil then
                anyApi = true
                if apiCd > cdRem then cdRem = apiCd end
            end
            if aliasKnown and state and state.spellCooldown then
                local c = state.spellCooldown(j.alias) or 0
                if c > cdRem then cdRem = c end
            end
        end
    end

    if not anyKnown then
        jShownSince = nil
        return nil
    end

    -- Si el cliente no reporta el cooldown por nombre/ID, confiar en el estado del motor (nunca asumir "listo")
    if not anyApi then
        if not (state and state.spellReady and state.spellReady(preferred or "JUDGEMENT")) then
            jShownSince = nil
            return nil
        end
    end

    -- Bloqueo por ultimo casteo (por si el cooldown del cliente tarda o reporta 0)
    local lock = (lastJudge + JUDGEMENT_LOCKOUT) - now
    if lock > cdRem then cdRem = lock end

    -- Sin mana suficiente
    if _G.IsUsableSpell then
        local usable, noMana = _G.IsUsableSpell(JUDGEMENT_SPELLS[2].name)
        if not usable and noMana then
            jShownSince = nil
            return nil
        end
    end

    local gcdRem = (state and state.gcdRemains) or 0
    if cdRem <= (gcdRem + 0.1) then
        -- el anti-traba cuenta solo sugerencias seguidas: un hueco de mas de 1 s reinicia el contador
        if not jShownSince or (now - jLastSeen) > 1.0 then
            jShownSince = now
            jLastSeen = now
        elseif (now - jShownSince) > STALL_SECONDS and lastJudge < jShownSince then
            jSuppressUntil = now + STALL_SUPPRESS
            jShownSince = nil
            return nil
        end
        jLastSeen = now
        return preferred or "JUDGEMENT"
    end

    jShownSince = nil
    return nil
end

-- Hand of Reckoning con Glyph of Reckoning (Custom WotLK Rebuffed: dano gratis fuera de GCD cada 8s)
local function IsReckoningReady(state)
    local pal = state.pal
    local hasReckoningGlyph = (pal and pal.hasGlyphOfReckoning)
        or (state.glyphs and (state.glyphs[62124] or state.glyphs[54928] or state.glyphs["Glyph of Reckoning"]))
    if not hasReckoningGlyph then return false end
    if not (state.hasTarget and not state.targetIsDead and state.targetCanAttack ~= false) then return false end
    if not (PalHasSpell(state, "HOR") or PalHasSpell(state, "Hand of Reckoning") or PalHasSpell(state, 62124)) then
        return false
    end

    local horCD = 0
    if _G.GetSpellCooldown then
        local s, d = _G.GetSpellCooldown("Hand of Reckoning")
        if not s or s == 0 then s, d = _G.GetSpellCooldown(62124) end
        if s and s > 0 and d and d > 1.5 then
            local now = state.now or (_G.GetTime and _G.GetTime()) or 0
            horCD = math.max(0, (s + d) - now)
        end
    elseif state.spellCooldown then
        horCD = state.spellCooldown("HOR") or 0
    end
    return horCD <= 0
end

--- Updates Paladin state: Art of War, Seals, Hammer of Wrath threshold, Avenging Wrath, Divine Plea.
-- @param state table Pre-allocated RotaCore.State.data table
-- @param _ number Current timestamp (unused)
local function UpdatePaladinState(state, _)
    local pal = state.pal
    if not pal then return end

    -- 1. Art of War Proc Tracking (59578 / 53488)
    pal.artOfWarRemaining = state.buffRemaining("The Art of War", "player")
    pal.hasArtOfWar = (pal.artOfWarRemaining > 0)

    -- 2. Active Seals Check (nombres conocidos y, si no, cualquier buff "Seal of ..." / "Sello de ...")
    local foundSeal = false
    local sealName = nil
    for i = 1, #SEAL_NAMES do
        local s = SEAL_NAMES[i]
        if state.hasBuff(s, "player") then
            foundSeal = true
            sealName = s
            break
        end
    end
    if not foundSeal and _G.UnitBuff then
        for i = 1, 40 do
            local name = _G.UnitBuff("player", i)
            if not name then break end
            if string.find(name, "^Seal of") or string.find(name, "^Sello") then
                foundSeal = true
                sealName = name
                break
            end
        end
    end
    pal.hasSeal = foundSeal
    pal.sealName = sealName

    -- 3. Target Health & Hammer of Wrath Eligibility (Execute phase <= 20% HP)
    local th = state.targetHealthPct or 100
    if _G.UnitHealth and _G.UnitHealthMax and state.hasTarget then
        local cur = _G.UnitHealth("target") or 0
        local maxH = _G.UnitHealthMax("target") or 0
        if maxH > 0 then
            th = (cur / maxH) * 100
        end
    end
    pal.targetHealthPct = th
    pal.canHammerOfWrath = (th <= 20 and th > 0)

    -- 4. Target Creature Type (Undead / Demon check for Holy Wrath)
    local cType = _G.UnitCreatureType and _G.UnitCreatureType("target")
    pal.isUndeadOrDemon = (cType == "Undead" or cType == "No-muerto" or cType == "Demon" or cType == "Demonio")

    -- 5. Player Buffs Tracking (Avenging Wrath, Divine Plea, Judgements of the Wise)
    pal.avengingWrathRemaining = state.buffRemaining("Avenging Wrath", "player")
    pal.hasAvengingWrath = (pal.avengingWrathRemaining > 0)

    pal.divinePleaRemaining = state.buffRemaining("Divine Plea", "player")
    pal.hasDivinePlea = (pal.divinePleaRemaining > 0)

    pal.jotwRemaining = state.buffRemaining("Judgements of the Wise", "player")
end

-- Funciones del Paladin para las reglas del preset (ver RotaClass_PAL/Presets.lua)
if RotaCore.Sandbox and RotaCore.Sandbox.AddHelper then
    local Sandbox = RotaCore.Sandbox
    --- Judgement listo (respeta el cooldown real y el anti-traba); devuelve el alias o nil
    Sandbox:AddHelper("judgement", function() return GetAvailableJudgement(Sandbox.current) end)
    --- Hand of Reckoning con Glyph of Reckoning listo (para reglas custom; el preset no lo sugiere)
    Sandbox:AddHelper("reckoning", function() return IsReckoningReady(Sandbox.current) end)
end

-- Register state provider with RotaCore
if RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("PALADIN", UpdatePaladinState)
end

RotaClass_PAL.UpdateState = UpdatePaladinState
RotaClass_PAL.GetAvailableJudgement = GetAvailableJudgement
RotaClass_PAL.IsReckoningReady = IsReckoningReady

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "PALADIN",
        addonName = "RotaClass_PAL",
        classColor = { r = 0.96, g = 0.55, b = 0.73 },
        builds = {
            { key = "retribution", name = "Retri", color = {0.96, 0.55, 0.73}, preset = "pal_retribution_pve" },
        },
        detectBuild = function()
            if RotaClass_PAL.DetectBuild then return RotaClass_PAL:DetectBuild() end
            return "retribution", "pal_retribution_pve", "Retribution"
        end,
        getIdlePreviewAction = function(buildKey)
            return "CS"
        end,
        stateProvider = RotaClass_PAL.UpdateState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("PALADIN", UpdatePaladinState)
end

return RotaClass_PAL