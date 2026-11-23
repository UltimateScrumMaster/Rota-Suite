-- RotaClass_PRI/RotaClass_PRI.lua — Shadow Priest State Provider & Evaluator (WoW 3.3.5a)
-- Solo Shadow (Disciplina y Sagrado no tienen rotacion de dano).
-- Fuentes: guias de Wowhead WotLK + cambios de Rebuffed (docs/REBUFFED.md).
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_PRI = {
    detectedBuild = "shadow",
    detectedPresetId = "pri_shadow_pve",
    detectedSpecName = "Shadow",
    detectedBadge = "[SH]",
}
_G.RotaClass_PRI = RotaClass_PRI

local function SN(id, fallback)
    return (_G.GetSpellInfo and _G.GetSpellInfo(id)) or fallback
end

-- Hechizos: alias -> { nombre ingles, ID de rango maximo }
local SPELLS = {
    SWP = { "Shadow Word: Pain", 48125 },   VT = { "Vampiric Touch", 48160 },     DP = { "Devouring Plague", 48300 },
    MB = { "Mind Blast", 48127 },           MF = { "Mind Flay", 48156 },          SWD = { "Shadow Word: Death", 48158 },
    MSEAR = { "Mind Sear", 53023 },         SHADOWFORM = { "Shadowform", 15473 }, FIEND = { "Shadowfiend", 34433 },
    DISP = { "Dispersion", 47585 },         INNERFIRE = { "Inner Fire", 48168 },  VE = { "Vampiric Embrace", 15286 },
    IFOCUS = { "Inner Focus", 14751 },
}

-- Nombres localizados de auras
local NAME = {
    SWP = SN(48125, "Shadow Word: Pain"),   VT = SN(48160, "Vampiric Touch"),     DP = SN(48300, "Devouring Plague"),
    WEAVING = SN(15258, "Shadow Weaving"),  SHADOWFORM = SN(15473, "Shadowform"), INNERFIRE = SN(48168, "Inner Fire"),
    VE = SN(15286, "Vampiric Embrace"),
}

local function PriHas(state, alias)
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
    if not PriHas(state, alias) then return false end
    local cd = Cd(state, alias)
    if cd ~= nil then return cd <= (((state and state.gcdRemains) or 0) + 0.1) end
    return (state.spellReady and state.spellReady(alias)) and true or false
end

local function Var(state, name, default)
    local v = state.vars and state.vars[name]
    if v == nil then return default end
    return v
end

-- Provider de estado (cada update; state.pri se aloca una sola vez)
local function UpdatePriestState(state, _)
    local pri = state.pri
    if not pri then
        pri = {}
        state.pri = pri
    end
    local now = state.now or (_G.GetTime and _G.GetTime()) or 0

    local weaving, form, ifire, ve = 0, false, 0, 0
    if _G.UnitBuff then
        for i = 1, 40 do
            local name, _, _, count, _, _, expT = _G.UnitBuff("player", i)
            if not name then break end
            local rem = (expT and expT > 0) and (expT - now) or 999
            if rem < 0 then rem = 0 end
            if name == NAME.WEAVING then weaving = count or 1
            elseif name == NAME.SHADOWFORM then form = true
            elseif name == NAME.INNERFIRE then ifire = rem
            elseif name == NAME.VE then ve = rem end
        end
    end
    pri.weaving, pri.shadowform, pri.innerFire, pri.vampiricEmbrace = weaving, form, ifire, ve

    local swp, vt, dp = 0, 0, 0
    if _G.UnitDebuff and state.hasTarget ~= false then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT, caster = _G.UnitDebuff("target", i)
            if not name then break end
            if caster == "player" then
                local rem = (expT and expT > 0) and (expT - now) or 999
                if rem < 0 then rem = 0 end
                if name == NAME.SWP then swp = rem
                elseif name == NAME.VT then vt = rem
                elseif name == NAME.DP then dp = rem end
            end
        end
    end
    pri.swp, pri.vt, pri.dp = swp, vt, dp
    pri.moving = (_G.GetUnitSpeed and (_G.GetUnitSpeed("player") or 0) > 0) and true or false
end

-- SHADOW
-- Shadowform > SW:P (una vez, con 5 stacks de Shadow Weaving) > Vampiric Touch > Devouring Plague > Mind Blast > Mind Flay
-- En movimiento: Shadow Word: Death > Devouring Plague. AoE: Mind Sear reemplaza a Mind Flay.
function RotaClass_PRI.EvaluateShadow(state)
    local pri = state.pri
    local gcd = state.gcdRemains or 0

    if not pri.shadowform and PriHas(state, "SHADOWFORM") then return "SHADOWFORM" end

    if pri.moving then
        if Ready(state, "SWD") then return "SWD" end
        if PriHas(state, "DP") then return "DP" end
    end

    -- SW:P toma los stacks de Shadow Weaving al aplicarse y Mind Flay lo renueva: esperar 5 stacks
    local swpReady = pri.weaving >= 5 or Var(state, "swpWaitWeaving", 1) == 0
    if pri.swp <= gcd and swpReady and PriHas(state, "SWP") then return "SWP" end
    -- Vampiric Touch tiene 1.5 s de casteo: renovar si se cae antes de que termine
    if pri.vt <= gcd + 1.5 and PriHas(state, "VT") then return "VT" end
    if pri.dp <= gcd and PriHas(state, "DP") then return "DP" end
    if Ready(state, "MB") then return "MB" end
    if state.aoeMode and PriHas(state, "MSEAR") then return "MSEAR" end
    return "MF"
end

function RotaClass_PRI.EvaluateShadowOff(state)
    local pri = state.pri
    local mana = state.powerPct or 100
    if not state.inCombat then
        if pri.innerFire <= 0 and PriHas(state, "INNERFIRE") then return "INNERFIRE" end
        if pri.vampiricEmbrace <= 0 and PriHas(state, "VE") then return "VE" end
        return nil
    end
    if mana < Var(state, "dispersionMana", 10) and Ready(state, "DISP") then return "DISP" end
    if (state.burstMode ~= false or mana < Var(state, "shadowfiendMana", 40)) and Ready(state, "FIEND") then
        return "FIEND"
    end
    if state.burstMode ~= false then
        -- Inner Focus justo antes de Mind Blast (+25% de critico, sin costo)
        if Ready(state, "MB") and Ready(state, "IFOCUS") then return "IFOCUS" end
        if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
        if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
    end
    return nil
end

RotaClass_PRI.Evaluate = {
    shadow = function(state)
        state.isWaiting = false
        return RotaClass_PRI.EvaluateShadow(state) or "MF"
    end,
}

if RotaCore.State and RotaCore.State.data then
    local sd = RotaCore.State.data
    sd.evaluatePriShadow = RotaClass_PRI.Evaluate.shadow
    sd.evaluatePriShadowOff = RotaClass_PRI.EvaluateShadowOff
end

-- Unico build de dano: Shadow
function RotaClass_PRI:DetectBuild()
    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile("pri_shadow_pve")
    end
    return "shadow", "pri_shadow_pve", "Shadow"
end

RotaClass_PRI.UpdateState = UpdatePriestState

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "PRIEST",
        addonName = "RotaClass_PRI",
        classColor = { r = 1.0, g = 1.0, b = 1.0 },
        builds = {
            { key = "shadow", name = "Shadow", color = {0.6, 0.4, 0.9}, preset = "pri_shadow_pve" },
        },
        detectBuild = function() return RotaClass_PRI:DetectBuild() end,
        getIdlePreviewAction = function() return "MF" end,
        stateProvider = UpdatePriestState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("PRIEST", UpdatePriestState)
end

return RotaClass_PRI
