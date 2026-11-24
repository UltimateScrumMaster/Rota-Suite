-- RotaClass_ROG/Presets.lua — Rogue RotationIR Presets (WoW 3.3.5a)
-- Builds: Assassination (Mutilate), Combat, Subtlety (Hemorrhage / Dagger-Dance).
-- Las reglas legibles (v2) estan al final del archivo; cada preset conserva su lista v1 como <id>_v1.
-- Las variables se ajustan por build y por fase (valores base; calibrar con WoWSims segun el equipo de cada fase).
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Presets = {}

-- Racial segun raza (Orc: Blood Fury | Troll: Berserking | Blood Elf: Arcane Torrent | otras: Blood Fury)
local function RacialSpell()
    local race
    if _G.UnitRace then
        local _, r = _G.UnitRace("player")
        race = r
    end
    if race == "Troll" then
        return { name = "Berserking", defaultId = 26297, overrideId = nil, matchById = false }
    elseif race == "BloodElf" then
        return { name = "Arcane Torrent", defaultId = 25046, overrideId = nil, matchById = false }
    end
    return { name = "Blood Fury", defaultId = 20572, overrideId = nil, matchById = false }
end

local function CommonSpells()
    return {
        MUT       = { name = "Mutilate", defaultId = 48666, overrideId = nil, matchById = false },
        ENV       = { name = "Envenom", defaultId = 57993, overrideId = nil, matchById = false },
        SND       = { name = "Slice and Dice", defaultId = 6774, overrideId = nil, matchById = false },
        RUP       = { name = "Rupture", defaultId = 48672, overrideId = nil, matchById = false },
        EVIS      = { name = "Eviscerate", defaultId = 48668, overrideId = nil, matchById = false },
        SS        = { name = "Sinister Strike", defaultId = 48638, overrideId = nil, matchById = false },
        HEMO      = { name = "Hemorrhage", defaultId = 48660, overrideId = nil, matchById = false },
        BACKSTAB  = { name = "Backstab", defaultId = 48657, overrideId = nil, matchById = false },
        AMBUSH    = { name = "Ambush", defaultId = 48691, overrideId = nil, matchById = false },
        GARROTE   = { name = "Garrote", defaultId = 48676, overrideId = nil, matchById = false },
        HFB       = { name = "Hunger for Blood", defaultId = 51662, overrideId = nil, matchById = false },
        FOK       = { name = "Fan of Knives", defaultId = 51723, overrideId = nil, matchById = false },
        EXPOSE    = { name = "Expose Armor", defaultId = 26866, overrideId = nil, matchById = false },
        COLDBLOOD = { name = "Cold Blood", defaultId = 14177, overrideId = nil, matchById = false },
        VANISH    = { name = "Vanish", defaultId = 26889, overrideId = nil, matchById = false },
        KS        = { name = "Killing Spree", defaultId = 51690, overrideId = nil, matchById = false },
        AR        = { name = "Adrenaline Rush", defaultId = 13750, overrideId = nil, matchById = false },
        BF        = { name = "Blade Flurry", defaultId = 13877, overrideId = nil, matchById = false },
        SDANCE    = { name = "Shadow Dance", defaultId = 51713, overrideId = nil, matchById = false },
        SHADOWSTEP= { name = "Shadowstep", defaultId = 36554, overrideId = nil, matchById = false },
        PREMED    = { name = "Premeditation", defaultId = 14183, overrideId = nil, matchById = false },
        PREP      = { name = "Preparation", defaultId = 14185, overrideId = nil, matchById = false },
        GHOSTLY   = { name = "Ghostly Strike", defaultId = 14278, overrideId = nil, matchById = false },
        TRICKS    = { name = "Tricks of the Trade", defaultId = 57934, overrideId = nil, matchById = false },
        GLOVES    = { name = "Hyperspeed Acceleration", defaultId = 54758, overrideId = nil, matchById = false },
        SPEED_POT = { name = "Potion of Speed", defaultId = 40211, overrideId = nil, matchById = false },
        RACIAL    = RacialSpell(),
    }
end

-- 1. ASSASSINATION (Mutilate): HfB (con sangrado) > SnD (solo si cayo, Cut to the Chase)
-- > Expose Armor (sin Warrior) > Envenom 4-5 CP > Mutilate | AoE: Fan of Knives
Presets.ROG_ASSASSINATION_PVE = {
    meta = {
        id = "rog_assassination_pve",
        name = "Assassination Rogue PvE (Mutilate)",
        shortName = "[A]",
        class = "ROGUE",
        spec = "Assassination",
        buildType = "assassination_mutilate",
        schema = 1,
        interface = 30300,
    },
    spells = CommonSpells(),
    vars = {
        aoeTargets = 6,
        envenomMinCP = 4,
        sndMargin = 1.5,
        hfbMargin = 4,
        exposeArmor = 0,
        usePotion = 0,
        tricks = 0,
        phase = 1,
    },
    sequences = {},
    lists = {
        main = {
            {
                id = "rog_assassination_pve_main",
                enabled = true,
                type = "customLua",
                action = "MUT",
                note = "Assassination Rogue PvE (Mutilate): motor del modulo (nunca devuelve nil)",
                code = [[
                    if state.evaluateRogAssassination then
                        return state.evaluateRogAssassination(state)
                    end
                    local rog = _G.RotaClass_ROG
                    if rog and rog.Evaluate then
                        return rog.Evaluate.assassination(state)
                    end
                    return nil
                ]],
            },
        },
        off = {
            {
                id = "rog_assassination_pve_off",
                enabled = true,
                type = "customLua",
                action = "RACIAL",
                note = "Assassination Rogue PvE (Mutilate): cooldowns y utilidades fuera de GCD",
                code = [[
                    if state.evaluateRogAssassinationOff then
                        return state.evaluateRogAssassinationOff(state)
                    end
                    local rog = _G.RotaClass_ROG
                    if rog and rog.EvaluateAssassinationOff then
                        return rog.EvaluateAssassinationOff(state)
                    end
                    return nil
                ]],
            },
        },
    },
}

-- 2. COMBAT: Expose Armor (sin Warrior) > SnD > Rupture 5 CP > Eviscerate (CP extra / Blade Flurry)
-- > Sinister Strike | Cooldowns: Blade Flurry > Killing Spree > Adrenaline Rush | AoE: Fan of Knives
Presets.ROG_COMBAT_PVE = {
    meta = {
        id = "rog_combat_pve",
        name = "Combat Rogue PvE",
        shortName = "[C]",
        class = "ROGUE",
        spec = "Combat",
        buildType = "combat",
        schema = 1,
        interface = 30300,
    },
    spells = CommonSpells(),
    vars = {
        aoeTargets = 2,   -- Wowhead: Fan of Knives + Blade Flurry ya rinden con 2 objetivos
        sndMargin = 1.2,
        ruptureMargin = 1.5,
        bladeFlurryST = 1,
        exposeArmor = 0,
        usePotion = 0,
        phase = 1,
    },
    sequences = {},
    lists = {
        main = {
            {
                id = "rog_combat_pve_main",
                enabled = true,
                type = "customLua",
                action = "SS",
                note = "Combat Rogue PvE: motor del modulo (nunca devuelve nil)",
                code = [[
                    if state.evaluateRogCombat then
                        return state.evaluateRogCombat(state)
                    end
                    local rog = _G.RotaClass_ROG
                    if rog and rog.Evaluate then
                        return rog.Evaluate.combat(state)
                    end
                    return nil
                ]],
            },
        },
        off = {
            {
                id = "rog_combat_pve_off",
                enabled = true,
                type = "customLua",
                action = "RACIAL",
                note = "Combat Rogue PvE: cooldowns y utilidades fuera de GCD",
                code = [[
                    if state.evaluateRogCombatOff then
                        return state.evaluateRogCombatOff(state)
                    end
                    local rog = _G.RotaClass_ROG
                    if rog and rog.EvaluateCombatOff then
                        return rog.EvaluateCombatOff(state)
                    end
                    return nil
                ]],
            },
        },
    },
}

-- 3. SUBTLETY (Hemorrhage): Expose Armor > SnD > Rupture (con Shadowstep) > Eviscerate 4-5 CP
-- > Ghostly Strike > Hemorrhage | Shadow Dance: Garrote > Ambush > debuffs > Eviscerate
Presets.ROG_SUBTLETY_PVE = {
    meta = {
        id = "rog_subtlety_pve",
        name = "Subtlety Rogue PvE (Hemorrhage)",
        shortName = "[S]",
        class = "ROGUE",
        spec = "Subtlety",
        buildType = "subtlety_hemo",
        schema = 1,
        interface = 30300,
    },
    spells = CommonSpells(),
    vars = {
        aoeTargets = 6,
        sndMargin = 1.5,
        ruptureMargin = 2.0,
        sdMinEnergy = 60,
        dagger = 0,
        backstab = 0,
        exposeArmor = 0,
        phase = 1,
    },
    sequences = {},
    lists = {
        main = {
            {
                id = "rog_subtlety_pve_main",
                enabled = true,
                type = "customLua",
                action = "HEMO",
                note = "Subtlety Rogue PvE (Hemorrhage): motor del modulo (nunca devuelve nil)",
                code = [[
                    if state.evaluateRogSubtlety then
                        return state.evaluateRogSubtlety(state)
                    end
                    local rog = _G.RotaClass_ROG
                    if rog and rog.Evaluate then
                        return rog.Evaluate.subtlety(state)
                    end
                    return nil
                ]],
            },
        },
        off = {
            {
                id = "rog_subtlety_pve_off",
                enabled = true,
                type = "customLua",
                action = "RACIAL",
                note = "Subtlety Rogue PvE (Hemorrhage): cooldowns y utilidades fuera de GCD",
                code = [[
                    if state.evaluateRogSubtletyOff then
                        return state.evaluateRogSubtletyOff(state)
                    end
                    local rog = _G.RotaClass_ROG
                    if rog and rog.EvaluateSubtletyOff then
                        return rog.EvaluateSubtletyOff(state)
                    end
                    return nil
                ]],
            },
        },
    },
}

-- 4. SUBTLETY DAGGER (Shadow Dance + Ambush/Backstab): igual que Hemorrhage pero con daga: Ambush en Shadow Dance y Backstab como generador
Presets.ROG_SUBTLETY_DAGGER_PVE = {
    meta = {
        id = "rog_subtlety_dagger_pve",
        name = "Subtlety Rogue PvE (Dagger / Dance)",
        shortName = "[SD]",
        class = "ROGUE",
        spec = "Subtlety",
        buildType = "subtlety_dagger",
        schema = 1,
        interface = 30300,
    },
    spells = CommonSpells(),
    vars = {
        aoeTargets = 6,
        sndMargin = 1.5,
        ruptureMargin = 2.0,
        sdMinEnergy = 60,
        dagger = 1,
        backstab = 1,
        exposeArmor = 0,
        phase = 1,
    },
    sequences = {},
    lists = {
        main = {
            {
                id = "rog_subtlety_dagger_pve_main",
                enabled = true,
                type = "customLua",
                action = "HEMO",
                note = "Subtlety Rogue PvE (Dagger / Dance): motor del modulo (nunca devuelve nil)",
                code = [[
                    if state.evaluateRogSubtlety then
                        return state.evaluateRogSubtlety(state)
                    end
                    local rog = _G.RotaClass_ROG
                    if rog and rog.Evaluate then
                        return rog.Evaluate.subtlety(state)
                    end
                    return nil
                ]],
            },
        },
        off = {
            {
                id = "rog_subtlety_dagger_pve_off",
                enabled = true,
                type = "customLua",
                action = "RACIAL",
                note = "Subtlety Rogue PvE (Dagger / Dance): cooldowns y utilidades fuera de GCD",
                code = [[
                    if state.evaluateRogSubtletyOff then
                        return state.evaluateRogSubtletyOff(state)
                    end
                    local rog = _G.RotaClass_ROG
                    if rog and rog.EvaluateSubtletyOff then
                        return rog.EvaluateSubtletyOff(state)
                    end
                    return nil
                ]],
            },
        },
    },
}

-- Register presets with RotaCore
-- ============================================================================
-- Rotaciones en reglas legibles (v2). Las listas de arriba (gancho al modulo) quedan como la v1 (<id>_v1).
-- Datos del modulo en "rog": cp, energy, energyRegen, sndRemaining, ruptureRemaining, hfbRemaining,
-- bladeFlurryRemaining, arRemaining, ksRemaining, shadowDanceRemaining, garroteRemaining, coldBloodRemaining,
-- armorDebuffRemaining, hasBleed, cutToTheChase, dagger. show(alias) marca "esperando" si falta energia.
-- ============================================================================
local R = RotaCore.Rule

local function Migrate(p, main, off)
    local v1 = RotaCore.V1Of(p, p.lists)
    p.lists = { main = RotaCore.Flatten(main), off = RotaCore.Flatten(off) }
    return v1
end

local function FanOfKnives(prefix)
    return R(prefix .. "_aoe", "FOK", "AoE: Slice and Dice arriba, Fan of Knives", [[
if aoe() and known("FOK") then
    if rog.cp >= 1 and rog.sndRemaining <= var("sndMargin", 1.5) then return show("SND") end
    return show("FOK")
end
]])
end

local ASSASSINATION_MAIN = {
    FanOfKnives("ass"),
    R("ass_hfb", "HFB", "Hunger for Blood siempre arriba (necesita sangrado: si no hay, Rupture lo habilita)", [[
if known("HFB") and rog.hfbRemaining <= var("hfbMargin", 4) then
    if rog.hasBleed then return show("HFB") end
    if rog.cp >= 1 then return show("RUP") end
    return show("MUT")
end
]]),
    R("ass_snd", "SND", "Slice and Dice solo si se cayo (Cut to the Chase lo renueva con Envenom)", [[
if rog.cp >= 1 and rog.sndRemaining <= var("sndMargin", 1.5) then
    if not rog.cutToTheChase or rog.sndRemaining <= 0 then return show("SND") end
end
]]),
    R("ass_expose", "EXPOSE", "Expose Armor si no hay Warrior (var exposeArmor)", [[
if rog.cp >= 4 and needExpose() then return show("EXPOSE") end
]]),
    R("ass_env", "ENV", "Envenom con 4-5 CP (var envenomMinCP)", [[
if rog.cp >= var("envenomMinCP", 4) then return show("ENV") end
]]),
    R("ass_mut", "MUT", "Mutilate", [[
return show("MUT")
]]),
}
local ASSASSINATION_OFF = {
    R("ass_coldblood", "COLDBLOOD", "Cold Blood para el Envenom", [[
if combat() and rog.cp >= var("envenomMinCP", 4) and ready("COLDBLOOD") and rog.coldBloodRemaining <= 0 then
    return "COLDBLOOD"
end
]]),
    R("ass_burst", "GLOVES", "Guantes, racial y pocion (var usePotion)", [[
if combat() and burst() then
    if gloves() then return "GLOVES" end
    if ready("RACIAL") then return "RACIAL" end
    if var("usePotion", 0) == 1 and potion("SPEED_POT") then return "SPEED_POT" end
end
]]),
    R("ass_tricks", "TRICKS", "Tricks of the Trade (var tricks)", [[
if combat() and var("tricks", 0) == 1 and ready("TRICKS") then return "TRICKS" end
]]),
}

local COMBAT_MAIN = {
    R("com_aoe", "FOK", "AoE: Slice and Dice con cualquier CP, Fan of Knives", [[
if aoe() and known("FOK") then
    if rog.cp >= 1 and rog.sndRemaining <= var("sndMargin", 1.2) then return show("SND") end
    return show("FOK")
end
]]),
    R("com_expose", "EXPOSE", "Expose Armor si no hay Warrior (var exposeArmor)", [[
if rog.cp >= 4 and needExpose() then return show("EXPOSE") end
]]),
    R("com_snd", "SND", "Slice and Dice: por caer con los CP que haya; con 5 CP si le quedan 5 s", [[
if rog.cp >= 1 and rog.sndRemaining <= var("sndMargin", 1.2) then return show("SND") end
if rog.cp >= 5 and rog.sndRemaining <= 5 then return show("SND") end
]]),
    R("com_rup", "RUP", "Rupture (no con Blade Flurry activo)", [[
local cleave = rog.bladeFlurryRemaining > 0
if not cleave and known("RUP") then
    if rog.cp >= 5 and rog.ruptureRemaining <= var("ruptureMargin", 1.5) then return show("RUP") end
    if rog.cp >= 4 and rog.ruptureRemaining <= 0 and rog.energy < 45 then return show("RUP") end
end
]]),
    R("com_evis", "EVIS", "Eviscerate con CP sobrantes (o con Blade Flurry)", [[
if rog.cp >= 5 then
    if rog.bladeFlurryRemaining > 0 or (rog.sndRemaining > 6 and rog.ruptureRemaining > 6) then return show("EVIS") end
end
]]),
    R("com_ss", "SS", "Sinister Strike", [[
return show("SS")
]]),
}
local COMBAT_OFF = {
    R("com_cds", "BF", "Blade Flurry > Killing Spree > Adrenaline Rush; guantes, racial y pocion durante", [[
if not combat() or not burst() then return nil end
if ready("BF") and known("BF") and rog.bladeFlurryRemaining <= 0 and (aoe() or var("bladeFlurryST", 1) == 1) then
    return "BF"
end
if known("KS") and ready("KS") and rog.arRemaining <= 0 and rog.energy <= 50 then return "KS" end
if known("AR") and ready("AR") and rog.arRemaining <= 0 then
    if not known("KS") or cd("KS") >= 100 or rog.ksRemaining > 0 or rog.energy <= 40 then return "AR" end
end
if rog.arRemaining > 0 or rog.bladeFlurryRemaining > 0 then
    if gloves() then return "GLOVES" end
    if ready("RACIAL") then return "RACIAL" end
    if var("usePotion", 0) == 1 and potion("SPEED_POT") then return "SPEED_POT" end
end
]]),
}

local SUBTLETY_MAIN = {
    FanOfKnives("sub"),
    R("sub_dance", "AMBUSH", "Shadow Dance: Garrote > SnD > Rupture > Eviscerate 4+ CP > Ambush (daga) / Hemorrhage", [[
if rog.shadowDanceRemaining > 0 then
    if known("GARROTE") and rog.garroteRemaining <= 0 and not rog.hasBleed then return show("GARROTE") end
    if rog.cp >= 1 and rog.sndRemaining <= var("sndMargin", 1.5) then return show("SND") end
    if rog.cp >= 4 and rog.ruptureRemaining <= var("ruptureMargin", 2.0) then return show("RUP") end
    if rog.cp >= 4 then return show("EVIS") end
    if (var("dagger", 0) == 1 or rog.dagger) and known("AMBUSH") then return show("AMBUSH") end
    return show("HEMO")
end
]]),
    R("sub_expose", "EXPOSE", "Expose Armor si no hay Warrior (var exposeArmor)", [[
if rog.cp >= 4 and needExpose() then return show("EXPOSE") end
]]),
    R("sub_snd", "SND", "Slice and Dice", [[
if rog.cp >= 1 and rog.sndRemaining <= var("sndMargin", 1.5) then return show("SND") end
]]),
    R("sub_rup", "RUP", "Rupture con 4+ CP", [[
if rog.cp >= 4 and rog.ruptureRemaining <= var("ruptureMargin", 2.0) and known("RUP") then return show("RUP") end
]]),
    R("sub_evis", "EVIS", "Eviscerate con 4+ CP", [[
if rog.cp >= 4 then return show("EVIS") end
]]),
    R("sub_ghostly", "GHOSTLY", "Ghostly Strike", [[
if known("GHOSTLY") and ready("GHOSTLY") then return show("GHOSTLY") end
]]),
    R("sub_builder", "HEMO", "Backstab con daga (var backstab), si no Hemorrhage", [[
if (var("dagger", 0) == 1 or rog.dagger) and var("backstab", 0) == 1 and known("BACKSTAB") then return show("BACKSTAB") end
return show("HEMO")
]]),
}
local SUBTLETY_OFF = {
    R("sub_shadowstep", "SHADOWSTEP", "Shadowstep antes de cada Rupture", [[
if combat() and rog.cp >= 4 and rog.ruptureRemaining <= (var("ruptureMargin", 2.0) + 1.5)
    and known("SHADOWSTEP") and ready("SHADOWSTEP") then
    return "SHADOWSTEP"
end
]]),
    R("sub_dance_cds", "PREMED", "En Shadow Dance: Premeditation, guantes y racial", [[
if combat() and rog.shadowDanceRemaining > 0 then
    if known("PREMED") and ready("PREMED") and rog.cp <= 3 then return "PREMED" end
    if burst() then
        if gloves() then return "GLOVES" end
        if ready("RACIAL") then return "RACIAL" end
    end
    return nil
end
]]),
    R("sub_dance", "SDANCE", "Shadow Dance con energia (var sdMinEnergy); Preparation si Shadow Dance tiene 15+ s de CD", [[
if combat() and burst() and rog.shadowDanceRemaining <= 0 then
    if known("SDANCE") and ready("SDANCE") and rog.energy >= var("sdMinEnergy", 60) then return "SDANCE" end
    local sdCD = known("SDANCE") and cd("SDANCE") or 0
    if known("PREP") and ready("PREP") and sdCD >= 15 then return "PREP" end
end
]]),
}

Presets.ROG_ASSASSINATION_PVE_V1 = Migrate(Presets.ROG_ASSASSINATION_PVE, ASSASSINATION_MAIN, ASSASSINATION_OFF)
Presets.ROG_COMBAT_PVE_V1 = Migrate(Presets.ROG_COMBAT_PVE, COMBAT_MAIN, COMBAT_OFF)
Presets.ROG_SUBTLETY_PVE_V1 = Migrate(Presets.ROG_SUBTLETY_PVE, SUBTLETY_MAIN, SUBTLETY_OFF)
Presets.ROG_SUBTLETY_DAGGER_PVE_V1 = Migrate(Presets.ROG_SUBTLETY_DAGGER_PVE, SUBTLETY_MAIN, SUBTLETY_OFF)

-- Pre-pull (boton Pre-Pull, una vez): Tricks of the Trade (con el tanque de objetivo) y poción
for _, key in ipairs({ "ROG_ASSASSINATION_PVE", "ROG_COMBAT_PVE", "ROG_SUBTLETY_PVE", "ROG_SUBTLETY_DAGGER_PVE" }) do
    Presets[key].lists.prepull = {
        R("rog_pre_tricks", "TRICKS", "Tricks of the Trade sobre el tanque (var tricks)", [[
if var("tricks", 0) == 1 and ready("TRICKS") then return "TRICKS" end
]]),
        RotaCore.PrepullPotion("melee"),
    }
    Presets[key].meta.prepullLead = 2
    Presets[key].meta.prepullNote = "Poción justo antes del pull (y Tricks of the Trade al tanque si tildaste tricks)."
end

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.ROG_ASSASSINATION_PVE.meta.requires = { "MUT" }
Presets.ROG_COMBAT_PVE.meta.requires = { "BF", "AR" }
Presets.ROG_SUBTLETY_PVE.meta.requires = { "HEMO", "SDANCE" }
Presets.ROG_SUBTLETY_DAGGER_PVE.meta.requires = { "SDANCE" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    for _, key in ipairs({ "ROG_ASSASSINATION_PVE", "ROG_COMBAT_PVE", "ROG_SUBTLETY_PVE", "ROG_SUBTLETY_DAGGER_PVE" }) do
        RotaCore.Profiles:RegisterPreset(Presets[key])
        RotaCore.Profiles:RegisterPreset(Presets[key .. "_V1"])
    end
end

return Presets
