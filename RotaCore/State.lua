-- RotaCore/State.lua — Zero-Allocation State Engine & Snapshot Provider (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local State = {
    providers = {},
}
RotaCore.State = State

-- Pre-allocated static state table (reused across all evaluations; NEVER re-instantiated in combat)
local stateData = {
    now = 0,
    inCombat = false,
    hasTarget = false,
    targetIsDead = false,
    targetCanAttack = false,
    gcdStart = 0,
    gcdDuration = 0,
    gcdRemains = 0,
    power = 0,
    maxPower = 0,
    powerPct = 0,
    powerType = 0,
    aoeCount = 1,
    aoePlateCount = 0,
    aoeLogCount = 0,
    aoeSwingCount = 0,
    aoeSource = "none",
    aoeMode = false,
    isAoE = false,
    burstMode = true,
    api = {
        nameplates = false,
        nameplatesReason = nil,
        ccChecks = false,
        silenceChecks = false,
        disarmChecks = false,
        clipboard = false,
        spellBaseCooldown = false,
    },
    playerSilenced = false,
    playerDisarmed = false,
    targetSilenced = false,
    targetControlled = false,
    ccNearby = false,
    nameplatesActive = false,
    nameplatesCount = 0,
    nameplatesScanIncomplete = false,
    nameplatesEnemiesDisabled = false,
    tickCount = 0,
    lastStateUpdate = 0,
    lastAoeUpdate = 0,
    lastCast = {},
    lastCLEUTime = 0,
    lastCombatLogClear = 0,
    lastAoeDropTime = 0,
    autoAoeActive = false,
    glyphs = {},
    talents = {},
    vars = {},
    class = {},
    runes = {
        bloodReady = 0,
        frostReady = 0,
        unholyReady = 0,
        deathReady = 0,
        effectiveBlood = 0,
        effectiveFrost = 0,
        effectiveUnholy = 0,
        grace = { 0, 0, 0, 0, 0, 0 },
        maxGrace = 0,
        slots = {
            { type = 1, ready = true, start = 0, duration = 0, cdRemains = 0 },
            { type = 1, ready = true, start = 0, duration = 0, cdRemains = 0 },
            { type = 3, ready = true, start = 0, duration = 0, cdRemains = 0 },
            { type = 3, ready = true, start = 0, duration = 0, cdRemains = 0 },
            { type = 2, ready = true, start = 0, duration = 0, cdRemains = 0 },
            { type = 2, ready = true, start = 0, duration = 0, cdRemains = 0 },
        },
    },
    dk = {
        hasGlyphOfDisease = false,
        hasHowlingBlast = false,
        hasScourgeStrike = false,
        hasNervesOfColdSteel = false,
        morbidityPoints = 0,
        nervesPoints = 0,
        scourgeStrikePoints = 0,
        ffRemaining = 0,
        bpRemaining = 0,
        hasFrostFever = false,
        hasBloodPlague = false,
        minDiseaseRemaining = 0,
        desolationRemaining = 0,
        hasDesolation = false,
        bloodTapRemaining = 0,
        hasBloodTap = false,
        killingMachine = false,
        rime = false,
        isBloodReservedForPestilence = false,
        canSpendBloodOnBS = true,
        aoeDiseasedCount = 0,
    },
    pal = {
        hasGlyphOfReckoning = false,
        hasArtOfWar = false,
        artOfWarRemaining = 0,
        hasSeal = false,
        sealName = nil,
        hasSacredShield = false,
        sacredShieldRemaining = 0,
        hasAvengingWrath = false,
        avengingWrathRemaining = 0,
        hasDivinePlea = false,
        divinePleaRemaining = 0,
        targetHealthPct = 100,
        canHammerOfWrath = false,
        isUndeadOrDemon = false,
    },
    war = {
        stance = 1,
        hasGlyphOfShatteringThrow = false,
        hasTasteForBloodTalent = false,
        tasteForBloodPoints = 0,
        hasBloodthirst = false,
        hasMortalStrike = false,
        hasBladestorm = false,
        hasBloodsurge = false,
        bloodsurgeRemaining = 0,
        hasSuddenDeath = false,
        suddenDeathRemaining = 0,
        hasTasteForBlood = false,
        tasteForBloodRemaining = 0,
        hasRend = false,
        rendRemaining = 0,
        targetHealthPct = 100,
        canExecute = false,
        canOverpower = false,
        isHeroicStrikeQueued = false,
        isCleaveQueued = false,
        isNextSwingQueued = false,
        rage = 0,
    },
}

-- FAST QUERY METHODS (0 ALLOCATION — NO CLOSURES IN HOT PATH)

local function QueryBuff(unit, auraName)
    local targetUnit = unit or "player"

    -- Ghoul Frenzy fast-return: if pet cast within 3.0s, assume buff active to avoid spam
    if targetUnit == "pet" and auraName == "Ghoul Frenzy" and stateData.lastCast then
        local lastGF = stateData.lastCast["Ghoul Frenzy"]
            or stateData.lastCast["GF"]
            or stateData.lastCast[63560]
            or stateData.lastCast[49213]
        if lastGF and (stateData.now - lastGF) < 3.0 then
            return 30, 1
        end
    end

    if not _G.UnitBuff and not _G.UnitAura then return 0, 0 end
    local queryFn = _G.UnitBuff or _G.UnitAura

    for i = 1, 40 do
        local name, _, _, count, _, duration, expirationTime = queryFn(targetUnit, i, "HELPFUL")
        if not name then
            break
        end
        if name == auraName then
            local rem = 0
            if expirationTime and expirationTime > 0 then
                rem = expirationTime - stateData.now
                if rem < 0 then rem = 0 end
            elseif duration == 0 then
                rem = 999999 -- Permanent passive buff
            end
            local finalCount = (count and count > 0) and count or 1
            return rem, finalCount
        end
    end
    return 0, 0
end

local function QueryDebuff(unit, debuffName, playerOnly)
    local targetUnit = unit or "target"
    if not _G.UnitDebuff and not _G.UnitAura then return 0, 0 end
    local queryFn = _G.UnitDebuff or _G.UnitAura

    for i = 1, 40 do
        local name, _, _, count, _, duration, expirationTime, unitCaster = queryFn(targetUnit, i, "HARMFUL")
        if not name then
            break
        end
        if name == debuffName then
            if (not playerOnly) or (unitCaster == "player") then
                local rem = 0
                if expirationTime and expirationTime > 0 then
                    rem = expirationTime - stateData.now
                    if rem < 0 then rem = 0 end
                elseif duration == 0 then
                    rem = 999999
                end
                local finalCount = (count and count > 0) and count or 1
                return rem, finalCount
            end
        end
    end
    return 0, 0
end

function stateData.buffRemaining(selfOrName, unitOrName, maybeUnit)
    local name, unit
    if maybeUnit ~= nil then
        name, unit = unitOrName, maybeUnit
    elseif type(selfOrName) == "table" then
        name, unit = unitOrName, "player"
    else
        name, unit = selfOrName, unitOrName or "player"
    end
    local rem, _ = QueryBuff(unit, name)
    return rem or 0
end
stateData.BuffRemaining = stateData.buffRemaining

function stateData.buffCount(selfOrName, unitOrName, maybeUnit)
    local name, unit
    if maybeUnit ~= nil then
        name, unit = unitOrName, maybeUnit
    elseif type(selfOrName) == "table" then
        name, unit = unitOrName, "player"
    else
        name, unit = selfOrName, unitOrName or "player"
    end
    local _, count = QueryBuff(unit, name)
    return count or 0
end
stateData.BuffCount = stateData.buffCount

function stateData.hasBuff(selfOrName, unitOrName, maybeUnit)
    local rem = stateData.buffRemaining(selfOrName, unitOrName, maybeUnit)
    return (rem or 0) > 0
end
stateData.HasBuff = stateData.hasBuff

function stateData.debuffRemaining(selfOrName, unitOrName, playerOnlyOrUnit, maybePlayerOnly)
    local name, unit, playerOnly
    if maybePlayerOnly ~= nil then
        name, unit, playerOnly = unitOrName, playerOnlyOrUnit, maybePlayerOnly
    elseif type(selfOrName) == "table" then
        name = unitOrName
        if type(playerOnlyOrUnit) == "string" then
            unit = playerOnlyOrUnit
            playerOnly = true
        elseif type(playerOnlyOrUnit) == "boolean" then
            unit = "target"
            playerOnly = playerOnlyOrUnit
        else
            unit = "target"
            playerOnly = true
        end
    else
        name = selfOrName
        unit = unitOrName or "target"
        playerOnly = (playerOnlyOrUnit == nil) and true or playerOnlyOrUnit
    end
    local onlyMine = (playerOnly == nil) and true or playerOnly
    local rem, _ = QueryDebuff(unit, name, onlyMine)
    return rem or 0
end
stateData.DebuffRemaining = stateData.debuffRemaining

function stateData.debuffCount(selfOrName, unitOrName, playerOnlyOrUnit, maybePlayerOnly)
    local name, unit, playerOnly
    if maybePlayerOnly ~= nil then
        name, unit, playerOnly = unitOrName, playerOnlyOrUnit, maybePlayerOnly
    elseif type(selfOrName) == "table" then
        name = unitOrName
        if type(playerOnlyOrUnit) == "string" then
            unit = playerOnlyOrUnit
            playerOnly = false
        elseif type(playerOnlyOrUnit) == "boolean" then
            unit = "target"
            playerOnly = playerOnlyOrUnit
        else
            unit = "target"
            playerOnly = false
        end
    else
        name = selfOrName
        unit = unitOrName or "target"
        playerOnly = (playerOnlyOrUnit == nil) and false or playerOnlyOrUnit
    end
    local onlyMine = (playerOnly == nil) and false or playerOnly
    local _, count = QueryDebuff(unit, name, onlyMine)
    return count or 0
end
stateData.DebuffCount = stateData.debuffCount

function stateData.hasDebuff(selfOrName, unitOrName, playerOnlyOrUnit, maybePlayerOnly)
    local rem = stateData.debuffRemaining(selfOrName, unitOrName, playerOnlyOrUnit, maybePlayerOnly)
    return (rem or 0) > 0
end
stateData.HasDebuff = stateData.hasDebuff

function stateData.spellReady(selfOrAlias, maybeAlias)
    local alias = (maybeAlias ~= nil) and maybeAlias or selfOrAlias
    if RotaCore.Spells and RotaCore.Spells.IsReady then
        return RotaCore.Spells:IsReady(alias, stateData.now, stateData.gcdRemains)
    end
    return false
end
stateData.SpellReady = stateData.spellReady
stateData.isReady = stateData.spellReady
stateData.IsReady = stateData.spellReady

function stateData.spellCooldown(selfOrAlias, maybeAlias)
    local alias = (maybeAlias ~= nil) and maybeAlias or selfOrAlias
    if RotaCore.Spells and RotaCore.Spells.GetCooldownRemaining then
        return RotaCore.Spells:GetCooldownRemaining(alias, stateData.now) or 0
    end
    return 0
end
stateData.SpellCooldown = stateData.spellCooldown
stateData.cooldown = stateData.spellCooldown
stateData.Cooldown = stateData.spellCooldown

function stateData.spellUsable(selfOrAlias, maybeAlias)
    local alias = (maybeAlias ~= nil) and maybeAlias or selfOrAlias
    if RotaCore.Spells and RotaCore.Spells.IsUsable then
        return RotaCore.Spells:IsUsable(alias)
    end
    return true
end
stateData.SpellUsable = stateData.spellUsable
stateData.isUsable = stateData.spellUsable
stateData.IsUsable = stateData.spellUsable

function stateData.spellInRange(selfOrAlias, aliasOrUnit, maybeUnit)
    local alias, unit
    if maybeUnit ~= nil then
        alias, unit = aliasOrUnit, maybeUnit
    elseif type(selfOrAlias) == "table" then
        alias, unit = aliasOrUnit, "target"
    else
        alias, unit = selfOrAlias, aliasOrUnit or "target"
    end
    if RotaCore.Spells and RotaCore.Spells.IsInRange then
        return RotaCore.Spells:IsInRange(alias, unit)
    end
    return 1
end
stateData.SpellInRange = stateData.spellInRange
stateData.inRange = stateData.spellInRange
stateData.InRange = stateData.spellInRange

function stateData.hasSpell(selfOrName, nameOrId)
    local target = (nameOrId ~= nil) and nameOrId or selfOrName
    if RotaCore.Spells and RotaCore.Spells.HasSpell then
        return RotaCore.Spells:HasSpell(target)
    end
    return false
end

function stateData.HasSpell(selfOrName, nameOrId)
    local target = (nameOrId ~= nil) and nameOrId or selfOrName
    if RotaCore.Spells and RotaCore.Spells.HasSpell then
        return RotaCore.Spells:HasSpell(target)
    end
    return false
end

stateData.isSpellKnown = stateData.hasSpell
stateData.IsSpellKnown = stateData.HasSpell

function stateData.isCurrentSpell(selfOrAlias, maybeAlias)
    local alias = (maybeAlias ~= nil) and maybeAlias or selfOrAlias
    if not _G.IsCurrentSpell or not alias then return false end
    local sName = RotaCore.Spells and RotaCore.Spells.GetInfo and RotaCore.Spells:GetInfo(alias)
    if sName and _G.IsCurrentSpell(sName) then return true end
    local spellId = RotaCore.Spells and RotaCore.Spells.ResolveID and RotaCore.Spells:ResolveID(alias)
    if spellId and _G.IsCurrentSpell(spellId) then return true end
    return _G.IsCurrentSpell(alias) and true or false
end
stateData.IsCurrentSpell = stateData.isCurrentSpell

local cachedHyperspeedName = "Hyperspeed Acceleration"
local function GetHyperspeedSpellName()
    if cachedHyperspeedName == "Hyperspeed Acceleration" and _G.GetSpellInfo then
        local n = _G.GetSpellInfo(54758)
        if n and n ~= "54758" then
            cachedHyperspeedName = n
        end
    end
    return cachedHyperspeedName
end

--- Determines whether engineering gloves (Hyperspeed Acceleration) are truly ready to use.
-- @param now number|nil
-- @return boolean
function State:AreGlovesReady(now)
    local curTime = now or (stateData.now > 0 and stateData.now or (_G.GetTime and _G.GetTime() or 0))

    -- 1. Check if Hyperspeed Acceleration buff is currently active on player
    local hyperspeedName = GetHyperspeedSpellName()
    if stateData.buffRemaining("Hyperspeed Acceleration", "player") > 0 then
        return false
    end
    if hyperspeedName ~= "Hyperspeed Acceleration" and stateData.buffRemaining(hyperspeedName, "player") > 0 then
        return false
    end
    if _G.UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, _, spellId = _G.UnitBuff("player", i)
            if not name then break end
            if spellId == 54758 or name == "Hyperspeed Acceleration" or name == hyperspeedName then
                return false
            end
        end
    end

    -- 2. Check if Hyperspeed Acceleration was cast within the last 58 seconds
    if stateData.lastCast then
        local lastGloves = stateData.lastCast["Hyperspeed Acceleration"]
            or stateData.lastCast[hyperspeedName]
            or stateData.lastCast[54758]
            or stateData.lastCast["HYPER"]
        if lastGloves and (curTime - lastGloves) < 58 then
            return false
        end
    end

    -- 3. Check equipment slot 10 (Hands)
    if not _G.GetInventoryItemID or not _G.GetInventoryItemCooldown then
        return false
    end
    local itemId = _G.GetInventoryItemID("player", 10)
    if not itemId then
        return false
    end

    local start, duration, enable = _G.GetInventoryItemCooldown("player", 10)
    if enable ~= 1 then
        return false
    end

    if duration and duration > 1.5 and start and start > 0 and ((start + duration) - curTime) > 0 then
        return false
    end

    if start and start > 0 and ((start + duration) - curTime) > 0 then
        return false
    end

    return true
end

function stateData.areGlovesReady(selfOrNow, maybeNow)
    local curNow = (maybeNow ~= nil) and maybeNow or ((type(selfOrNow) == "number") and selfOrNow or nil)
    return State:AreGlovesReady(curNow)
end
stateData.AreGlovesReady = stateData.areGlovesReady

function stateData.safeToSpendPair(selfOrSlotA, slotBOrSlotA, maybeSlotB)
    local slotA, slotB
    if maybeSlotB ~= nil then
        slotA, slotB = slotBOrSlotA, maybeSlotB
    elseif type(selfOrSlotA) == "table" then
        slotA, slotB = slotBOrSlotA, nil
    else
        slotA, slotB = selfOrSlotA, slotBOrSlotA
    end
    if type(slotA) == "string" then
        local lower = slotA:lower()
        if lower:find("blood") or lower == "b" then
            slotA, slotB = 1, 2
        elseif lower:find("unholy") or lower == "u" then
            slotA, slotB = 3, 4
        elseif lower:find("frost") or lower == "f" then
            slotA, slotB = 5, 6
        end
    end
    if type(slotA) == "number" then
        slotB = slotB or (slotA + 1)
        -- In WoW 3.3.5a: 1,2 = Blood (type 1); 3,4 = Unholy (type 2); 5,6 = Frost (type 3)
        local targetType = (slotA == 1) and 1 or ((slotA == 3) and 2 or ((slotA == 5) and 3 or nil))
        if targetType and stateData.runes and stateData.runes.slots then
            local sCheck = stateData.runes.slots[slotA]
            if sCheck and sCheck.type and sCheck.type ~= targetType and sCheck.type ~= 4 then
                local foundA = nil
                local foundB = nil
                for i = 1, 6 do
                    local st = stateData.runes.slots[i]
                    if st and (st.type == targetType or st.type == 4) then
                        if not foundA then
                            foundA = i
                        elseif not foundB then
                            foundB = i
                            break
                        end
                    end
                end
                if foundA and foundB then
                    slotA, slotB = foundA, foundB
                end
            end
        end
    end
    local sA = stateData.runes and stateData.runes.slots and stateData.runes.slots[slotA]
    local sB = stateData.runes and stateData.runes.slots and stateData.runes.slots[slotB]
    if not sA or not sB then return false end

    -- If both runes in the pair are ready:
    -- Spending one leaves the other ready.
    if sA.ready and sB.ready then
        local dndCD = stateData.spellCooldown("DND") or 0
        local gcdRem = stateData.gcdRemains or 0
        if dndCD <= (gcdRem + 0.1) and stateData.canCastRunes(1, 1, 1) then
            -- DnD is ready and we can cast it right now: prioritize DnD
            return false
        end
        return true
    end

    -- If neither rune in the pair is ready:
    if not sA.ready and not sB.ready then
        return false
    end

    -- If only one rune in the pair is ready:
    local dndCD = stateData.spellCooldown("DND") or 0
    local gcdRem = stateData.gcdRemains or 0
    if dndCD <= (gcdRem + 0.1) then
        return false
    end
    if dndCD >= 9.5 then
        return true
    end
    local cdOther = (sA.ready and sB.cdRemains) or (sB.ready and sA.cdRemains) or 0
    if (dndCD - cdOther) >= 1.0 then
        return true
    end
    return false
end
stateData.SafeToSpendPair = stateData.safeToSpendPair

function stateData.grace(selfOrRType, maybeRType)
    local rType = (maybeRType ~= nil) and maybeRType or selfOrRType
    if type(rType) == "string" then
        local lower = rType:lower()
        if lower == "blood" or lower == "b" then rType = 1
        elseif lower == "unholy" or lower == "u" then rType = 2
        elseif lower == "frost" or lower == "f" then rType = 3
        elseif lower == "death" or lower == "d" then rType = 4
        end
    end
    local runes = stateData.runes
    if not runes or not runes.slots then return 0 end

    local maxG = 0
    for s = 1, 6 do
        local slotData = runes.slots[s]
        if slotData and (slotData.type == rType or (slotData.type == 4 and (rType == 2 or rType == 3))) then
            local g = runes.grace[s] or 0
            if g > maxG then maxG = g end
        end
    end
    return maxG
end
stateData.Grace = stateData.grace

function stateData.canWithRunes(selfOrLim, arg1, arg2, arg3, arg4, arg5)
    local lim, reqBlood, reqFrost, reqUnholy, reserveBloodForPest
    if type(selfOrLim) == "table" then
        lim, reqBlood, reqFrost, reqUnholy, reserveBloodForPest = arg1, arg2, arg3, arg4, arg5
    else
        lim, reqBlood, reqFrost, reqUnholy, reserveBloodForPest = selfOrLim, arg1, arg2, arg3, arg4
    end

    lim = lim or 0
    reqBlood = reqBlood or 0
    reqFrost = reqFrost or 0
    reqUnholy = reqUnholy or 0

    local runes = stateData.runes
    if not runes or not runes.slots then return false end

    local nb, nu, nf, nd = 0, 0, 0, 0
    for s = 1, 6 do
        local slotData = runes.slots[s]
        if slotData and slotData.cdRemains <= lim then
            local t = slotData.type
            if t == 1 then nb = nb + 1
            elseif t == 2 then nu = nu + 1
            elseif t == 3 then nf = nf + 1
            elseif t == 4 then nd = nd + 1
            end
        end
    end

    local missB = math.max(0, reqBlood - nb)
    local missF = math.max(0, reqFrost - nf)
    local missU = math.max(0, reqUnholy - nu)
    local totalDeathNeeded = missB + missF + missU
    if nd < totalDeathNeeded then return false end

    -- Smart Pestilence Rune Reservation
    local checkReserve = (reserveBloodForPest == true) or (reserveBloodForPest == nil and stateData.dk and stateData.dk.reserveActive)
    if checkReserve and stateData.dk and stateData.dk.reserveActive then
        local ffRem = stateData.dk.ffRemaining or 0
        local bpRem = stateData.dk.bpRemaining or 0
        local minDis = math.min(ffRem, bpRem)
        local btCD = (stateData.spellCooldown and (stateData.spellCooldown("BT") or stateData.spellCooldown("Blood Tap"))) or 0
        local isObliterateCost = (reqBlood == 0 and reqFrost >= 1 and reqUnholy >= 1)

        -- Desbloqueo de Obliterate con runas de Muerte (Blood of the North):
        -- Permite gastar Death Runes en Obliterate siempre que minDisease > 3.5s o Blood Tap esté listo (btCD == 0)
        local obliterateUnlocked = isObliterateCost and (minDis > 3.5 or btCD == 0)
        if not obliterateUnlocked then
            local costBD = reqBlood + missF + missU
            local leftBD = (nb + nd) - costBD
            if leftBD < 1 then
                local rechargeLimit = minDis - 1.0
                local rechargeCount = 0
                for s = 1, 6 do
                    local slotData = runes.slots[s]
                    if slotData and (slotData.type == 1 or slotData.type == 4) then
                        if slotData.cdRemains <= rechargeLimit then
                            rechargeCount = rechargeCount + 1
                        end
                    end
                end
                if (rechargeCount - costBD) < 1 then
                    return false
                end
            end
        end
    end

    return true
end
stateData.CanWithRunes = stateData.canWithRunes

function stateData.canCastRunes(selfOrB, fOrB, uOrF, maybeU)
    local b, f, u
    if maybeU ~= nil then
        b, f, u = fOrB, uOrF, maybeU
    elseif type(selfOrB) == "table" then
        b, f, u = fOrB, uOrF, 0
    else
        b, f, u = selfOrB, fOrB, uOrF
    end
    return stateData.canWithRunes(0, b or 0, f or 0, u or 0, false)
end
stateData.CanCastRunes = stateData.canCastRunes

function stateData.dndReadyIn()
    return stateData.spellCooldown("DND") or 0
end
stateData.DndReadyIn = stateData.dndReadyIn

local bit_band = (_G.bit and _G.bit.band) or function(a, b)
    local p, c = 1, 0
    while a > 0 and b > 0 do
        local ra, rb = a % 2, b % 2
        if ra == 1 and rb == 1 then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    return c
end

local AFFILIATION_MINE = _G.COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local REACTION_HOSTILE = _G.COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040

State.plateGUIDs = {}
State.logDamagedGUIDs = {}
State.logSwingGUIDs = {}
State.activeLogGUIDs = {}
State.fusedGUIDs = {}

local NAMEPLATE_TOKENS = {}
for i = 1, 40 do
    NAMEPLATE_TOKENS[i] = "nameplate" .. i
end

RotaCore.AoERange = RotaCore.AoERange or {
    DEATHKNIGHT = 34368, -- ~8 yd
    PALADIN     = 34368, -- ~8 yd
    WARRIOR     = 34368, -- ~8 yd
    ROGUE       = 34368, -- ~8 yd
    SHAMAN      = 34368, -- ~8 yd (Elemental: usar AoE manual)
    WARLOCK     = 34368, -- ~8 yd (caster: usar AoE manual)
    MAGE        = 34368, -- ~8 yd (caster: usar AoE manual)
    PRIEST      = 34368, -- ~8 yd (caster: usar AoE manual)
    HUNTER      = 34368, -- ~8 yd (a distancia: usar AoE manual)
    DRUID       = 34368, -- ~8 yd (Balance: usar AoE manual)
}

function State:OnCombatLogEvent(...)
    local timestamp, subEvent, sourceGUID, _, sourceFlags, destGUID, destName, destFlags = ...
    if type(timestamp) == "string" and not subEvent then
        subEvent = timestamp
    end
    if not subEvent then return end

    local now = (_G.GetTime and _G.GetTime()) or stateData.now
    if stateData.now and stateData.now > now then
        now = stateData.now
    end
    stateData.lastCLEUTime = now

    if subEvent == "UNIT_DIED" then
        if destGUID then
            State.logDamagedGUIDs[destGUID] = nil
            State.logSwingGUIDs[destGUID] = nil
        end
        return
    end

    -- Component 1: Enemies damaged by me or my pets/guardians
    local isDamage = (subEvent == "SWING_DAMAGE" or subEvent == "SPELL_DAMAGE"
        or subEvent == "SPELL_PERIODIC_DAMAGE" or subEvent == "RANGE_DAMAGE"
        or subEvent == "DAMAGE_SHIELD" or subEvent == "DAMAGE_SPLIT")
    if isDamage and sourceFlags and destFlags and destGUID and destGUID ~= "" then
        if bit_band(sourceFlags, AFFILIATION_MINE) ~= 0 and bit_band(destFlags, REACTION_HOSTILE) ~= 0 then
            State.logDamagedGUIDs[destGUID] = now
        end
    end

    -- Component 2: Enemies swinging at player (melee attackers)
    local db = _G.RotaCoreDB
    local swingEnabled = not db or db.aoeSwingSignal ~= false
    if swingEnabled and (subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED") then
        if sourceGUID and sourceGUID ~= "" and sourceFlags and destGUID then
            local playerGUID = (_G.UnitGUID and _G.UnitGUID("player")) or stateData.playerGUID
            local isDestPlayer = (destGUID == playerGUID) or (destName and _G.UnitIsUnit and _G.UnitIsUnit(destName, "player"))
            if isDestPlayer and bit_band(sourceFlags, REACTION_HOSTILE) ~= 0 then
                State.logSwingGUIDs[sourceGUID] = now
            end
        end
    end
end

function State:OnSpellcastSucceeded(unit, spellName)
    if unit ~= "player" then return end
    local now = _G.GetTime and _G.GetTime() or stateData.now
    if spellName then
        stateData.lastCast[spellName] = now
        if spellName == "Ghoul Frenzy" then
            stateData.lastCast["GF"] = now
            stateData.lastCast[63560] = now
            stateData.lastCast[49213] = now
        elseif spellName == "Hyperspeed Acceleration" then
            stateData.lastCast["HYPER"] = now
            stateData.lastCast[54758] = now
        elseif spellName == "Pestilence" then
            stateData.lastCast["PEST"] = now
            stateData.lastCast[50842] = now
        elseif spellName == "Raise Dead" then
            stateData.lastCast["RD"] = now
            stateData.lastCast[46584] = now
        elseif spellName == "Blood Tap" then
            stateData.lastCast["BT"] = now
            stateData.lastCast[45529] = now
        end
    end

    -- Watchdog: if in combat and Combat Log has been silent > 3.5s, trigger CombatLogClearEntries()
    local inCombat = (_G.UnitAffectingCombat and _G.UnitAffectingCombat("player")) or stateData.inCombat
    if inCombat then
        if (now - (stateData.lastCLEUTime or 0)) > 3.5 then
            if (now - (stateData.lastCombatLogClear or 0)) >= 10.0 then
                stateData.lastCombatLogClear = now
                if _G.CombatLogClearEntries then
                    _G.CombatLogClearEntries()
                end
            end
        end
    end
end

State.data = stateData

--- Registers a class-specific state updater hook.
-- @param classKey string e.g. "DEATHKNIGHT"
-- @param providerFn function(state, now)
function State:RegisterProvider(classKey, providerFn)
    State.providers[classKey] = providerFn
end

--- Scans active player talents and glyph sockets (WoW 3.3.5a / WotLK Rebuffed)
function State:ScanTalentsAndGlyphs()
    if not _G.UnitClass then return end
    local _, playerClass = _G.UnitClass("player")
    if not playerClass then return end

    -- 1. Scan Glyphs (sockets 1 to 6)
    local glyphMap = {}
    local hasGlyphOfDisease = false
    local hasGlyphOfReckoning = false
    local hasGlyphOfShatteringThrow = false

    if _G.GetGlyphSocketInfo then
        for i = 1, 6 do
            local enabled, _, glyphSpellID = _G.GetGlyphSocketInfo(i)
            if enabled and glyphSpellID and glyphSpellID > 0 then
                glyphMap[glyphSpellID] = true
                local gName = _G.GetSpellInfo and _G.GetSpellInfo(glyphSpellID)
                if gName then
                    glyphMap[gName] = true
                    local lowerName = gName:lower()
                    if lowerName:find("disease") or lowerName:find("enfermedad") then
                        hasGlyphOfDisease = true
                    end
                    if lowerName:find("reckoning") or lowerName:find("expiación") or lowerName:find("expiacion") then
                        hasGlyphOfReckoning = true
                    end
                    if lowerName:find("shattering throw") or lowerName:find("lanzamiento destrozador") then
                        hasGlyphOfShatteringThrow = true
                    end
                end
                if glyphSpellID == 63334 or glyphSpellID == 58680 then
                    hasGlyphOfDisease = true
                end
                if glyphSpellID == 62124 or glyphSpellID == 54928 then
                    hasGlyphOfReckoning = true
                end
                if glyphSpellID == 58357 or glyphSpellID == 64382 then
                    hasGlyphOfShatteringThrow = true
                end
            end
        end
    end

    stateData.glyphs = glyphMap
    stateData.dk.hasGlyphOfDisease = hasGlyphOfDisease
    stateData.pal.hasGlyphOfReckoning = hasGlyphOfReckoning
    stateData.war.hasGlyphOfShatteringThrow = hasGlyphOfShatteringThrow

    -- 2. Scan Talents
    local numTabs = _G.GetNumTalentTabs and _G.GetNumTalentTabs() or 3
    stateData.dk.hasHowlingBlast = false
    stateData.dk.hasScourgeStrike = false
    stateData.dk.hasNervesOfColdSteel = false
    stateData.dk.morbidityPoints = 0
    stateData.dk.nervesPoints = 0
    stateData.dk.scourgeStrikePoints = 0

    stateData.war.hasTasteForBloodTalent = false
    stateData.war.tasteForBloodPoints = 0
    stateData.war.hasBloodthirst = false
    stateData.war.hasMortalStrike = false
    stateData.war.hasBladestorm = false

    for tab = 1, numTabs do
        local numTalents = _G.GetNumTalents and _G.GetNumTalents(tab) or 0
        for idx = 1, numTalents do
            local name, _, _, _, rank = _G.GetTalentInfo(tab, idx)
            local r = rank or 0
            if name and r > 0 then
                local lower = name:lower()
                if playerClass == "DEATHKNIGHT" then
                    if lower:find("howling blast") or lower:find("explosión aullante") or lower:find("explosion aullante") then
                        stateData.dk.hasHowlingBlast = true
                    elseif lower:find("nerves of cold steel") or lower:find("nervios de acero") then
                        stateData.dk.hasNervesOfColdSteel = true
                        stateData.dk.nervesPoints = r
                    elseif lower:find("morbidity") or lower:find("morbilidad") then
                        stateData.dk.morbidityPoints = r
                    elseif lower:find("scourge strike") or lower:find("golpe de la plaga") then
                        stateData.dk.hasScourgeStrike = true
                        stateData.dk.scourgeStrikePoints = r
                    end
                elseif playerClass == "WARRIOR" then
                    if lower:find("taste for blood") or lower:find("gusto por la sangre") then
                        stateData.war.hasTasteForBloodTalent = true
                        stateData.war.tasteForBloodPoints = r
                    elseif lower:find("bloodthirst") or lower:find("sed de sangre") then
                        stateData.war.hasBloodthirst = true
                    elseif lower:find("mortal strike") or lower:find("golpe mortal") then
                        stateData.war.hasMortalStrike = true
                    elseif lower:find("bladestorm") or lower:find("filotormenta") then
                        stateData.war.hasBladestorm = true
                    end
                end
            end
        end
    end

    if playerClass == "DEATHKNIGHT" then
        if _G.IsSpellKnown then
            if _G.IsSpellKnown(49143) or _G.IsSpellKnown(51411) then
                stateData.dk.hasHowlingBlast = true
            end
            if _G.IsSpellKnown(55090) or _G.IsSpellKnown(55271) then
                stateData.dk.hasScourgeStrike = true
            end
            if _G.IsSpellKnown(49011) or _G.IsSpellKnown(49012) or _G.IsSpellKnown(49013) then
                stateData.dk.hasNervesOfColdSteel = true
            end
        end
        local mod = RotaCore.GetClassModule and RotaCore:GetClassModule(playerClass)
        if mod and mod.detectBuild then
            pcall(mod.detectBuild)
        elseif _G.RotaClass_DK and _G.RotaClass_DK.DetectBuild then
            pcall(function() _G.RotaClass_DK:DetectBuild() end)
        end
    elseif playerClass == "WARRIOR" then
        if _G.IsSpellKnown then
            if _G.IsSpellKnown(23881) then stateData.war.hasBloodthirst = true end
            if _G.IsSpellKnown(12294) then stateData.war.hasMortalStrike = true end
            if _G.IsSpellKnown(46924) then stateData.war.hasBladestorm = true end
        end
        local mod = RotaCore.GetClassModule and RotaCore:GetClassModule(playerClass)
        if mod and mod.detectBuild then
            pcall(mod.detectBuild)
        elseif _G.RotaClass_WAR and _G.RotaClass_WAR.DetectSpec then
            pcall(function() _G.RotaClass_WAR:DetectSpec() end)
        end
    else
        local mod = RotaCore.GetClassModule and RotaCore:GetClassModule(playerClass)
        if mod and mod.detectBuild then
            pcall(mod.detectBuild)
        end
    end
end

State.activePlates = {}

function State:OnNameplateAdded(plateOrToken)
    if plateOrToken then
        State.activePlates[plateOrToken] = true
    end
end

function State:OnNameplateRemoved(plateOrToken)
    if plateOrToken then
        State.activePlates[plateOrToken] = nil
    end
end

local function CheckUnitPlateRange(unit, itemId)
    if itemId and _G.IsItemInRange then
        local inRange = _G.IsItemInRange(itemId, unit)
        if inRange == 1 then
            return true
        elseif inRange == 0 then
            return false
        end
    end
    if _G.CheckInteractDistance then
        local dist = _G.CheckInteractDistance(unit, 3)
        if dist == 1 or dist == true then
            return true
        end
    end
    return false
end

local function EvaluatePlateUnit(unit, playerClass, rangeItem)
    if not _G.UnitExists(unit) then return false end
    local guid = _G.UnitGUID and _G.UnitGUID(unit)
    if not guid then return false end

    local isDead = (_G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost(unit)) or (_G.UnitIsDead and _G.UnitIsDead(unit))
    if isDead then return false end

    local canAttack = (_G.UnitCanAttack and _G.UnitCanAttack("player", unit))
    if not canAttack then return false end

    local inCombat = (_G.UnitAffectingCombat and _G.UnitAffectingCombat(unit))
    if not inCombat then return false end

    if not CheckUnitPlateRange(unit, rangeItem) then
        return false
    end

    local Compat = RotaCore.Compat
    local isCC = (Compat and Compat.UnitIsControlled and Compat.UnitIsControlled(unit))
    local isTarget = (_G.UnitIsUnit and _G.UnitIsUnit(unit, "target"))
    if isCC and not isTarget and (_G.RotaCoreDB and _G.RotaCoreDB.useCCExclusion == true) then
        return false, guid, true, false
    end

    local isDis = false
    if playerClass == "DEATHKNIGHT" then
        local ffRem = QueryDebuff(unit, "Frost Fever", true)
        local bpRem = QueryDebuff(unit, "Blood Plague", true)
        if ffRem > 0 and bpRem > 0 then
            isDis = true
        end
    end

    return true, guid, isCC, isDis
end

function State:UpdateStatusAndEnemies(playerClass)
    local Compat = RotaCore.Compat
    if Compat then
        if Compat.Refresh then Compat:Refresh() end
        stateData.api.nameplates = Compat.hasNameplates
        stateData.api.ccChecks = Compat.hasCC
        stateData.api.silenceChecks = Compat.hasSilence
        stateData.api.disarmChecks = Compat.hasDisarm
        stateData.api.clipboard = Compat.hasClipboard
        stateData.api.spellBaseCooldown = Compat.hasSpellBaseCD

        stateData.playerSilenced = Compat.UnitIsSilenced("player")
        stateData.playerDisarmed = Compat.UnitIsDisarmed("player")
        if stateData.hasTarget and not stateData.targetIsDead then
            stateData.targetSilenced = Compat.UnitIsSilenced("target")
            stateData.targetControlled = Compat.UnitIsControlled("target")
        else
            stateData.targetSilenced = false
            stateData.targetControlled = false
        end
    else
        stateData.playerSilenced = false
        stateData.playerDisarmed = false
        stateData.targetSilenced = false
        stateData.targetControlled = false
    end

    stateData.ccNearby = false
    if stateData.dk then
        stateData.dk.aoeDiseasedCount = 0
    end

    local now = stateData.now
    stateData.lastAoeUpdate = now

    -- -------------------------------------------------------------
    -- Señal A: Nameplates (Enumeración directa 1..40 deduplicada por GUID)
    -- -------------------------------------------------------------
    local plateCount = 0
    local plateGUIDs = State.plateGUIDs
    for k in pairs(plateGUIDs) do plateGUIDs[k] = nil end

    local npReason = nil
    local npAvailable = false

    local showEnemies = _G.GetCVar and _G.GetCVar("nameplateShowEnemies")
    if showEnemies == "0" then
        stateData.nameplatesActive = false
        stateData.nameplatesCount = 0
        stateData.nameplatesScanIncomplete = false
        stateData.nameplatesEnemiesDisabled = true
        npReason = "nameplates enemigas desactivadas"
    else
        stateData.nameplatesEnemiesDisabled = false
        if Compat and Compat.hasNameplates and stateData.api.nameplates ~= false then
            local expectedPlates = nil
            local plateList = Compat.GetNamePlates and Compat.GetNamePlates()
            if type(plateList) == "table" then
                expectedPlates = #plateList
            end

            local rangeItem = (RotaCore.AoERange and RotaCore.AoERange[playerClass]) or 34368
            local unitsFound = 0
            local diseasedCount = 0

            for i = 1, 40 do
                local token = NAMEPLATE_TOKENS[i]
                if _G.UnitExists and _G.UnitExists(token) then
                    unitsFound = unitsFound + 1
                    local ok, passes, guid, isCC, isDis = pcall(EvaluatePlateUnit, token, playerClass, rangeItem)
                    if ok then
                        if isCC then stateData.ccNearby = true end
                        if passes and guid then
                            if not plateGUIDs[guid] then
                                plateGUIDs[guid] = true
                                plateCount = plateCount + 1
                            end
                            if isDis then diseasedCount = diseasedCount + 1 end
                        end
                    end

                    if expectedPlates and unitsFound >= expectedPlates then
                        break
                    end
                end
            end

            if expectedPlates and unitsFound < expectedPlates then
                stateData.nameplatesScanIncomplete = true
            else
                stateData.nameplatesScanIncomplete = false
            end

            stateData.nameplatesCount = unitsFound
            stateData.nameplatesActive = (unitsFound > 0 or plateCount > 0)
            npAvailable = true

            if playerClass == "DEATHKNIGHT" and stateData.dk then
                stateData.dk.aoeDiseasedCount = diseasedCount
            end
        else
            stateData.nameplatesActive = false
            stateData.nameplatesCount = 0
            stateData.nameplatesScanIncomplete = false
        end
    end

    stateData.aoePlateCount = plateCount
    stateData.api.nameplatesReason = npReason

    -- -------------------------------------------------------------
    -- Señal B: Combat Log (Dañados por mí + Atacantes en melee)
    -- -------------------------------------------------------------
    local window = (_G.RotaCoreDB and _G.RotaCoreDB.aoeLogWindow) or 4.0
    local activeLogGUIDs = State.activeLogGUIDs
    for k in pairs(activeLogGUIDs) do activeLogGUIDs[k] = nil end

    local logCount = 0
    for guid, lastSeen in pairs(State.logDamagedGUIDs) do
        if (now - lastSeen) <= window then
            activeLogGUIDs[guid] = true
            logCount = logCount + 1
        else
            State.logDamagedGUIDs[guid] = nil
        end
    end

    local swingCount = 0
    local swingEnabled = not _G.RotaCoreDB or _G.RotaCoreDB.aoeSwingSignal ~= false
    for guid, lastSeen in pairs(State.logSwingGUIDs) do
        if (now - lastSeen) <= window then
            swingCount = swingCount + 1
            if swingEnabled then
                if not activeLogGUIDs[guid] then
                    activeLogGUIDs[guid] = true
                    logCount = logCount + 1
                end
            end
        else
            State.logSwingGUIDs[guid] = nil
        end
    end

    stateData.aoeLogCount = logCount
    stateData.aoeSwingCount = swingCount

    -- -------------------------------------------------------------
    -- Fusión de Señales: union | confirm | plates | classic
    -- -------------------------------------------------------------
    local fusionMode = (_G.RotaCoreDB and _G.RotaCoreDB.aoeFusion) or "union"
    if not npAvailable then
        fusionMode = "classic"
    end

    local hasValidTarget = stateData.hasTarget and not stateData.targetIsDead and stateData.targetCanAttack
    local finalCount
    local aoeSource

    if fusionMode == "union" then
        local fused = State.fusedGUIDs
        for k in pairs(fused) do fused[k] = nil end
        local count = 0
        for g in pairs(plateGUIDs) do
            fused[g] = true
            count = count + 1
        end
        for g in pairs(activeLogGUIDs) do
            if not fused[g] then
                fused[g] = true
                count = count + 1
            end
        end

        if plateCount > 0 and logCount > 0 then
            aoeSource = "both"
        elseif plateCount > 0 then
            aoeSource = "plates"
        elseif logCount > 0 then
            aoeSource = "log"
        else
            aoeSource = "none"
        end

        if count == 0 and hasValidTarget then
            count = math.max(1, stateData.aoeCount or 1)
            if aoeSource == "none" then aoeSource = "classic" end
        end
        finalCount = math.max(1, count)

    elseif fusionMode == "confirm" then
        local c = math.min(plateCount, logCount)
        if plateCount > 0 and logCount > 0 then
            aoeSource = "both"
        elseif plateCount > 0 then
            aoeSource = "plates"
        elseif logCount > 0 then
            aoeSource = "log"
        else
            aoeSource = "none"
        end

        if c == 0 and hasValidTarget then
            c = 1
            if aoeSource == "none" then aoeSource = "classic" end
        end
        finalCount = math.max(1, c)

    elseif fusionMode == "plates" then
        if plateCount > 0 then
            finalCount = plateCount
            aoeSource = "plates"
        elseif hasValidTarget then
            finalCount = math.max(1, (logCount > 0) and logCount or (stateData.aoeCount or 1))
            aoeSource = "classic"
        else
            finalCount = 1
            aoeSource = "none"
        end

    else -- "classic"
        if logCount > 0 then
            finalCount = logCount
        elseif hasValidTarget then
            finalCount = math.max(1, stateData.aoeCount or 1)
        else
            finalCount = 1
        end
        aoeSource = "classic"
    end

    stateData.aoeCount = finalCount
    stateData.aoeSource = aoeSource
end

--- Updates all core state metrics. MUST produce 0 KB/s GC in regime.
-- @param now number|nil Optional explicit time for deterministic tests
-- @return table Pre-allocated stateData table
function State:Update(now)
    stateData.now = now or (_G.GetTime and _G.GetTime() or 0)
    stateData.tickCount = (stateData.tickCount or 0) + 1
    stateData.lastStateUpdate = stateData.now
    stateData.suggestedOff = nil

    local playerClass = nil
    if _G.UnitClass then
        local _, c = _G.UnitClass("player")
        playerClass = c
    end

    -- Target status
    if _G.UnitExists then
        stateData.hasTarget = _G.UnitExists("target") and true or false
        stateData.targetIsDead = (_G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost("target")) and true or false
        stateData.targetCanAttack = (_G.UnitCanAttack and _G.UnitCanAttack("player", "target")) and true or false
    else
        stateData.hasTarget = true
        stateData.targetIsDead = false
        stateData.targetCanAttack = true
    end

    State:UpdateStatusAndEnemies(playerClass)

    if _G.UnitHealth and _G.UnitHealthMax and stateData.hasTarget then
        local th = _G.UnitHealth("target") or 0
        local thm = _G.UnitHealthMax("target") or 0
        stateData.targetHealthPct = (thm > 0) and (th / thm * 100) or 100
    else
        stateData.targetHealthPct = 100
    end

    -- Global Cooldown (GCD) check via standard GCD spell (e.g. 61304) or Spells helper
    if _G.GetSpellCooldown then
        local gcdStart, gcdDur = _G.GetSpellCooldown(61304)
        if gcdDur and gcdDur > 0 and gcdDur <= 1.5 then
            stateData.gcdStart = gcdStart
            stateData.gcdDuration = gcdDur
            local rem = (gcdStart + gcdDur) - stateData.now
            stateData.gcdRemains = rem > 0 and rem or 0
        else
            stateData.gcdRemains = 0
            stateData.gcdStart = 0
            stateData.gcdDuration = 0
        end
    end

    -- Power / Resources
    if _G.UnitPower then
        local pType = 0
        if _G.UnitClass then
            local _, classToken = _G.UnitClass("player")
            if classToken == "WARRIOR" then
                pType = 1
            elseif classToken == "DEATHKNIGHT" then
                pType = 6
            elseif classToken == "ROGUE" then
                pType = 3
            end
        end
        stateData.powerType = pType
        stateData.power = _G.UnitPower("player", pType)
        stateData.maxPower = _G.UnitPowerMax and _G.UnitPowerMax("player", pType) or 100
        stateData.powerPct = (stateData.maxPower > 0) and (stateData.power / stateData.maxPower * 100) or 0
    end

    -- Settings: Burst Mode & AoE Mode computation (0 allocation)
    local dbSettings = _G.RotaCoreDB and _G.RotaCoreDB.settings
    if dbSettings then
        stateData.burstMode = (dbSettings.burstMode ~= false)
        local aoeSetting = dbSettings.aoeMode
        if aoeSetting == "OFF" or aoeSetting == false then
            stateData.aoeMode = false
        elseif aoeSetting == "ON" or (aoeSetting == true and dbSettings.autoAoE == false) then
            stateData.aoeMode = true
        else -- "AUTO" or default
            local mod = RotaCore.GetClassModule and RotaCore:GetClassModule(playerClass)
            local aoeThreshold = (mod and mod.aoeThreshold)
                or (stateData.vars and stateData.vars.aoeTargets)
                or (playerClass == "WARRIOR" and 2 or 3)
            local aoeDropThreshold = (aoeThreshold <= 2) and 1 or 2

            if stateData.aoeCount >= aoeThreshold then
                stateData.autoAoeActive = true
                stateData.lastAoeDropTime = 0
            elseif stateData.aoeCount <= aoeDropThreshold then
                if stateData.autoAoeActive then
                    if stateData.lastAoeDropTime == 0 then
                        stateData.lastAoeDropTime = stateData.now
                    end
                    if (stateData.now - stateData.lastAoeDropTime) >= 3.0 then
                        stateData.autoAoeActive = false
                        stateData.lastAoeDropTime = 0
                    end
                else
                    stateData.autoAoeActive = false
                    stateData.lastAoeDropTime = 0
                end
            end

            -- Watchdog Fallback: if Combat Log hasn't reported for > 4.0s in combat, fallback to ST (only when nameplates are not active)
            local cleuSilent = (not stateData.nameplatesActive) and stateData.inCombat
                and stateData.lastCLEUTime > 0 and (stateData.now - stateData.lastCLEUTime) > 4.0
            if cleuSilent then
                stateData.aoeMode = false
            else
                stateData.aoeMode = stateData.autoAoeActive or false
            end
        end
    else
        stateData.burstMode = true
        stateData.aoeMode = false
    end
    stateData.isAoE = stateData.aoeMode

    -- Execute registered class providers (e.g. DK runes, grace period, Desolation)
    for _, provider in pairs(State.providers) do
        provider(stateData, stateData.now)
    end

    return stateData
end

-- Pre-allocated event listener frame for Combat Log & Succeeded Casts
if _G.CreateFrame then
    local stateEventFrame = _G.CreateFrame("Frame", "RotaCoreStateEventFrame")
    stateEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    stateEventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    stateEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    stateEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    stateEventFrame:RegisterEvent("PLAYER_LOGIN")
    stateEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    stateEventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    stateEventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    stateEventFrame:RegisterEvent("GLYPH_UPDATED")
    stateEventFrame:RegisterEvent("GLYPH_ADDED")
    stateEventFrame:RegisterEvent("GLYPH_REMOVED")
    stateEventFrame:RegisterEvent("NAME_PLATE_CREATED")
    stateEventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    stateEventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    stateEventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            State:OnCombatLogEvent(...)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, spellName = ...
            State:OnSpellcastSucceeded(unit, spellName)
        elseif event == "PLAYER_REGEN_DISABLED" then
            stateData.inCombat = true
            stateData.lastCLEUTime = _G.GetTime and _G.GetTime() or stateData.now
        elseif event == "PLAYER_REGEN_ENABLED" then
            stateData.inCombat = false
        elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_CREATED" then
            local plateOrToken = ...
            State:OnNameplateAdded(plateOrToken)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            local plateOrToken = ...
            State:OnNameplateRemoved(plateOrToken)
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or
               event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" or
               event == "GLYPH_UPDATED" or event == "GLYPH_ADDED" or event == "GLYPH_REMOVED" then
            if event == "PLAYER_ENTERING_WORLD" then
                for k in pairs(State.activePlates) do
                    State.activePlates[k] = nil
                end
                for k in pairs(State.logDamagedGUIDs) do
                    State.logDamagedGUIDs[k] = nil
                end
                for k in pairs(State.logSwingGUIDs) do
                    State.logSwingGUIDs[k] = nil
                end
            end
            State:ScanTalentsAndGlyphs()
        end
    end)
    State.eventFrame = stateEventFrame
end

return State
