-- RotaClass_MAG/Presets.lua — Mage RotationIR Presets (WoW 3.3.5a)
-- Cada preset es un gancho al motor del modulo (RotaClass_MAG.lua) + sus variables de ajuste.
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
        AB = S("Arcane Blast", 42897),          AM = S("Arcane Missiles", 42846),
        ABAR = S("Arcane Barrage", 44781),      AP = S("Arcane Power", 12042),
        POM = S("Presence of Mind", 12043),     IV = S("Icy Veins", 12472),
        MI = S("Mirror Image", 55342),          EVO = S("Evocation", 12051),
        FB = S("Fireball", 42833),              FFB = S("Frostfire Bolt", 47610),
        PYRO = S("Pyroblast", 42891),           LB = S("Living Bomb", 55360),
        SCORCH = S("Scorch", 42859),            COMB = S("Combustion", 11129),
        FROSTBOLT = S("Frostbolt", 42842),      DF = S("Deep Freeze", 44572),
        WE = S("Summon Water Elemental", 31687), BLIZZ = S("Blizzard", 42940),
        FS = S("Flamestrike", 42926),           AE = S("Arcane Explosion", 42921),
        TW = S("Time Warp", 80353),             BW = S("Blast Wave", 42945),
        DB = S("Dragon's Breath", 42950),       FBLAST = S("Fire Blast", 42873),
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

local function Preset(id, name, short, spec, mainFn, offFn, mainAction, vars, main, off)
    vars.aoeTargets = 3
    local p = {
        meta = {
            id = id,
            name = name,
            shortName = short,
            class = "MAGE",
            spec = spec,
            buildType = string.lower(spec),
            schema = 1,
            interface = 30300,
        },
        spells = CommonSpells(),
        vars = vars,
        lists = { main = main, off = off },
    }
    local v1 = RotaCore.V1Of(p, {
        main = { Hook(id .. "_main", mainAction, name .. ": prioridad principal", mainFn) },
        off = { Hook(id .. "_off", "RACIAL", name .. ": cooldowns", offFn) },
    })
    return p, v1
end

-- Cooldowns comunes al final de cada lista off
local function GlovesRacial(prefix)
    return R(prefix .. "_gloves", "GLOVES", "Guantes", [[
if combat() and burst() and gloves() then return "GLOVES" end
]]), R(prefix .. "_racial", "RACIAL", "Racial", [[
if combat() and burst() and ready("RACIAL") then return "RACIAL" end
]])
end

-- Datos del modulo en "mag": abStacks, abCasts (Arcane Blast desde el ultimo Arcane Missiles), abProcAt (en que
-- Arcane Blast salio Missile Barrage), missileBarrage, hotStreak, brainFreeze, fingersOfFrost, fofStacks,
-- livingBomb, critDebuff, firestarter, hasPet, moving (segundos que quedan de cada buff/debuff).

-- Arcane (Wowhead, "Better Rotation")
Presets.MAG_ARCANE_PVE, Presets.MAG_ARCANE_PVE_V1 = Preset("mag_arcane_pve", "Arcane Mage PvE", "[ARC]", "Arcane",
    "evaluateMagArcane", "evaluateMagArcaneOff", "AB", {
        evocationMana = 15,     -- Evocation debajo de este % de mana
        aoeSpell = "BLIZZ",     -- AoE: "BLIZZ", "FS" (Flamestrike) o "AE" (Arcane Explosion)
    }, {
        R("arc_moving", "ABAR", "En movimiento: Arcane Barrage", [[
if mag.moving and ready("ABAR") then return "ABAR" end
]]),
        R("arc_aoe", "BLIZZ", "AoE: el hechizo elegido en aoeSpell", [[
if aoe() and known(var("aoeSpell", "BLIZZ")) then return var("aoeSpell", "BLIZZ") end
]]),
        R("arc_evo", "EVO", "Evocation sin mana", [[
if powerPct() < var("evocationMana", 15) and ready("EVO") then return "EVO" end
]]),
        R("arc_am_proc", "AM", "Missile Barrage: Arcane Missiles despues del 4.o Arcane Blast (o del siguiente al proc)", [[
if mag.missileBarrage > 0 then
    local procAt = mag.abProcAt or mag.abCasts
    local need = 4
    if procAt >= 4 then need = procAt + 1 end
    if mag.abCasts >= need then return "AM" end
end
]]),
        R("arc_am_6", "AM", "Sin proc: Arcane Missiles despues del 6.o Arcane Blast", [[
if mag.abCasts >= 6 then return "AM" end
]]),
        R("arc_ab", "AB", "Arcane Blast", [[
return "AB"
]]),
    }, {
        R("arc_ap", "AP", "Arcane Power", [[
if combat() and burst() and ready("AP") then return "AP" end
]]),
        R("arc_pom", "POM", "Presence of Mind con 3+ stacks de Arcane Blast", [[
if combat() and burst() and mag.abStacks >= 3 and ready("POM") then return "POM" end
]]),
        R("arc_iv", "IV", "Icy Veins", [[
if combat() and burst() and ready("IV") then return "IV" end
]]),
        R("arc_mi", "MI", "Mirror Image", [[
if combat() and burst() and ready("MI") then return "MI" end
]]),
        GlovesRacial("arc"),
    })

-- Fire (Wowhead)
Presets.MAG_FIRE_PVE, Presets.MAG_FIRE_PVE_V1 = Preset("mag_fire_pve", "Fire Mage PvE", "[FIRE]", "Fire",
    "evaluateMagFire", "evaluateMagFireOff", "FB", {
        scorch = 0,             -- 1: mantener Improved Scorch si nadie pone el debuff de critico (Wowhead no lo usa)
        filler = "FB",          -- "FB" (Fireball) o "FFB" (Frostfire Bolt, build TTW/FFB)
    }, {
        R("fire_aoe", "FS", "AoE: Living Bomb > Flamestrike con Firestarter > Blast Wave > Dragon's Breath > Flamestrike", [[
if aoe() then
    if mag.livingBomb <= gcd() and known("LB") then return "LB" end
    if mag.firestarter > gcd() and known("FS") then return "FS" end
    if ready("BW") then return "BW" end
    if ready("DB") then return "DB" end
    if known("FS") then return "FS" end
end
]]),
        R("fire_pyro", "PYRO", "Hot Streak: Pyroblast", [[
if mag.hotStreak > gcd() and known("PYRO") then return "PYRO" end
]]),
        R("fire_lb", "LB", "Living Bomb (dejarla explotar)", [[
if mag.livingBomb <= gcd() and known("LB") then return "LB" end
]]),
        R("fire_moving", "FBLAST", "En movimiento: Fire Blast", [[
if mag.moving and ready("FBLAST") then return "FBLAST" end
]]),
        R("fire_scorch", "SCORCH", "Scorch si nadie pone el debuff de critico (var scorch)", [[
if var("scorch", 0) == 1 and mag.critDebuff <= gcd() + 2 and known("SCORCH") then return "SCORCH" end
]]),
        R("fire_filler", "FB", "Fireball (o Frostfire Bolt con filler = FFB)", [[
if var("filler", "FB") == "FFB" and known("FFB") then return "FFB" end
return "FB"
]]),
    }, {
        R("fire_comb", "COMB", "Combustion con Living Bomb recien puesta", [[
if combat() and burst() and mag.livingBomb > 6 and ready("COMB") then return "COMB" end
]]),
        R("fire_mi", "MI", "Mirror Image", [[
if combat() and burst() and ready("MI") then return "MI" end
]]),
        GlovesRacial("fire"),
    })

-- Frost (Wowhead: con Fingers of Frost, Frostbolt, Frostbolt y Deep Freeze con la ultima carga)
Presets.MAG_FROST_PVE, Presets.MAG_FROST_PVE_V1 = Preset("mag_frost_pve", "Frost Mage PvE", "[FROST]", "Frost",
    "evaluateMagFrost", "evaluateMagFrostOff", "FROSTBOLT", {}, {
        R("frost_we", "WE", "Water Elemental", [[
if combat() and not mag.hasPet and ready("WE") then return "WE" end
]]),
        R("frost_aoe", "BLIZZ", "AoE: Blizzard", [[
if aoe() and known("BLIZZ") then return "BLIZZ" end
]]),
        R("frost_df", "DF", "Deep Freeze con la ultima carga de Fingers of Frost", [[
if mag.fingersOfFrost > gcd() and mag.fofStacks <= 1 and ready("DF") then return "DF" end
]]),
        R("frost_ffb", "FFB", "Brain Freeze: Frostfire Bolt", [[
if mag.brainFreeze > gcd() and known("FFB") then return "FFB" end
]]),
        R("frost_moving", "FBLAST", "En movimiento: Fire Blast", [[
if mag.moving and ready("FBLAST") then return "FBLAST" end
]]),
        R("frost_fb", "FROSTBOLT", "Frostbolt", [[
return "FROSTBOLT"
]]),
    }, {
        R("frost_iv", "IV", "Icy Veins", [[
if combat() and burst() and ready("IV") then return "IV" end
]]),
        R("frost_mi", "MI", "Mirror Image", [[
if combat() and burst() and ready("MI") then return "MI" end
]]),
        GlovesRacial("frost"),
    })

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.MAG_ARCANE_PVE.meta.requires = { "AP" }
Presets.MAG_FIRE_PVE.meta.requires = { "LB", "PYRO" }
Presets.MAG_FROST_PVE.meta.requires = { "WE", "DF" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    for _, key in ipairs({ "MAG_ARCANE_PVE", "MAG_FIRE_PVE", "MAG_FROST_PVE" }) do
        RotaCore.Profiles:RegisterPreset(Presets[key])
        RotaCore.Profiles:RegisterPreset(Presets[key .. "_V1"])
    end
end

return Presets
