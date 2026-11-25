-- RotaClass_DK/RotaClass_DK.lua — Death Knight 6 Runes, Grace Period, Build Detection & Presets (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_DK = {
    readySince = { 0, 0, 0, 0, 0, 0 },
    detectedBuild = "unholy_2h",
    detectedPresetId = "dk_unholy_2h_pve",
    detectedSpecName = "UH",
    detectedBadge = "[U]",
}
_G.RotaClass_DK = RotaClass_DK

local MAX_GRACE_PERIOD = 2.5

local cachedGFName = "Ghoul Frenzy"
local function GetGFSpellName()
    if cachedGFName == "Ghoul Frenzy" and _G.GetSpellInfo then
        local localizedGF = _G.GetSpellInfo(49213) or _G.GetSpellInfo(63560)
        if localizedGF and localizedGF ~= "49213" and localizedGF ~= "63560" then
            cachedGFName = localizedGF
        end
    end
    return cachedGFName
end

--- Safe spell check helper for DK provider to prevent any attempt to call method errors
local function DKHasSpell(spellOrId)
    if not spellOrId then return false end
    if type(spellOrId) == "number" and _G.IsSpellKnown and _G.IsSpellKnown(spellOrId) then
        return true
    end
    if RotaCore.Spells and (RotaCore.Spells.HasSpell or RotaCore.Spells.hasSpell) then
        local fn = RotaCore.Spells.HasSpell or RotaCore.Spells.hasSpell
        local ok, res = pcall(fn, RotaCore.Spells, spellOrId)
        if not ok then ok, res = pcall(fn, spellOrId) end
        if ok and res then return true end
    end
    if _G.GetSpellCooldown then
        return _G.GetSpellCooldown(spellOrId) ~= nil
    end
    return false
end

RotaClass_DK.HasSpell = function(selfOrSpell, spell)
    local target = (spell ~= nil) and spell or selfOrSpell
    return DKHasSpell(target)
end
RotaClass_DK.hasSpell = RotaClass_DK.HasSpell

local function HasDKSpell(state, alias)
    if state and state.hasSpell then
        local s = state.hasSpell(alias)
        if s ~= nil then return s end
        if alias == "OBL" then
            s = state.hasSpell("OB") or state.hasSpell("Obliterate")
            if s ~= nil then return s end
        elseif alias == "OB" then
            s = state.hasSpell("OBL") or state.hasSpell("Obliterate")
            if s ~= nil then return s end
        elseif alias == "FS" then
            s = state.hasSpell("Frost Strike")
            if s ~= nil then return s end
        elseif alias == "HB" then
            s = state.hasSpell("Howling Blast")
            if s ~= nil then return s end
        elseif alias == "HOW" then
            s = state.hasSpell("Horn of Winter")
            if s ~= nil then return s end
        end
    end
    local has = DKHasSpell(alias)
    if not has and (alias == "OBL" or alias == "OB") then
        has = DKHasSpell("OBL") or DKHasSpell("OB") or DKHasSpell("Obliterate") or DKHasSpell(49020)
    elseif not has and alias == "FS" then
        has = DKHasSpell("Frost Strike") or DKHasSpell(49143)
    end
    return has
end

--- Updates Death Knight runes, grace period, disease timers and Desolation status.
-- @param state table Pre-allocated RotaCore.State.data table
-- @param now number Current timestamp
local function UpdateDKState(state, now)
    local runes = state.runes
    local dk = state.dk

    runes.bloodReady = 0
    runes.frostReady = 0
    runes.unholyReady = 0
    runes.deathReady = 0
    runes.maxGrace = 0

    -- 1. Scan 6 Runes & Calculate 2.5s Grace Period
    if _G.GetRuneCooldown and _G.GetRuneType then
        for slot = 1, 6 do
            local start, duration, runeReady = _G.GetRuneCooldown(slot)
            local rType = _G.GetRuneType(slot)
            local slotData = runes.slots[slot]

            slotData.type = rType
            slotData.start = start or 0
            slotData.duration = duration or 0

            local rem = (runeReady or not start or start == 0) and 0 or math.max(0, (start + duration) - now)
            slotData.cdRemains = rem

            if rem == 0 then
                slotData.ready = true
                if not RotaClass_DK.readySince[slot] or RotaClass_DK.readySince[slot] == 0 then
                    if start and start > 0 and duration and duration > 0 and (start + duration) <= now then
                        RotaClass_DK.readySince[slot] = start + duration
                    else
                        RotaClass_DK.readySince[slot] = now
                    end
                end
                local elapsed = math.min(MAX_GRACE_PERIOD, math.max(0, now - RotaClass_DK.readySince[slot]))
                runes.grace[slot] = elapsed
                if elapsed > runes.maxGrace then
                    runes.maxGrace = elapsed
                end

                -- Count ready runes by type (1: Blood, 2: Unholy, 3: Frost, 4: Death)
                if rType == 1 then
                    runes.bloodReady = runes.bloodReady + 1
                elseif rType == 2 then
                    runes.unholyReady = runes.unholyReady + 1
                elseif rType == 3 then
                    runes.frostReady = runes.frostReady + 1
                elseif rType == 4 then
                    runes.deathReady = runes.deathReady + 1
                end
            else
                slotData.ready = false
                RotaClass_DK.readySince[slot] = nil
                runes.grace[slot] = 0
            end
        end
    end

    -- Effective rune counts (Death runes can substitute for any rune)
    runes.effectiveBlood = runes.bloodReady + runes.deathReady
    runes.effectiveFrost = runes.frostReady + runes.deathReady
    runes.effectiveUnholy = runes.unholyReady + runes.deathReady

    -- 2. Target Diseases (Frost Fever & Blood Plague)
    dk.ffRemaining = (state.debuffRemaining and state.debuffRemaining("Frost Fever", "target", true)) or 0
    dk.bpRemaining = (state.debuffRemaining and state.debuffRemaining("Blood Plague", "target", true)) or 0
    dk.hasFrostFever = (dk.ffRemaining > 0)
    dk.hasBloodPlague = (dk.bpRemaining > 0)

    if dk.hasFrostFever and dk.hasBloodPlague then
        dk.minDiseaseRemaining = (dk.ffRemaining < dk.bpRemaining) and dk.ffRemaining or dk.bpRemaining
    else
        dk.minDiseaseRemaining = 0
    end

    -- 3. Player Buffs (Desolation, Blood Tap, Killing Machine, Rime)
    -- Desolation, presencias, Unholy Strength/Might y Ghoul Frenzy del pet: lectura propia por indice (UH)
    if RotaClass_DK.UHScan then RotaClass_DK.UHScan(state, now) end

    dk.bloodTapRemaining = (state.buffRemaining and state.buffRemaining("Blood Tap", "player")) or 0
    dk.hasBloodTap = (dk.bloodTapRemaining > 0)

    dk.killingMachine = (state.hasBuff and state.hasBuff("Killing Machine", "player")) or false
    dk.rime = (state.hasBuff and state.hasBuff("Freezing Fog", "player")) or false

    -- 4. Pestilence Rune Reservation Logic
    local pestMargin = (state.vars and state.vars.pestMargin) or 3.0
    local diseasesActive = dk.hasFrostFever and dk.hasBloodPlague
    local expiringSoon = diseasesActive and (dk.minDiseaseRemaining <= pestMargin)

    if expiringSoon then
        if runes.effectiveBlood <= 1 then
            -- Reserve the last available Blood/Death rune strictly for Pestilence
            dk.isBloodReservedForPestilence = true
            dk.canSpendBloodOnBS = false
        else
            -- We have >= 2 Blood/Death runes; 1 can be spent on BS, other stays for Pestilence
            dk.isBloodReservedForPestilence = false
            dk.canSpendBloodOnBS = true
        end
    else
        dk.isBloodReservedForPestilence = false
        dk.canSpendBloodOnBS = (runes.effectiveBlood > 0)
    end

    -- 5. Desolation Maintenance Flag
    local desolationMargin = (state.vars and state.vars.desolationMargin) or 3.0
    dk.needsDesolation = (not dk.hasDesolation) or (dk.desolationRemaining <= desolationMargin)

    -- 6. Pet Status & Ghoul Frenzy Logic
    local petAlive = false
    if _G.UnitExists and _G.UnitExists("pet") then
        if not _G.UnitIsDead or not _G.UnitIsDead("pet") then
            petAlive = true
        end
    end
    dk.petAlive = petAlive
    -- Army of the Dead tauntea adds: solo se sugiere contra jefes
    dk.targetIsBoss = (_G.UnitClassification and _G.UnitClassification("target") == "worldboss") and true or false

    local gfName = GetGFSpellName()

    local knowsGF = false
    if _G.IsSpellKnown then
        knowsGF = _G.IsSpellKnown(49213) or _G.IsSpellKnown(63560)
    elseif _G.GetSpellCooldown then
        local cdStart = _G.GetSpellCooldown(gfName)
        if cdStart ~= nil then
            knowsGF = true
        end
    end
    if not knowsGF then
        knowsGF = DKHasSpell("GF") or DKHasSpell(gfName)
    end
    dk.knowsGF = knowsGF

    local gfRem = 0
    if petAlive and knowsGF and RotaClass_DK.UHGetGFRemaining then
        gfRem = RotaClass_DK.UHGetGFRemaining(now)
    end
    dk.gfRemaining = gfRem
    dk.hasGhoulFrenzy = (gfRem > 0)

    -- Ghoul Frenzy real CD check (must not have CD > gcdRem)
    local gfCD = 0
    if _G.GetSpellCooldown and knowsGF then
        local sStart, sDur = _G.GetSpellCooldown(gfName)
        if sStart and sStart > 0 and sDur and sDur > 1.5 then
            local rem = (sStart + sDur) - now
            gfCD = rem > 0 and rem or 0
        end
    end
    dk.gfCD = gfCD
    dk.canCastGF = petAlive and knowsGF and (gfCD <= (state.gcdRemains or 0))

    -- 7. Raise Dead (Frost): burstMode ON, cd <= 0, and not cast in last 60s
    local lastRDCast = state.lastCast and (state.lastCast["Raise Dead"]
        or state.lastCast["RD"]
        or state.lastCast[46584]) or 0
    local rdCD = (state.spellCooldown and state.spellCooldown("RD")) or 0
    dk.canRaiseDead = (state.burstMode ~= false) and (rdCD <= 0) and ((now - lastRDCast) >= 60.0)

    -- 8. Frost Reserve Active & Urgent Pestilence
    local gcdLen = (state.gcdDuration and state.gcdDuration > 0) and state.gcdDuration or 1.5
    local gcdRem = state.gcdRemains or 0
    if diseasesActive and (dk.minDiseaseRemaining - gcdRem) <= (10.0 + gcdLen + 1.0) then
        dk.reserveActive = true
    else
        dk.reserveActive = false
    end

    if diseasesActive and (dk.minDiseaseRemaining - gcdRem) <= (pestMargin or 1.5) then
        dk.urgentPest = true
    else
        dk.urgentPest = false
    end
end

-- AUTOMATIC BUILD DETECTION (Frost 1F-4F, Unholy Morb 1UM-2UM, Unholy 2H 1U-2U)

--- Detects active Death Knight build based on talent points and known abilities.
-- - If Howling Blast (spell known or talent ID 49143 / 51411) -> Frost (1F-4F)
-- - If Unholy tree has most points:
--     * If Nerves of Cold Steel (Frost ID 49011 / 49012 / 49013) has points -> Unholy Morb (1UM-2UM)
--     * Otherwise -> Unholy 2H (1U-2U)
-- @return string buildKey, string activePresetId, string specName
function RotaClass_DK:DetectBuild()
    local detectedKey
    local presetId
    local specName
    local badge

    -- 1. Check Howling Blast (Spell known or Talent ID 49143 / 51411 / 49184 / 51410)
    local hasHowlingBlast = false
    if _G.IsSpellKnown then
        if _G.IsSpellKnown(49184) or _G.IsSpellKnown(51409) or _G.IsSpellKnown(51410) or _G.IsSpellKnown(51411) then
            hasHowlingBlast = true
        end
    end

    local hbName = "Howling Blast"
    if _G.GetSpellInfo then
        local localizedHB = _G.GetSpellInfo(51411) or _G.GetSpellInfo(49184)
        if localizedHB and localizedHB ~= "51411" and localizedHB ~= "49184" then hbName = localizedHB end
    end


    -- 2. Scan Talent Trees (Tab 1: Blood, Tab 2: Frost, Tab 3: Unholy)
    local bloodPoints = 0
    local frostPoints = 0
    local unholyPoints = 0
    local hasNervesOfColdSteel = false

    local nervesName = "Nerves of Cold Steel"
    if _G.GetSpellInfo then
        local localizedNerves = _G.GetSpellInfo(49011) or _G.GetSpellInfo(49012) or _G.GetSpellInfo(49013)
        if localizedNerves and localizedNerves ~= "49011"
            and localizedNerves ~= "49012" and localizedNerves ~= "49013" then
            nervesName = localizedNerves
        end
    end

    local fsName = "Frost Strike"
    if _G.GetSpellInfo then
        local localizedFS = _G.GetSpellInfo(49143) or _G.GetSpellInfo(55268)
        if localizedFS and localizedFS ~= "49143" and localizedFS ~= "55268" then fsName = localizedFS end
    end
    local howlingBlastPoints = 0
    local frostStrikePoints = 0

    -- Check direct IsSpellKnown for Nerves of Cold Steel ranks
    if _G.IsSpellKnown then
        if _G.IsSpellKnown(49011) or _G.IsSpellKnown(49012) or _G.IsSpellKnown(49013) then
            hasNervesOfColdSteel = true
        end
    end

    -- Check Scourge Strike
    local hasScourgeStrike = false
    if _G.IsSpellKnown then
        if _G.IsSpellKnown(55090) or _G.IsSpellKnown(55265) or _G.IsSpellKnown(55270) or _G.IsSpellKnown(55271) then
            hasScourgeStrike = true
        end
    end
    local ssName = "Scourge Strike"
    if _G.GetSpellInfo then
        local localizedSS = _G.GetSpellInfo(55271) or _G.GetSpellInfo(55090)
        if localizedSS and localizedSS ~= "55271" and localizedSS ~= "55090" then ssName = localizedSS end
    end

    for tab = 1, 3 do
        local tabSum = 0
        local numTalents = _G.GetNumTalents and _G.GetNumTalents(tab) or 0

        for idx = 1, numTalents do
            if _G.GetTalentInfo then
                local name, _, _, _, currentRank = _G.GetTalentInfo(tab, idx)
                local rank = currentRank or 0
                if rank > 0 then
                    tabSum = tabSum + rank

                    -- Check Howling Blast & Frost Strike in Frost tab
                    if tab == 2 then
                        local lowerName = name and name:lower() or ""
                        local isHB = (name == hbName or name == "Howling Blast"
                            or lowerName:find("howling blast") or lowerName:find("aullido"))
                        local isFS = (name == fsName or name == "Frost Strike"
                            or lowerName:find("frost strike") or lowerName:find("golpe de escarcha"))
                        if isHB then
                            howlingBlastPoints = howlingBlastPoints + rank
                            hasHowlingBlast = true
                        elseif isFS then
                            frostStrikePoints = frostStrikePoints + rank
                        end
                    end

                    -- Check Nerves of Cold Steel in Frost tab
                    if tab == 2 and (name == nervesName or name == "Nerves of Cold Steel") then
                        hasNervesOfColdSteel = true
                    end

                    -- Check Scourge Strike in Unholy tab
                    if tab == 3 and (name == ssName or name == "Scourge Strike") then
                        hasScourgeStrike = true
                    end
                end
            end
        end

        -- If GetTalentTabInfo provides pointsSpent, also consider it
        if _G.GetTalentTabInfo then
            local _, _, pointsSpent = _G.GetTalentTabInfo(tab)
            if type(pointsSpent) == "number" and pointsSpent > tabSum then
                tabSum = pointsSpent
            end
        end

        if tab == 1 then
            bloodPoints = tabSum
        elseif tab == 2 then
            frostPoints = tabSum
        elseif tab == 3 then
            unholyPoints = tabSum
        end
    end

    RotaClass_DK.bloodPoints = bloodPoints
    RotaClass_DK.frostPoints = frostPoints
    RotaClass_DK.unholyPoints = unholyPoints
    RotaClass_DK.howlingBlastPoints = howlingBlastPoints
    RotaClass_DK.frostStrikePoints = frostStrikePoints

    -- 3. Spec Decision Logic
    -- Los talentos mandan. Por hechizo solo si la API de talentos no dio puntos:
    -- GetSpellCooldown(id) devuelve datos aunque el hechizo no se conozca, y State.data queda viejo tras un respec.
    -- Al loguear el cliente puede dar 0 puntos hasta que llegan los talentos: sin ellos no se distingue Morb de 2H
    -- (Nerves of Cold Steel es pasivo). En AUTO no se cambia la build con esa adivinanza; se reintenta (OnUpdate).
    local talentsPending = (bloodPoints + frostPoints + unholyPoints == 0)
    RotaClass_DK.talentsPending = talentsPending
    if talentsPending then
        if DKHasSpell(hbName) then hasHowlingBlast = true end
        if DKHasSpell(ssName) then hasScourgeStrike = true end
        local sData = RotaCore.State and RotaCore.State.data
        if sData and sData.dk then
            if sData.dk.hasHowlingBlast then hasHowlingBlast = true end
            if sData.dk.hasScourgeStrike then hasScourgeStrike = true end
            if sData.dk.hasNervesOfColdSteel then hasNervesOfColdSteel = true end
        end
    end

    if hasHowlingBlast then
        detectedKey = "frost"
        presetId = "dk_frost_pve"
        specName = "Frost"
        badge = "[F]"
    elseif (not hasScourgeStrike) and (hasNervesOfColdSteel or unholyPoints >= 40) then
        detectedKey = "unholy_morb"
        presetId = "dk_unholy_morb_pve"
        specName = "UH Morb (DW)"
        badge = "[UM]"
    elseif hasScourgeStrike and hasNervesOfColdSteel then
        detectedKey = "unholy_dw_ss"
        presetId = "dk_unholy_dw_ss_pve"
        specName = "UH Morb+SS (DW+SS)"
        badge = "[UMS]"
    else
        detectedKey = "unholy_2h"
        presetId = "dk_unholy_2h_pve"
        specName = "UH"
        badge = "[U]"
    end

    RotaClass_DK.detectedBuild = detectedKey
    RotaClass_DK.detectedPresetId = presetId
    RotaClass_DK.detectedSpecName = specName
    RotaClass_DK.detectedBadge = badge

    -- 4. Apply manual user override from Settings if configured
    local selected = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or "auto"
    local activePreset = presetId
    local manual = true

    if selected == "frost" or selected == "Frost" or selected == "Frost (DW)" then
        activePreset = "dk_frost_pve"
        RotaClass_DK.detectedBadge = "[F]"
    elseif selected == "unholy_morb" or selected == "morb" or selected == "Unholy Morb (DW)" then
        activePreset = "dk_unholy_morb_pve"
        RotaClass_DK.detectedBadge = "[UM]"
    elseif selected == "unholy_dw_ss" or selected == "dw_ss" or selected == "dwss" or selected == "ums" then
        activePreset = "dk_unholy_dw_ss_pve"
        RotaClass_DK.detectedBadge = "[UMS]"
    elseif selected == "unholy_2h" or selected == "unholy" or selected == "Unholy (2H)" or selected == "2h" then
        activePreset = "dk_unholy_2h_pve"
        RotaClass_DK.detectedBadge = "[U]"
    else
        manual = false
    end

    if talentsPending and not manual and not hasHowlingBlast then
        -- AUTO sin talentos: se queda la build activa (o la guardada) hasta que el reintento lea los talentos
        local cur = RotaCore.Profiles and RotaCore.Profiles.GetActiveProfile and RotaCore.Profiles:GetActiveProfile()
        local curId = cur and cur.meta and (cur.meta.v1Of or cur.meta.id)
        local db = _G.RotaCoreDB
        local key = RotaCore.GetCharKey and RotaCore:GetCharKey()
        local saved = db and key and db.charProfiles and db.charProfiles[key]
        local P = RotaCore.Profiles and RotaCore.Profiles.presets
        if curId and P and P[curId] and P[curId].meta.class == "DEATHKNIGHT" then
            return detectedKey, curId, specName
        elseif saved and P and P[saved] and P[saved].meta.class == "DEATHKNIGHT" then
            activePreset = saved
        end
    end

    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(activePreset)
    end

    return detectedKey, activePreset, specName
end

function RotaClass_DK.grace(rType)
    if RotaCore.State and RotaCore.State.data and RotaCore.State.data.grace then
        return RotaCore.State.data.grace(rType)
    end
    return 0
end
RotaClass_DK.Grace = RotaClass_DK.grace

function RotaClass_DK.CanWithRunes(lim, reqBlood, reqFrost, reqUnholy, reserveBloodForPest)
    if RotaCore.State and RotaCore.State.data and RotaCore.State.data.canWithRunes then
        return RotaCore.State.data.canWithRunes(lim, reqBlood, reqFrost, reqUnholy, reserveBloodForPest)
    end
    return false
end

local FROST_HORIZONS = { 0, 0.5, 1.0, 1.5, 2.5 }

--- Frost DK Priority Evaluator (Wowhead 3.3.5a + WeakAura v4.6 lookahead)
-- @param state table Pre-allocated RotaCore.State.data table
-- @return string Action alias
function RotaClass_DK.EvaluateFrost(state)
    local dk = state.dk
    local runes = state.runes
    local gcdRem = state.gcdRemains or 0
    local gcdLen = (state.gcdDuration and state.gcdDuration > 0) and state.gcdDuration or 1.5
    local rp = state.power or 0

    local ffRem = dk.ffRemaining or 0
    local bpRem = dk.bpRemaining or 0
    local hasFF = dk.hasFrostFever
    local hasBP = dk.hasBloodPlague
    local m = (hasFF and hasBP) and math.min(ffRem, bpRem) or 0

    local kmUp = state.hasBuff("Killing Machine", "player") or dk.killingMachine
    local fogUp = state.hasBuff("Freezing Fog", "player") or dk.rime

    local btCD = state.spellCooldown("BT") or 0
    local uaCD = state.spellCooldown("UA") or 0
    local hbCD = state.spellCooldown("HB") or 0

    local aoeMode = state.aoeMode or state.isAoE
    state.isWaiting = false

    local canWithRunes = state.canWithRunes or (RotaCore.State and RotaCore.State.data and RotaCore.State.data.canWithRunes)

    local hasFS = HasDKSpell(state, "FS")
    local okFS = hasFS and (rp >= 32)
    local okDCFallback = (not hasFS) and (rp >= 40) and HasDKSpell(state, "DC")
    local canDumpRP = okFS or okDCFallback
    local rpDump = okFS and "FS" or (okDCFallback and "DC")

    local maxPower = state.maxPower or 100
    local rpCap = maxPower - 15
    if state.vars and state.vars.rpDumpMin and state.vars.rpDumpMin < rpCap then
        rpCap = state.vars.rpDumpMin
    end

    if aoeMode then
        -- --------------------------------------------------------------------
        -- FROST AOE (Wowhead + WotLK Rebuffed): Evaluar estrictamente h = 0 primero
        -- --------------------------------------------------------------------
        local lim = gcdRem
        local okIT = canWithRunes(lim, 0, 1, 0, false)
        local okPS = canWithRunes(lim, 0, 0, 1, false)
        local okPEST = canWithRunes(lim, 1, 0, 0, false)
        local okHB = (hbCD <= lim) and (fogUp or canWithRunes(lim, 0, 1, 1, true))
        local okDND = (state.spellCooldown("DND") <= lim) and canWithRunes(lim, 1, 1, 1, true)
        local okBB = canWithRunes(lim, 1, 0, 0, true)
        local okOBL = canWithRunes(lim, 0, 1, 1, true)

        -- 1. IT / PS si faltan enfermedades -> PEST (refresh urgente o spread)
        if (ffRem - gcdRem) <= 0 and okIT then
            return "IT"
        end
        if (bpRem - gcdRem) <= 0 and okPS then
            return "PS"
        end
        if hasFF and hasBP and (m - gcdRem <= gcdLen + 0.5) and okPEST then
            return "PEST"
        end
        local now = state.now or 0
        local lastPest = (state.lastCast and (state.lastCast["PEST"] or state.lastCast["Pestilence"] or state.lastCast[50842])) or 0
        local needSpread = (lastPest == 0) or ((now - lastPest) > (m - 3.0))
        if hasFF and hasBP and needSpread and okPEST then
            return "PEST"
        end

        -- 2. HB (Howling Blast) si esta listo (hbCD <= gcdRem)
        if okHB and HasDKSpell(state, "HB") then
            return "HB"
        end

        -- 3. DND si aoeCount >= 10 y listo
        if (state.aoeCount or 1) >= 10 and okDND and HasDKSpell(state, "DND") then
            return "DND"
        end

        -- 4. FS (Frost Strike) si el RP esta por capear (state.power >= (maxPower - 15) y fsOK)
        if rp >= rpCap and canDumpRP then
            return rpDump
        end

        -- 5. BB (Blood Boil) con runas Blood/Death disponibles en h = 0
        if hasFF and hasBP and okBB then
            if (state.burstMode ~= false) and (uaCD <= lim) and HasDKSpell(state, "UA") then
                state.suggestedOff = "UA"
            end
            if HasDKSpell(state, "BB") then
                return "BB"
            end
        end

        -- 6. Gasto de RP con Frost Strike en AoE mientras HB esta en cooldown:
        -- Si fsOK (state.power >= 32): a menos que tenga Killing Machine activo Y a Howling Blast le falte <= 1.5s,
        -- DEBE devolver "FS" para gastar el Poder Runico en AoE tal como indica Wowhead.
        if canDumpRP then
            local holdForKM = kmUp and (hbCD <= gcdRem + 1.5) and (rp < maxPower) and HasDKSpell(state, "HB")
            if not holdForKM then
                return rpDump
            end
        end

        -- 7. OB con runas Frost+Unholy listas en h = 0 (si hbCD > gcdRem + 1.5)
        if okOBL and (hbCD > gcdRem + 1.5) and HasDKSpell(state, "OBL") then
            return "OBL"
        end

        -- Si retiene para KM con HB en <= 1.5s
        if kmUp and (hbCD <= gcdRem + 1.5) and HasDKSpell(state, "HB") then
            state.isWaiting = true
            return "HB"
        end

        -- Horn of Winter filler en h = 0
        if state.buffRemaining("Horn of Winter", "player") <= 5 and state.spellReady("HOW") == true then
            return "HOW"
        end

        -- --------------------------------------------------------------------
        -- Horizontes futuros h > 0 para AoE (si nada se pudo lanzar en h = 0)
        -- --------------------------------------------------------------------
        for hIdx = 2, 5 do
            local h = FROST_HORIZONS[hIdx]
            local hLim = gcdRem + h
            local hIT = canWithRunes(hLim, 0, 1, 0, false)
            local hPS = canWithRunes(hLim, 0, 0, 1, false)
            local hPEST = canWithRunes(hLim, 1, 0, 0, false)
            local hHB = (hbCD <= hLim) and (fogUp or canWithRunes(hLim, 0, 1, 1, true))
            local hBB = canWithRunes(hLim, 1, 0, 0, true)
            local hOBL = canWithRunes(hLim, 0, 1, 1, true)

            if (ffRem - gcdRem) <= 0 and hIT then
                state.isWaiting = true
                return "IT"
            end
            if (bpRem - gcdRem) <= 0 and hPS then
                state.isWaiting = true
                return "PS"
            end
            if hasFF and hasBP and (m - gcdRem <= gcdLen + 0.5) and hPEST then
                state.isWaiting = true
                return "PEST"
            end
            if hHB and HasDKSpell(state, "HB") then
                state.isWaiting = true
                return "HB"
            end
            if hasFF and hasBP and hBB and HasDKSpell(state, "BB") then
                state.isWaiting = true
                return "BB"
            end
            if hOBL and HasDKSpell(state, "OBL") then
                state.isWaiting = true
                return "OBL"
            end
        end

        if HasDKSpell(state, "HOW") then
            return "HOW"
        end

        state.isWaiting = true
        return "HB"

    else
        -- --------------------------------------------------------------------
        -- FROST SINGLE TARGET (Wowhead + WeakAura): Evaluar estrictamente h = 0 primero
        -- --------------------------------------------------------------------
        local lim = gcdRem
        local okIT = canWithRunes(lim, 0, 1, 0, false)
        local okPS = canWithRunes(lim, 0, 0, 1, false)
        local okPEST = canWithRunes(lim, 1, 0, 0, false)
        local okOBL = canWithRunes(lim, 0, 1, 1, true)
        local okBS = canWithRunes(lim, 1, 0, 0, true)
        local okHB = (hbCD <= lim) and (fogUp or canWithRunes(lim, 0, 1, 1, true))

        -- 1. Enfermedades caidas (IT, PS) y refresh urgente (PEST)
        if (ffRem - gcdRem) <= 0 and okIT then
            return "IT"
        end
        if (bpRem - gcdRem) <= 0 and okPS then
            return "PS"
        end

        local hasGlyphOfDisease = (dk.hasGlyphOfDisease ~= false)
        if not hasGlyphOfDisease then
            if (ffRem - gcdRem) <= 2.5 and okIT then
                return "IT"
            end
            if (bpRem - gcdRem) <= 2.5 and okPS then
                return "PS"
            end
        else
            if hasFF and hasBP and (m <= 3.5) then
                local btBuff = dk.bloodTapRemaining or 0
                if (runes.bloodReady >= 1 or runes.deathReady >= 1 or btBuff > 0) then
                    state.suggestedOff = nil
                    if okPEST then
                        return "PEST"
                    end
                elseif (runes.bloodReady == 0 and runes.deathReady == 0) and btCD <= 0 and HasDKSpell(state, "BT") then
                    local minCD = 999
                    for s = 1, 6 do
                        local sData = runes.slots[s]
                        if sData and (sData.type == 1 or sData.type == 4) then
                            if sData.cdRemains < minCD then minCD = sData.cdRemains end
                        end
                    end
                    if minCD > (m - 0.5) then
                        state.suggestedOff = "BT"
                        state.isWaiting = true
                        return "PEST"
                    end
                end
            end

            if hasFF and hasBP and (m - gcdRem <= gcdLen + 1.0) and okPEST then
                return "PEST"
            end
        end

        local gFrost = state.grace and state.grace(3) or 0
        local gUnholy = state.grace and state.grace(2) or 0

        -- 2. HB con proc Freezing Fog (ffRem >= 3 y hbCD <= gcdRem)
        if fogUp and ffRem >= 3 and (hbCD <= gcdRem) and okHB and HasDKSpell(state, "HB") then
            if kmUp and (not okOBL) and gFrost <= 1.5 and gUnholy <= 1.5 and canDumpRP then
                return rpDump
            else
                return "HB"
            end
        end

        -- 3. FS con proc Killing Machine (si grace(Frost) <= 1.5 and grace(Unholy) <= 1.5 y fsOK)
        if kmUp and gFrost <= 1.5 and gUnholy <= 1.5 and ffRem >= 3 and canDumpRP then
            return rpDump
        end

        -- 4. OB (Obliterate) SOLO si las runas estan listas AHORA (lim = gcdRem) respetando reserveActive
        if okOBL and HasDKSpell(state, "OBL") then
            return "OBL"
        end

        -- 5. FS (Frost Strike) si el RP esta cerca del cap (state.power >= (state.maxPower or 100) - 15 y fsOK)
        if rp >= rpCap and canDumpRP then
            return rpDump
        end

        -- 6. PEST filler (minDisease <= 6 y uaCD >= 6 con runa lista ahora)
        --    -> BS filler (minDisease > 10 con runa Blood lista ahora) -> HB con Freezing Fog
        if ffRem > 0 and ffRem <= 6 and uaCD >= 6 and okPEST then
            return "PEST"
        end
        if ffRem > 10 and okBS and HasDKSpell(state, "BS") then
            return "BS"
        end
        if fogUp and (hbCD <= gcdRem) and okHB and HasDKSpell(state, "HB") then
            return "HB"
        end

        -- 7. FS (Frost Strike) GASTADOR DE RP EN h = 0:
        -- Si llego hasta aqui (Obliterate NO tiene runas listas ahora mismo en h = 0)
        -- y el jugador puede lanzar Frost Strike (canDumpRP / rp >= 32),
        -- DEBE devolver "FS" INMEDIATAMENTE en h = 0 antes de mirar horizontes futuros (h > 0)!
        if canDumpRP then
            return rpDump
        end

        -- 8. HOW (Horn of Winter)
        if state.buffRemaining("Horn of Winter", "player") <= 5 and state.spellReady("HOW") == true then
            return "HOW"
        end

        -- --------------------------------------------------------------------
        -- HORIZONTES FUTUROS (h = {0.5, 1.0, 1.5, 2.5}):
        -- Recien si en h = 0 NO se pudo lanzar NADA (ni OB, ni BS, ni FS porque RP < 32)
        -- --------------------------------------------------------------------
        for hIdx = 2, 5 do
            local h = FROST_HORIZONS[hIdx]
            local hLim = gcdRem + h

            local hIT = canWithRunes(hLim, 0, 1, 0, false)
            local hPS = canWithRunes(hLim, 0, 0, 1, false)
            local hPEST = canWithRunes(hLim, 1, 0, 0, false)
            local hOBL = canWithRunes(hLim, 0, 1, 1, true)
            local hBS = canWithRunes(hLim, 1, 0, 0, true)
            local hHB = (hbCD <= hLim) and (fogUp or canWithRunes(hLim, 0, 1, 1, true))

            if (ffRem - gcdRem) <= 0 and hIT then
                state.isWaiting = true
                return "IT"
            end
            if (bpRem - gcdRem) <= 0 and hPS then
                state.isWaiting = true
                return "PS"
            end
            if hasFF and hasBP and (m - gcdRem <= gcdLen + 1.0) and hPEST then
                state.isWaiting = true
                return "PEST"
            end
            if fogUp and (hbCD <= hLim) and hHB and HasDKSpell(state, "HB") then
                state.isWaiting = true
                return "HB"
            end
            if hOBL and HasDKSpell(state, "OBL") then
                state.isWaiting = true
                return "OBL"
            end
            if ffRem > 10 and hBS and HasDKSpell(state, "BS") then
                state.isWaiting = true
                return "BS"
            end
        end

        if HasDKSpell(state, "HOW") then
            return "HOW"
        end

        state.isWaiting = true
        return "OBL"
    end
end

--- Unholy DK Priority Evaluator (Morb and Scourge Strike variants)
-- @param state table Pre-allocated RotaCore.State.data table
-- @param isSS boolean True for Scourge Strike build, false for Morb build
-- @return string Action alias
-- UNHOLY MORB / MORB+SS  (ConRO Morb WA v7 + Gargoyle snapshot + Blood Tap inteligente)
-- Lectura propia de buffs (no depende de state.buffRemaining) y tracking de casts por CLEU.
local UH = { cast = {}, petGUID = nil, gfScan = 0, desSeen = false, bsCasts = 0, names = nil }
RotaClass_DK.UH = UH

local function UHNames()
    local n = UH.names
    if n then return n end
    n = { gf = "Ghoul Frenzy", des = "Desolation", up = "Unholy Presence", bp = "Blood Presence",
          us = "Unholy Strength", um = "Unholy Might" }
    if _G.GetSpellInfo then
        local function loc(id, fb)
            local s = _G.GetSpellInfo(id)
            if s and s ~= "" and s ~= tostring(id) then return s end
            return fb
        end
        n.gf = loc(63560, n.gf)
        n.up = loc(48265, n.up)
        n.bp = loc(48266, n.bp)
        UH.names = n          -- solo se cachea si la API respondio
    end
    return n
end

local function UHSecs(exp, now)
    if not exp or exp <= 0 then return 30 end      -- aura sin expiracion visible: asumir vigente
    local r = exp - now
    return r > 0 and r or 0
end

--- Escanea buffs del jugador y del pet (index loop; 0 garbage). Llamado desde el provider cada update.
function RotaClass_DK.UHScan(state, now)
    local dk = state.dk
    local N = UHNames()
    local des, um, upOn, bpOn = 0, 0, false, false
    if _G.UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, exp, _, _, _, sid = _G.UnitBuff("player", i)
            if not name then break end
            if name == N.des or sid == 63583 or sid == 66803 then
                des = UHSecs(exp, now)
            elseif name == N.up or sid == 48265 then
                upOn = true
            elseif name == N.bp or sid == 48266 then
                bpOn = true
            elseif name == N.us or name == N.um then
                local r = UHSecs(exp, now)
                if r > um then um = r end
            end
        end
    end
    if des > 0 then UH.desSeen = true end
    dk.desolationRemaining = des
    dk.hasDesolation = des > 0
    dk.umRemaining = um
    dk.hasUnholyPresence = upOn
    dk.hasBloodPresence = bpOn

    -- Ghoul Frenzy: buff en el pet
    local gf = 0
    local petOK = _G.UnitExists and _G.UnitExists("pet")
    if petOK then
        local g = _G.UnitGUID and _G.UnitGUID("pet")
        if g ~= UH.petGUID then
            UH.petGUID = g
            UH.cast.GF = 0                 -- pet nuevo: el buff viejo ya no existe
        end
        if _G.UnitBuff then
            for i = 1, 40 do
                local name, _, _, _, _, _, exp, _, _, _, sid = _G.UnitBuff("pet", i)
                if not name then break end
                if name == N.gf or sid == 63560 then
                    gf = UHSecs(exp, now)
                    break
                end
            end
        end
    else
        UH.petGUID = nil
        UH.cast.GF = 0
    end
    UH.gfScan = gf
end

--- Ghoul Frenzy restante: buff leido en el pet; si no se pudo leer, estimado desde el ultimo cast (30s).
function RotaClass_DK.UHGetGFRemaining(now)
    if UH.gfScan > 0 then return UH.gfScan end
    -- Recien casteado (UNIT_SPELLCAST_SUCCEEDED) y el buff de la mascota todavia no aparece: asumir 30 s
    local lc = RotaCore.State and RotaCore.State.data and RotaCore.State.data.lastCast
    local ev = lc and (lc["Ghoul Frenzy"] or lc["GF"]) or 0
    if ev > 0 and (now - ev) >= 0 and (now - ev) <= 3 then return 30 end
    local c = UH.cast.GF or 0
    if c > 0 then
        local est = 30 - (now - c)
        if est > 0 then return est end
    end
    return 0
end

-- ----------------------------------------------------------------------------
-- Helpers de runas (slots: 1,2 Blood | 3,4 Unholy | 5,6 Frost; tipo 4 = Death)
-- ----------------------------------------------------------------------------
local function UHCanCast(runes, b, f, u)
    local nb = b - runes.bloodReady;  if nb < 0 then nb = 0 end
    local nf = f - runes.frostReady;  if nf < 0 then nf = 0 end
    local nu = u - runes.unholyReady; if nu < 0 then nu = 0 end
    return (nb + nf + nu) <= runes.deathReady
end

local function UHDeficit(runes, b, f, u)
    local nb = b - runes.bloodReady;  if nb < 0 then nb = 0 end
    local nf = f - runes.frostReady;  if nf < 0 then nf = 0 end
    local nu = u - runes.unholyReady; if nu < 0 then nu = 0 end
    return nb + nf + nu - runes.deathReady
end

local function UHSlotCD(runes, i)
    local s = runes.slots and runes.slots[i]
    return (s and s.cdRemains) or 0
end

--- Segundos hasta tener una runa utilizable del tipo t (1 Blood, 2 Unholy, 3 Frost); las Death sirven para todo.
local function UHTypeWait(runes, t)
    local best = 999
    local sl = runes.slots
    if not sl then return 0 end
    for i = 1, 6 do
        local s = sl[i]
        if s and (s.type == t or s.type == 4) then
            local c = s.cdRemains or 0
            if c < best then best = c end
        end
    end
    return best
end

local function UHBloodSlots(runes)
    local n = 0
    local sl = runes.slots
    if sl then
        for i = 1, 6 do
            if sl[i] and sl[i].type == 1 then n = n + 1 end
        end
    end
    return n
end

--- Par seguro: gastar una runa del par (a,b) no atrasa Death and Decay (logica SafeToSpendPair del WA v7).
local function UHSafePair(runes, a, b, dndCD)
    local ca, cb = UHSlotCD(runes, a), UHSlotCD(runes, b)
    local ra, rb = ca <= 0, cb <= 0
    if not ra and not rb then return false end
    -- una runa gastada ahora vuelve en 'duration' (10s base, menos con haste): si DnD tarda mas, no lo atrasa
    local sl = runes.slots and runes.slots[a]
    local rd = (sl and sl.duration and sl.duration > 0) and sl.duration or 10
    if dndCD >= (rd - 0.2) then return true end
    if ra and rb then return true end
    local cooling = ra and cb or ca
    return cooling <= (dndCD + 0.2)
end

--- Gastar una runa del tipo t no debe dejar la enfermedad sin refresco: si queda una sola runa lista,
--- la otra tiene que volver antes de que haga falta (remUntilNeed = segundos hasta el limite de refresco).
local function UHKeepsRuneFor(runes, t, remUntilNeed)
    local ready, nextBack = 0, 999
    local sl = runes.slots
    if not sl then return true end
    for i = 1, 6 do
        local s = sl[i]
        if s and (s.type == t or s.type == 4) then
            local c = s.cdRemains or 0
            if c <= 0 then ready = ready + 1 elseif c < nextBack then nextBack = c end
        end
    end
    if ready >= 2 then return true end
    if remUntilNeed < 0 then remUntilNeed = 0 end
    return nextBack <= (remUntilNeed + 0.3)
end

local function UHHealthOK()
    if _G.UnitHealth and _G.UnitHealthMax then
        local mx = _G.UnitHealthMax("player")
        if mx and mx > 0 then return (_G.UnitHealth("player") / mx) > 0.35 end
    end
    return true
end

-- ----------------------------------------------------------------------------
-- Funciones del DK para las reglas del preset (ver RotaClass_DK/Presets.lua)
-- ----------------------------------------------------------------------------
local RUNE_TYPE = { blood = 1, unholy = 2, frost = 3 }
local PAIR = { blood = 1, unholy = 3, frost = 5 } -- primer slot de cada par (Blood 1-2, Unholy 3-4, Frost 5-6)

-- Contexto del Unholy: lo que la v1 calculaba al principio de la evaluacion. Una vez por tick, tabla reusada.
local uhCtx = {}
local function UHContext(state)
    local c = uhCtx
    if c.tick == state.tickCount and c.now == state.now then return c end
    c.tick, c.now = state.tickCount, state.now
    local dk, runes = state.dk, state.runes
    local gcdRem = state.gcdRemains or 0
    local rp = state.power or 0
    local now = state.now or 0
    local v = state.vars
    c.isSS = (v and v.scourgeStrike == 1) and true or false
    dk.wantBT = nil

    c.ffRem, c.bpRem = dk.ffRemaining or 0, dk.bpRemaining or 0
    c.desRem, c.gfRem = dk.desolationRemaining or 0, dk.gfRemaining or 0
    c.gfUsable = (dk.petAlive and dk.knowsGF and ((dk.gfCD or 0) <= gcdRem)) and true or false
    c.hasIT, c.hasPS = DKHasSpell("IT"), DKHasSpell("PS")
    c.hasBS, c.hasBB = DKHasSpell("BS"), DKHasSpell("BB")
    c.hasDND, c.hasDC = DKHasSpell("DND"), DKHasSpell("DC")
    c.hasSS = c.isSS and DKHasSpell("SS")
    c.dndCD = c.hasDND and (state.spellCooldown("DND") or 0) or 99

    local gargKnown = DKHasSpell("GARG")
    local gargCD = gargKnown and (state.spellCooldown("GARG") or 0) or 999
    local burstOn = state.burstMode ~= false
    c.gargCD = gargCD
    local gargReady = gargKnown and burstOn and gargCD <= (gcdRem + 0.1)
    c.reserveU = (gargReady and rp >= 50 and not dk.hasUnholyPresence) and true or false
    local dmin = (dk.hasFrostFever and dk.hasBloodPlague) and ((c.ffRem < c.bpRem) and c.ffRem or c.bpRem) or 0
    local longFight = UH.combatStart and (now - UH.combatStart) > 15
    c.gargBlocked = (gargReady and not (state.inCombat == true and (dmin >= 4.5 or dk.hasUnholyPresence or longFight)))
        and true or false
    c.rpFloor = (gargKnown and burstOn and gargCD <= 12 and not c.gargBlocked) and 60 or 0

    local btKnown = DKHasSpell("BT")
    local btCD = btKnown and (state.spellCooldown("BT") or 0) or 999
    c.btReserved = (gargKnown and burstOn and gargCD <= 8) and true or false
    c.btGain = (btKnown and btCD <= 0 and UHBloodSlots(runes) > 0 and runes.bloodReady == 0 and UHHealthOK()) and true or false

    c.safeB = UHSafePair(runes, 1, 2, c.dndCD)
    c.safeU = UHSafePair(runes, 3, 4, c.dndCD)
    c.safeF = UHSafePair(runes, 5, 6, c.dndCD)
    local dndIn = c.dndCD
    local w = UHTypeWait(runes, 1); if w > dndIn then dndIn = w end
    w = UHTypeWait(runes, 2);       if w > dndIn then dndIn = w end
    w = UHTypeWait(runes, 3);       if w > dndIn then dndIn = w end
    c.dndIn = dndIn
    c.desOK = (UH.desSeen or UH.bsCasts < 3) and true or false
    c.uFree = runes.unholyReady + runes.deathReady - (c.reserveU and 1 or 0)
    c.keepU = UHKeepsRuneFor(runes, 2, c.bpRem - gcdRem - 2.5)
    c.keepUGF = (not c.gfUsable) or UHKeepsRuneFor(runes, 2, c.gfRem - gcdRem - 3.5)
    c.keepF = UHKeepsRuneFor(runes, 3, c.ffRem - gcdRem - 2.5)
    return c
end

-- Contexto de Frost: lo que la v1 calculaba al principio de EvaluateFrost. Una vez por tick, tabla reusada.
local frCtx = {}
local function FrostContext(state)
    local c = frCtx
    if c.tick == state.tickCount and c.now == state.now then return c end
    c.tick, c.now = state.tickCount, state.now
    local dk = state.dk
    c.gcdLen = (state.gcdDuration and state.gcdDuration > 0) and state.gcdDuration or 1.5
    c.ffRem, c.bpRem = dk.ffRemaining or 0, dk.bpRemaining or 0
    c.hasFF, c.hasBP = dk.hasFrostFever, dk.hasBloodPlague
    c.m = (c.hasFF and c.hasBP) and math.min(c.ffRem, c.bpRem) or 0
    c.km = (state.hasBuff("Killing Machine", "player") or dk.killingMachine) and true or false
    c.fog = (state.hasBuff("Freezing Fog", "player") or dk.rime) and true or false
    c.btCD = state.spellCooldown("BT") or 0
    c.uaCD = state.spellCooldown("UA") or 0
    c.hbCD = state.spellCooldown("HB") or 0
    local rp = state.power or 0
    local hasFS = HasDKSpell(state, "FS")
    local okFS = hasFS and (rp >= 32)
    local okDC = (not hasFS) and (rp >= 40) and HasDKSpell(state, "DC")
    c.canDump = (okFS or okDC) and true or false
    c.dump = okFS and "FS" or (okDC and "DC") or nil
    c.maxPower = state.maxPower or 100
    local rpCap = c.maxPower - 15
    if state.vars and state.vars.rpDumpMin and state.vars.rpDumpMin < rpCap then rpCap = state.vars.rpDumpMin end
    c.rpCap = rpCap
    return c
end

if RotaCore.Sandbox and RotaCore.Sandbox.AddHelper then
    local Sandbox = RotaCore.Sandbox
    --- contexto de Frost (plagas, procs Killing Machine / Freezing Fog, CDs, gasto de RP): ver FrostContext
    Sandbox:AddHelper("frost", function() return FrostContext(Sandbox.current) end)
    --- contexto del Unholy (plagas, Gargola, Blood Tap, pares seguros de runas...): ver UHContext
    Sandbox:AddHelper("unholy", function() return UHContext(Sandbox.current) end)
    --- alcanzan las runas listas (Death cubre lo que falte) para b Blood, f Frost, u Unholy
    Sandbox:AddHelper("canCast", function(b, f, u) return UHCanCast(Sandbox.current.runes, b, f, u) end)
    --- cuantas runas faltan para b/f/u (contando las Death)
    Sandbox:AddHelper("runeDeficit", function(b, f, u) return UHDeficit(Sandbox.current.runes, b, f, u) end)
    --- segundos hasta tener una runa "blood" / "unholy" / "frost" (o Death)
    Sandbox:AddHelper("runeWait", function(t) return UHTypeWait(Sandbox.current.runes, RUNE_TYPE[t] or t) end)
    --- gastar una runa del par "blood" / "unholy" / "frost" no atrasa Death and Decay
    Sandbox:AddHelper("safePair", function(t)
        local a = PAIR[t]
        return UHSafePair(Sandbox.current.runes, a, a + 1, UHContext(Sandbox.current).dndCD)
    end)
    --- gastar una runa del tipo deja otra lista (o que vuelve) antes de `secs` segundos
    Sandbox:AddHelper("keepsRune", function(t, secs)
        return UHKeepsRuneFor(Sandbox.current.runes, RUNE_TYPE[t] or t, secs)
    end)
    --- pedir Blood Tap (lista off) para poder lanzar `alias`; devuelve el alias
    Sandbox:AddHelper("bloodTapFor", function(alias)
        Sandbox.current.dk.wantBT = alias
        return alias
    end)
    --- vida propia > 35% (Blood Tap cuesta vida)
    Sandbox:AddHelper("healthOK", function() return UHHealthOK() end)
    --- Blood Tap conocido, fuera de CD y con vida
    Sandbox:AddHelper("bloodTapReady", function()
        local st = Sandbox.current
        return DKHasSpell("BT") and (st.spellCooldown("BT") or 0) <= 0 and UHHealthOK()
    end)
    --- mas de 15 s de combate (la Gargola no espera plagas firmes)
    Sandbox:AddHelper("longFight", function()
        local st = Sandbox.current
        return (UH.combatStart and ((st.now or 0) - UH.combatStart) > 15) and true or false
    end)
    --- momento del ultimo Pestilence (combat log o evento de casteo), 0 si no hubo
    Sandbox:AddHelper("lastPestilence", function()
        local st = Sandbox.current
        local lastPest = UH.cast.PEST or 0
        local lc = st.lastCast
        local ev = lc and (lc["Pestilence"] or lc["PEST"] or lc[50842]) or 0
        if ev > lastPest then lastPest = ev end
        return lastPest
    end)
end

-- ----------------------------------------------------------------------------
-- Evaluador principal Unholy Morb (isSS=false) / Morb + Scourge Strike (isSS=true)
-- ----------------------------------------------------------------------------
function RotaClass_DK.EvaluateUnholy(state, isSS)
    local dk = state.dk
    local runes = state.runes
    local gcdRem = state.gcdRemains or 0
    local rp = state.power or 0
    local now = state.now or 0

    if isSS == nil then
        isSS = (RotaClass_DK.detectedBuild ~= "unholy_morb")
    end

    state.isWaiting = false
    state.reason = nil
    dk.wantBT = nil

    local ffRem = dk.ffRemaining or 0
    local bpRem = dk.bpRemaining or 0
    local desRem = dk.desolationRemaining or 0
    local gfRem = dk.gfRemaining or 0
    local gfUsable = dk.petAlive and dk.knowsGF and ((dk.gfCD or 0) <= gcdRem)

    local hasIT, hasPS = DKHasSpell("IT"), DKHasSpell("PS")
    local hasBS, hasBB = DKHasSpell("BS"), DKHasSpell("BB")
    local hasDND, hasDC = DKHasSpell("DND"), DKHasSpell("DC")
    local hasSS = isSS and DKHasSpell("SS")
    local dndCD = hasDND and (state.spellCooldown("DND") or 0) or 99

    local gargKnown = DKHasSpell("GARG")
    local gargCD = gargKnown and (state.spellCooldown("GARG") or 0) or 999
    local burstOn = state.burstMode ~= false
    local gargReady = gargKnown and burstOn and gargCD <= (gcdRem + 0.1)
    local reserveU = gargReady and rp >= 50 and not dk.hasUnholyPresence      -- guardar una runa Unholy para UP
    -- La lista off pide la Gargola solo en combate y con las plagas firmes (>= 4.5 s) o ya en UP o pelea larga.
    -- Si la Gargola esta lista pero frenada por eso, no tiene sentido guardar RP para ella.
    local dmin = (dk.hasFrostFever and dk.hasBloodPlague) and ((ffRem < bpRem) and ffRem or bpRem) or 0
    local longFight = UH.combatStart and (now - UH.combatStart) > 15
    local gargBlocked = gargReady and not (state.inCombat == true and (dmin >= 4.5 or dk.hasUnholyPresence or longFight))
    -- no vaciar RP justo antes de Gargoyle (cuesta 60)
    local rpFloor = (gargKnown and burstOn and gargCD <= 12 and not gargBlocked) and 60 or 0

    local btKnown = DKHasSpell("BT")
    local btCD = btKnown and (state.spellCooldown("BT") or 0) or 999
    local bloodSlots = UHBloodSlots(runes)
    local btReserved = gargKnown and burstOn and gargCD <= 8
    -- Blood Tap solo suma una runa si las dos Blood estan en CD (si hay una lista se convertiria sin ganancia)
    local btGain = btKnown and btCD <= 0 and bloodSlots > 0 and runes.bloodReady == 0 and UHHealthOK()

    -- Pares de runas que se pueden gastar sin atrasar DnD (Blood 1-2, Unholy 3-4, Frost 5-6)
    local safeB = UHSafePair(runes, 1, 2, dndCD)
    local safeU = UHSafePair(runes, 3, 4, dndCD)
    local safeF = UHSafePair(runes, 5, 6, dndCD)
    -- DnD listo en menos de lo que tarda en volver la runa que falta
    local dndIn = dndCD
    do
        local w = UHTypeWait(runes, 1); if w > dndIn then dndIn = w end
        w = UHTypeWait(runes, 2);       if w > dndIn then dndIn = w end
        w = UHTypeWait(runes, 3);       if w > dndIn then dndIn = w end
    end

    local desOK = UH.desSeen or UH.bsCasts < 3     -- si el buff nunca se detecta, no forzar BS infinito
    local aoeMode = state.aoeMode or state.isAoE

    -- 0. AoE: Death and Decay antes que las enfermedades (Wowhead: DnD donde se junta el grupo y despues plagas)
    if aoeMode and hasDND and dndCD <= (gcdRem + 0.1) and UHCanCast(runes, 1, 1, 1) then return "DND" end

    -- 1. Enfermedades: IT / PS cuando quedan <= 2.5s (con Blood Tap si no hay runa y tarda)
    if hasIT and (ffRem - gcdRem) <= 2.5 then
        state.reason = "Refrescar Frost Fever"
        if UHCanCast(runes, 0, 1, 0) then return "IT" end
        if btGain and not btReserved and UHDeficit(runes, 0, 1, 0) == 1 and UHTypeWait(runes, 3) > 0.8 then
            dk.wantBT = "IT"; return "IT"
        end
        if UHTypeWait(runes, 3) <= (gcdRem + 1.5) then
            state.isWaiting = true; state.waitTime = UHTypeWait(runes, 3); return "IT"
        end
        state.reason = nil
    end
    if hasPS and (bpRem - gcdRem) <= 2.5 then
        state.reason = "Refrescar Blood Plague"
        if UHCanCast(runes, 0, 0, 1) then return "PS" end
        if btGain and not btReserved and UHDeficit(runes, 0, 0, 1) == 1 and UHTypeWait(runes, 2) > 0.8 then
            dk.wantBT = "PS"; return "PS"
        end
        if UHTypeWait(runes, 2) <= (gcdRem + 1.5) then
            state.isWaiting = true; state.waitTime = UHTypeWait(runes, 2); return "PS"
        end
        state.reason = nil
    end

    -- 2. Desolation: Blood Strike cuando quedan <= 2s
    if hasBS and desOK and (desRem - gcdRem) <= 2.0 then
        state.reason = "Mantener Desolation"
        if UHCanCast(runes, 1, 0, 0) then return "BS" end
        if btGain and not btReserved and UHTypeWait(runes, 1) > 0.8 then
            dk.wantBT = "BS"; return "BS"
        end
        if UHTypeWait(runes, 1) <= (gcdRem + 1.0) then
            state.isWaiting = true; state.waitTime = UHTypeWait(runes, 1); return "BS"
        end
        state.reason = nil
    end

    -- 3. Death and Decay apenas este disponible (proteger runas)
    if hasDND and dndCD <= (gcdRem + 0.1) then
        state.reason = "Death and Decay listo"
        if UHCanCast(runes, 1, 1, 1) then return "DND" end
        if btGain and UHDeficit(runes, 1, 1, 1) == 1 then
            state.reason = "Blood Tap para Death and Decay"
            dk.wantBT = "DND"; return "DND"
        end
        local w = UHTypeWait(runes, 1)
        local w2 = UHTypeWait(runes, 2); if w2 > w then w = w2 end
        w2 = UHTypeWait(runes, 3);       if w2 > w then w = w2 end
        if w <= (gcdRem + 1.5) then
            state.reason = "Esperando runas para Death and Decay"
            state.isWaiting = true; state.waitTime = w; return "DND"
        end
        state.reason = nil
    end

    if aoeMode then
        -- AoE: Pestilence solo para esparcir a enemigos sin plagas, o para refrescar con Glyph of Disease
        if dk.hasFrostFever and dk.hasBloodPlague and DKHasSpell("PEST") and UHCanCast(runes, 1, 0, 0) then
            local needSpread
            local plates = state.aoePlateCount or 0
            if plates > 0 then
                -- nameplates: hay algun enemigo en rango sin Frost Fever + Blood Plague
                needSpread = plates > (dk.aoeDiseasedCount or 0)
            else
                -- sin nameplates: re-esparcir cada 20 s (ultimo Pestilence por combat log o por evento de casteo)
                local lastPest = UH.cast.PEST or 0
                local lc = state.lastCast
                local ev = lc and (lc["Pestilence"] or lc["PEST"] or lc[50842]) or 0
                if ev > lastPest then lastPest = ev end
                needSpread = (lastPest == 0) or ((now - lastPest) > 20)
            end
            local refresh = dk.hasGlyphOfDisease == true and safeB
                and ((ffRem - gcdRem) < 8.0 or (bpRem - gcdRem) < 8.0)
            if needSpread then state.reason = "Esparcir plagas"; return "PEST" end
            if refresh then state.reason = "Refrescar plagas (Glyph of Disease)"; return "PEST" end
        end
        if hasBB and safeB and UHCanCast(runes, 1, 0, 0) then state.reason = "Blood Boil (AoE)"; return "BB" end
        if isSS then
            if hasSS and safeU and safeF and UHCanCast(runes, 0, 1, 1) then return "SS" end
        else
            if hasIT and safeF and UHCanCast(runes, 0, 1, 0) then return "IT" end
        end
        if safeU and UHCanCast(runes, 0, 0, 1) and (runes.unholyReady + runes.deathReady - (reserveU and 1 or 0)) > 0 then
            if gfUsable and (gfRem - gcdRem) <= 10 and UHKeepsRuneFor(runes, 2, bpRem - gcdRem - 2.5) then return "GF" end
            if hasPS then return "PS" end
        end
        if btGain and not btReserved and hasBB and dndCD > 3 then
            dk.wantBT = "BB"; return "BB"
        end
        if hasDC and rp >= 40 and (rp - 40) >= rpFloor and dndIn > (gcdRem + 0.8) then return "DC" end
        if DKHasSpell("HOW") and (state.spellCooldown("HOW") or 0) <= gcdRem and dndIn > (gcdRem + 1.0) then
            state.reason = "Horn of Winter (relleno)"; return "HOW"
        end
        state.isWaiting = true
        state.waitTime = hasDND and dndIn or nil
        state.reason = "Esperando runas"
        return hasDND and "DND" or "IT"
    end

    -- ------------------------------------------------------------------ ST
    -- 4. Ghoul Frenzy: cuando le quedan <= 10s
    if gfUsable and (gfRem - gcdRem) <= 10 then
        state.reason = "Ghoul Frenzy por caerse"
        if UHCanCast(runes, 0, 0, 1) and (safeU or runes.deathReady >= 1)
           and ((gfRem <= 3.5 and gfRem < (bpRem - gcdRem)) or UHKeepsRuneFor(runes, 2, bpRem - gcdRem - 2.5)) then
            return "GF"
        end
        if btGain and not btReserved then
            dk.wantBT = "GF"; return "GF"
        end
        if gfRem <= 3.5 and gfRem < (bpRem - gcdRem) and UHCanCast(runes, 0, 0, 1) then return "GF" end
        state.reason = nil
    end

    -- 5. Death Coil anti-cap
    if hasDC and ((rp >= 80 and (gargCD > 5 or gargBlocked)) or rp >= 100) then
        state.reason = "Death Coil: evitar cap de RP"; return "DC"
    end

    -- 6. Gasto de pares sin atrasar DnD
    local uFree = runes.unholyReady + runes.deathReady - (reserveU and 1 or 0)
    local keepU = UHKeepsRuneFor(runes, 2, bpRem - gcdRem - 2.5)
    local keepUGF = (not gfUsable) or UHKeepsRuneFor(runes, 2, gfRem - gcdRem - 3.5)
    local keepF = UHKeepsRuneFor(runes, 3, ffRem - gcdRem - 2.5)
    if isSS then
        -- refresco temprano de plagas con el par seguro (evita gastar la ultima runa justo antes de que caigan)
        if hasPS and (bpRem - gcdRem) <= 5 and safeU and UHCanCast(runes, 0, 0, 1) and uFree > 0 then return "PS" end
        if hasIT and (ffRem - gcdRem) <= 5 and safeF and UHCanCast(runes, 0, 1, 0) then return "IT" end
        if hasSS and safeU and safeF and UHCanCast(runes, 0, 1, 1) and uFree > 0 and keepU and keepUGF and keepF then return "SS" end
        if gfUsable and gfRem < 14 and safeU and UHCanCast(runes, 0, 0, 1) and uFree > 0 and keepU then return "GF" end
    else
        if hasIT and safeF and UHCanCast(runes, 0, 1, 0) then return "IT" end
        if safeU and UHCanCast(runes, 0, 0, 1) and uFree > 0 then
            if gfUsable and gfRem < 14 and keepU then return "GF" end
            if hasPS and keepUGF then return "PS" end
        end
    end

    -- 7. Runas Blood: BS si Desolation < 10s o sin Unholy Strength/Might, si no BB
    if safeB and UHCanCast(runes, 1, 0, 0) then
        if hasBS and ((desRem - gcdRem) < 10.0 or (dk.umRemaining or 0) <= 0) then return "BS" end
        if hasBB then return "BB" end
        if hasBS then return "BS" end
    end

    -- 8. Blood Tap inteligente: Blood en CD -> runa Death extra para GF (<14s) o Blood Boil / Blood Strike
    if btGain and not btReserved then
        if gfUsable and gfRem < 14 and (not reserveU) then
            dk.wantBT = "GF"; return "GF"
        end
        if dndCD > 3 then
            if hasBS and (desRem - gcdRem) < 10.0 then dk.wantBT = "BS"; return "BS" end
            if hasBB then dk.wantBT = "BB"; return "BB" end
        end
    end

    -- 9. Death Coil mientras se espera DnD, sin gastar el RP que necesita Gargoyle
    if hasDC and rp >= 40 and (rp - 40) >= rpFloor and dndIn > (gcdRem + 0.8)
       and (gargCD > 0 or rp >= 100 or not burstOn or gargBlocked) then
        state.reason = "Death Coil: gastar RP"; return "DC"
    end
    if DKHasSpell("HOW") and (state.spellCooldown("HOW") or 0) <= gcdRem and dndIn > (gcdRem + 1.0) then
        state.reason = "Horn of Winter (relleno)"; return "HOW"
    end
    state.isWaiting = true
    state.waitTime = hasDND and dndIn or nil
    if hasDC and rp >= 40 and (rp - 40) < rpFloor then
        state.reason = "Guardando RP para la Gargola"
    elseif hasDC and rp >= 40 and dndIn <= (gcdRem + 0.8) then
        state.reason = "Death and Decay en menos de 1 GCD"
    else
        state.reason = "Esperando runas"
    end
    return hasDND and "DND" or "IT"
end

function RotaClass_DK.EvaluateUnholyMorb(state)
    return RotaClass_DK.EvaluateUnholy(state, false)
end

function RotaClass_DK.EvaluateUnholySS(state)
    return RotaClass_DK.EvaluateUnholy(state, true)
end

-- ----------------------------------------------------------------------------
-- Lista "off": Gargoyle (UP -> racial -> GARG, BP al desaparecer), Blood Tap, haste/ERW
-- ----------------------------------------------------------------------------
function RotaClass_DK.EvaluateUnholyOff(state)
    local dk = state.dk
    local runes = state.runes
    local gcdRem = state.gcdRemains or 0
    local rp = state.power or 0
    local now = state.now or 0
    local burstOn = state.burstMode ~= false
    local inCombat = state.inCombat

    local gargKnown = DKHasSpell("GARG")
    local gargCD = gargKnown and (state.spellCooldown("GARG") or 0) or 999
    local btKnown = DKHasSpell("BT")
    local btCD = btKnown and (state.spellCooldown("BT") or 0) or 999
    local btOK = btKnown and btCD <= 0 and UHHealthOK()
    -- La Gargola toma la haste en cada golpe (Wowhead WotLK + changelog Rebuffed 2026-08-01):
    -- entrar en Unholy Presence antes de invocarla, quedarse mientras vive (30 s) y volver a Blood Presence al final.
    local hasUP = dk.hasUnholyPresence
    local gargActive = gargKnown and gargCD > 150      -- CD de 3 min: los primeros 30 s la Gargola esta viva
    local backToBP = not (state.vars and state.vars.gargBackToBP == 0)

    -- 1. Gargola ya desaparecio: volver a Blood Presence
    if backToBP and hasUP and gargKnown and gargCD > 0 and not gargActive and inCombat == true then
        if UHCanCast(runes, 1, 0, 0) then return "BP" end
        if btOK and UHDeficit(runes, 1, 0, 0) == 1 and UHTypeWait(runes, 1) > 0.8 then return "BT" end
    end

    -- 2. Gargola lista: UP -> racial -> GARG
    -- No arrancar con las plagas por caerse (salvo que lleve >15s sin poder aplicarlas).
    local dmin = 0
    if dk.hasFrostFever and dk.hasBloodPlague then
        dmin = (dk.ffRemaining < dk.bpRemaining) and dk.ffRemaining or dk.bpRemaining
    end
    local longFight = UH.combatStart and (now - UH.combatStart) > 15
    if burstOn and gargKnown and gargCD <= (gcdRem + 0.1) and rp >= 60 and inCombat == true
       and (dmin >= 4.5 or hasUP or longFight) then
        if not hasUP then
            if UHCanCast(runes, 0, 0, 1) then return "UP" end
            if btOK and UHDeficit(runes, 0, 0, 1) == 1 and UHTypeWait(runes, 2) > 0.8 and runes.bloodReady == 0 then
                return "BT"
            end
            return nil
        end
        if state.spellReady("BF") then return "BF" end
        if state.spellReady("RACIAL") then return "RACIAL" end
        return "GARG"
    end

    -- 3. Blood Tap pedido por la lista principal (IT / PS / BS / DnD / GF / BB)
    if dk.wantBT and btOK and inCombat ~= false then
        return "BT"
    end

    -- 4. Gargoyle recien invocado (cd > 150): haste y Empower Rune Weapon
    if burstOn and gargKnown and gargCD > 150 and inCombat == true then
        if state.areGlovesReady and state.areGlovesReady(now) then return "HYPER" end
        if state.spellReady("BERSERKING") then return "BERSERKING" end
        if state.spellReady("SPEED_POT") then return "SPEED_POT" end
        if (state.spellCooldown("ERW") or 0) <= 0
           and (runes.bloodReady + runes.frostReady + runes.unholyReady + runes.deathReady) <= 2 then
            return "ERW"
        end
        -- Wowhead: despues de ERW, Army of the Dead con los mismos buffs (toma la haste al castear)
        if not (state.vars and state.vars.armyOfTheDead == 0) and dk.targetIsBoss
           and (state.spellCooldown("ERW") or 0) > 0 and DKHasSpell("AOTD") and state.spellReady("AOTD") then
            return "AOTD"
        end
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Tracking de casts propios (CLEU 3.3.5a: sin hideCaster; se tolera el formato con hideCaster)
-- ----------------------------------------------------------------------------
local UH_CAST_IDS = {
    [63560] = "GF", [49213] = "GF", [45529] = "BT", [49206] = "GARG",
    [48265] = "UP", [48266] = "BP", [50842] = "PEST", [49930] = "BS",
}

function RotaClass_DK.UHOnCombatLog(sub, a3, a4, a5, a6, a7, a8, a9, a10, a11)
    if sub ~= "SPELL_CAST_SUCCESS" then return end
    local src, sid, sname
    if type(a3) == "boolean" then src, sid, sname = a4, a10, a11 else src, sid, sname = a3, a9, a10 end
    if not src or src ~= (_G.UnitGUID and _G.UnitGUID("player")) then return end
    local key = UH_CAST_IDS[sid]
    if not key and sname then
        local N = UHNames()
        if sname == N.gf then key = "GF"
        elseif sname == "Blood Tap" then key = "BT"
        elseif sname == "Summon Gargoyle" then key = "GARG"
        elseif sname == "Pestilence" then key = "PEST"
        elseif sname == "Blood Strike" then key = "BS" end
    end
    if not key then return end
    UH.cast[key] = (_G.GetTime and _G.GetTime()) or 0
    if key == "BS" then UH.bsCasts = UH.bsCasts + 1 end
end

if _G.CreateFrame and not RotaClass_DK.uhCastFrame then
    local cf = _G.CreateFrame("Frame", "RotaClass_DK_UHCastFrame")
    cf:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    cf:RegisterEvent("PLAYER_REGEN_ENABLED")
    cf:RegisterEvent("PLAYER_REGEN_DISABLED")
    cf:SetScript("OnEvent", function(_, event, _, sub, a3, a4, a5, a6, a7, a8, a9, a10, a11)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            RotaClass_DK.UHOnCombatLog(sub, a3, a4, a5, a6, a7, a8, a9, a10, a11)
        elseif event == "PLAYER_REGEN_DISABLED" then
            UH.combatStart = _G.GetTime and _G.GetTime() or 0
            UH.bsCasts = 0       -- nuevo pull: reintentar deteccion de Desolation
        else
            UH.combatStart = nil
        end
    end)
    RotaClass_DK.uhCastFrame = cf
end

--- Unholy 2H DK Priority Evaluator (Warcraft Tavern 3.3.5a)
function RotaClass_DK.EvaluateUnholy2H(state)
    local dk = state.dk
    local runes = state.runes
    local gcdRem = state.gcdRemains or 0
    local rp = state.power or 0

    local ffRem = dk.ffRemaining or 0
    local bpRem = dk.bpRemaining or 0
    local hasFF = dk.hasFrostFever
    local hasBP = dk.hasBloodPlague
    local desRem = dk.desolationRemaining or 0
    local aoeMode = state.aoeMode or state.isAoE
    state.isWaiting = false

    local canCastRunes = state.canCastRunes or (RotaCore.State and RotaCore.State.data and RotaCore.State.data.canCastRunes)

    if aoeMode then
        local dndCD = state.spellCooldown("DND") or 0
        if dndCD <= (gcdRem + 0.1) and canCastRunes(1, 1, 1) then
            return "DND"
        end
        if (ffRem - gcdRem) <= 2.5 and (runes.frostReady > 0 or runes.deathReady > 0) then
            return "IT"
        end
        if (bpRem - gcdRem) <= 2.5 and (runes.unholyReady > 0 or runes.deathReady > 0) then
            return "PS"
        end
        local now = state.now or 0
        local lastPest = (state.lastCast and (state.lastCast["PEST"] or state.lastCast["Pestilence"] or state.lastCast[50842])) or 0
        local needSpread = (lastPest == 0) or ((now - lastPest) > (dk.minDiseaseRemaining - 3.0))
        if hasFF and hasBP and needSpread and canCastRunes(1, 0, 0) and DKHasSpell("PEST") then
            return "PEST"
        end
        if (desRem - gcdRem) <= 2.0 and canCastRunes(1, 0, 0) and DKHasSpell("BS") then
            return "BS"
        end
        if canCastRunes(1, 0, 0) and DKHasSpell("BB") then
            return "BB"
        end
        if canCastRunes(0, 1, 1) and DKHasSpell("SS") then
            return "SS"
        end
        if rp >= 40 and DKHasSpell("DC") then
            return "DC"
        end
        state.isWaiting = true
        return "DND"
    else
        -- Con Glyph of Disease en 2H: si las enfermedades van a expirar y estan ambas arriba, PEST
        if dk.hasGlyphOfDisease and hasFF and hasBP and (dk.minDiseaseRemaining - gcdRem <= 2.5)
            and canCastRunes(1, 0, 0) and DKHasSpell("PEST") then
            return "PEST"
        end

        -- 1. Mantener Bone Shield si no está activo (fuera de combate o con runa Unholy libre)
        local bshRem = state.buffRemaining("Bone Shield", "player") or 0
        if bshRem <= 0 and DKHasSpell("BSH") then
            if (not state.inCombat and not state.hasTarget) and (runes.unholyReady > 0 or runes.deathReady > 0) then
                return "BSH"
            elseif runes.unholyReady > 0 and (desRem - gcdRem) > 3.0 and ffRem > 2.0 and bpRem > 2.0 then
                return "BSH"
            end
        end

        -- 2. Icy Touch (ffRem <= 2.0s) -> Plague Strike (bpRem <= 2.0s)
        if (ffRem - gcdRem) <= 2.0 and (runes.frostReady > 0 or runes.deathReady > 0) and DKHasSpell("IT") then
            return "IT"
        end
        if (bpRem - gcdRem) <= 2.0 and (runes.unholyReady > 0 or runes.deathReady > 0) and DKHasSpell("PS") then
            return "PS"
        end

        -- 3. Blood Strike si desRem <= 3.0s (mantener Desolation es prioridad)
        if (desRem - gcdRem) <= 3.0 and canCastRunes(1, 0, 0) and DKHasSpell("BS") then
            return "BS"
        end

        -- 4. Scourge Strike (gastador principal de Frost + Unholy)
        if canCastRunes(0, 1, 1) and DKHasSpell("SS") then
            return "SS"
        end

        -- 5. Blood Strike (con runas Blood para mantener Desolation y generar RP)
        if canCastRunes(1, 0, 0) and DKHasSpell("BS") then
            return "BS"
        end

        -- 6. Death Coil (rp >= 40). Con Gargoyle listo y burst ON se reservan 60 RP (Sudden Doom lo lanza gratis)
        local gargKnown2H = DKHasSpell("GARG")
        local gargCD2H = gargKnown2H and (state.spellCooldown("GARG") or 0) or 999
        local holdForGarg = gargKnown2H and (state.burstMode ~= false) and (gargCD2H <= 0)
        local minDC = holdForGarg and 100 or 40
        if DKHasSpell("DC") and (rp >= minDC or (state.hasBuff and state.hasBuff("Sudden Doom", "player"))) then
            return "DC"
        end
        local howRem = state.buffRemaining("Horn of Winter", "player") or 0
        if howRem <= 5 and DKHasSpell("HOW") then
            return "HOW"
        end

        state.isWaiting = true
        return "SS"
    end
end

if RotaCore.State and RotaCore.State.data then
    RotaCore.State.data.evaluateFrost = RotaClass_DK.EvaluateFrost
    RotaCore.State.data.evaluateUnholyMorb = RotaClass_DK.EvaluateUnholyMorb
    RotaCore.State.data.evaluateUnholySS = RotaClass_DK.EvaluateUnholySS
    RotaCore.State.data.evaluateUnholyOff = RotaClass_DK.EvaluateUnholyOff
    RotaCore.State.data.evaluateUnholy2H = RotaClass_DK.EvaluateUnholy2H
    RotaCore.State.data.canWithRunes = RotaCore.State.data.canWithRunes or RotaClass_DK.CanWithRunes
    RotaCore.State.data.grace = RotaCore.State.data.grace or RotaClass_DK.grace
end

RotaClass_DK.UpdateState = UpdateDKState

-- Sin este registro RotaCore solo ve el build "auto" y el boton Build no cicla.
if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "DEATHKNIGHT",
        addonName = "RotaClass_DK",
        classColor = { r = 0.77, g = 0.12, b = 0.23 },
        builds = {
            { key = "auto", name = "AUTO", color = {1.0, 0.9, 0.0} },
            { key = "frost", name = "Frost", color = {0.0, 0.8, 1.0}, preset = "dk_frost_pve" },
            { key = "unholy_morb", name = "UH Morb (DW)", color = {0.3, 1.0, 0.3}, preset = "dk_unholy_morb_pve" },
            { key = "unholy_dw_ss", name = "UH Morb+SS (DW+SS)", color = {0.2, 1.0, 0.7}, preset = "dk_unholy_dw_ss_pve" },
            { key = "unholy_2h", name = "UH", color = {0.8, 0.5, 1.0}, preset = "dk_unholy_2h_pve" },
        },
        detectBuild = function() return RotaClass_DK:DetectBuild() end,
        getIdlePreviewAction = function(buildKey)
            if buildKey == "unholy_morb" then return "DND" end
            if buildKey == "frost" then return "OBL" end
            return "SS"
        end,
        stateProvider = UpdateDKState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("DEATHKNIGHT", UpdateDKState)
end

-- Event Frame for Talent Updates and Load
if _G.CreateFrame then
    local f = _G.CreateFrame("Frame", "RotaClass_DK_EventFrame")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED"
           or event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_LOGIN" then
            RotaClass_DK:DetectBuild()
        end
    end)
    -- Talentos todavia sin cargar (0 puntos): reintentar la deteccion cada 1 s hasta que lleguen
    -- (en Rebuffed PLAYER_TALENT_UPDATE no siempre llega despues del login)
    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        if not RotaClass_DK.talentsPending then return end
        acc = acc + elapsed
        if acc < 1 then return end
        acc = 0
        RotaClass_DK:DetectBuild()
    end)
    RotaClass_DK.eventFrame = f
end

return RotaClass_DK
