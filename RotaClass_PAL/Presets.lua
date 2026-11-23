-- RotaClass_PAL/Presets.lua — Retribution Paladin RotationIR Presets (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Presets = {}

-- Retribution (Wowhead WotLK). Cada regla es un paso de la prioridad, de arriba hacia abajo:
-- la primera que devuelve una habilidad gana. Funciones disponibles: ready, cd, buff, debuff, mana, aoe,
-- burst, combat, targetHP, targetType, gloves, wait, soonest, say, known + judgement() del Paladin + datos en "pal".
Presets.PAL_RETRIBUTION_PVE = {
    meta = {
        id = "pal_retribution_pve",
        name = "Retribution Paladin PvE",
        class = "PALADIN",
        spec = "Retribution",
        schema = 1,
        interface = 30300,
    },
    spells = {
        SOV       = { name = "Seal of Vengeance",         defaultId = 31801, overrideId = nil, matchById = false },
        SOC       = { name = "Seal of Corruption",        defaultId = 53736, overrideId = nil, matchById = false },
        COMMAND   = { name = "Seal of Command",           defaultId = 20375, overrideId = nil, matchById = false },
        SOR       = { name = "Seal of Righteousness",     defaultId = 21084, overrideId = nil, matchById = false },
        HOW       = { name = "Hammer of Wrath",           defaultId = 48806, overrideId = nil, matchById = false },
        JUDGEMENT = { name = "Judgement of Wisdom",       defaultId = 53408, overrideId = nil, matchById = false },
        JOW       = { name = "Judgement of Wisdom",       defaultId = 53408, overrideId = nil, matchById = false },
        JOL       = { name = "Judgement of Light",        defaultId = 20271, overrideId = nil, matchById = false },
        JOJ       = { name = "Judgement of Justice",      defaultId = 53407, overrideId = nil, matchById = false },
        HOR       = { name = "Hand of Reckoning",         defaultId = 62124, overrideId = nil, matchById = false },
        CS        = { name = "Crusader Strike",           defaultId = 35395, overrideId = nil, matchById = false },
        DS        = { name = "Divine Storm",              defaultId = 53385, overrideId = nil, matchById = false },
        CONS      = { name = "Consecration",              defaultId = 48819, overrideId = nil, matchById = false },
        HW        = { name = "Holy Wrath",                defaultId = 48817, overrideId = nil, matchById = false },
        EXO       = { name = "Exorcism",                  defaultId = 48801, overrideId = nil, matchById = false },
        AW        = { name = "Avenging Wrath",            defaultId = 31884, overrideId = nil, matchById = false },
        DP        = { name = "Divine Plea",               defaultId = 54428, overrideId = nil, matchById = false },
        GLOVES    = { name = "Hyperspeed Acceleration",   defaultId = 54758, overrideId = nil, matchById = false },
        RACIAL    = { name = "Blood Fury",                defaultId = 20572, overrideId = nil, matchById = false },
    },
    vars = {},
    lists = {
        main = {
            {
                id = "ret_aoe_cons",
                enabled = true,
                type = "customLua",
                action = "CONS",
                note = "AoE: Consecration con mana >= 40%",
                code = [[
if aoe() and ready("CONS") and mana() >= 40 then return "CONS" end
]],
            },
            {
                id = "ret_aoe_ds",
                enabled = true,
                type = "customLua",
                action = "DS",
                note = "AoE: Divine Storm",
                code = [[
if aoe() and ready("DS") then return "DS" end
]],
            },
            {
                id = "ret_aoe_judgement",
                enabled = true,
                type = "customLua",
                action = "JUDGEMENT",
                note = "AoE: Judgement",
                code = [[
if aoe() then
    local j = judgement()
    if j then return j end
end
]],
            },
            {
                id = "ret_aoe_hw",
                enabled = true,
                type = "customLua",
                action = "HW",
                note = "AoE: Holy Wrath contra no-muertos / demonios",
                code = [[
local t = targetType()
if aoe() and (t == "Undead" or t == "Demon") and ready("HW") then return "HW" end
]],
            },
            {
                id = "ret_cs",
                enabled = true,
                type = "customLua",
                action = "CS",
                note = "Crusader Strike",
                code = [[
if ready("CS") then return "CS" end
]],
            },
            {
                id = "ret_judgement",
                enabled = true,
                type = "customLua",
                action = "JUDGEMENT",
                note = "Judgement",
                code = [[
local j = judgement()
if j then return j end
]],
            },
            {
                id = "ret_how",
                enabled = true,
                type = "customLua",
                action = "HOW",
                note = "Hammer of Wrath con el objetivo debajo de 20%",
                code = [[
if pal.canHammerOfWrath and ready("HOW") then return "HOW" end
]],
            },
            {
                id = "ret_ds",
                enabled = true,
                type = "customLua",
                action = "DS",
                note = "Divine Storm",
                code = [[
if ready("DS") then return "DS" end
]],
            },
            {
                id = "ret_cons",
                enabled = true,
                type = "customLua",
                action = "CONS",
                note = "Consecration con mana >= 40%",
                code = [[
if ready("CONS") and mana() >= 40 then return "CONS" end
]],
            },
            {
                id = "ret_exo",
                enabled = true,
                type = "customLua",
                action = "EXO",
                note = "Exorcism solo con The Art of War",
                code = [[
if pal.hasArtOfWar and ready("EXO") then return "EXO" end
]],
            },
            {
                id = "ret_hw",
                enabled = true,
                type = "customLua",
                action = "HW",
                note = "Holy Wrath contra no-muertos / demonios",
                code = [[
local t = targetType()
if (t == "Undead" or t == "Demon") and ready("HW") then return "HW" end
]],
            },
            {
                id = "ret_plea",
                enabled = true,
                type = "customLua",
                action = "DP",
                note = "Divine Plea con mana < 25%",
                code = [[
if mana() < 25 and not pal.hasDivinePlea and ready("DP") then return "DP" end
]],
            },
            {
                id = "ret_wait",
                enabled = true,
                type = "customLua",
                action = "CS",
                note = "Nada listo: esperar CS o DS, el que vuelva antes",
                code = [[
local a = soonest("CS", "DS")
if a then return wait(a, cd(a)) end
]],
            },
        },
        off = {
            {
                id = "ret_seal_aoe",
                enabled = true,
                type = "customLua",
                action = "COMMAND",
                note = "AoE: Seal of Command",
                code = [[
if aoe() and known("COMMAND") and buff("Seal of Command") == 0 then return "COMMAND" end
]],
            },
            {
                id = "ret_seal_st",
                enabled = true,
                type = "customLua",
                action = "SOV",
                note = "Single target: Seal of Vengeance / Corruption / Righteousness",
                code = [[
if not aoe() then
    if known("SOV") then
        if buff("Seal of Vengeance") == 0 then return "SOV" end
    elseif known("SOC") then
        if buff("Seal of Corruption") == 0 then return "SOC" end
    elseif known("SOR") and buff("Seal of Righteousness") == 0 then
        return "SOR"
    end
end
]],
            },
            {
                id = "ret_aw",
                enabled = true,
                type = "customLua",
                action = "AW",
                note = "Avenging Wrath (Burst)",
                code = [[
if burst() and combat() and ready("AW") and not pal.hasAvengingWrath then return "AW" end
]],
            },
            {
                id = "ret_gloves",
                enabled = true,
                type = "customLua",
                action = "GLOVES",
                note = "Guantes de ingeniero (Burst)",
                code = [[
if burst() and combat() and gloves() then return "GLOVES" end
]],
            },
            {
                id = "ret_racial",
                enabled = true,
                type = "customLua",
                action = "RACIAL",
                note = "Racial (Burst)",
                code = [[
if burst() and combat() and ready("RACIAL") then return "RACIAL" end
]],
            },
        },
    },
}

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.PAL_RETRIBUTION_PVE.meta.requires = { "CS", "DS" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    RotaCore.Profiles:RegisterPreset(Presets.PAL_RETRIBUTION_PVE)
end

return Presets
