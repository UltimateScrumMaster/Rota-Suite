-- RotaClass_DRU/Presets.lua — Druid RotationIR Presets (WoW 3.3.5a)
-- Rotaciones en reglas legibles (v2). La v1 (gancho al evaluador del modulo) queda como <id>_v1.
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
    if race == "Tauren" then return S("War Stomp", 20549) end
    return S("Shadowmeld", 58984)
end

local function CommonSpells()
    return {
        WRATH = S("Wrath", 48461),              SF = S("Starfire", 48465),
        MF = S("Moonfire", 48463),              IS = S("Insect Swarm", 48468),
        FF = S("Faerie Fire", 770),             FFF = S("Faerie Fire (Feral)", 16857),
        STARFALL = S("Starfall", 53201),        FON = S("Force of Nature", 33831),
        HURRICANE = S("Hurricane", 48467),      MOONKIN = S("Moonkin Form", 24858),
        CAT = S("Cat Form", 768),               SR = S("Savage Roar", 52610),
        RIP = S("Rip", 49800),                  RAKE = S("Rake", 48574),
        MANGLE = S("Mangle (Cat)", 48566),      SHRED = S("Shred", 48572),
        SWIPE = S("Swipe (Cat)", 62078),        TF = S("Tiger's Fury", 50213),
        BERSERK = S("Berserk", 50334),
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

-- Datos del modulo en "dru": moonkin, cat, savageRoar, clearcasting, berserk, solar, lunar (segundos de cada buff),
-- lastEclipse ("lunar" / "solar"), insectSwarm, moonfire, faerieFire, rip, rake, mangle (segundos de cada debuff),
-- energy, cp (combo points), moving.

-- BALANCE (Wowhead)
local BALANCE_MAIN = {
    R("bal_form", "MOONKIN", "Moonkin Form", [[
if not dru.moonkin and known("MOONKIN") then return "MOONKIN" end
]]),
    R("bal_aoe", "STARFALL", "AoE: Starfall, si no Hurricane", [[
if aoe() then
    if ready("STARFALL") then return "STARFALL" end
    if known("HURRICANE") then return "HURRICANE" end
end
]]),
    R("bal_ff", "FF", "Faerie Fire", [[
if dru.faerieFire <= gcd() and known("FF") then return "FF" end
]]),
    R("bal_moving", "MF", "En movimiento: Insect Swarm / Moonfire", [[
if dru.moving then
    if dru.insectSwarm <= gcd() and known("IS") then return "IS" end
    if dru.moonfire <= gcd() and known("MF") then return "MF" end
end
]]),
    R("bal_is", "IS", "Insect Swarm (no en los ultimos 5 s de Eclipse Lunar)", [[
if dru.insectSwarm <= gcd() and not (dru.lunar > 0 and dru.lunar < 5) and known("IS") then return "IS" end
]]),
    R("bal_cds", "FON", "Fuera de Eclipse: Force of Nature y Starfall (Burst)", [[
if burst() and combat() and dru.lunar <= 0 and dru.solar <= 0 then
    if ready("FON") then return "FON" end
    if ready("STARFALL") then return "STARFALL" end
end
]]),
    R("bal_eclipse", "SF", "Eclipse Lunar: Starfire / Solar: Wrath / sin Eclipse: el del ultimo Eclipse", [[
if dru.lunar > 0 then return "SF" end
if dru.solar > 0 then return "WRATH" end
if dru.lastEclipse == "lunar" then return "SF" end
return "WRATH"
]]),
}
local BALANCE_OFF = {
    R("bal_lunar_cds", "GLOVES", "Guantes y racial al empezar un Eclipse Lunar", [[
if burst() and combat() and dru.lunar > 10 then
    if gloves() then return "GLOVES" end
    if ready("RACIAL") then return "RACIAL" end
end
]]),
}

-- FERAL (Wowhead). Los sangrados no se renuevan antes de que caigan. catCost / poolFor / shredLeavesFor son del
-- modulo: costo de energia (mitad con Berserk), esperar energia mostrando la habilidad, y si despues de un Shred
-- alcanza la energia para renovar algo a tiempo (10 de energia por segundo).
local FERAL_MAIN = {
    R("fer_cat", "CAT", "Cat Form", [[
if not dru.cat and known("CAT") then return "CAT" end
]]),
    R("fer_sr", "SR", "Savage Roar caido (1+ CP)", [[
if dru.cp >= 1 and dru.savageRoar <= gcd() and known("SR") then say("Savage Roar caido"); return poolFor("SR") end
]]),
    R("fer_aoe", "SWIPE", "AoE: Rake sin CP (var aoeRake), si no Swipe (Cat)", [[
if aoe() then
    if dru.cp == 0 and var("aoeRake", 1) == 1 and dru.rake <= gcd() and known("RAKE") then
        say("Rake: 1 CP para Savage Roar")
        return poolFor("RAKE")
    end
    if known("SWIPE") then
        if dru.clearcasting > gcd() then return "SWIPE" end
        return poolFor("SWIPE")
    end
end
]]),
    R("fer_cc", "SHRED", "Clearcasting: Shred gratis", [[
if dru.clearcasting > gcd() and known("SHRED") then say("Clearcasting: Shred gratis"); return "SHRED" end
]]),
    R("fer_rip", "RIP", "Rip con 5 CP, cuando se cayo", [[
if dru.cp >= 5 and dru.rip <= gcd() and known("RIP") then say("5 CP y Rip caido"); return poolFor("RIP") end
]]),
    R("fer_rake", "RAKE", "Rake caido", [[
if dru.rake <= gcd() and known("RAKE") then say("Rake caido"); return poolFor("RAKE") end
]]),
    R("fer_mangle", "MANGLE", "Mangle caido", [[
if dru.mangle <= gcd() and known("MANGLE") then say("Mangle caido"); return poolFor("MANGLE") end
]]),
    R("fer_ff", "FFF", "Faerie Fire (Feral) si el objetivo no tiene Faerie Fire (var maintainFF)", [[
if var("maintainFF", 1) == 1 and dru.faerieFire <= gcd() and ready("FFF") then
    say("Objetivo sin Faerie Fire")
    return "FFF"
end
]]),
    R("fer_shred", "SHRED", "Shred si despues alcanza para renovar todo a tiempo; si no, esperar lo que se cae", [[
local poolAlias, poolRem = nil, 999
if dru.cp >= 1 and known("SR") and not shredLeavesFor(dru.savageRoar, "SR") then
    poolAlias, poolRem = "SR", dru.savageRoar
end
if dru.cp >= 5 and dru.rip < poolRem and known("RIP") and not shredLeavesFor(dru.rip, "RIP") then
    poolAlias, poolRem = "RIP", dru.rip
end
if dru.rake < poolRem and known("RAKE") and not shredLeavesFor(dru.rake, "RAKE") then
    poolAlias, poolRem = "RAKE", dru.rake
end
if dru.mangle < poolRem and known("MANGLE") and not shredLeavesFor(dru.mangle, "MANGLE") then
    poolAlias, poolRem = "MANGLE", dru.mangle
end
-- Rebuffed: con Glyph of Omen of Clarity, Faerie Fire (Feral) da Clearcasting: se usa en vez de esperar
if (poolAlias or dru.energy < catCost("SHRED")) and glyphOn("omen") and ready("FFF") then
    say("Glyph of Omen of Clarity: Faerie Fire da Clearcasting")
    return "FFF"
end
if poolAlias then
    say("Juntando energia: se cae pronto")
    return wait(poolAlias, poolRem - gcd())
end
return poolFor("SHRED")
]]),
}
local FERAL_OFF = {
    R("fer_tf", "TF", "Tiger's Fury con menos de 40 de energia (no durante Berserk)", [[
if combat() and dru.cat and dru.energy < 40 and dru.berserk <= 0 and ready("TF") then return "TF" end
]]),
    R("fer_burst", "BERSERK", "Berserk con Tiger's Fury en CD 15+ s; guantes y racial", [[
if combat() and dru.cat and burst() then
    if cd("TF") >= 15 and ready("BERSERK") then return "BERSERK" end
    if gloves() then return "GLOVES" end
    if ready("RACIAL") then return "RACIAL" end
end
]]),
}

-- Balance: Moonkin > Faerie Fire > Insect Swarm > Force of Nature / Starfall > Starfire (Lunar) / Wrath (Solar)
Presets.DRU_BALANCE_PVE = {
    meta = {
        id = "dru_balance_pve",
        name = "Balance Druid PvE",
        shortName = "[BAL]",
        class = "DRUID",
        spec = "Balance",
        buildType = "balance",
        schema = 1,
        interface = 30300,
    },
    spells = CommonSpells(),
    vars = {
        aoeTargets = 4,
    },
    lists = {
        main = BALANCE_MAIN,
        off = BALANCE_OFF,
    },
}

-- Feral: Savage Roar > Shred (Clearcasting) > Faerie Fire (Feral) > Rip > Rake > Mangle > Shred
Presets.DRU_FERAL_PVE = {
    meta = {
        id = "dru_feral_pve",
        name = "Feral Druid PvE (Cat)",
        shortName = "[FER]",
        class = "DRUID",
        spec = "Feral",
        buildType = "feral",
        schema = 1,
        interface = 30300,
    },
    spells = CommonSpells(),
    vars = {
        aoeTargets = 3,
        aoeRake = 1,       -- 1: en AoE, Rake para tener 1 CP de Savage Roar
        maintainFF = 1,    -- 1: poner Faerie Fire (Feral) si el objetivo no tiene Faerie Fire; 0: otro lo pone
    },
    lists = {
        main = FERAL_MAIN,
        off = FERAL_OFF,
    },
}

-- Glifos que cambian un poco la rotacion (toggles en Opciones > Rotacion)
Presets.DRU_FERAL_PVE.glyphs = {
    omen = { name = "Glyph of Omen of Clarity", spell = 16864,
        desc = "Cambio del servidor: Faerie Fire (Feral) da Clearcasting en cada golpe; se usa en vez de esperar energía." },
}

-- Pre-pull (boton Pre-Pull, una vez)
Presets.DRU_BALANCE_PVE.lists.prepull = {
    RotaCore.PrepullPotion("caster"),
    R("bal_pre_wrath", "WRATH", "Wrath precasteado", [[
if known("WRATH") then return "WRATH" end
]]),
}
Presets.DRU_BALANCE_PVE.meta.prepullLead = 3
Presets.DRU_BALANCE_PVE.meta.prepullNote = "Poción y Wrath unos 3 s antes."
Presets.DRU_FERAL_PVE.lists.prepull = { RotaCore.PrepullPotion("melee") }
Presets.DRU_FERAL_PVE.meta.prepullLead = 2
Presets.DRU_FERAL_PVE.meta.prepullNote = "Poción justo antes del pull."

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.DRU_BALANCE_PVE.meta.requires = { "MOONKIN", "STARFALL" }
Presets.DRU_FERAL_PVE.meta.requires = { "MANGLE", "BERSERK" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    RotaCore.Profiles:RegisterPreset(Presets.DRU_BALANCE_PVE)
    RotaCore.Profiles:RegisterPreset(Presets.DRU_FERAL_PVE)
    RotaCore.Profiles:RegisterPreset(RotaCore.V1Of(Presets.DRU_BALANCE_PVE, {
        main = { Hook("dru_balance_main", "WRATH", "Balance Druid: prioridad principal", "evaluateDruBalance") },
        off = { Hook("dru_balance_off", "RACIAL", "Balance Druid: cooldowns", "evaluateDruBalanceOff") },
    }))
    RotaCore.Profiles:RegisterPreset(RotaCore.V1Of(Presets.DRU_FERAL_PVE, {
        main = { Hook("dru_feral_main", "SHRED", "Feral Druid: prioridad principal", "evaluateDruFeral") },
        off = { Hook("dru_feral_off", "TF", "Feral Druid: Tiger's Fury, Berserk y cooldowns", "evaluateDruFeralOff") },
    }))
end

return Presets
