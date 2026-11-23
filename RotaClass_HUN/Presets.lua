-- RotaClass_HUN/Presets.lua — Hunter RotationIR Presets (WoW 3.3.5a)
-- Cada preset es un gancho al motor del modulo (RotaClass_HUN.lua) + sus variables de ajuste.
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
    return S("Blood Fury", 20572)
end

local function CommonSpells()
    return {
        KS = S("Kill Shot", 61006),              KC = S("Kill Command", 34026),
        MULTI = S("Multi-Shot", 49048),          SERPENT = S("Serpent Sting", 49001),
        ARCANE = S("Arcane Shot", 49045),        STEADY = S("Steady Shot", 49052),
        AIMED = S("Aimed Shot", 49050),          CHIMERA = S("Chimera Shot", 53209),
        ES = S("Explosive Shot", 60053),         BA = S("Black Arrow", 63672),
        SILENCE = S("Silencing Shot", 34490),    BW = S("Bestial Wrath", 19574),
        RF = S("Rapid Fire", 3045),              READY = S("Readiness", 23989),
        VOLLEY = S("Volley", 58434),             TRAP = S("Trap Launcher: Explosive Trap", 82939),
        DRAGONHAWK = S("Aspect of the Dragonhawk", 61847), VIPER = S("Aspect of the Viper", 34074),
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

local function Preset(id, name, short, spec, buildType, mainFn, offFn, vars, main, off)
    vars.aoeTargets = 3
    vars.viperMana = 10        -- Aspect of the Viper debajo de este % de mana
    vars.viperExitMana = 70    -- volver a Dragonhawk arriba de este %
    local p = {
        meta = {
            id = id,
            name = name,
            shortName = short,
            class = "HUNTER",
            spec = spec,
            buildType = buildType,
            schema = 1,
            interface = 30300,
        },
        spells = CommonSpells(),
        vars = vars,
        lists = { main = RotaCore.Flatten(main), off = RotaCore.Flatten(off) },
    }
    local v1 = RotaCore.V1Of(p, {
        main = { Hook(id .. "_main", "STEADY", name .. ": prioridad principal", mainFn) },
        off = { Hook(id .. "_off", "KC", name .. ": aspecto y cooldowns", offFn) },
    })
    return p, v1
end

-- Reglas comunes. Datos del modulo en "hun": serpentSting (segundos de tu Serpent Sting), targetHealthPct,
-- dragonhawk, viper, lockAndLoad.
local function AoE(prefix)
    return R(prefix .. "_aoe", "VOLLEY", "AoE: Explosive Trap > Multi-Shot > Volley", [[
if aoe() then
    if ready("TRAP") then return "TRAP" end
    if ready("MULTI") then return "MULTI" end
    if known("VOLLEY") then return "VOLLEY" end
end
]])
end
local function KillShot(prefix)
    return R(prefix .. "_ks", "KS", "Kill Shot con el objetivo debajo de 20%", [[
if hun.targetHealthPct <= 20 and ready("KS") then return "KS" end
]])
end
local function Steady(prefix)
    return R(prefix .. "_steady", "STEADY", "Steady Shot (relleno)", [[
return "STEADY"
]])
end
local function Aspect(prefix)
    return R(prefix .. "_aspect", "DRAGONHAWK", "Aspecto: Viper sin mana, Dragonhawk el resto del tiempo", [[
if hun.viper then
    if powerPct() >= var("viperExitMana", 70) and known("DRAGONHAWK") then return "DRAGONHAWK" end
elseif combat() and powerPct() < var("viperMana", 10) and known("VIPER") then
    return "VIPER"
elseif not hun.dragonhawk and known("DRAGONHAWK") then
    return "DRAGONHAWK"
end
]])
end
local function Cooldowns(prefix)
    return {
        R(prefix .. "_kc", "KC", "Kill Command", [[
if combat() and ready("KC") then return "KC" end
]]),
        R(prefix .. "_rf", "RF", "Rapid Fire", [[
if combat() and burst() and ready("RF") then return "RF" end
]]),
        R(prefix .. "_gloves", "GLOVES", "Guantes", [[
if combat() and burst() and gloves() then return "GLOVES" end
]]),
        R(prefix .. "_racial", "RACIAL", "Racial", [[
if combat() and burst() and ready("RACIAL") then return "RACIAL" end
]]),
    }
end

-- Beast Mastery (Wowhead)
Presets.HUN_BEAST_MASTERY_PVE, Presets.HUN_BEAST_MASTERY_PVE_V1 = Preset("hun_beast_mastery_pve",
    "Beast Mastery Hunter PvE", "[BM]", "Beast Mastery", "beast_mastery", "evaluateHunBeastMastery",
    "evaluateHunBeastMasteryOff", {
        multiShotMana = 40,   -- Multi-Shot en ST solo con mana >= este %
        arcaneShot = 1,       -- 0 cuando tengas suficiente Armor Penetration
    }, {
        AoE("bm"),
        KillShot("bm"),
        R("bm_multi", "MULTI", "Multi-Shot si sobra mana", [[
if powerPct() >= var("multiShotMana", 40) and ready("MULTI") then return "MULTI" end
]]),
        R("bm_serpent", "SERPENT", "Serpent Sting", [[
if hun.serpentSting <= gcd() and known("SERPENT") then return "SERPENT" end
]]),
        R("bm_arcane", "ARCANE", "Arcane Shot (var arcaneShot)", [[
if var("arcaneShot", 1) == 1 and ready("ARCANE") then return "ARCANE" end
]]),
        Steady("bm"),
    }, {
        Aspect("bm"),
        R("bm_bw", "BW", "Bestial Wrath", [[
if combat() and burst() and ready("BW") then return "BW" end
]]),
        Cooldowns("bm"),
    })

-- Marksmanship (Wowhead)
Presets.HUN_MARKSMANSHIP_PVE, Presets.HUN_MARKSMANSHIP_PVE_V1 = Preset("hun_marksmanship_pve",
    "Marksmanship Hunter PvE", "[MM]", "Marksmanship", "marksmanship", "evaluateHunMarksmanship",
    "evaluateHunMarksmanshipOff", {
        explosiveTrap = 1,    -- 1: Trap Launcher: Explosive Trap a CD en ST
        arcaneShot = 1,
    }, {
        AoE("mm"),
        KillShot("mm"),
        R("mm_serpent", "SERPENT", "Serpent Sting (Chimera Shot lo renueva)", [[
if hun.serpentSting <= gcd() and known("SERPENT") then return "SERPENT" end
]]),
        R("mm_chimera", "CHIMERA", "Chimera Shot con Serpent Sting puesto", [[
if hun.serpentSting > gcd() and ready("CHIMERA") then return "CHIMERA" end
]]),
        R("mm_aimed", "AIMED", "Aimed Shot", [[
if ready("AIMED") then return "AIMED" end
]]),
        R("mm_trap", "TRAP", "Trap Launcher: Explosive Trap (var explosiveTrap)", [[
if var("explosiveTrap", 1) == 1 and ready("TRAP") then return "TRAP" end
]]),
        R("mm_arcane", "ARCANE", "Arcane Shot (var arcaneShot)", [[
if var("arcaneShot", 1) == 1 and ready("ARCANE") then return "ARCANE" end
]]),
        Steady("mm"),
    }, {
        Aspect("mm"),
        Cooldowns("mm"),
        R("mm_silence", "SILENCE", "Silencing Shot", [[
if combat() and ready("SILENCE") then return "SILENCE" end
]]),
        R("mm_readiness", "READY", "Readiness con Rapid Fire y Chimera Shot gastados", [[
if combat() and burst() and ready("READY") and cd("RF") > 30 and cd("CHIMERA") > 2 then return "READY" end
]]),
    })

-- Survival (Wowhead)
Presets.HUN_SURVIVAL_PVE, Presets.HUN_SURVIVAL_PVE_V1 = Preset("hun_survival_pve", "Survival Hunter PvE", "[SV]",
    "Survival", "survival", "evaluateHunSurvival", "evaluateHunSurvivalOff", {
        explosiveTrap = 1,    -- 0 si el boss se mueve mucho: usa Black Arrow
    }, {
        AoE("sv"),
        KillShot("sv"),
        R("sv_es", "ES", "Explosive Shot", [[
if ready("ES") then return "ES" end
]]),
        R("sv_trap", "TRAP", "Trap Launcher: Explosive Trap, antes de reponer Serpent Sting (var explosiveTrap)", [[
if var("explosiveTrap", 1) == 1 and ready("TRAP") then return "TRAP" end
]]),
        R("sv_serpent", "SERPENT", "Serpent Sting (solo si se cayo)", [[
if hun.serpentSting <= gcd() and known("SERPENT") then return "SERPENT" end
]]),
        R("sv_ba", "BA", "Black Arrow", [[
if ready("BA") then return "BA" end
]]),
        R("sv_aimed", "AIMED", "Aimed Shot", [[
if ready("AIMED") then return "AIMED" end
]]),
        Steady("sv"),
    }, {
        Aspect("sv"),
        Cooldowns("sv"),
    })

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.HUN_BEAST_MASTERY_PVE.meta.requires = { "BW" }
Presets.HUN_MARKSMANSHIP_PVE.meta.requires = { "CHIMERA" }
Presets.HUN_SURVIVAL_PVE.meta.requires = { "ES" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    for _, key in ipairs({ "HUN_BEAST_MASTERY_PVE", "HUN_MARKSMANSHIP_PVE", "HUN_SURVIVAL_PVE" }) do
        RotaCore.Profiles:RegisterPreset(Presets[key])
        RotaCore.Profiles:RegisterPreset(Presets[key .. "_V1"])
    end
end

return Presets
