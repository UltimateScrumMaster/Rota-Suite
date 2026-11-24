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

-- Shadow (Wowhead + feedback de jugadores de Sombras). Cada regla es un paso de la prioridad: la primera que devuelve una habilidad gana.
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
        IFOCUS = S("Inner Focus", 14751),       SPEED_POT = S("Potion of Speed", 40211),
        GLOVES = S("Hyperspeed Acceleration", 54758),
        RACIAL = RacialSpell(),
    },
    vars = {
        aoeTargets = 4,
        shadowfiendMana = 40,   -- Shadowfiend sin Burst debajo de este % de mana
        dispersionMana = 10,    -- Dispersion debajo de este % de mana
    },
    lists = {
        main = {
            R("pri_form", "SHADOWFORM", "Shadowform", [[
if not pri.shadowform and known("SHADOWFORM") then return "SHADOWFORM" end
]]),
            R("pri_moving", "SWD", "En movimiento: renovar Devouring Plague, Shadow Word: Death, y si no Devouring Plague", [[
if pri.moving then
    if pri.dp <= gcd() and known("DP") then return "DP" end
    if ready("SWD") then return "SWD" end
    if known("DP") then return "DP" end
end
]]),
            R("pri_aoe", "MSEAR", "AoE (4+ enemigos, var aoeTargets): Mind Sear", [[
if aoe() and known("MSEAR") then return "MSEAR" end
]]),
            R("pri_vt", "VT", "Vampiric Touch: renovar cuando le queda el tiempo de casteo real, sin perder ticks", [[
local cast = castTime("VT")
if cast <= 0 then cast = 1.5 end
if pri.vt <= cast and known("VT") then return "VT" end
]]),
            R("pri_dp", "DP", "Devouring Plague: renovar cuando se cae", [[
if pri.dp <= 0 and known("DP") then return "DP" end
]]),
            R("pri_opener", "SWD", "Opener: Shadow Word: Death (hasta 2 stacks de Shadow Weaving) y Mind Flay hasta 5", [[
if pri.swp <= 0 and pri.weaving < 5 then
    if pri.weaving <= 2 and ready("SWD") then return "SWD" end
    return "MF"
end
]]),
            R("pri_swp", "SWP", "Shadow Word: Pain con 5 stacks y Improved Spirit Tap (o cuando termina la poción)", [[
if pri.swp <= 0 and pri.weaving >= 5 and known("SWP") then
    local spiritTap = buff(59000) > 0        -- Improved Spirit Tap
    local potionOver = buff(53908) <= gcd()  -- Potion of Speed terminada (o sin poción)
    if spiritTap or potionOver then return "SWP" end
    return "MF"
end
]]),
            R("pri_mb", "MB", "Mind Blast a cooldown", [[
if ready("MB") then return "MB" end
]]),
            R("pri_mf", "MF", "Mind Flay (relleno; se puede cortar despues del segundo tick)", [[
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
            R("pri_ifocus_opener", "IFOCUS", "Opener: Inner Focus con 3-4 stacks, para el Shadow Word: Pain", [[
if combat() and burst() and pri.swp <= 0 and pri.weaving >= 3 and pri.weaving < 5 and ready("IFOCUS") then
    return "IFOCUS"
end
]]),
            R("pri_disp", "DISP", "Dispersion con poco mana (var dispersionMana)", [[
if combat() and powerPct() < var("dispersionMana", 10) and ready("DISP") then return "DISP" end
]]),
            R("pri_fiend", "FIEND", "Shadowfiend (Burst, o con poco mana: var shadowfiendMana)", [[
if combat() and (burst() or powerPct() < var("shadowfiendMana", 40)) and ready("FIEND") then return "FIEND" end
]]),
            R("pri_gloves", "GLOVES", "Guantes a cooldown", [[
if combat() and burst() and gloves() then return "GLOVES" end
]]),
            R("pri_racial", "RACIAL", "Racial a cooldown", [[
if combat() and burst() and ready("RACIAL") then return "RACIAL" end
]]),
            R("pri_ifocus", "IFOCUS", "Inner Focus a cooldown con Shadow Word: Pain ya puesto", [[
if combat() and burst() and pri.swp > 0 and ready("IFOCUS") then return "IFOCUS" end
]]),
        },
    },
}
-- Pre-pull (boton Pre-Pull, una vez): poción y Vampiric Touch precasteado; despues Devouring Plague y el opener
Presets.PRI_SHADOW_PVE.lists.prepull = {
    RotaCore.PrepullPotion("melee"), -- Potion of Speed (feedback de jugadores de Sombras)
    R("pri_pre_vt", "VT", "Vampiric Touch precasteado (llega con el pull)", [[
if pri.vt <= 0 and known("VT") then return "VT" end
]]),
}
Presets.PRI_SHADOW_PVE.meta.prepullLead = 3
Presets.PRI_SHADOW_PVE.meta.prepullNote = "Poción y Vampiric Touch precasteado unos 3 s antes; con el pull, Devouring Plague."

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
