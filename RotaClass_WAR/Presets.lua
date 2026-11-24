-- RotaClass_WAR/Presets.lua — Fury & Arms Warrior RotationIR Presets (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Presets = {}

-- 1. FURY WARRIOR PVE PRESET (RotationIR - Wowhead 3.3.5a)
-- ST: Bloodthirst > Whirlwind > Slam (Bloodsurge) > Execute (<=20%) > Sunder Armor
-- AoE: Whirlwind (#1) > Bloodthirst (#2) > Slam (Bloodsurge) > Execute
-- Off (On-Next-Swing):
--   - Heroic Strike en ST (rage >= 50, not queued)
--   - Cleave en AoE (rage >= 45, not queued)
--   - Burst: Death Wish, Guantes, Racial
Presets.WAR_FURY_PVE = {
    meta = {
        id = "war_fury_pve",
        name = "Fury Warrior PvE",
        class = "WARRIOR",
        spec = "Fury",
        schema = 1,
        interface = 30300,
    },
    spells = {
        BT     = { name = "Bloodthirst",               defaultId = 23881, overrideId = nil, matchById = false },
        WW     = { name = "Whirlwind",                 defaultId = 1680,  overrideId = nil, matchById = false },
        SLAM   = { name = "Slam",                      defaultId = 1464,  overrideId = nil, matchById = false },
        EXEC   = { name = "Execute",                   defaultId = 5308,  overrideId = nil, matchById = false },
        HS     = { name = "Heroic Strike",             defaultId = 78,    overrideId = nil, matchById = false },
        CLEAVE = { name = "Cleave",                    defaultId = 845,   overrideId = nil, matchById = false },
        DW     = { name = "Death Wish",                defaultId = 12292, overrideId = nil, matchById = false },
        REC    = { name = "Recklessness",              defaultId = 1719,  overrideId = nil, matchById = false },
        BR     = { name = "Bloodrage",                 defaultId = 2687,  overrideId = nil, matchById = false },
        BS         = { name = "Berserker Stance",          defaultId = 2458,  overrideId = nil, matchById = false },
        BATTLE     = { name = "Battle Stance",             defaultId = 2457,  overrideId = nil, matchById = false },
        OP         = { name = "Overpower",                 defaultId = 7384,  overrideId = nil, matchById = false },
        REND       = { name = "Rend",                      defaultId = 772,   overrideId = nil, matchById = false },
        SUNDER     = { name = "Sunder Armor",              defaultId = 7386,  overrideId = nil, matchById = false },
        SHATTERING = { name = "Shattering Throw",          defaultId = 64382, overrideId = nil, matchById = false },
        ST         = { name = "Shattering Throw",          defaultId = 64382, overrideId = nil, matchById = false },
        GLOVES     = { name = "Hyperspeed Acceleration",   defaultId = 54758, overrideId = nil, matchById = false },
        RACIAL     = { name = "Blood Fury",                defaultId = 20572, overrideId = nil, matchById = false },
    },
    vars = {
        hsRageThreshold = 50,
        cleaveRageThreshold = 45,
        maintainSunder = false,
    },
    sequences = {
        opener = {
            enabled = true,
            resetOnCombatEnd = true,
            timeout = 8,
            steps = { "BT", "WW" },
        },
    },
    lists = {
        main = {
            -- Direct Lua Evaluator Hook (Wowhead Fury Priority)
            {
                id = "war_fury_eval_hook",
                enabled = true,
                type = "customLua",
                action = "BT",
                note = "Fury Warrior Wowhead 3.3.5a Priority (ST & AoE)",
                code = [[
                    if state.evaluateFury then
                        return state.evaluateFury(state)
                    end
                    local war = _G.RotaClass_WAR
                    if war and war.EvaluateFury then
                        return war.EvaluateFury(state)
                    end
                    return nil
                ]],
            },
            -- Declarative AST Fallback Rules (AoE)
            {
                id = "war_fury_ww_aoe",
                enabled = true,
                type = "block",
                action = "WW",
                isAoE = true,
                note = "Whirlwind #1 priority in AoE with sufficient Rage",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "WW" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 25 }
                    }
                }
            },
            {
                id = "war_fury_bt_aoe",
                enabled = true,
                type = "block",
                action = "BT",
                isAoE = true,
                note = "Bloodthirst #2 priority in AoE with sufficient Rage",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "BT" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 20 }
                    }
                }
            },
            -- Declarative AST Fallback Rules (Single Target)
            {
                id = "war_fury_bt",
                enabled = true,
                type = "block",
                action = "BT",
                isAoE = false,
                note = "Bloodthirst on cooldown with sufficient Rage",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "BT" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 20 }
                    }
                }
            },
            {
                id = "war_fury_ww",
                enabled = true,
                type = "block",
                action = "WW",
                isAoE = false,
                note = "Whirlwind on cooldown with sufficient Rage",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "WW" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 25 }
                    }
                }
            },
            {
                id = "war_fury_slam_proc",
                enabled = true,
                type = "block",
                action = "SLAM",
                note = "Instant Slam strictly on Bloodsurge proc",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.hasBloodsurge" },
                        r = { op = "val", val = true }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 15 }
                    }
                }
            },
            {
                id = "war_fury_exec",
                enabled = true,
                type = "block",
                action = "EXEC",
                note = "Execute when target <= 20% and primary attacks on CD",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.canExecute" },
                        r = { op = "val", val = true }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 30 }
                    }
                }
            },
        },
        off = {
            -- Direct Lua Evaluator Hook (Heroic Strike / Cleave & Burst)
            {
                id = "war_fury_off_eval_hook",
                enabled = true,
                type = "customLua",
                action = "HS",
                note = "Fury Warrior On-Next-Swing & Burst Cooldowns",
                code = [[
                    if state.evaluateFuryOff then
                        return state.evaluateFuryOff(state)
                    end
                    local war = _G.RotaClass_WAR
                    if war and war.EvaluateFuryOff then
                        return war.EvaluateFuryOff(state)
                    end
                    return nil
                ]],
            },
            -- Declarative AST Fallback Rules
            {
                id = "war_fury_death_wish",
                enabled = true,
                type = "block",
                isBurst = true,
                action = "DW",
                note = "Death Wish 20% damage burst off-GCD",
                when = {
                    op = "call", fn = "spell.ready", args = { "DW" }
                }
            },
            {
                id = "war_fury_gloves",
                enabled = true,
                type = "block",
                isBurst = true,
                action = "GLOVES",
                note = "Hyperspeed Accelerators gloves",
                when = {
                    op = "cmp", cmp = "==",
                    l = { op = "call", fn = "areGlovesReady", args = {} },
                    r = { op = "val", val = true }
                }
            },
            {
                id = "war_fury_heroic_strike",
                enabled = true,
                type = "block",
                action = "HS",
                isAoE = false,
                note = "Queue Heroic Strike if not queued and surplus Rage available (ST)",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.isHeroicStrikeQueued" },
                        r = { op = "val", val = false }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "var", name = "hsRageThreshold" }
                    }
                }
            },
            {
                id = "war_fury_cleave",
                enabled = true,
                type = "block",
                action = "CLEAVE",
                isAoE = true,
                note = "Queue Cleave for AoE if not queued and surplus Rage",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.isCleaveQueued" },
                        r = { op = "val", val = false }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "var", name = "cleaveRageThreshold" }
                    }
                }
            },
        }
    }
}

-- 1B. FURY WARRIOR OVERPOWER WEAVING PVE PRESET (20/51/0)
-- ST: Bloodthirst > Whirlwind > Slam (Bloodsurge) > Overpower Weaving (OP / Rend) > Execute
-- AoE: Whirlwind (#1) > Bloodthirst (#2) > Slam (Bloodsurge) > Execute
Presets.WAR_FURY_OVERPOWER_PVE = {
    meta = {
        id = "war_fury_overpower_pve",
        name = "Fury Warrior (Overpower Weaving 20/51) PvE",
        class = "WARRIOR",
        spec = "Fury",
        schema = 1,
        interface = 30300,
    },
    spells = Presets.WAR_FURY_PVE.spells,
    vars = {
        hsRageThreshold = 50,
        cleaveRageThreshold = 45,
        maintainSunder = false,
    },
    sequences = {
        opener = {
            enabled = true,
            resetOnCombatEnd = true,
            timeout = 8,
            steps = { "BT", "WW" },
        },
    },
    lists = {
        main = {
            {
                id = "war_fury_op_eval_hook",
                enabled = true,
                type = "customLua",
                action = "BT",
                note = "Fury Overpower Weaving (20/51/0) Priority (ST & AoE)",
                code = [[
                    if state.evaluateFury then
                        return state.evaluateFury(state)
                    end
                    local war = _G.RotaClass_WAR
                    if war and war.EvaluateFury then
                        return war.EvaluateFury(state)
                    end
                    return nil
                ]],
            },
        },
        off = {
            {
                id = "war_fury_op_off_eval_hook",
                enabled = true,
                type = "customLua",
                action = "HS",
                note = "Fury Overpower Weaving On-Next-Swing & Burst Cooldowns",
                code = [[
                    if state.evaluateFuryOff then
                        return state.evaluateFuryOff(state)
                    end
                    local war = _G.RotaClass_WAR
                    if war and war.EvaluateFuryOff then
                        return war.EvaluateFuryOff(state)
                    end
                    return nil
                ]],
            },
        }
    }
}

-- 2. ARMS WARRIOR PVE PRESET (RotationIR - Wowhead 3.3.5a)
-- ST: Rend (debuff == 0, no renovar antes) > Execute(Sudden Death o <=20%)
--     > Overpower > Bladestorm(Rend>6s, sin proc SD, OP gastado) > MS > Slam filler
-- AoE: Rend > Sweeping Strikes > Overpower > Thunder Clap > Bladestorm > MS
-- Off: Cleave en AoE (rage >= 50), Heroic Strike en ST (rage >= 60)
Presets.WAR_ARMS_PVE = {
    meta = {
        id = "war_arms_pve",
        name = "Arms Warrior PvE",
        class = "WARRIOR",
        spec = "Arms",
        schema = 1,
        interface = 30300,
    },
    spells = {
        MS     = { name = "Mortal Strike",             defaultId = 12294, overrideId = nil, matchById = false },
        REND   = { name = "Rend",                      defaultId = 772,   overrideId = nil, matchById = false },
        OP     = { name = "Overpower",                 defaultId = 7384,  overrideId = nil, matchById = false },
        EXEC   = { name = "Execute",                   defaultId = 5308,  overrideId = nil, matchById = false },
        BS     = { name = "Bladestorm",                defaultId = 46924, overrideId = nil, matchById = false },
        SLAM   = { name = "Slam",                      defaultId = 1464,  overrideId = nil, matchById = false },
        TC     = { name = "Thunder Clap",              defaultId = 6343,  overrideId = nil, matchById = false },
        SW     = { name = "Sweeping Strikes",          defaultId = 12328, overrideId = nil, matchById = false },
        HS     = { name = "Heroic Strike",             defaultId = 78,    overrideId = nil, matchById = false },
        CLEAVE = { name = "Cleave",                    defaultId = 845,   overrideId = nil, matchById = false },
        BR     = { name = "Bloodrage",                 defaultId = 2687,  overrideId = nil, matchById = false },
        GLOVES     = { name = "Hyperspeed Acceleration",   defaultId = 54758, overrideId = nil, matchById = false },
        RACIAL     = { name = "Blood Fury",                defaultId = 20572, overrideId = nil, matchById = false },
        SUNDER     = { name = "Sunder Armor",              defaultId = 7386,  overrideId = nil, matchById = false },
        SHATTERING = { name = "Shattering Throw",          defaultId = 64382, overrideId = nil, matchById = false },
        ST         = { name = "Shattering Throw",          defaultId = 64382, overrideId = nil, matchById = false },
    },
    vars = {
        hsRageThreshold = 60,
        cleaveRageThreshold = 50,
    },
    sequences = {
        opener = {
            enabled = true,
            resetOnCombatEnd = true,
            timeout = 8,
            steps = { "REND", "MS" },
        },
    },
    lists = {
        main = {
            -- Direct Lua Evaluator Hook (Wowhead Arms Priority)
            {
                id = "war_arms_eval_hook",
                enabled = true,
                type = "customLua",
                action = "MS",
                note = "Arms Warrior Wowhead 3.3.5a Priority (ST & AoE)",
                code = [[
                    if state.evaluateArms then
                        return state.evaluateArms(state)
                    end
                    local war = _G.RotaClass_WAR
                    if war and war.EvaluateArms then
                        return war.EvaluateArms(state)
                    end
                    return nil
                ]],
            },
            -- Declarative AST Fallback Rules (AoE)
            {
                id = "war_arms_rend_aoe",
                enabled = true,
                type = "block",
                action = "REND",
                isAoE = true,
                note = "Maintain Rend in AoE when expired (0s)",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.rendRemaining" },
                        r = { op = "val", val = 0 }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 10 }
                    }
                }
            },
            {
                id = "war_arms_sw_main_aoe",
                enabled = true,
                type = "block",
                action = "SW",
                isAoE = true,
                note = "Sweeping Strikes #2 in AoE",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "SW" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 30 }
                    }
                }
            },
            {
                id = "war_arms_op_aoe",
                enabled = true,
                type = "block",
                action = "OP",
                isAoE = true,
                note = "Overpower #3 in AoE",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.canOverpower" },
                        r = { op = "val", val = true }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 5 }
                    }
                }
            },
            {
                id = "war_arms_tc_aoe",
                enabled = true,
                type = "block",
                action = "TC",
                isAoE = true,
                note = "Thunder Clap #4 in AoE",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "TC" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 20 }
                    }
                }
            },
            {
                id = "war_arms_bladestorm_aoe",
                enabled = true,
                type = "block",
                isBurst = true,
                action = "BS",
                isAoE = true,
                note = "Bladestorm #5 in AoE",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "BS" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 25 }
                    }
                }
            },
            -- Declarative AST Fallback Rules (Single Target)
            {
                id = "war_arms_rend",
                enabled = true,
                type = "block",
                action = "REND",
                isAoE = false,
                note = "Maintain Rend strictly when expired (0s)",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.rendRemaining" },
                        r = { op = "val", val = 0 }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 10 }
                    }
                }
            },
            {
                id = "war_arms_exec",
                enabled = true,
                type = "block",
                action = "EXEC",
                note = "Execute on Sudden Death proc or <= 20% health",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.canExecute" },
                        r = { op = "val", val = true }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 15 }
                    }
                }
            },
            {
                id = "war_arms_overpower",
                enabled = true,
                type = "block",
                action = "OP",
                note = "Overpower when Taste for Blood is active or dodge",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.canOverpower" },
                        r = { op = "val", val = true }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 5 }
                    }
                }
            },
            {
                id = "war_arms_ms",
                enabled = true,
                type = "block",
                action = "MS",
                note = "Mortal Strike on cooldown",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "MS" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 30 }
                    }
                }
            },
            {
                id = "war_arms_bladestorm",
                enabled = true,
                type = "block",
                isBurst = true,
                action = "BS",
                note = "Bladestorm when Rend > 6s and Overpower used",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "BS" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 25 }
                    }
                }
            },
            {
                id = "war_arms_slam",
                enabled = true,
                type = "block",
                action = "SLAM",
                note = "Slam filler when MS and OP are on CD",
                when = {
                    op = "cmp", cmp = ">=",
                    l = { op = "state", path = "power" },
                    r = { op = "val", val = 15 }
                }
            },
        },
        off = {
            -- Direct Lua Evaluator Hook (Heroic Strike / Cleave & Burst)
            {
                id = "war_arms_off_eval_hook",
                enabled = true,
                type = "customLua",
                action = "HS",
                note = "Arms Warrior On-Next-Swing & Burst Cooldowns",
                code = [[
                    if state.evaluateArmsOff then
                        return state.evaluateArmsOff(state)
                    end
                    local war = _G.RotaClass_WAR
                    if war and war.EvaluateArmsOff then
                        return war.EvaluateArmsOff(state)
                    end
                    return nil
                ]],
            },
            -- Declarative AST Fallback Rules
            {
                id = "war_arms_sweeping_strikes",
                enabled = true,
                type = "block",
                action = "SW",
                isAoE = true,
                note = "Sweeping Strikes for AoE",
                when = {
                    op = "and",
                    l = {
                        op = "call", fn = "spell.ready", args = { "SW" }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "val", val = 30 }
                    }
                }
            },
            {
                id = "war_arms_heroic_strike",
                enabled = true,
                type = "block",
                action = "HS",
                isAoE = false,
                note = "Queue Heroic Strike if not queued and rage >= 60",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.isHeroicStrikeQueued" },
                        r = { op = "val", val = false }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "var", name = "hsRageThreshold" }
                    }
                }
            },
            {
                id = "war_arms_cleave",
                enabled = true,
                type = "block",
                action = "CLEAVE",
                isAoE = true,
                note = "Queue Cleave if not queued and rage >= 50",
                when = {
                    op = "and",
                    l = {
                        op = "cmp", cmp = "==",
                        l = { op = "state", path = "war.isCleaveQueued" },
                        r = { op = "val", val = false }
                    },
                    r = {
                        op = "cmp", cmp = ">=",
                        l = { op = "state", path = "power" },
                        r = { op = "var", name = "cleaveRageThreshold" }
                    }
                }
            },
        }
    }
}

-- Register presets with RotaCore
-- ============================================================================
-- Rotaciones en reglas legibles (v2). Las listas de arriba quedan como la v1 (<id>_v1): gancho al modulo +
-- reglas de respaldo por bloques. Las reglas nuevas van primero y las de respaldo se conservan detras.
-- Datos del modulo en "war": rage, stance, hasBloodsurge, hasSuddenDeath, hasTasteForBlood, canExecute,
-- canOverpower, rendRemaining, sunderCount, hasDeathWish, isNextSwingQueued.
-- spellReady("X") = listo cuando termina el GCD actual (el chequeo que usa el Guerrero).
-- ============================================================================
local R = RotaCore.Rule

-- Reglas nuevas + las de respaldo de la v1 (sin su gancho, que era la primera)
local function Migrate(p, main, off)
    local v1 = RotaCore.V1Of(p, p.lists)
    local function WithFallback(rules, old)
        local out = RotaCore.Flatten(rules)
        for i = 2, #old do out[#out + 1] = old[i] end
        return out
    end
    p.lists = { main = WithFallback(main, v1.lists.main), off = WithFallback(off, v1.lists.off) }
    return v1
end

local FURY_MAIN = {
    R("fury_aoe", "WW", "AoE: Whirlwind > Bloodthirst > Slam (Bloodsurge) > Execute", [[
if aoe() then
    local rage = war.rage
    if known("WW") and spellReady("WW") and rage >= 25 then return "WW" end
    if known("BT") and spellReady("BT") and rage >= 20 then return "BT" end
    if war.hasBloodsurge and known("SLAM") and rage >= 15 then return "SLAM" end
    if war.canExecute and known("EXEC") and rage >= 45 then return "EXEC" end
end
]]),
    R("fury_bt", "BT", "Bloodthirst", [[
if not aoe() and known("BT") and spellReady("BT") and war.rage >= 20 then return "BT" end
]]),
    R("fury_ww", "WW", "Whirlwind", [[
if not aoe() and known("WW") and spellReady("WW") and war.rage >= 25 then return "WW" end
]]),
    R("fury_slam", "SLAM", "Slam con Bloodsurge", [[
if not aoe() and war.hasBloodsurge and known("SLAM") and war.rage >= 15 then return "SLAM" end
]]),
    R("fury_op", "OP", "Build Overpower: Overpower y Rend con Bloodthirst y Whirlwind en CD", [[
if not aoe() and opWeaving() and cd("BT") > 1.5 and cd("WW") > 1.5 and not war.hasBloodsurge then
    if (war.canOverpower or war.hasTasteForBlood) and known("OP") and war.rage >= 5 then return "OP" end
    if war.rendRemaining == 0 and cd("BT") > 2.0 and cd("WW") > 2.0 and known("REND") and war.rage >= 10 then
        return "REND"
    end
end
]]),
    R("fury_exec", "EXEC", "Execute (lo ultimo, sin Bloodsurge)", [[
if not aoe() and war.canExecute and known("EXEC") and war.rage >= 30 and not war.hasBloodsurge then return "EXEC" end
]]),
    R("fury_sunder", "SUNDER", "Sunder Armor hasta 5 stacks (var maintainSunder)", [[
if not aoe() and var("maintainSunder", nil) and war.sunderCount < 5 and known("SUNDER") and war.rage >= 15 then
    return "SUNDER"
end
]]),
}
local FURY_OFF = {
    R("fury_shattering", "SHATTERING", "Shattering Throw (Glyph de Rebuffed)", [[
if glyphOn("shattering") and shatteringReady() then return "SHATTERING" end
]]),
    R("fury_swing", "HS", "Heroic Strike (Cleave en AoE) con ira de sobra", [[
if not war.isNextSwingQueued then
    if aoe() then
        if war.rage >= 45 and known("CLEAVE") then return "CLEAVE" end
    elseif war.rage >= 50 and known("HS") then
        return "HS"
    end
end
]]),
    R("fury_br", "BR", "Bloodrage con poca ira", [[
if known("BR") and spellReady("BR") and war.rage < 20 then return "BR" end
]]),
    R("fury_burst", "DW", "Death Wish, guantes, racial", [[
if burst() then
    if known("DW") and spellReady("DW") and not war.hasDeathWish then return "DW" end
    if gloves() then return "GLOVES" end
    if known("RACIAL") and spellReady("RACIAL") then return "RACIAL" end
end
]]),
}

local ARMS_MAIN = {
    R("arms_aoe", "TC", "AoE: Rend > Sweeping Strikes > Overpower > Thunder Clap > Bladestorm > Mortal Strike", [[
if aoe() then
    local rage = war.rage
    if war.rendRemaining == 0 and known("REND") and rage >= 10 then return "REND" end
    if known("SW") and spellReady("SW") and rage >= 30 then return "SW" end
    if war.canOverpower and known("OP") and rage >= 5 then return "OP" end
    if known("TC") and spellReady("TC") and rage >= 20 then return "TC" end
    if burst() and known("BS") and spellReady("BS") and war.rendRemaining > 6.0 and not war.canOverpower and rage >= 25 then
        return "BS"
    end
    if known("MS") and spellReady("MS") and rage >= 30 then return "MS" end
end
]]),
    R("arms_rend", "REND", "Rend (no renovar antes de que caiga)", [[
if not aoe() and war.rendRemaining == 0 and known("REND") and war.rage >= 10 then return "REND" end
]]),
    R("arms_sunder", "SUNDER", "Sunder Armor hasta 5 stacks (var maintainSunder)", [[
if not aoe() and var("maintainSunder", nil) and war.sunderCount < 5 and known("SUNDER") and war.rage >= 15 then
    return "SUNDER"
end
]]),
    R("arms_exec", "EXEC", "Execute con Sudden Death o debajo de 20%", [[
if not aoe() and (war.hasSuddenDeath or war.canExecute) and known("EXEC") and war.rage >= 15 then return "EXEC" end
]]),
    R("arms_ms", "MS", "Mortal Strike (Rebuffed: Improved Mortal Strike, antes que Overpower)", [[
if not aoe() and known("MS") and spellReady("MS") and war.rage >= 30 then return "MS" end
]]),
    R("arms_op", "OP", "Overpower", [[
if not aoe() and war.canOverpower and known("OP") and war.rage >= 5 then return "OP" end
]]),
    R("arms_bs", "BS", "Bladestorm con Rend > 6 s, sin Sudden Death ni Overpower", [[
if not aoe() and burst() and known("BS") and spellReady("BS") and war.rendRemaining > 6.0
    and not war.hasSuddenDeath and not war.canOverpower and war.rage >= 25 then
    return "BS"
end
]]),
    R("arms_slam", "SLAM", "Slam (relleno)", [[
if not aoe() and known("SLAM") and war.rage >= 15 then return "SLAM" end
]]),
}
local ARMS_OFF = {
    R("arms_shattering", "SHATTERING", "Shattering Throw (Glyph de Rebuffed)", [[
if glyphOn("shattering") and shatteringReady() then return "SHATTERING" end
]]),
    R("arms_sw", "SW", "AoE: Sweeping Strikes", [[
if aoe() and known("SW") and spellReady("SW") and war.rage >= 30 then return "SW" end
]]),
    R("arms_swing", "HS", "Heroic Strike (Cleave en AoE) con ira de sobra", [[
if not war.isNextSwingQueued then
    if aoe() then
        if war.rage >= 50 and known("CLEAVE") then return "CLEAVE" end
    elseif war.rage >= 60 and known("HS") then
        return "HS"
    end
end
]]),
    R("arms_br", "BR", "Bloodrage con poca ira", [[
if known("BR") and spellReady("BR") and war.rage < 20 then return "BR" end
]]),
    R("arms_burst", "GLOVES", "Guantes y racial", [[
if burst() then
    if gloves() then return "GLOVES" end
    if known("RACIAL") and spellReady("RACIAL") then return "RACIAL" end
end
]]),
}

Presets.WAR_FURY_PVE_V1 = Migrate(Presets.WAR_FURY_PVE, FURY_MAIN, FURY_OFF)
Presets.WAR_FURY_OVERPOWER_PVE_V1 = Migrate(Presets.WAR_FURY_OVERPOWER_PVE, FURY_MAIN, FURY_OFF)
Presets.WAR_ARMS_PVE_V1 = Migrate(Presets.WAR_ARMS_PVE, ARMS_MAIN, ARMS_OFF)

-- Glifos que cambian un poco la rotacion (toggles en Opciones > Rotacion)
local SHATTERING_GLYPH = {
    shattering = { name = "Glyph of Shattering Throw", ids = { 58357, 64382 }, spell = 64382,
        desc = "Cambio del servidor: Shattering Throw instantáneo y en cualquier postura; entra con Burst." },
}
for _, key in ipairs({ "WAR_FURY_PVE", "WAR_FURY_OVERPOWER_PVE", "WAR_ARMS_PVE" }) do
    Presets[key].glyphs = SHATTERING_GLYPH
end

-- Pre-pull (boton Pre-Pull, una vez): poción
for _, key in ipairs({ "WAR_FURY_PVE", "WAR_FURY_OVERPOWER_PVE", "WAR_ARMS_PVE" }) do
    Presets[key].lists.prepull = { RotaCore.PrepullPotion("melee") }
    Presets[key].meta.prepullLead = 2
    Presets[key].meta.prepullNote = "Poción justo antes del pull."
end

-- Hechizos de talento sin los que la build no funciona: si falta alguno, RotaCore avisa una vez por chat
Presets.WAR_FURY_PVE.meta.requires = { "BT" }
Presets.WAR_FURY_OVERPOWER_PVE.meta.requires = { "BT" }
Presets.WAR_ARMS_PVE.meta.requires = { "MS" }

if RotaCore.Profiles and RotaCore.Profiles.RegisterPreset then
    for _, key in ipairs({ "WAR_FURY_PVE", "WAR_FURY_OVERPOWER_PVE", "WAR_ARMS_PVE" }) do
        RotaCore.Profiles:RegisterPreset(Presets[key])
        RotaCore.Profiles:RegisterPreset(Presets[key .. "_V1"])
    end
end

return Presets
