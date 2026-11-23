-- RotaClass_PRI/Presets.lua — Shadow Priest RotationIR Preset (WoW 3.3.5a)
-- Rotacion en reglas legibles (v2). La v1 (gancho al evaluador del modulo) queda como pri_shadow_pve_v1.
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
    return S("Berserking", 26297)
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

-- Shadow (Wowhead). Cada regla es un paso de la prioridad: la primera que devuelve una habilidad gana.
-- Datos del modulo en "pri": shadowform, weaving (stacks de Shadow Weaving), swp / vt / dp (segundos que le
-- quedan a cada DoT tuyo), innerFire, vampiricEmbrace, moving.
Presets.PRI_SHADOW_PVE = {
    meta = {
        id = "pri_shadow_pve",
        name = "Shadow Priest PvE",
        shortName = "[SH]",
        class = "PRIEST",
        spec = "Shadow",
        buildType = "shadow",
        schema = 1,
        interface = 30300,
    },
    spells = {
        SWP = S("Shadow Word: Pain", 48125),    VT = S("Vampiric Touch", 48160),
        DP = S("Devouring Plague", 48300),      MB = S("Mind Blast", 48127),
        MF = S("Mind Flay", 48156),             SWD = S("Shadow Word: Death", 48158),
        MSEAR = S("Mind Sear", 53023),          SHADOWFORM = S("Shadowform", 15473),
        FIEND = S("Shadowfiend", 34433),        DISP = S("Dispersion", 47585),
        INNERFIRE = S("Inner Fire", 48168),     VE = S("Vampiric Embrace", 15286),
        IFOCUS = S("Inner Focus", 14751),
        GLOVES = S("Hyperspeed Acceleration", 54758),
        RACIAL = RacialSpell(),
    },
    vars = {
        aoeTargets = 4,
        swpWaitWeaving = 1,     -- 1: aplicar SW:P recien con 5 stacks de Shadow Weaving
        shadowfiendMana = 40,   -- Shadowfiend sin Burst debajo de este % de mana
        dispersionMana = 10,    -- Dispersion debajo de este % de mana
    },
    lists = {
        main = {
            R("pri_form", "SHADOWFORM", "Shadowform", [[
if not pri.shadowform and known("SHADOWFORM") then return "SHADOWFORM" end
]]),
            R("pri_moving", "SWD", "En movimiento: Shadow Word: Death, si no Devouring Plague", [[
if pri.moving then
    if ready("SWD") then return "SWD" end
    if known("DP") then return "DP" end
end
]]),
            R("pri_swp", "SWP", "Shadow Word: Pain con 5 stacks de Shadow Weaving (Mind Flay lo renueva)", [[
local weavingOk = pri.weaving >= 5 or var("swpWaitWeaving", 1) == 0
if pri.swp <= gcd() and weavingOk and known("SWP") then return "SWP" end
]]),
            R("pri_vt", "VT", "Vampiric Touch (1.5 s de casteo: renovar antes de que caiga)", [[
if pri.vt <= gcd() + 1.5 and known("VT") then return "VT" end
]]),
            R("pri_dp", "DP", "Devouring Plague", [[
if pri.dp <= gcd() and known("DP") then return "DP" end
]]),
            R("pri_mb", "MB", "Mind Blast", [[
if ready("MB") then return "MB" end
]]),
            R("pri_msear", "MSEAR", "AoE: Mind Sear", [[
if aoe() and known("MSEAR") then return "MSEAR" end
]]),
            R("pri_mf", "MF", "Mind Flay (relleno)", [[
return "MF"
]]),
        },
        off = {
            R("pri_buffs", "INNERFIRE", "Fuera de combate: Inner Fire y Vampiric Embrace", [[
if not combat() then
    if pri.innerFire <= 0 and known("INNERFIRE") then return "INNERFIRE" end
    if pri.vampiricEmbrace <= 0 and known("VE") then return "VE" end
end
]]),
            R("pri_disp", "DISP", "Dispersion con poco mana", [[
if combat() and powerPct() < var("dispersionMana", 10) and ready("DISP") then return "DISP" end
]]),
            R("pri_fiend", "FIEND", "Shadowfiend (Burst, o con poco mana)", [[
if combat() and (burst() or powerPct() < var("shadowfiendMana", 40)) and ready("FIEND") then return "FIEND" end
]]),
            R("pri_ifocus", "IFOCUS", "Inner Focus justo antes de Mind Blast", [[
if combat() and burst() and ready("MB") and ready("IFOCUS") then return "IFOCUS" end
]]),
            R("pri_gloves", "GLOVES", "Guantes", [[
if combat() and burst() and gloves() then return "GLOVES" end
]]),
            R("pri_racial", "RACIAL", "Racial", [[
if combat() and burst() and ready("RACIAL") then return "RACIAL" end
]]),
        },
    },
}
Presets.PRI_SHADOW_PVE_V1 = RotaCore.V1Of(Presets.PRI_SHADOW_PVE, {
    main = { Hook("pri_shadow_main", "MF", "Shadow Priest: prioridad principal", "evaluatePriShadow") },
    off = { Hook("pri_shadow_off", "FIEND", "Shadow Priest: buffs y cooldowns", "evaluatePriShadowOff") },
})

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.PRI_SHADOW_PVE.meta.requires = { "SHADOWFORM", "VT" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    RotaCore.Profiles:RegisterPreset(Presets.PRI_SHADOW_PVE)
    RotaCore.Profiles:RegisterPreset(Presets.PRI_SHADOW_PVE_V1)
end

return Presets
