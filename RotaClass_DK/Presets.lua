-- RotaClass_DK/Presets.lua — Frost, Unholy 2H & Unholy Morb DK Presets (WoWSims 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Presets = {}

-- Common Spell Catalog for Death Knight Presets
local DK_COMMON_SPELLS = {
    IT          = { name = "Icy Touch",               defaultId = 49909, overrideId = nil, matchById = false },
    PS          = { name = "Plague Strike",           defaultId = 49921, overrideId = nil, matchById = false },
    BS          = { name = "Blood Strike",            defaultId = 49930, overrideId = nil, matchById = false },
    BB          = { name = "Blood Boil",              defaultId = 49941, overrideId = nil, matchById = false },
    SS          = { name = "Scourge Strike",          defaultId = 55271, overrideId = nil, matchById = false },
    DC          = { name = "Death Coil",              defaultId = 49895, overrideId = nil, matchById = false },
    DND         = { name = "Death and Decay",         defaultId = 49938, overrideId = nil, matchById = false },
    GF          = { name = "Ghoul Frenzy",            defaultId = 63560, overrideId = nil, matchById = false },
    GARG        = { name = "Summon Gargoyle",         defaultId = 49206, overrideId = nil, matchById = false },
    AOTD        = { name = "Army of the Dead",        defaultId = 49208, overrideId = nil, matchById = false },
    ERW         = { name = "Empower Rune Weapon",     defaultId = 47568, overrideId = nil, matchById = false },
    PEST        = { name = "Pestilence",              defaultId = 50842, overrideId = nil, matchById = false },
    HOW         = { name = "Horn of Winter",          defaultId = 57623, overrideId = nil, matchById = false },
    BT          = { name = "Blood Tap",               defaultId = 45529, overrideId = nil, matchById = false },
    OB          = { name = "Obliterate",              defaultId = 51425, overrideId = nil, matchById = false },
    FS          = { name = "Frost Strike",            defaultId = 55268, overrideId = nil, matchById = false },
    HB          = { name = "Howling Blast",           defaultId = 51411, overrideId = nil, matchById = false },
    UA          = { name = "Unbreakable Armor",       defaultId = 51271, overrideId = nil, matchById = false },
    RD          = { name = "Raise Dead",              defaultId = 46584, overrideId = nil, matchById = false },
    BP          = { name = "Blood Presence",          defaultId = 48266, overrideId = nil, matchById = false },
    UP          = { name = "Unholy Presence",         defaultId = 48265, overrideId = nil, matchById = false },
    HYPER       = { name = "Hyperspeed Acceleration", defaultId = 54758, overrideId = nil, matchById = false },
    GLOVES      = { name = "Hyperspeed Acceleration", defaultId = 54758, overrideId = nil, matchById = false },
    BF          = { name = "Blood Fury",              defaultId = 20572, overrideId = nil, matchById = false },
    RACIAL      = { name = "Blood Fury",              defaultId = 20572, overrideId = nil, matchById = false },
    BERSERKING  = { name = "Berserking",              defaultId = 26297, overrideId = nil, matchById = false },
    STONEFORM   = { name = "Stoneform",               defaultId = 20594, overrideId = nil, matchById = false },
    SPEED_POT   = { name = "Potion of Speed",         defaultId = 40211, overrideId = nil, matchById = false },
    OBL         = { name = "Obliterate",              defaultId = 51425, overrideId = nil, matchById = false },
    DD          = { name = "Death and Decay",         defaultId = 49938, overrideId = nil, matchById = false },
    BSH         = { name = "Bone Shield",             defaultId = 49222, overrideId = nil, matchById = false },
}

-- 1. FROST DK PVE PRESET (traducido 1:1 desde el perfil DSL dk_frost_pve)
Presets.DK_FROST_PVE = {
    meta = {
        id = "dk_frost_pve",
        name = "DK Frost PvE",
        shortName = "[F]",
        class = "DEATHKNIGHT",
        spec = "Frost",
        buildType = "frost",
        schema = 1,
        interface = 30300,
    },
    spells = DK_COMMON_SPELLS,
    vars = {
        pestMargin = 1.5,
        pestFillerMargin = 6.0,
        rpDumpMin = 115,
        aoeTargets = 3,
    },
    sequences = {
        -- Opener: DESACTIVADO por defecto (enabled=false)
        opener = {
            enabled = false,
            resetOnCombatEnd = true,
            timeout = 8,
            steps = {
                "IT", "PS", "BT", "UA", "HYPER", "BF", "BERSERKING", "STONEFORM",
                "OB", "FS", "PEST", "ERW", "OB", "FS", "OB", "OB", "RD"
            },
        },
    },
    lists = {
        main = {
            -- Frost DK Priority (WeakAura v4.6 + Wowhead 3.3.5a)
            {
                id = "frost_wowhead_master",
                enabled = true,
                type = "customLua",
                action = "OBL",
                note = "Frost DK Priority (WeakAura v4.6 + Wowhead 3.3.5a)",
                code = [[
                    if state.evaluateFrost then
                        local r = state.evaluateFrost(state)
                        -- Blood Tap es fuera de GCD: nunca debe quedarse como accion principal
                        if r == "BT" then
                            state.suggestedOff = "BT"
                            r = nil
                        end
                        return r
                    end
                    return nil
                ]]
            },
        },
        off = {
            -- Blood Tap for urgent Pestilence refresh
            {
                id = "frost_off_bt_urgent_pest",
                enabled = true,
                isBurst = false,
                type = "customLua",
                action = "BT",
                note = "Blood Tap for urgent Pestilence refresh (solo si esta listo y hace falta)",
                code = [[
                    -- Nunca sugerir Blood Tap fuera de combate ni si esta en cooldown
                    if state.inCombat ~= true or state.spellReady("BT") ~= true then
                        state.suggestedOff = nil
                        return nil
                    end
                    -- Ya hay runa Death lista o Blood Tap ya activo: no hace falta
                    if state.runes.deathReady >= 1 or (state.dk and (state.dk.bloodTapRemaining or 0) > 0) then
                        state.suggestedOff = nil
                        return nil
                    end
                    if state.suggestedOff == "BT" then
                        state.suggestedOff = nil
                        if state.runes.bloodReady == 0 then
                            return "BT"
                        end
                        return nil
                    end
                    local dk = state.dk
                    local m = (dk.hasFrostFever and dk.hasBloodPlague) and math.min(dk.ffRemaining or 0, dk.bpRemaining or 0) or 0
                    if dk.hasFrostFever and dk.hasBloodPlague and m <= 3.5 then
                        if state.runes.bloodReady == 0 and state.runes.deathReady == 0 then
                            local btCD = state.spellCooldown("BT") or 0
                            if btCD <= 0 then
                                local minCD = 999
                                for s = 1, 6 do
                                    local sData = state.runes.slots[s]
                                    if sData and (sData.type == 1 or sData.type == 4) then
                                        if sData.cdRemains < minCD then minCD = sData.cdRemains end
                                    end
                                end
                                if minCD > (m - 0.5) then
                                    return "BT"
                                end
                            end
                        end
                    end
                    return nil
                ]]
            },
            -- Unbreakable Armor off-GCD (BURST)
            {
                id = "frost_off_ua",
                enabled = true,
                isBurst = true,
                type = "block",
                action = "UA",
                note = "Unbreakable Armor off-GCD (Burst)",
                when = {
                    op = "and",
                    l = { op = "cmp", cmp = "==", l = { op = "state", path = "inCombat" }, r = { op = "val", val = true } },
                    r = { op = "cmp", cmp = "==", l = { op = "call", fn = "spell.ready", args = { "UA" } },
                        r = { op = "val", val = true } }
                }
            },
            -- Empower Rune Weapon (BURST: when all runes on CD)
            {
                id = "frost_off_erw",
                enabled = true,
                isBurst = true,
                type = "block",
                action = "ERW",
                note = "Empower Rune Weapon when runes are empty (Burst)",
                when = {
                    op = "and",
                    l = { op = "cmp", cmp = "==", l = { op = "state", path = "inCombat" }, r = { op = "val", val = true } },
                    r = {
                        op = "and",
                        l = { op = "cmp", cmp = "==", l = { op = "call", fn = "spell.ready", args = { "ERW" } },
                            r = { op = "val", val = true } },
                        r = {
                            op = "and",
                            l = { op = "cmp", cmp = "==", l = { op = "state", path = "runes.frostReady" },
                                r = { op = "val", val = 0 } },
                            r = { op = "cmp", cmp = "==", l = { op = "state", path = "runes.unholyReady" },
                                r = { op = "val", val = 0 } }
                        }
                    }
                }
            },
            -- Hyperspeed Acceleration engineering gloves (BURST)
            {
                id = "frost_off_burst_items",
                enabled = true,
                isBurst = true,
                type = "customLua",
                action = "HYPER",
                note = "Hyperspeed Acceleration engineering gloves (Burst)",
                code = [[
                    if state.inCombat and state.burstMode ~= false and state.areGlovesReady(state.now) then
                        return "HYPER"
                    end
                    return nil
                ]]
            }
        }
    }
}

-- 2. UNHOLY MORB DK PVE PRESET (WoWSims 1UM, 2UM)
Presets.DK_UNHOLY_MORB_PVE = {
    meta = {
        id = "dk_unholy_morb_pve",
        name = "DK UH Morb (DW) PvE",
        shortName = "[UM]",
        class = "DEATHKNIGHT",
        spec = "Unholy",
        buildType = "unholy_morb",
        schema = 1,
        interface = 30300,
    },
    spells = DK_COMMON_SPELLS,
    vars = {
        aoeTargets = 3,
        gargBackToBP = 1,   -- 1: volver a Blood Presence cuando la Gargola desaparece; 0: quedarse en UP
        armyOfTheDead = 1,  -- 1: Army of the Dead despues de ERW con la Gargola viva (solo jefes); 0: nunca
        rpDumpMin = 80,
    },
    sequences = {
        -- Opener desactivado por defecto (sin Scourge Strike en la build Morb)
        opener = {
            enabled = false,
            resetOnCombatEnd = true,
            timeout = 8,
            steps = { "IT", "PS", "DND", "BS" },
        },
    },
    lists = {
        main = {
            -- Unholy Morb: Ghoul Frenzy / Desolation / enfermedades / DnD protegido / Blood Tap inteligente (ConRO Morb v7)
            {
                id = "uh_master",
                enabled = true,
                type = "customLua",
                action = "DND",
                note = "UH Morb (DW): GF + Desolation + Dots + DnD protegido (ConRO Morb v7)",
                code = [[
                    if state.evaluateUnholyMorb then
                        return state.evaluateUnholyMorb(state)
                    end
                    return nil
                ]]
            },
        },
        off = {
            -- Gargoyle con snapshot (UP -> racial -> GARG -> BP), Blood Tap, haste/ERW
            {
                id = "uh_off_master",
                enabled = true,
                isBurst = false,
                type = "customLua",
                action = "GARG",
                note = "Gargoyle en UP (BP al desaparecer), Blood Tap inteligente, haste/ERW",
                code = [[
                    if state.evaluateUnholyOff then
                        return state.evaluateUnholyOff(state)
                    end
                    return nil
                ]]
            }
        }
    }
}

-- 3. UNHOLY 2H DK PVE PRESET (WoWSims 1U, 2U)
Presets.DK_UNHOLY_PVE = {
    meta = {
        id = "dk_unholy_2h_pve",
        name = "DK UH PvE",
        shortName = "[U]",
        class = "DEATHKNIGHT",
        spec = "Unholy",
        buildType = "unholy_2h",
        schema = 1,
        interface = 30300,
    },
    spells = DK_COMMON_SPELLS,
    vars = {
        armyOfTheDead = 1,  -- 1: Army of the Dead despues de ERW con la Gargola viva (solo jefes); 0: nunca
        pestMargin = 3.0,
        rpDumpMin = 80,
        desolationMargin = 3.0,
        aoeTargets = 3,
    },
    sequences = {
        opener = {
            enabled = false,
            resetOnCombatEnd = true,
            timeout = 12,
            steps = { "IT", "PS", "BS", "SS", "BS", "DC" },
        },
    },
    lists = {
        main = {
            -- Master Unholy 2H Wowhead 3.3.5a Evaluator
            {
                id = "unholy_2h_wowhead_master",
                enabled = true,
                type = "customLua",
                action = "SS",
                note = "UH Priority (Warcraft Tavern 3.3.5a)",
                code = [[
                    if state.evaluateUnholy2H then
                        return state.evaluateUnholy2H(state)
                    elseif state.evaluateUnholySS then
                        return state.evaluateUnholySS(state)
                    end
                    return nil
                ]]
            },
        },
        off = {
            -- Blood Tap off-GCD (strictly NOT affected by Burst toggle)
            {
                id = "u2h_off_bt",
                enabled = true,
                isBurst = false,
                type = "customLua",
                action = "BT",
                note = "Blood Tap off-GCD for Desolation or Ghoul Frenzy",
                code = [[
                    local btCD = state.spellCooldown("BT") or 0
                    if btCD > 0 then return nil end
                    local gcdRem = state.gcdRemains or 0
                    local dk = state.dk

                    if state.suggestedOff == "BT" then
                        state.suggestedOff = nil
                        return "BT"
                    end

                    -- 1. Desolation recovery when Blood runes on CD
                    if not dk.hasDesolation and state.runes.bloodReady == 0 and state.runes.deathReady == 0 then
                        return "BT"
                    end

                    -- 2. Ghoul Frenzy emergency trigger via BT
                    if dk.petAlive and dk.knowsGF and (dk.gfCD <= gcdRem) and ((dk.gfRemaining - gcdRem) <= 4.0) then
                        local u1 = state.runes and state.runes.slots and state.runes.slots[3]
                        local u2 = state.runes and state.runes.slots and state.runes.slots[4]
                        local bothUnholySlow = (u1 and u1.cdRemains > 3.5) and (u2 and u2.cdRemains > 3.5)
                        if bothUnholySlow and ((dk.desolationRemaining - gcdRem) > 8.0) then
                            return "BT"
                        end
                    end

                    return nil
                ]]
            },
            -- Unholy Burst Module: Snapshot Gargoyle (UP -> Racial -> Garg), Haste (Gloves/Berserk/Pot) + ERW post-garg, BP restore
            {
                id = "u2h_burst_module",
                enabled = true,
                isBurst = true,
                type = "customLua",
                action = "GARG",
                note = "Unholy Burst: UP -> Racial -> Gargoyle, haste + ERW con Gargoyle activa, BP al desaparecer",
                code = [[
                    local now = state.now
                    local gargKnown = (not state.hasSpell) or state.hasSpell("GARG")
                    if not gargKnown then return nil end
                    local gargCD = state.spellCooldown("GARG") or 0
                    local burstOn = state.burstMode ~= false

                    -- La Gargola toma la haste en cada golpe: UP antes de invocarla y mientras vive, BP al desaparecer
                    local hasUP = state.hasBuff("Unholy Presence", "player") or (state.buffRemaining("Unholy Presence", "player") > 0)
                    -- 1. Gargoyle listo (rp >= 60, Desolation activa): entrar en UP -> racial -> GARG
                    if burstOn and gargCD <= 0 and state.power >= 60 and state.dk.hasDesolation then
                        if not hasUP then
                            if state.canCastRunes(0, 0, 1) then
                                return "UP"
                            end
                            return nil
                        end
                        if state.spellReady("BF") then
                            return "BF"
                        elseif state.spellReady("RACIAL") then
                            return "RACIAL"
                        end
                        return "GARG"
                    end

                    -- 2. Gargoyle ya desaparecio (CD <= 150): volver a Blood Presence
                    if gargCD > 0 and gargCD <= 150 and hasUP then
                        if state.canCastRunes(1, 0, 0) then
                            return "BP"
                        end
                        if (state.spellCooldown("BT") or 0) <= 0 then
                            return "BT"
                        end
                    end

                    -- 3. Gargoyle activo (cooldown > 150s): haste y ERW
                    if burstOn and gargCD > 150 then
                        if state.areGlovesReady and state.areGlovesReady(now) then
                            return "HYPER"
                        end
                        if state.spellReady("BERSERKING") then
                            return "BERSERKING"
                        end
                        if state.spellReady("SPEED_POT") then
                            return "SPEED_POT"
                        end
                        local erwCD = state.spellCooldown("ERW") or 0
                        if erwCD <= 0 then
                            return "ERW"
                        end
                        -- Despues de ERW, Army of the Dead (solo contra jefes: sus ghouls tauntean adds)
                        if state.vars.armyOfTheDead ~= 0 and state.dk.targetIsBoss and state.spellReady("AOTD") then
                            return "AOTD"
                        end
                    end
                    return nil
                ]]
            }
        }
    }
}


-- 4. UNHOLY DW-SS (con Scourge Strike): Morb + Scourge Strike gastando el par Frost+Unholy
local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

local function BuildDWSS()
    local p = DeepCopy(Presets.DK_UNHOLY_MORB_PVE)
    p.meta.id = "dk_unholy_dw_ss_pve"
    p.meta.name = "DK UH Morb+SS (DW+SS) PvE"
    p.meta.shortName = "[UMS]"
    p.meta.buildType = "unholy_dw_ss"
    p.sequences.opener.steps = { "IT", "PS", "DND", "BS", "SS" }
    local m = p.lists.main[1]
    m.note = "UH Morb+SS (DW+SS): Scourge Strike + GF + Desolation + Dots + DnD protegido"
    m.code = [[
                    if state.evaluateUnholySS then
                        return state.evaluateUnholySS(state)
                    end
                    return nil
                ]]
    return p
end

Presets.DK_UNHOLY_2H_PVE = Presets.DK_UNHOLY_PVE
Presets.DK_UNHOLY_DW_SS_PVE = BuildDWSS()

-- ============================================================================
-- Rotaciones en reglas legibles (v2). Las listas de arriba quedan como la v1 (<id>_v1).
-- Funciones del DK: unholy() (contexto calculado una vez por evaluacion: ffRem/bpRem/desRem/gfRem = segundos de
-- plagas, Desolation y Ghoul Frenzy; dndCD/dndIn = Death and Decay; safeB/safeU/safeF = gastar ese par no atrasa
-- DnD; btGain/btReserved = Blood Tap; gargCD/gargBlocked/rpFloor/reserveU = Gargola; keepU/keepUGF/keepF = no
-- quedarse sin runa para refrescar), canCast(b, f, u), runeDeficit(b, f, u), runeWait("blood"/"unholy"/"frost"),
-- keepsRune(tipo, segundos), bloodTapFor(alias), healthOK(). Datos en "dk" y "runes".
-- ============================================================================
local R = RotaCore.Rule

local function Migrate(p, main, off)
    local v1 = RotaCore.V1Of(p, p.lists)
    p.lists = { main = RotaCore.Flatten(main), off = RotaCore.Flatten(off) }
    return v1
end

local UNHOLY_MAIN = {
    R("uh_aoe_dnd", "DND", "AoE: Death and Decay antes que las plagas", [[
local u = unholy()
if aoe() and u.hasDND and u.dndCD <= gcd() + 0.1 and canCast(1, 1, 1) then return "DND" end
]]),
    R("uh_ff", "IT", "Frost Fever: refrescar con <= 2.5 s (Blood Tap si falta la runa y tarda)", [[
local u = unholy()
if u.hasIT and u.ffRem - gcd() <= 2.5 then
    say("Refrescar Frost Fever")
    if canCast(0, 1, 0) then return "IT" end
    if u.btGain and not u.btReserved and runeDeficit(0, 1, 0) == 1 and runeWait("frost") > 0.8 then
        return bloodTapFor("IT")
    end
    if runeWait("frost") <= gcd() + 1.5 then return wait("IT", runeWait("frost")) end
    say(nil)
end
]]),
    R("uh_bp", "PS", "Blood Plague: refrescar con <= 2.5 s (Blood Tap si falta la runa y tarda)", [[
local u = unholy()
if u.hasPS and u.bpRem - gcd() <= 2.5 then
    say("Refrescar Blood Plague")
    if canCast(0, 0, 1) then return "PS" end
    if u.btGain and not u.btReserved and runeDeficit(0, 0, 1) == 1 and runeWait("unholy") > 0.8 then
        return bloodTapFor("PS")
    end
    if runeWait("unholy") <= gcd() + 1.5 then return wait("PS", runeWait("unholy")) end
    say(nil)
end
]]),
    R("uh_desolation", "BS", "Desolation: Blood Strike con <= 2 s", [[
local u = unholy()
if u.hasBS and u.desOK and u.desRem - gcd() <= 2.0 then
    say("Mantener Desolation")
    if canCast(1, 0, 0) then return "BS" end
    if u.btGain and not u.btReserved and runeWait("blood") > 0.8 then return bloodTapFor("BS") end
    if runeWait("blood") <= gcd() + 1.0 then return wait("BS", runeWait("blood")) end
    say(nil)
end
]]),
    R("uh_dnd", "DND", "Death and Decay apenas esta disponible", [[
local u = unholy()
if u.hasDND and u.dndCD <= gcd() + 0.1 then
    say("Death and Decay listo")
    if canCast(1, 1, 1) then return "DND" end
    if u.btGain and runeDeficit(1, 1, 1) == 1 then
        say("Blood Tap para Death and Decay")
        return bloodTapFor("DND")
    end
    local w = math.max(runeWait("blood"), runeWait("unholy"), runeWait("frost"))
    if w <= gcd() + 1.5 then
        say("Esperando runas para Death and Decay")
        return wait("DND", w)
    end
    say(nil)
end
]]),
    R("uh_aoe", "PEST", "AoE: Pestilence para esparcir (o refrescar con Glyph of Disease) > Blood Boil > relleno", [[
if not aoe() then return nil end
local u = unholy()
if dk.hasFrostFever and dk.hasBloodPlague and known("PEST") and canCast(1, 0, 0) then
    local needSpread
    local plates = aoePlateCount or 0
    if plates > 0 then
        needSpread = plates > (dk.aoeDiseasedCount or 0)
    else
        local lastPest = lastPestilence()
        needSpread = lastPest == 0 or (now - lastPest) > 20
    end
    local refresh = dk.hasGlyphOfDisease == true and u.safeB and (u.ffRem - gcd() < 8.0 or u.bpRem - gcd() < 8.0)
    if needSpread then say("Esparcir plagas"); return "PEST" end
    if refresh then say("Refrescar plagas (Glyph of Disease)"); return "PEST" end
end
if u.hasBB and u.safeB and canCast(1, 0, 0) then say("Blood Boil (AoE)"); return "BB" end
if u.isSS then
    if u.hasSS and u.safeU and u.safeF and canCast(0, 1, 1) then return "SS" end
elseif u.hasIT and u.safeF and canCast(0, 1, 0) then
    return "IT"
end
if u.safeU and canCast(0, 0, 1) and u.uFree > 0 then
    if u.gfUsable and u.gfRem - gcd() <= 10 and u.keepU then return "GF" end
    if u.hasPS then return "PS" end
end
if u.btGain and not u.btReserved and u.hasBB and u.dndCD > 3 then return bloodTapFor("BB") end
if u.hasDC and power() >= 40 and power() - 40 >= u.rpFloor and u.dndIn > gcd() + 0.8 then return "DC" end
if known("HOW") and cd("HOW") <= gcd() and u.dndIn > gcd() + 1.0 then say("Horn of Winter (relleno)"); return "HOW" end
say("Esperando runas")
if u.hasDND then return wait("DND", u.dndIn) end
return wait("IT")
]]),
    R("uh_gf", "GF", "Ghoul Frenzy con <= 10 s", [[
local u = unholy()
if u.gfUsable and u.gfRem - gcd() <= 10 then
    say("Ghoul Frenzy por caerse")
    local urgent = u.gfRem <= 3.5 and u.gfRem < u.bpRem - gcd()
    if canCast(0, 0, 1) and (u.safeU or runes.deathReady >= 1) and (urgent or u.keepU) then return "GF" end
    if u.btGain and not u.btReserved then return bloodTapFor("GF") end
    if urgent and canCast(0, 0, 1) then return "GF" end
    say(nil)
end
]]),
    R("uh_dc_cap", "DC", "Death Coil para no llegar al tope de RP", [[
local u = unholy()
if u.hasDC and ((power() >= 80 and (u.gargCD > 5 or u.gargBlocked)) or power() >= 100) then
    say("Death Coil: evitar cap de RP")
    return "DC"
end
]]),
    R("uh_spend", "IT", "Gastar pares de runas sin atrasar DnD", [[
local u = unholy()
if u.isSS then
    if u.hasPS and u.bpRem - gcd() <= 5 and u.safeU and canCast(0, 0, 1) and u.uFree > 0 then return "PS" end
    if u.hasIT and u.ffRem - gcd() <= 5 and u.safeF and canCast(0, 1, 0) then return "IT" end
    if u.hasSS and u.safeU and u.safeF and canCast(0, 1, 1) and u.uFree > 0 and u.keepU and u.keepUGF and u.keepF then
        return "SS"
    end
    if u.gfUsable and u.gfRem < 14 and u.safeU and canCast(0, 0, 1) and u.uFree > 0 and u.keepU then return "GF" end
else
    if u.hasIT and u.safeF and canCast(0, 1, 0) then return "IT" end
    if u.safeU and canCast(0, 0, 1) and u.uFree > 0 then
        if u.gfUsable and u.gfRem < 14 and u.keepU then return "GF" end
        if u.hasPS and u.keepUGF then return "PS" end
    end
end
]]),
    R("uh_blood", "BS", "Runas Blood: Blood Strike (Desolation < 10 s o sin Unholy Might), si no Blood Boil", [[
local u = unholy()
if u.safeB and canCast(1, 0, 0) then
    if u.hasBS and (u.desRem - gcd() < 10.0 or (dk.umRemaining or 0) <= 0) then return "BS" end
    if u.hasBB then return "BB" end
    if u.hasBS then return "BS" end
end
]]),
    R("uh_bt", "GF", "Blood Tap: runa extra para Ghoul Frenzy o Blood Boil / Blood Strike", [[
local u = unholy()
if u.btGain and not u.btReserved then
    if u.gfUsable and u.gfRem < 14 and not u.reserveU then return bloodTapFor("GF") end
    if u.dndCD > 3 then
        if u.hasBS and u.desRem - gcd() < 10.0 then return bloodTapFor("BS") end
        if u.hasBB then return bloodTapFor("BB") end
    end
end
]]),
    R("uh_dc", "DC", "Death Coil mientras se espera DnD, sin gastar el RP de la Gargola", [[
local u = unholy()
if u.hasDC and power() >= 40 and power() - 40 >= u.rpFloor and u.dndIn > gcd() + 0.8
    and (u.gargCD > 0 or power() >= 100 or not burst() or u.gargBlocked) then
    say("Death Coil: gastar RP")
    return "DC"
end
]]),
    R("uh_how", "HOW", "Horn of Winter (relleno)", [[
local u = unholy()
if known("HOW") and cd("HOW") <= gcd() and u.dndIn > gcd() + 1.0 then say("Horn of Winter (relleno)"); return "HOW" end
]]),
    R("uh_wait", "DND", "Nada para hacer: esperar Death and Decay", [[
local u = unholy()
if u.hasDC and power() >= 40 and power() - 40 < u.rpFloor then
    say("Guardando RP para la Gargola")
elseif u.hasDC and power() >= 40 and u.dndIn <= gcd() + 0.8 then
    say("Death and Decay en menos de 1 GCD")
else
    say("Esperando runas")
end
if u.hasDND then return wait("DND", u.dndIn) end
return wait("IT")
]]),
}

local UNHOLY_OFF = {
    R("uh_off_bp", "BP", "Gargola terminada: volver a Blood Presence (var gargBackToBP)", [[
local gargCD = known("GARG") and cd("GARG") or 999
if var("gargBackToBP", 1) ~= 0 and dk.hasUnholyPresence and known("GARG") and gargCD > 0 and gargCD <= 150
    and combat() then
    if canCast(1, 0, 0) then return "BP" end
    if bloodTapReady() and runeDeficit(1, 0, 0) == 1 and runeWait("blood") > 0.8 then return "BT" end
end
]]),
    R("uh_off_garg", "GARG", "Gargola: Unholy Presence > racial > Gargola (con plagas firmes)", [[
local gargCD = known("GARG") and cd("GARG") or 999
local dmin = 0
if dk.hasFrostFever and dk.hasBloodPlague then dmin = math.min(dk.ffRemaining, dk.bpRemaining) end
if burst() and known("GARG") and gargCD <= gcd() + 0.1 and power() >= 60 and combat()
    and (dmin >= 4.5 or dk.hasUnholyPresence or longFight()) then
    if not dk.hasUnholyPresence then
        if canCast(0, 0, 1) then return "UP" end
        if bloodTapReady() and runeDeficit(0, 0, 1) == 1 and runeWait("unholy") > 0.8 and runes.bloodReady == 0 then
            return "BT"
        end
        return false
    end
    if spellReady("BF") then return "BF" end
    if spellReady("RACIAL") then return "RACIAL" end
    return "GARG"
end
]]),
    R("uh_off_bt", "BT", "Blood Tap pedido por la lista principal", [[
if dk.wantBT and bloodTapReady() and inCombat ~= false then return "BT" end
]]),
    R("uh_off_haste", "HYPER", "Gargola viva: guantes, Berserking, pocion, ERW y Army of the Dead (var armyOfTheDead)", [[
if burst() and known("GARG") and cd("GARG") > 150 and combat() then
    if gloves() then return "HYPER" end
    if spellReady("BERSERKING") then return "BERSERKING" end
    local pot = potion("SPEED_POT")
    if pot then return pot end
    local ready = runes.bloodReady + runes.frostReady + runes.unholyReady + runes.deathReady
    if cd("ERW") <= 0 and ready <= 2 then return "ERW" end
    -- Army of the Dead: solo contra jefes (los ghouls tauntean), o contra cualquiera con Glyph of Army of the Dead
if var("armyOfTheDead", 1) ~= 0 and (dk.targetIsBoss or glyphOn("army")) and cd("ERW") > 0 and known("AOTD")
    and spellReady("AOTD") then
        return "AOTD"
    end
end
]]),
}

-- UH 2H (Scourge Strike con arma de dos manos; la eligio el dueno, Wowhead ya no la recomienda).
-- canCastRunes(b, f, u) = alcanzan las runas (del estado). La lista off ya eran reglas y queda igual.
local UNHOLY_2H_MAIN = {
    R("u2h_aoe", "DND", "AoE: DnD > plagas > Pestilence > Desolation > Blood Boil > Scourge Strike > Death Coil", [[
if not aoe() then return nil end
local g = gcd()
if cd("DND") <= g + 0.1 and canCastRunes(1, 1, 1) then return "DND" end
if dk.ffRemaining - g <= 2.5 and (runes.frostReady > 0 or runes.deathReady > 0) then return "IT" end
if dk.bpRemaining - g <= 2.5 and (runes.unholyReady > 0 or runes.deathReady > 0) then return "PS" end
local lastPest = lastCast and (lastCast["PEST"] or lastCast["Pestilence"] or lastCast[50842]) or 0
local needSpread = lastPest == 0 or (now - lastPest) > (dk.minDiseaseRemaining - 3.0)
if dk.hasFrostFever and dk.hasBloodPlague and needSpread and canCastRunes(1, 0, 0) and known("PEST") then return "PEST" end
if dk.desolationRemaining - g <= 2.0 and canCastRunes(1, 0, 0) and known("BS") then return "BS" end
if canCastRunes(1, 0, 0) and known("BB") then return "BB" end
if canCastRunes(0, 1, 1) and known("SS") then return "SS" end
if power() >= 40 and known("DC") then return "DC" end
return wait("DND")
]]),
    R("u2h_pest", "PEST", "Glyph of Disease: Pestilence para refrescar las plagas", [[
if dk.hasGlyphOfDisease and dk.hasFrostFever and dk.hasBloodPlague and dk.minDiseaseRemaining - gcd() <= 2.5
    and canCastRunes(1, 0, 0) and known("PEST") then
    return "PEST"
end
]]),
    R("u2h_bsh", "BSH", "Bone Shield (fuera de combate, o con runa Unholy libre y todo firme)", [[
if buff("Bone Shield") <= 0 and known("BSH") then
    if not inCombat and not hasTarget and (runes.unholyReady > 0 or runes.deathReady > 0) then return "BSH" end
    if runes.unholyReady > 0 and dk.desolationRemaining - gcd() > 3.0 and dk.ffRemaining > 2.0 and dk.bpRemaining > 2.0 then
        return "BSH"
    end
end
]]),
    R("u2h_dots", "IT", "Plagas: Icy Touch / Plague Strike con <= 2 s", [[
if dk.ffRemaining - gcd() <= 2.0 and (runes.frostReady > 0 or runes.deathReady > 0) and known("IT") then return "IT" end
if dk.bpRemaining - gcd() <= 2.0 and (runes.unholyReady > 0 or runes.deathReady > 0) and known("PS") then return "PS" end
]]),
    R("u2h_desolation", "BS", "Desolation: Blood Strike con <= 3 s", [[
if dk.desolationRemaining - gcd() <= 3.0 and canCastRunes(1, 0, 0) and known("BS") then return "BS" end
]]),
    R("u2h_ss", "SS", "Scourge Strike", [[
if canCastRunes(0, 1, 1) and known("SS") then return "SS" end
]]),
    R("u2h_bs", "BS", "Blood Strike", [[
if canCastRunes(1, 0, 0) and known("BS") then return "BS" end
]]),
    R("u2h_dc", "DC", "Death Coil (con la Gargola lista se guardan 60 RP; Sudden Doom lo lanza gratis)", [[
local holdForGarg = known("GARG") and burst() and cd("GARG") <= 0
local minDC = holdForGarg and 100 or 40
if known("DC") and (power() >= minDC or buff("Sudden Doom") > 0) then return "DC" end
]]),
    R("u2h_how", "HOW", "Horn of Winter", [[
if buff("Horn of Winter") <= 5 and known("HOW") then return "HOW" end
]]),
    R("u2h_wait", "SS", "Nada listo: esperar Scourge Strike", [[
return wait("SS")
]]),
}
Presets.DK_UNHOLY_PVE_V1 = Migrate(Presets.DK_UNHOLY_PVE, UNHOLY_2H_MAIN, Presets.DK_UNHOLY_PVE.lists.off)

-- FROST (Wowhead). frost() = contexto: ffRem/bpRem/m (plaga mas corta), km (Killing Machine), fog (Freezing
-- Fog / Rime), btCD/uaCD/hbCD, canDump/dump (Frost Strike o Death Coil para gastar RP), rpCap, gcdLen.
-- canWithRunes(segundos, b, f, u, guardarBloodParaPest) = habra runas en ese tiempo. grace(tipo) = gracia de runa.
local FROST_MAIN = {
    R("fr_aoe", "HB", "AoE: plagas > Pestilence > Howling Blast > DnD (10+) > Frost Strike > Blood Boil > Obliterate", [[
if not aoe() then return nil end
local c = frost()
local g = gcd()
local okIT = canWithRunes(g, 0, 1, 0, false)
local okPS = canWithRunes(g, 0, 0, 1, false)
local okPEST = canWithRunes(g, 1, 0, 0, false)
local okHB = c.hbCD <= g and (c.fog or canWithRunes(g, 0, 1, 1, true))
local okDND = cd("DND") <= g and canWithRunes(g, 1, 1, 1, true)
local okBB = canWithRunes(g, 1, 0, 0, true)
local okOBL = canWithRunes(g, 0, 1, 1, true)
if c.ffRem - g <= 0 and okIT then return "IT" end
if c.bpRem - g <= 0 and okPS then return "PS" end
if c.hasFF and c.hasBP and c.m - g <= c.gcdLen + 0.5 and okPEST then return "PEST" end
local lastPest = lastCast and (lastCast["PEST"] or lastCast["Pestilence"] or lastCast[50842]) or 0
local needSpread = lastPest == 0 or (now - lastPest) > (c.m - 3.0)
if c.hasFF and c.hasBP and needSpread and okPEST then return "PEST" end
if okHB and known("HB") then return "HB" end
if (aoeCount or 1) >= 10 and okDND and known("DND") then return "DND" end
if power() >= c.rpCap and c.canDump then return c.dump end
if c.hasFF and c.hasBP and okBB then
    if burst() and c.uaCD <= g and known("UA") then state.suggestedOff = "UA" end
    if known("BB") then return "BB" end
end
if c.canDump then
    local holdForKM = c.km and c.hbCD <= g + 1.5 and power() < c.maxPower and known("HB")
    if not holdForKM then return c.dump end
end
if okOBL and c.hbCD > g + 1.5 and known("OBL") then return "OBL" end
if c.km and c.hbCD <= g + 1.5 and known("HB") then return wait("HB") end
if buff("Horn of Winter") <= 5 and spellReady("HOW") == true then return "HOW" end
-- Nada ahora: lo primero que se va a poder en 0.5 / 1 / 1.5 / 2.5 s
for i = 1, 4 do
    local h = (i == 4) and 2.5 or i * 0.5
    local lim = g + h
    if c.ffRem - g <= 0 and canWithRunes(lim, 0, 1, 0, false) then return wait("IT") end
    if c.bpRem - g <= 0 and canWithRunes(lim, 0, 0, 1, false) then return wait("PS") end
    if c.hasFF and c.hasBP and c.m - g <= c.gcdLen + 0.5 and canWithRunes(lim, 1, 0, 0, false) then return wait("PEST") end
    if c.hbCD <= lim and (c.fog or canWithRunes(lim, 0, 1, 1, true)) and known("HB") then return wait("HB") end
    if c.hasFF and c.hasBP and canWithRunes(lim, 1, 0, 0, true) and known("BB") then return wait("BB") end
    if canWithRunes(lim, 0, 1, 1, true) and known("OBL") then return wait("OBL") end
end
if known("HOW") then return "HOW" end
return wait("HB")
]]),
    R("fr_dots", "IT", "Plagas caidas: Icy Touch / Plague Strike", [[
local c = frost()
local g = gcd()
if c.ffRem - g <= 0 and canWithRunes(g, 0, 1, 0, false) then return "IT" end
if c.bpRem - g <= 0 and canWithRunes(g, 0, 0, 1, false) then return "PS" end
]]),
    R("fr_refresh", "PEST", "Refrescar plagas: IT/PS sin Glyph of Disease; Pestilence (con Blood Tap si hace falta) con el glifo", [[
local c = frost()
local g = gcd()
local okPEST = canWithRunes(g, 1, 0, 0, false)
if dk.hasGlyphOfDisease == false then
    if c.ffRem - g <= 2.5 and canWithRunes(g, 0, 1, 0, false) then return "IT" end
    if c.bpRem - g <= 2.5 and canWithRunes(g, 0, 0, 1, false) then return "PS" end
    return nil
end
if c.hasFF and c.hasBP and c.m <= 3.5 then
    if runes.bloodReady >= 1 or runes.deathReady >= 1 or (dk.bloodTapRemaining or 0) > 0 then
        state.suggestedOff = nil
        if okPEST then return "PEST" end
    elseif c.btCD <= 0 and known("BT") then
        -- sin runa Blood/Death: Blood Tap si la proxima tarda mas que las plagas
        local minCD = 999
        for i = 1, 6 do
            local r = runes.slots[i]
            if r and (r.type == 1 or r.type == 4) and r.cdRemains < minCD then minCD = r.cdRemains end
        end
        if minCD > c.m - 0.5 then
            state.suggestedOff = "BT"
            return wait("PEST")
        end
    end
end
if c.hasFF and c.hasBP and c.m - g <= c.gcdLen + 1.0 and okPEST then return "PEST" end
]]),
    R("fr_rime", "HB", "Freezing Fog: Howling Blast (Killing Machine va a Frost Strike si Obliterate no esta listo)", [[
local c = frost()
local g = gcd()
local okOBL = canWithRunes(g, 0, 1, 1, true)
local okHB = c.hbCD <= g and (c.fog or canWithRunes(g, 0, 1, 1, true))
if c.fog and c.ffRem >= 3 and c.hbCD <= g and okHB and known("HB") then
    if c.km and not okOBL and grace(3) <= 1.5 and grace(2) <= 1.5 and c.canDump then return c.dump end
    return "HB"
end
]]),
    R("fr_km", "FS", "Killing Machine: Frost Strike", [[
local c = frost()
if c.km and grace(3) <= 1.5 and grace(2) <= 1.5 and c.ffRem >= 3 and c.canDump then return c.dump end
]]),
    R("fr_obl", "OBL", "Obliterate con runas listas ahora", [[
if canWithRunes(gcd(), 0, 1, 1, true) and known("OBL") then return "OBL" end
]]),
    R("fr_fs_cap", "FS", "Frost Strike cerca del tope de RP", [[
local c = frost()
if power() >= c.rpCap and c.canDump then return c.dump end
]]),
    R("fr_fillers", "PEST", "Relleno: Pestilence (plagas <= 6 s y UA en CD), Blood Strike, Howling Blast con Freezing Fog", [[
local c = frost()
local g = gcd()
if c.ffRem > 0 and c.ffRem <= 6 and c.uaCD >= 6 and canWithRunes(g, 1, 0, 0, false) then return "PEST" end
if c.ffRem > 10 and canWithRunes(g, 1, 0, 0, true) and known("BS") then return "BS" end
if c.fog and c.hbCD <= g and (c.fog or canWithRunes(g, 0, 1, 1, true)) and known("HB") then return "HB" end
]]),
    R("fr_fs", "FS", "Frost Strike para gastar RP", [[
local c = frost()
if c.canDump then return c.dump end
]]),
    R("fr_how", "HOW", "Horn of Winter", [[
if buff("Horn of Winter") <= 5 and spellReady("HOW") == true then return "HOW" end
]]),
    R("fr_soon", "OBL", "Nada ahora: lo primero que se va a poder en 0.5 / 1 / 1.5 / 2.5 s", [[
local c = frost()
local g = gcd()
for i = 1, 4 do
    local h = (i == 4) and 2.5 or i * 0.5
    local lim = g + h
    if c.ffRem - g <= 0 and canWithRunes(lim, 0, 1, 0, false) then return wait("IT") end
    if c.bpRem - g <= 0 and canWithRunes(lim, 0, 0, 1, false) then return wait("PS") end
    if c.hasFF and c.hasBP and c.m - g <= c.gcdLen + 1.0 and canWithRunes(lim, 1, 0, 0, false) then return wait("PEST") end
    if c.fog and c.hbCD <= lim and (c.fog or canWithRunes(lim, 0, 1, 1, true)) and known("HB") then return wait("HB") end
    if canWithRunes(lim, 0, 1, 1, true) and known("OBL") then return wait("OBL") end
    if c.ffRem > 10 and canWithRunes(lim, 1, 0, 0, true) and known("BS") then return wait("BS") end
end
if known("HOW") then return "HOW" end
return wait("OBL")
]]),
}
-- La lista off de Frost ya eran reglas: se conserva igual
Presets.DK_FROST_PVE_V1 = Migrate(Presets.DK_FROST_PVE, FROST_MAIN, Presets.DK_FROST_PVE.lists.off)

Presets.DK_UNHOLY_MORB_PVE.vars.scourgeStrike = 0
Presets.DK_UNHOLY_DW_SS_PVE.vars.scourgeStrike = 1   -- Morb + Scourge Strike con el par Frost + Unholy
Presets.DK_UNHOLY_MORB_PVE_V1 = Migrate(Presets.DK_UNHOLY_MORB_PVE, UNHOLY_MAIN, UNHOLY_OFF)
Presets.DK_UNHOLY_DW_SS_PVE_V1 = Migrate(Presets.DK_UNHOLY_DW_SS_PVE, UNHOLY_MAIN, UNHOLY_OFF)

-- Register presets automatically with RotaCore.Profiles
-- Glifos que cambian un poco la rotacion (toggles en Opciones > Rotacion; ver RotaCore/Glyphs.lua)
local ARMY_GLYPH = {
    army = { name = "Glyph of Army of the Dead", spell = 42650,
        desc = "Los ghouls no tauntean: Army of the Dead entra en el pre-pull (Frost) y en combate también fuera de jefes (Unholy)." },
}
for _, key in ipairs({ "DK_FROST_PVE", "DK_UNHOLY_MORB_PVE", "DK_UNHOLY_DW_SS_PVE", "DK_UNHOLY_PVE" }) do
    Presets[key].glyphs = ARMY_GLYPH
end

-- Pre-pull (boton Pre-Pull, una vez)
local PREPULL_POTION = RotaCore.PrepullPotion("melee")
Presets.DK_FROST_PVE.lists.prepull = {
    R("pre_army", "AOTD", "Con Glyph of Army of the Dead: Army of the Dead (canaliza 4 s)", [[
if glyphOn("army") and known("AOTD") and spellReady("AOTD") then return "AOTD" end
]]),
    PREPULL_POTION,
}
Presets.DK_FROST_PVE.meta.prepullLead = 10
Presets.DK_FROST_PVE.meta.prepullNote = "Con Glyph of Army of the Dead: Army of the Dead unos 10 s antes, después la poción."
for _, key in ipairs({ "DK_UNHOLY_MORB_PVE", "DK_UNHOLY_DW_SS_PVE", "DK_UNHOLY_PVE" }) do
    Presets[key].lists.prepull = { PREPULL_POTION }
    Presets[key].meta.prepullLead = 2
    Presets[key].meta.prepullNote = "Poción justo antes del pull. Army of the Dead va en combate, después de Empower Rune Weapon."
end

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.DK_FROST_PVE.meta.requires = { "HB", "FS" }
Presets.DK_UNHOLY_MORB_PVE.meta.requires = { "GF", "GARG" }
Presets.DK_UNHOLY_DW_SS_PVE.meta.requires = { "SS" }
Presets.DK_UNHOLY_PVE.meta.requires = { "SS", "GARG" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    RotaCore.Profiles:RegisterPreset(Presets.DK_FROST_PVE)
    RotaCore.Profiles:RegisterPreset(Presets.DK_FROST_PVE_V1)
    RotaCore.Profiles:RegisterPreset(Presets.DK_UNHOLY_MORB_PVE)
    RotaCore.Profiles:RegisterPreset(Presets.DK_UNHOLY_MORB_PVE_V1)
    RotaCore.Profiles:RegisterPreset(Presets.DK_UNHOLY_PVE)
    RotaCore.Profiles:RegisterPreset(Presets.DK_UNHOLY_PVE_V1)
    RotaCore.Profiles:RegisterPreset(Presets.DK_UNHOLY_DW_SS_PVE)
    RotaCore.Profiles:RegisterPreset(Presets.DK_UNHOLY_DW_SS_PVE_V1)
end

return Presets