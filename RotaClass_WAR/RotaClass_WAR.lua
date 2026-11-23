-- RotaClass_WAR/RotaClass_WAR.lua — Warrior State Provider & On-Next-Swing Engine (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_WAR = {
    detectedSpec = "Fury",
    detectedPresetId = "war_fury_pve",
}
_G.RotaClass_WAR = RotaClass_WAR

--- Safe spell check helper for Warrior
local function WarHasSpell(state, spellOrId)
    if not spellOrId then return false end
    if state and state.hasSpell then
        return state.hasSpell(spellOrId)
    end
    if RotaCore.Spells and RotaCore.Spells.HasSpell then
        return RotaCore.Spells:HasSpell(spellOrId)
    end
    if _G.GetSpellCooldown then
        return _G.GetSpellCooldown(spellOrId) ~= nil
    end
    return false
end

RotaClass_WAR.HasSpell = function(selfOrSpell, spell)
    local target = (spell ~= nil) and spell or selfOrSpell
    return WarHasSpell(nil, target)
end
RotaClass_WAR.hasSpell = RotaClass_WAR.HasSpell

--- Detects active Warrior spec (Arms or Fury) based on known talents/spells
function RotaClass_WAR:DetectSpec()
    local hasBT = WarHasSpell(nil, "Bloodthirst") or WarHasSpell(nil, 23881)
    local hasMS = WarHasSpell(nil, "Mortal Strike") or WarHasSpell(nil, 12294)
    local hasBS = WarHasSpell(nil, "Bladestorm") or WarHasSpell(nil, 46924)

    if _G.IsSpellKnown then
        if not hasBT then hasBT = _G.IsSpellKnown(23881) end
        if not hasMS then hasMS = _G.IsSpellKnown(12294) end
        if not hasBS then hasBS = _G.IsSpellKnown(46924) end
    end

    local sData = RotaCore.State and RotaCore.State.data
    local warData = sData and sData.war
    local hasTFB = warData and (warData.hasTasteForBloodTalent or (warData.tasteForBloodPoints and warData.tasteForBloodPoints > 0))

    if not hasTFB and _G.GetNumTalents and _G.GetTalentInfo then
        local numTalents = _G.GetNumTalents(1) or 0
        for idx = 1, numTalents do
            local name, _, _, _, rank = _G.GetTalentInfo(1, idx)
            if name and rank and rank > 0 then
                local lower = name:lower()
                if lower:find("taste for blood") or lower:find("gusto por la sangre") then
                    hasTFB = true
                    break
                end
            end
        end
    end

    local spec = "Fury"
    local buildKey = "fury"
    local presetId = "war_fury_pve"
    local badge = "[FURY]"

    if hasMS or hasBS then
        spec = "Arms"
        buildKey = "arms"
        presetId = "war_arms_pve"
        badge = "[ARMS]"
    elseif hasBT and hasTFB then
        spec = "Fury"
        buildKey = "fury_overpower"
        presetId = "war_fury_overpower_pve"
        badge = "[FOP]"
    elseif hasBT then
        spec = "Fury"
        buildKey = "fury"
        presetId = "war_fury_pve"
        badge = "[FURY]"
    end

    local selected = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild()
    if selected == "arms" or selected == "Arms" or selected == "55/8/8" then
        spec = "Arms"
        buildKey = "arms"
        presetId = "war_arms_pve"
        badge = "[ARMS]"
    elseif selected == "fury_overpower" or selected == "op" or selected == "overpower" or selected == "20/51" or selected == "fury_op" then
        spec = "Fury"
        buildKey = "fury_overpower"
        presetId = "war_fury_overpower_pve"
        badge = "[FOP]"
    elseif selected == "fury" or selected == "Fury" or selected == "18/53" then
        spec = "Fury"
        buildKey = "fury"
        presetId = "war_fury_pve"
        badge = "[FURY]"
    end

    RotaClass_WAR.detectedSpec = spec
    RotaClass_WAR.detectedBuild = buildKey
    RotaClass_WAR.detectedPresetId = presetId
    RotaClass_WAR.detectedBadge = badge

    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(presetId)
    end

    return spec, presetId, buildKey
end

--- Updates Warrior state: Stances, Rage, Procs (Bloodsurge, Sudden Death, Taste for Blood),
--  Rend, Execute threshold, and On-Next-Swing queued status via IsCurrentSpell.
-- @param state table Pre-allocated RotaCore.State.data table
-- @param _ number Current timestamp (unused)
local function UpdateWarriorState(state, _)
    local war = state.war
    if not war then return end

    -- 1. Stance Tracking (1: Battle Stance, 2: Defensive Stance, 3: Berserker Stance)
    war.stance = (_G.GetShapeshiftForm and _G.GetShapeshiftForm()) or 1

    -- 2. Rage Tracking
    war.rage = state.power or 0
    war.ragePct = state.powerPct or 0

    -- 3. Target Health & Execute Phase (<= 20% health or Sudden Death proc)
    local th = state.targetHealthPct or 100
    if _G.UnitHealth and _G.UnitHealthMax and state.hasTarget then
        local cur = _G.UnitHealth("target") or 0
        local maxH = _G.UnitHealthMax("target") or 0
        if maxH > 0 then
            th = (cur / maxH) * 100
        end
    end
    war.targetHealthPct = th

    -- 4. Procs & Buffs Tracking
    war.bloodsurgeRemaining = state.buffRemaining("Bloodsurge", "player")
    war.hasBloodsurge = (war.bloodsurgeRemaining > 0)

    war.suddenDeathRemaining = state.buffRemaining("Sudden Death", "player")
    war.hasSuddenDeath = (war.suddenDeathRemaining > 0)

    war.tasteForBloodRemaining = state.buffRemaining("Taste for Blood", "player")
    war.hasTasteForBlood = (war.tasteForBloodRemaining > 0)

    war.hasDeathWish = state.hasBuff("Death Wish", "player")
    war.hasRecklessness = state.hasBuff("Recklessness", "player")
    war.hasBloodrage = state.hasBuff("Bloodrage", "player")

    -- 5. Target Debuffs Tracking (Rend & Sunder Armor)
    war.rendRemaining = state.debuffRemaining("Rend", "target", true)
    war.hasRend = (war.rendRemaining > 0)

    war.sunderCount = state.debuffCount("Sunder Armor", "target", false)
    war.sunderRemaining = state.debuffRemaining("Sunder Armor", "target", false)

    -- 6. Execute & Overpower Status
    war.canExecute = (th <= 20 and th > 0) or war.hasSuddenDeath

    local opUsable = false
    if _G.IsUsableSpell then
        local u, noMana = _G.IsUsableSpell("Overpower")
        if u and not noMana then
            opUsable = true
        end
    end
    war.canOverpower = (war.hasTasteForBlood or opUsable) and (war.stance == 1 or war.stance == 0)

    -- 7. On-Next-Swing Queue Status (Heroic Strike & Cleave)
    local hsQueued = false
    local cleaveQueued = false
    if state.isCurrentSpell then
        hsQueued = state.isCurrentSpell("Heroic Strike")
        cleaveQueued = state.isCurrentSpell("Cleave")
    elseif _G.IsCurrentSpell then
        hsQueued = (_G.IsCurrentSpell("Heroic Strike") or _G.IsCurrentSpell(47450) or _G.IsCurrentSpell(78)) and true or false
        cleaveQueued = (_G.IsCurrentSpell("Cleave") or _G.IsCurrentSpell(47520) or _G.IsCurrentSpell(845)) and true or false
    end
    war.isHeroicStrikeQueued = hsQueued
    war.isCleaveQueued = cleaveQueued
    war.isNextSwingQueued = hsQueued or cleaveQueued
end

-- Build Fury con Overpower (20/51): por build detectada, preset activo (o su v1) o talento Taste for Blood en AUTO
local function IsOPWeaving(war)
    if RotaClass_WAR.detectedBuild == "fury_overpower" then return true end
    local p = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    local id = p and p.meta and (p.meta.v1Of or p.meta.id)
    if id == "war_fury_overpower_pve" then return true end
    if RotaClass_WAR.detectedBuild == nil or RotaClass_WAR.detectedBuild == "auto" then
        if war and (war.hasTasteForBloodTalent or (war.tasteForBloodPoints and war.tasteForBloodPoints > 0)) then
            return true
        end
    end
    return false
end

-- Shattering Throw con Glyph of Shattering Throw (Rebuffed): listo, con ira, objetivo valido que no es jugador
local function ShatteringReady(state, war, rage)
    if state.burstMode == false then return false end
    local glyphMap = state.glyphs
    local hasGlyph = (war and war.hasGlyphOfShatteringThrow) or (glyphMap and (glyphMap[58357] or glyphMap[64382]))
    if not hasGlyph or rage < 25 then return false end
    local stReady = (state.spellReady and (state.spellReady("SHATTERING") or state.spellReady("ST")))
    local isTargetValid = state.hasTarget and not (_G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost("target"))
    local isNotPlayer = not (_G.UnitIsPlayer and _G.UnitIsPlayer("target"))
    local canAttack = not _G.UnitCanAttack or _G.UnitCanAttack("player", "target")
    return (stReady and isTargetValid and isNotPlayer and canAttack) and true or false
end

-- Funciones del Guerrero para las reglas del preset (ver RotaClass_WAR/Presets.lua)
if RotaCore.Sandbox and RotaCore.Sandbox.AddHelper then
    local Sandbox = RotaCore.Sandbox
    --- jugando Fury con Overpower (build 20/51)
    Sandbox:AddHelper("opWeaving", function() return IsOPWeaving(Sandbox.current.war) end)
    --- Shattering Throw (Glyph de Rebuffed) listo para tirar
    Sandbox:AddHelper("shatteringReady", function()
        local st = Sandbox.current
        local war = st.war
        return ShatteringReady(st, war, war and war.rage or (st.power or 0))
    end)
end

--- Fury Warrior Main GCD Priority Evaluator (Wowhead 3.3.5a)
-- Single Target: BT > WW > Slam(Bloodsurge) > Execute(<=20%) > Sunder
-- AoE: WW > BT > Slam(Bloodsurge) > Execute
function RotaClass_WAR.EvaluateFury(state)
    local war = state.war
    local aoeMode = state.aoeMode or state.isAoE
    local rage = war and war.rage or (state.power or 0)
    local hasBloodsurge = war and war.hasBloodsurge
    local canExecute = war and war.canExecute

    local isOPWeaving = IsOPWeaving(war)

    if aoeMode then
        -- FURY AOE: WW pasa a ser prioridad #1 por encima de BT
        -- 1. Whirlwind (#1 en AoE)
        if WarHasSpell(state, "WW") and state.spellReady("WW") and rage >= 25 then
            return "WW"
        end
        -- 2. Bloodthirst (#2 en AoE)
        if WarHasSpell(state, "BT") and state.spellReady("BT") and rage >= 20 then
            return "BT"
        end
        -- 3. Slam (SOLO con proc instantáneo de Bloodsurge cuando WW y BT en CD)
        if hasBloodsurge and WarHasSpell(state, "SLAM") and rage >= 15 then
            return "SLAM"
        end
        -- 4. Execute (solo si WW y BT en CD y rage >= 45)
        if canExecute and WarHasSpell(state, "EXEC") and rage >= 45 then
            return "EXEC"
        end
    else
        -- FURY SINGLE TARGET (Wowhead): Bloodthirst > Whirlwind > Slam (Bloodsurge) > Execute
        -- Bloodthirst primero por su CD mas corto: es mas facil perder un BT que un WW en la pelea
        if WarHasSpell(state, "BT") and state.spellReady("BT") and rage >= 20 then
            return "BT"
        end
        if WarHasSpell(state, "WW") and state.spellReady("WW") and rage >= 25 then
            return "WW"
        end
        -- 3. Slam (SOLO si tiene el buff Bloodsurge activo)
        if hasBloodsurge and WarHasSpell(state, "SLAM") and rage >= 15 then
            return "SLAM"
        end

        local btCD = (state.spellCooldown and state.spellCooldown("BT")) or 0
        local wwCD = (state.spellCooldown and state.spellCooldown("WW")) or 0

        -- 4. Overpower Weaving (20/51/0 Build):
        if isOPWeaving and btCD > 1.5 and wwCD > 1.5 and not hasBloodsurge then
            local opReady = (war and (war.canOverpower or war.hasTasteForBlood))
            if opReady and WarHasSpell(state, "OP") and rage >= 5 then
                return "OP"
            end

            local rendRem = (war and war.rendRemaining) or 0
            if rendRem == 0 and btCD > 2.0 and wwCD > 2.0 and WarHasSpell(state, "REND") and rage >= 10 then
                return "REND"
            end
        end

        -- 5. Execute (prioridad más baja, solo si target <= 20%, BT y WW en CD, no Bloodsurge y rage >= 30)
        if canExecute and WarHasSpell(state, "EXEC") and rage >= 30 and not hasBloodsurge then
            return "EXEC"
        end
        -- 6. Sunder Armor (si maintainSunder activo y < 5 stacks)
        local vars = state.vars or {}
        if vars.maintainSunder and (war and war.sunderCount or 0) < 5 and WarHasSpell(state, "SUNDER") and rage >= 15 then
            return "SUNDER"
        end
    end

    return nil
end

--- Fury Warrior Off-GCD & On-Next-Swing Evaluator (Wowhead 3.3.5a)
-- Cleave en AoE (rage >= 45), Heroic Strike en ST (rage >= 50), nunca ya encolados
-- Burst: Death Wish, Guantes, Racial, Shattering Throw (con glifo custom)
function RotaClass_WAR.EvaluateFuryOff(state)
    local war = state.war
    local aoeMode = state.aoeMode or state.isAoE
    local rage = war and war.rage or (state.power or 0)
    local isNextQueued = war and war.isNextSwingQueued

    -- 0. Shattering Throw con Glyph of Shattering Throw (Rebuffed: -20% armadura instantaneo en burst)
    if ShatteringReady(state, war, rage) then return "SHATTERING" end

    -- 1. Ataques On-Next-Swing (nunca van al icono principal de GCD)
    if not isNextQueued then
        if aoeMode then
            if rage >= 45 and WarHasSpell(state, "CLEAVE") then
                return "CLEAVE"
            end
        else
            if rage >= 50 and WarHasSpell(state, "HS") then
                return "HS"
            end
        end
    end

    -- 2. Bloodrage (si rage < 20)
    if WarHasSpell(state, "BR") and state.spellReady("BR") and rage < 20 then
        return "BR"
    end

    -- 3. Burst Cooldowns cuando Burst: ON
    if state.burstMode ~= false then
        if WarHasSpell(state, "DW") and state.spellReady("DW") and not (war and war.hasDeathWish) then
            return "DW"
        end
        if state.areGlovesReady and state.areGlovesReady(state.now) then
            return "GLOVES"
        end
        if WarHasSpell(state, "RACIAL") and state.spellReady("RACIAL") then
            return "RACIAL"
        end
    end

    return nil
end

--- Arms Warrior Main GCD Priority Evaluator (Wowhead 3.3.5a)
-- ST: Rend (debuff == 0, no renovar antes) > Sunder (<5) > Execute(Sudden Death o <=20%)
--     > MS > Overpower > Bladestorm(Rend>6s, sin proc SD, OP gastado) > Slam filler
-- AoE: Rend > Sweeping Strikes > Overpower > Thunder Clap > Bladestorm > MS
function RotaClass_WAR.EvaluateArms(state)
    local war = state.war
    local aoeMode = state.aoeMode or state.isAoE
    local rage = war and war.rage or (state.power or 0)

    local rendRem = war and war.rendRemaining or 0
    local hasSD = war and war.hasSuddenDeath
    local canOP = war and war.canOverpower
    local canExec = war and war.canExecute

    if aoeMode then
        -- ARMS AOE:
        -- 1. Rend en target primario si no activo
        if rendRem == 0 and WarHasSpell(state, "REND") and rage >= 10 then
            return "REND"
        end
        -- 2. Sweeping Strikes (en main GCD si no lanzado off-GCD)
        if WarHasSpell(state, "SW") and state.spellReady("SW") and rage >= 30 then
            return "SW"
        end
        -- 3. Overpower si está activo
        if canOP and WarHasSpell(state, "OP") and rage >= 5 then
            return "OP"
        end
        -- 4. Thunder Clap en cooldown (mantiene Deep Wounds en hasta 10 objetivos)
        if WarHasSpell(state, "TC") and state.spellReady("TC") and rage >= 20 then
            return "TC"
        end
        -- 5. Bladestorm (verificando Rend > 6.0s y que ya se haya gastado Overpower)
        if (state.burstMode ~= false) and WarHasSpell(state, "BS") and state.spellReady("BS")
            and rendRem > 6.0 and not canOP and rage >= 25 then
            return "BS"
        end
        -- 6. Mortal Strike
        if WarHasSpell(state, "MS") and state.spellReady("MS") and rage >= 30 then
            return "MS"
        end
    else
        -- ARMS SINGLE TARGET:
        -- 1. Rend: Si NO está activo (rendRemaining == 0). no refrescar antes de que caiga.
        if rendRem == 0 and WarHasSpell(state, "REND") and rage >= 10 then
            return "REND"
        end
        -- 2. Sunder Armor: si maintainSunder activo y < 5 stacks
        local vars = state.vars or {}
        if vars.maintainSunder and (war and war.sunderCount or 0) < 5 and WarHasSpell(state, "SUNDER") and rage >= 15 then
            return "SUNDER"
        end
        -- 3. Execute: Sudden Death proc O target <= 20% HP
        if (hasSD or canExec) and WarHasSpell(state, "EXEC") and rage >= 15 then
            return "EXEC"
        end
        -- 4. Mortal Strike en cooldown (Rebuffed: Improved Mortal Strike +35%, va antes que Overpower)
        if WarHasSpell(state, "MS") and state.spellReady("MS") and rage >= 30 then
            return "MS"
        end
        -- 5. Overpower: si es usable (Taste for Blood proc o esquive)
        if canOP and WarHasSpell(state, "OP") and rage >= 5 then
            return "OP"
        end
        -- 6. Bladestorm: solo si Rend > 6.0s, NO proc Sudden Death, y NO Overpower disponible
        if (state.burstMode ~= false) and WarHasSpell(state, "BS") and state.spellReady("BS")
            and rendRem > 6.0 and not hasSD and not canOP and rage >= 25 then
            return "BS"
        end
        -- 7. Slam: Filler si rage >= 15 y MS/OP/Execute no están listos
        if WarHasSpell(state, "SLAM") and rage >= 15 then
            return "SLAM"
        end
    end

    return nil
end

--- Arms Warrior Off-GCD & On-Next-Swing Evaluator (Wowhead 3.3.5a)
-- Sweeping Strikes en AoE, Cleave (rage >= 50) en AoE, Heroic Strike (rage >= 60) en ST
function RotaClass_WAR.EvaluateArmsOff(state)
    local war = state.war
    local aoeMode = state.aoeMode or state.isAoE
    local rage = war and war.rage or (state.power or 0)
    local isNextQueued = war and war.isNextSwingQueued

    -- 0. Shattering Throw con Glyph of Shattering Throw (Rebuffed: -20% armadura instantaneo en burst)
    if ShatteringReady(state, war, rage) then return "SHATTERING" end

    -- 1. Sweeping Strikes en AoE
    if aoeMode and WarHasSpell(state, "SW") and state.spellReady("SW") and rage >= 30 then
        return "SW"
    end

    -- 2. Ataques On-Next-Swing (solo con exceso de ira y sin estar encolados)
    if not isNextQueued then
        if aoeMode then
            if rage >= 50 and WarHasSpell(state, "CLEAVE") then
                return "CLEAVE"
            end
        else
            if rage >= 60 and WarHasSpell(state, "HS") then
                return "HS"
            end
        end
    end

    -- 3. Bloodrage si rage < 20
    if WarHasSpell(state, "BR") and state.spellReady("BR") and rage < 20 then
        return "BR"
    end

    -- 4. Burst en Off-GCD cuando Burst: ON
    if state.burstMode ~= false then
        if state.areGlovesReady and state.areGlovesReady(state.now) then
            return "GLOVES"
        end
        if WarHasSpell(state, "RACIAL") and state.spellReady("RACIAL") then
            return "RACIAL"
        end
    end

    return nil
end

--- Master Evaluator dispatch for Warrior: routes to Arms or Fury
function RotaClass_WAR.Evaluate(state)
    local spec = RotaClass_WAR.detectedSpec
    local activeProfile = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if activeProfile and activeProfile.meta and activeProfile.meta.spec then
        spec = activeProfile.meta.spec
    end
    if spec == "Arms" then
        return RotaClass_WAR.EvaluateArms(state)
    else
        return RotaClass_WAR.EvaluateFury(state)
    end
end

function RotaClass_WAR.EvaluateOff(state)
    local spec = RotaClass_WAR.detectedSpec
    local activeProfile = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if activeProfile and activeProfile.meta and activeProfile.meta.spec then
        spec = activeProfile.meta.spec
    end
    if spec == "Arms" then
        return RotaClass_WAR.EvaluateArmsOff(state)
    else
        return RotaClass_WAR.EvaluateFuryOff(state)
    end
end

if RotaCore.State and RotaCore.State.data then
    RotaCore.State.data.evaluateWarrior = RotaClass_WAR.Evaluate
    RotaCore.State.data.evaluateWarriorOff = RotaClass_WAR.EvaluateOff
    RotaCore.State.data.evaluateFury = RotaClass_WAR.EvaluateFury
    RotaCore.State.data.evaluateFuryOff = RotaClass_WAR.EvaluateFuryOff
    RotaCore.State.data.evaluateArms = RotaClass_WAR.EvaluateArms
    RotaCore.State.data.evaluateArmsOff = RotaClass_WAR.EvaluateArmsOff
end

function RotaClass_WAR:DetectBuild()
    local spec, presetId, buildKey = self:DetectSpec()
    return buildKey, presetId, spec
end

RotaClass_WAR.UpdateState = UpdateWarriorState

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "WARRIOR",
        addonName = "RotaClass_WAR",
        classColor = { r = 0.78, g = 0.61, b = 0.43 },
        aoeThreshold = 2,
        builds = {
            { key = "auto", name = "AUTO", color = {1.0, 0.9, 0.0} },
            { key = "fury", name = "Fury (18/53)", color = {1.0, 0.35, 0.2}, preset = "war_fury_pve" },
            {
                key = "fury_overpower",
                name = "Fury OP (20/51)",
                color = {1.0, 0.55, 0.25},
                preset = "war_fury_overpower_pve",
            },
            { key = "arms", name = "Arms (55/8/8)", color = {0.8, 0.4, 0.2}, preset = "war_arms_pve" },
        },
        detectBuild = function() return RotaClass_WAR:DetectBuild() end,
        getIdlePreviewAction = function(buildKey)
            if buildKey == "arms" or buildKey == "war_arms_pve" then
                return "MS"
            else
                return "BT"
            end
        end,
        stateProvider = RotaClass_WAR.UpdateState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("WARRIOR", UpdateWarriorState)
end

-- Event Frame for Talent Updates and Load
if _G.CreateFrame then
    local f = _G.CreateFrame("Frame", "RotaClass_WAR_EventFrame")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_LOGIN" then
            RotaClass_WAR:DetectSpec()
        end
    end)
    RotaClass_WAR.eventFrame = f
end

return RotaClass_WAR
