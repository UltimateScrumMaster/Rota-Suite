-- RotaClass_WL/Presets.lua — Warlock RotationIR Presets (WoW 3.3.5a)
-- Cada preset es un gancho al motor del modulo (RotaClass_WL.lua) + sus variables de ajuste.
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Presets = {}

local function S(name, id)
    return { name = name, defaultId = id, overrideId = nil, matchById = false }
end

local function RacialSpell()
    local race
    if _G.UnitRace then
        local _, r = _G.UnitRace("player")
        race = r
    end
    if race == "Troll" then return S("Berserking", 26297) end
    if race == "BloodElf" then return S("Arcane Torrent", 28730) end
    return S("Blood Fury", 33702)
end

local function CommonSpells()
    return {
        SB = S("Shadow Bolt", 47809),             HAUNT = S("Haunt", 59164),
        CORR = S("Corruption", 47813),            UA = S("Unstable Affliction", 47843),
        COA = S("Curse of Agony", 47864),         COD = S("Curse of Doom", 47867),
        COE = S("Curse of the Elements", 47865),  DSOUL = S("Drain Soul", 47855),
        LT = S("Life Tap", 57946),                IMM = S("Immolate", 47811),
        INC = S("Incinerate", 47838),             CONF = S("Conflagrate", 17962),
        CB = S("Chaos Bolt", 59172),              SF = S("Soul Fire", 47825),
        SEED = S("Seed of Corruption", 47836),    META = S("Metamorphosis", 47241),
        DE = S("Demonic Empowerment", 47193),     IA = S("Immolation Aura", 50589),
        SFURY = S("Shadowfury", 47847),
        GLOVES = S("Hyperspeed Acceleration", 54758),
        RACIAL = RacialSpell(),
    }
end

local function Hook(id, action, note, fnName)
    return {
        id = id,
        enabled = true,
        type = "customLua",
        action = action,
        note = note,
        code = "if state." .. fnName .. " then return state." .. fnName .. "(state) end\nreturn nil",
    }
end

local R = RotaCore.Rule

local function Preset(id, name, short, spec, mainFn, offFn, mainAction, curse, shadowMastery, main, off)
    local p = {
        meta = {
            id = id,
            name = name,
            shortName = short,
            class = "WARLOCK",
            spec = spec,
            buildType = string.lower(spec),
            schema = 1,
            interface = 30300,
        },
        spells = CommonSpells(),
        vars = {
            aoeTargets = 4,
            curse = curse,       -- "auto" (Doom en bosses, Agony en el resto), "doom", "agony" o "elements"
            glyphLifeTap = 1,    -- 1: mantener el buff de Glyph of Life Tap en combate
            lifeTapMana = 15,    -- Life Tap debajo de este % de mana
            shadowMastery = shadowMastery,  -- 1: Shadow Bolt si falta Shadow Mastery (0 si otro brujo lo pone)
        },
        lists = { main = main, off = off },
    }
    local v1 = RotaCore.V1Of(p, {
        main = { Hook(id .. "_main", mainAction, name .. ": prioridad principal", mainFn) },
        off = { Hook(id .. "_off", "RACIAL", name .. ": cooldowns", offFn) },
    })
    return p, v1
end

-- Reglas comunes
local function LifeTap(prefix)
    return R(prefix .. "_lt", "LT", "Life Tap (poco mana o buff de Glyph of Life Tap caido)", [[
if lifeTapNeeded() then return "LT" end
]])
end
local function ShadowMastery(prefix)
    return R(prefix .. "_sm", "SB", "Shadow Bolt para poner Shadow Mastery", [[
if shadowMasteryNeeded() then return "SB" end
]])
end
local function Curse(prefix, default)
    return R(prefix .. "_curse", "COA", "Maldicion (var curse)", [[
local c = curse("]] .. default .. [[")
if c then return c end
]])
end
local function BurstOff(prefix)
    return R(prefix .. "_gloves", "GLOVES", "Guantes", [[
if combat() and burst() and gloves() then return "GLOVES" end
]]), R(prefix .. "_racial", "RACIAL", "Racial", [[
if combat() and burst() and ready("RACIAL") then return "RACIAL" end
]])
end

-- Datos del modulo en "wl": corruption, ua, haunt, immolate, coa, cod, coe (segundos que quedan de tus DoTs),
-- shadowMastery, lifeTapBuff, decimation, moltenCore, metamorphosis, shadowTrance, targetHealthPct, isBoss, hasPet,
-- uaCast, hauntCast, sbCast, effGcd, nextFree, castRem, channeling, projLT, projSM, projCorr, projUA, projHaunt.

-- Affliction (Wowhead)
Presets.WL_AFFLICTION_PVE, Presets.WL_AFFLICTION_PVE_V1 = Preset("wl_affliction_pve", "Affliction Warlock PvE",
    "[AFF]", "Affliction", "evaluateWlAffliction", "evaluateWlAfflictionOff", "SB", "agony", 1, {
        R("aff_aoe", "SEED", "AoE: Seed of Corruption", [[
if aoe() and known("SEED") then return "SEED" end
]]),
        R("aff_lt", "LT", "Life Tap (poco mana o buff de Glyph of Life Tap caido)", [[
if affLifeTapNeeded() then return "LT" end
]]),
        R("aff_sm", "SB", "Shadow Bolt para poner o renovar Shadow Mastery", [[
if affShadowMasteryNeeded() then return "SB" end
]]),
        R("aff_corr", "CORR", "Corruption (si se cayo, o 1 vez <= 35% por Abrazo de la Muerte)", [[
if affCorrNeeded() then return "CORR" end
]]),
        R("aff_ua", "UA", "Unstable Affliction (renovar justo al tiempo de casteo real)", [[
if wl.projUA <= wl.uaCast and known("UA") then
    local pre = affBefore("UA")
    if pre then return pre end
    return "UA"
end
]]),
        R("aff_curse", "COA", "Maldicion (var curse)", [[
local c = affCurse("agony")
if c then
    local pre = affBefore(c)
    if pre then return pre end
    return c
end
]]),
        R("aff_haunt", "HAUNT", "Poseer (casteo real + tiempo de vuelo)", [[
if affHauntNeeded() then
    local pre = affBefore("HAUNT")
    if pre then return pre end
    return "HAUNT"
end
]]),
        R("aff_dsoul", "DSOUL", "Drain Soul (< 25%), protegiendo buffs y DoTs antes de canalizar", [[
if wl.targetHealthPct <= 25 and known("DSOUL") then
    local pre = affBefore("DSOUL")
    if pre then return pre end
    return "DSOUL"
end
]]),
        R("aff_sb", "SB", "Shadow Bolt (relleno), protegiendo Poseer, UA y buffs", [[
local pre = affBefore("SB")
if pre then return pre end
return "SB"
]]),
    }, { BurstOff("aff") })
Presets.WL_AFFLICTION_PVE.vars.hauntTravel = 0.8 -- tiempo estimado de vuelo de Poseer (segundos)
Presets.WL_AFFLICTION_PVE.vars.uaWaitMax = 0.5   -- espera maxima para renovar UA sin cortar el ultimo tick
Presets.WL_AFFLICTION_PVE.vars.corrExecute = "boss" -- renovar Corrupcion <= 35%: "boss" (jefes), "all" (todos), "off"

-- Demonology (Wowhead)
Presets.WL_DEMONOLOGY_PVE, Presets.WL_DEMONOLOGY_PVE_V1 = Preset("wl_demonology_pve", "Demonology Warlock PvE",
    "[DEMO]", "Demonology", "evaluateWlDemonology", "evaluateWlDemonologyOff", "SB", "auto", 1, {
        R("demo_aoe", "SEED", "AoE: Immolation Aura en Metamorphosis, si no Seed of Corruption", [[
if aoe() then
    if wl.metamorphosis > 0 and ready("IA") then return "IA" end
    if known("SEED") then return "SEED" end
end
]]),
        LifeTap("demo"),
        ShadowMastery("demo"),
        Curse("demo", "auto"),
        R("demo_corr", "CORR", "Corruption (antes que Immolate: da Molten Core)", [[
if wl.corruption <= gcd() and known("CORR") then return "CORR" end
]]),
        R("demo_imm", "IMM", "Immolate", [[
if wl.immolate <= gcd() + 2 and known("IMM") then return "IMM" end
]]),
        R("demo_sf", "SF", "Decimation: Soul Fire", [[
if wl.decimation > gcd() and known("SF") then return "SF" end
]]),
        R("demo_inc", "INC", "Molten Core: Incinerate", [[
if wl.moltenCore > gcd() and known("INC") then return "INC" end
]]),
        R("demo_sb", "SB", "Shadow Bolt", [[
return "SB"
]]),
    }, {
        R("demo_de", "DE", "Demonic Empowerment", [[
if combat() and wl.hasPet and ready("DE") then return "DE" end
]]),
        R("demo_meta", "META", "Metamorphosis", [[
if burst() and combat() and wl.metamorphosis <= 0 and ready("META") then return "META" end
]]),
        BurstOff("demo"),
    })

-- Destruction (Wowhead)
Presets.WL_DESTRUCTION_PVE, Presets.WL_DESTRUCTION_PVE_V1 = Preset("wl_destruction_pve", "Destruction Warlock PvE",
    "[DEST]", "Destruction", "evaluateWlDestruction", "evaluateWlDestructionOff", "INC", "auto", 0, {
        R("dest_aoe", "SEED", "AoE: Shadowfury, si no Seed of Corruption", [[
if aoe() then
    if ready("SFURY") then return "SFURY" end
    if known("SEED") then return "SEED" end
end
]]),
        LifeTap("dest"),
        Curse("dest", "auto"),
        R("dest_imm", "IMM", "Immolate", [[
if wl.immolate <= gcd() + 2 and known("IMM") then return "IMM" end
]]),
        R("dest_conf", "CONF", "Conflagrate (necesita Immolate)", [[
if wl.immolate > gcd() and ready("CONF") then return "CONF" end
]]),
        R("dest_cb", "CB", "Chaos Bolt", [[
if ready("CB") then return "CB" end
]]),
        R("dest_inc", "INC", "Incinerate", [[
return "INC"
]]),
    }, { BurstOff("dest") })

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.WL_AFFLICTION_PVE.meta.requires = { "UA", "HAUNT" }
Presets.WL_DEMONOLOGY_PVE.meta.requires = { "META" }
Presets.WL_DESTRUCTION_PVE.meta.requires = { "CONF", "CB" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    for _, key in ipairs({ "WL_AFFLICTION_PVE", "WL_DEMONOLOGY_PVE", "WL_DESTRUCTION_PVE" }) do
        RotaCore.Profiles:RegisterPreset(Presets[key])
        RotaCore.Profiles:RegisterPreset(Presets[key .. "_V1"])
    end
end

return Presets
