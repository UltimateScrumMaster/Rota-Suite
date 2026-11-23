-- RotaClass_SHA/Presets.lua — Shaman RotationIR Presets (WoW 3.3.5a)
-- Cada preset es un gancho al motor del modulo (RotaClass_SHA.lua) + sus variables de ajuste.
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
    if race == "Draenei" then return S("Gift of the Naaru", 59547) end
    return S("Blood Fury", 33697)
end

local function CommonSpells()
    return {
        LB = S("Lightning Bolt", 49238),       CL = S("Chain Lightning", 49271),
        LVB = S("Lava Burst", 60043),          FS = S("Flame Shock", 49233),
        ES = S("Earth Shock", 49231),          TS = S("Thunderstorm", 59159),
        EM = S("Elemental Mastery", 16166),    FET = S("Fire Elemental Totem", 2894),
        TOW = S("Totem of Wrath", 57722),      MAGMA = S("Magma Totem", 58734),
        FN = S("Fire Nova", 61657),            SS = S("Stormstrike", 17364),
        LL = S("Lava Lash", 60103),            FSPIRIT = S("Feral Spirit", 51533),
        SR = S("Shamanistic Rage", 30823),     LS = S("Lightning Shield", 49281),
        WS = S("Water Shield", 57960),         FTW = S("Flametongue Weapon", 58790),
        WFW = S("Windfury Weapon", 58804),     FRS = S("Frost Shock", 49236),
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

local function GlovesRacial(prefix)
    return R(prefix .. "_gloves", "GLOVES", "Guantes", [[
if combat() and burst() and gloves() then return "GLOVES" end
]]), R(prefix .. "_racial", "RACIAL", "Racial", [[
if combat() and burst() and ready("RACIAL") then return "RACIAL" end
]])
end

-- Datos del modulo en "sha": flameShock (segundos de tu Flame Shock), maelstrom (stacks), fireTotem (nombre del
-- totem de fuego o nil), fireElemental, magma, lightningShield, waterShield, mainImbue, offImbue, dualWield, moving.
-- Flame Shock, Earth Shock y Frost Shock comparten cooldown: ready("ES") dice si hay shock disponible.

-- 1. ELEMENTAL (Wowhead)
Presets.SHA_ELEMENTAL_PVE = {
    meta = {
        id = "sha_elemental_pve",
        name = "Elemental Shaman PvE",
        shortName = "[ELE]",
        class = "SHAMAN",
        spec = "Elemental",
        buildType = "elemental",
        schema = 1,
        interface = 30300,
    },
    spells = CommonSpells(),
    vars = {
        aoeTargets = 3,
        thunderstormMana = 60,    -- Thunderstorm por mana debajo de este %
        fireElemental = 1,        -- 1: sugerir Fire Elemental Totem con Burst ON
    },
    lists = {
        main = {
            R("ele_moving", "FRS", "En movimiento: Flame Shock si se cayo, si no Frost Shock", [[
if sha.moving and ready("ES") then
    if sha.flameShock <= gcd() and known("FS") then return "FS" end
    if known("FRS") then return "FRS" end
end
]]),
            R("ele_aoe", "CL", "AoE: Magma > Fire Nova > Chain Lightning > Flame Shock > Lava Burst > Thunderstorm > Lightning Bolt", [[
if aoe() then
    if not sha.fireTotem and ready("MAGMA") then return "MAGMA" end
    if sha.fireTotem and not sha.fireElemental and ready("FN") then return "FN" end
    if ready("CL") then return "CL" end
    if sha.flameShock <= gcd() and ready("ES") and known("FS") then return "FS" end
    if sha.flameShock > gcd() + 1.5 and ready("LVB") then return "LVB" end
    if powerPct() < var("thunderstormMana", 60) and ready("TS") then return "TS" end
    return "LB"
end
]]),
            R("ele_fs", "FS", "Flame Shock", [[
if sha.flameShock <= gcd() and ready("ES") and known("FS") then return "FS" end
]]),
            R("ele_lvb", "LVB", "Lava Burst si Flame Shock sigue puesto al terminar el casteo", [[
if sha.flameShock > gcd() + 1.5 and ready("LVB") then return "LVB" end
]]),
            R("ele_ts", "TS", "Thunderstorm por mana", [[
if powerPct() < var("thunderstormMana", 60) and ready("TS") then return "TS" end
]]),
            R("ele_tow", "TOW", "Totem of Wrath si no hay totem de fuego", [[
if combat() and not sha.fireTotem and ready("TOW") then return "TOW" end
]]),
            R("ele_lb", "LB", "Lightning Bolt", [[
return "LB"
]]),
        },
        off = {
            R("ele_shield", "WS", "Water Shield", [[
if sha.waterShield <= 0 and sha.lightningShield <= 0 and ready("WS") then return "WS" end
]]),
            R("ele_imbue", "FTW", "Fuera de combate: Flametongue Weapon", [[
if not combat() and not sha.mainImbue and known("FTW") then return "FTW" end
]]),
            R("ele_em", "EM", "Elemental Mastery", [[
if combat() and burst() and ready("EM") then return "EM" end
]]),
            R("ele_fet", "FET", "Fire Elemental Totem (var fireElemental)", [[
if combat() and burst() and var("fireElemental", 1) == 1 and not sha.fireElemental and ready("FET") then return "FET" end
]]),
            GlovesRacial("ele"),
        },
    },
}

-- 2. ENHANCEMENT (Wowhead)
Presets.SHA_ENHANCEMENT_PVE = {
    meta = {
        id = "sha_enhancement_pve",
        name = "Enhancement Shaman PvE",
        shortName = "[ENH]",
        class = "SHAMAN",
        spec = "Enhancement",
        buildType = "enhancement",
        schema = 1,
        interface = 30300,
    },
    spells = CommonSpells(),
    vars = {
        aoeTargets = 3,
        maelstromMin = 5,          -- stacks de Maelstrom Weapon para Lightning Bolt / Chain Lightning instantaneo
        shamanisticRageMana = 100, -- Shamanistic Rage con mana <= este %; 100 = a cooldown (Wowhead)
        fireElemental = 1,
    },
    lists = {
        main = {
            R("enh_aoe_totems", "MAGMA", "AoE: Magma Totem, despues Fire Nova", [[
if aoe() then
    if not sha.fireTotem and ready("MAGMA") then return "MAGMA" end
    if sha.fireTotem and not sha.fireElemental and ready("FN") then return "FN" end
end
]]),
            R("enh_maelstrom", "LB", "Maelstrom Weapon lleno: Lightning Bolt (Chain Lightning en AoE)", [[
if sha.maelstrom >= var("maelstromMin", 5) then
    if aoe() and ready("CL") then return "CL" end
    return "LB"
end
]]),
            R("enh_ss", "SS", "Stormstrike", [[
if ready("SS") then return "SS" end
]]),
            R("enh_fs", "FS", "Flame Shock", [[
if ready("ES") and sha.flameShock <= gcd() and known("FS") then return "FS" end
]]),
            R("enh_magma", "MAGMA", "Magma Totem", [[
if combat() and not sha.fireTotem and ready("MAGMA") then return "MAGMA" end
]]),
            R("enh_ls", "LS", "Lightning Shield", [[
if sha.lightningShield <= 0 and known("LS") then return "LS" end
]]),
            R("enh_es", "ES", "Earth Shock", [[
if ready("ES") then return "ES" end
]]),
            R("enh_fn", "FN", "Fire Nova", [[
if sha.fireTotem and not sha.fireElemental and ready("FN") then return "FN" end
]]),
            R("enh_ll", "LL", "Lava Lash", [[
if ready("LL") then return "LL" end
]]),
            R("enh_wait", "SS", "Nada listo: esperar Stormstrike", [[
return wait("SS")
]]),
        },
        off = {
            R("enh_imbues", "WFW", "Fuera de combate: Windfury Weapon y Flametongue en la otra mano", [[
if not combat() then
    if not sha.mainImbue and known("WFW") then return "WFW" end
    if sha.dualWield and not sha.offImbue and known("FTW") then return "FTW" end
end
]]),
            R("enh_sr", "SR", "Shamanistic Rage (var shamanisticRageMana; 100 = a cooldown)", [[
if combat() and powerPct() <= var("shamanisticRageMana", 100) and ready("SR") then return "SR" end
]]),
            R("enh_spirit", "FSPIRIT", "Feral Spirit", [[
if combat() and burst() and ready("FSPIRIT") then return "FSPIRIT" end
]]),
            R("enh_fet", "FET", "Fire Elemental Totem (var fireElemental)", [[
if combat() and burst() and var("fireElemental", 1) == 1 and not sha.fireElemental and ready("FET") then return "FET" end
]]),
            GlovesRacial("enh"),
        },
    },
}
Presets.SHA_ELEMENTAL_PVE_V1 = RotaCore.V1Of(Presets.SHA_ELEMENTAL_PVE, {
    main = { Hook("sha_ele_main", "LB", "Elemental Shaman: prioridad principal", "evaluateShaElemental") },
    off = { Hook("sha_ele_off", "EM", "Elemental Shaman: escudos, imbue y cooldowns", "evaluateShaElementalOff") },
})
Presets.SHA_ENHANCEMENT_PVE_V1 = RotaCore.V1Of(Presets.SHA_ENHANCEMENT_PVE, {
    main = { Hook("sha_enh_main", "SS", "Enhancement Shaman: prioridad principal", "evaluateShaEnhancement") },
    off = { Hook("sha_enh_off", "FSPIRIT", "Enhancement Shaman: imbues y cooldowns", "evaluateShaEnhancementOff") },
})

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.SHA_ELEMENTAL_PVE.meta.requires = { "TS" }
Presets.SHA_ENHANCEMENT_PVE.meta.requires = { "SS", "LL" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    for _, key in ipairs({ "SHA_ELEMENTAL_PVE", "SHA_ENHANCEMENT_PVE" }) do
        RotaCore.Profiles:RegisterPreset(Presets[key])
        RotaCore.Profiles:RegisterPreset(Presets[key .. "_V1"])
    end
end

return Presets
