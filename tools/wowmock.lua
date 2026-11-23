-- tools/wowmock.lua — High-Fidelity Mock Environment for WoW 3.3.5a (Interface 30300)
-- Implements: Monotonic Clock, DK 6 Runes with 2.5s Grace Period, GCD, UnitAura 3.3.5a, Frame Events & Spells.

local wowmock = {
    now = 1000.0,
    gcdStart = 0,
    gcdDuration = 0,
    playerClass = { "Death Knight", "DEATHKNIGHT" },
    runes = {},
    auras = {
        player = {},
        target = {},
    },
    spells = {},
    power = {
        player = { [0] = 1000, [1] = 0, [6] = 0 }, -- 0: Mana, 1: Rage, 6: Runic Power
        maxPower = { [0] = 5000, [1] = 100, [6] = 100 },
    },
    health = {
        player = 10000,
        target = 50000,
    },
    maxHealth = {
        player = 10000,
        target = 50000,
    },
    currentSpells = {},
    shapeshiftForm = 1,
    creatureTypes = {
        target = "Humanoid",
    },
    talents = {
        activeGroup = 1,
        tabs = {
            [1] = { name = "Blood", pointsSpent = 0, talents = {} },
            [2] = { name = "Frost", pointsSpent = 0, talents = {} },
            [3] = { name = "Unholy", pointsSpent = 0, talents = {} },
        },
    },
    spellbook = {
        tabs = {},
        spells = {},
        knownSpells = {},
    },
    frames = {},
    registeredEvents = {}, -- [eventName] = { [frame] = true }
    nameplates = {},
    controlledUnits = {},
    silencedUnits = {},
    disarmedUnits = {},
    combatUnits = {},
    cannotAttack = {},
    clipboard = nil,
    spellBaseCD = {},
    threatSituation = {},
}

local MOCK_NP_TOKENS = {}
local MOCK_NP_GUIDS = {}
local MOCK_NP_NAMES = {}
for i = 1, 40 do
    local tok = "nameplate" .. i
    MOCK_NP_TOKENS[tok] = i
    MOCK_NP_GUIDS[tok] = string.format("0xF13000000000%04X", i)
    MOCK_NP_NAMES[tok] = "Mob " .. tok
end

-- ============================================================================
-- 1. TIME / CLOCK
-- ============================================================================

function wowmock.getTime()
    return wowmock.now
end

function wowmock.setTime(t)
    wowmock.now = t
end

function wowmock.advanceTime(dt)
    wowmock.now = wowmock.now + dt
    wowmock.updateRunes()
end

-- ============================================================================
-- 2. DEATH KNIGHT 6 RUNES & 2.5s GRACE PERIOD
-- ============================================================================
-- Standard 3.3.5a Rune Types:
-- 1: Blood, 2: Unholy, 3: Frost, 4: Death
-- Slots: 1, 2 = Blood; 3, 4 = Frost; 5, 6 = Unholy

local BASE_RUNE_CD = 10.0
local MAX_GRACE_PERIOD = 2.5

function wowmock.initRunes()
    wowmock.runes = {
        { id = 1, defaultType = 1, currentType = 1, start = 0, duration = 0, readyAt = 0, ready = true },
        { id = 2, defaultType = 1, currentType = 1, start = 0, duration = 0, readyAt = 0, ready = true },
        { id = 3, defaultType = 3, currentType = 3, start = 0, duration = 0, readyAt = 0, ready = true },
        { id = 4, defaultType = 3, currentType = 3, start = 0, duration = 0, readyAt = 0, ready = true },
        { id = 5, defaultType = 2, currentType = 2, start = 0, duration = 0, readyAt = 0, ready = true },
        { id = 6, defaultType = 2, currentType = 2, start = 0, duration = 0, readyAt = 0, ready = true },
    }
end

function wowmock.updateRunes()
    local t = wowmock.now
    for i = 1, 6 do
        local r = wowmock.runes[i]
        if not r.ready and t >= r.readyAt then
            r.ready = true
            -- readyAt marks the moment it finished cooldown
        end
    end
end

function wowmock.getGracePeriod(slot)
    local r = wowmock.runes[slot]
    if not r or not r.ready or r.readyAt == 0 then
        return 0
    end
    local elapsedSinceReady = wowmock.now - r.readyAt
    if elapsedSinceReady < 0 then elapsedSinceReady = 0 end
    return math.min(MAX_GRACE_PERIOD, elapsedSinceReady)
end

function wowmock.useRune(slot)
    local r = wowmock.runes[slot]
    if not r then return false, "invalid_slot" end
    if not r.ready then return false, "on_cooldown" end

    local grace = wowmock.getGracePeriod(slot)
    local actualCD = BASE_RUNE_CD - grace
    if actualCD < 0 then actualCD = 0 end

    r.start = wowmock.now
    r.duration = actualCD
    r.readyAt = wowmock.now + actualCD
    r.ready = false

    return true, actualCD, grace
end

function wowmock.spendRuneByType(runeType)
    -- First try exact rune type match, then Death rune (4)
    for i = 1, 6 do
        local r = wowmock.runes[i]
        if r.ready and r.currentType == runeType then
            return wowmock.useRune(i)
        end
    end
    if runeType ~= 4 then
        for i = 1, 6 do
            local r = wowmock.runes[i]
            if r.ready and r.currentType == 4 then
                return wowmock.useRune(i)
            end
        end
    end
    return false, "no_runes_ready"
end

function wowmock.convertRune(slot, newType)
    local r = wowmock.runes[slot]
    if r then
        r.currentType = newType
        return true
    end
    return false
end

-- WoW 3.3.5a API: GetRuneCooldown(slot) -> start, duration, runeReady
function wowmock.getRuneCooldown(slot)
    local r = wowmock.runes[slot]
    if not r then return 0, 0, false end
    if r.ready then
        return r.start, r.duration, true
    else
        return r.start, r.duration, false
    end
end

-- WoW 3.3.5a API: GetRuneType(slot) -> runeType
function wowmock.getRuneType(slot)
    local r = wowmock.runes[slot]
    return r and r.currentType or 1
end

-- ============================================================================
-- 3. GLOBAL COOLDOWN (GCD)
-- ============================================================================

function wowmock.triggerGCD(duration)
    wowmock.gcdStart = wowmock.now
    wowmock.gcdDuration = duration or 1.5
end

function wowmock.isGCDActive()
    return (wowmock.now < (wowmock.gcdStart + wowmock.gcdDuration))
end

-- ============================================================================
-- 4. UNIT AURA (WoW 3.3.5a Indexed Signature)
-- ============================================================================
-- Signature: UnitAura(unit, index [, filter])
-- Returns: name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId

function wowmock.setAura(unit, aura)
    if not wowmock.auras[unit] then wowmock.auras[unit] = {} end
    table.insert(wowmock.auras[unit], {
        name = aura.name or "Unknown Aura",
        rank = aura.rank or "",
        icon = aura.icon or "Interface\\Icons\\Spell_Nature_BloodLust",
        count = aura.count or 0,
        debuffType = aura.debuffType or "",
        duration = aura.duration or 0,
        expirationTime = aura.expirationTime or (aura.duration and (wowmock.now + aura.duration) or 0),
        unitCaster = aura.unitCaster or "player",
        isStealable = aura.isStealable or false,
        shouldConsolidate = aura.shouldConsolidate or false,
        spellId = aura.spellId or 0,
        filter = aura.filter or "HELPFUL",
    })
end

function wowmock.setDebuff(unit, idx, name, debuffType, duration, expirationTime, count, spellId, unitCaster)
    wowmock.setAura(unit, {
        name = name,
        filter = "HARMFUL",
        debuffType = debuffType,
        duration = duration,
        expirationTime = (expirationTime and (wowmock.now + expirationTime)) or (duration and (wowmock.now + duration)) or 0,
        count = count or 1,
        spellId = spellId or 0,
        unitCaster = unitCaster or "player",
    })
end

function wowmock.clearAuras(unit)
    if unit then
        wowmock.auras[unit] = {}
    else
        wowmock.auras.player = {}
        wowmock.auras.target = {}
    end
end

function wowmock.unitAura(unit, index, filter)
    local list = wowmock.auras[unit]
    if not list then return nil end

    local matchCount = 0
    for _, aura in ipairs(list) do
        local matches = true
        if filter then
            if filter:find("HELPFUL") and aura.filter ~= "HELPFUL" then matches = false end
            if filter:find("HARMFUL") and aura.filter ~= "HARMFUL" then matches = false end
            if filter:find("PLAYER") and aura.unitCaster ~= "player" then matches = false end
        end
        if matches then
            matchCount = matchCount + 1
            if matchCount == index then
                return aura.name, aura.rank, aura.icon, aura.count, aura.debuffType,
                       aura.duration, aura.expirationTime, aura.unitCaster,
                       aura.isStealable, aura.shouldConsolidate, aura.spellId
            end
        end
    end
    return nil
end

-- ============================================================================
-- 5. POWER & RESOURCES
-- ============================================================================

function wowmock.setPower(unit, powerType, currentVal, maxVal)
    if not wowmock.power[unit] then wowmock.power[unit] = {} end
    if not wowmock.power.maxPower[unit] then wowmock.power.maxPower[unit] = {} end
    wowmock.power[unit][powerType] = currentVal
    if maxVal then
        wowmock.power.maxPower[unit][powerType] = maxVal
    end
end

function wowmock.getPower(unit, powerType)
    powerType = powerType or 0
    local u = wowmock.power[unit]
    return (u and u[powerType]) or 0
end

function wowmock.getPowerMax(unit, powerType)
    powerType = powerType or 0
    local u = wowmock.power.maxPower[unit]
    return (u and u[powerType]) or 100
end

function wowmock.setHealth(unit, cur, maxVal)
    wowmock.health[unit] = cur
    if maxVal then wowmock.maxHealth[unit] = maxVal end
end

function wowmock.setCurrentSpell(nameOrId, isCurrent)
    wowmock.currentSpells[nameOrId] = isCurrent or nil
end

function wowmock.setShapeshiftForm(form)
    wowmock.shapeshiftForm = form or 1
end

function wowmock.setCreatureType(unit, cType)
    wowmock.creatureTypes[unit] = cType
end

function wowmock.setClass(name, token)
    wowmock.playerClass[1] = name
    wowmock.playerClass[2] = token
end

-- ============================================================================
-- 6. SPELLBOOK & COOLDOWNS
-- ============================================================================

function wowmock.addSpellBookItem(slot, spellId)
    wowmock.spellbook.spells[slot] = spellId
end

function wowmock.registerSpell(id, name, rank, icon, cdDuration, isRanged)
    local entry = {
        id = id,
        name = name,
        rank = rank or "",
        icon = icon or "Interface\\Icons\\Spell_Nature_BloodLust",
        cdDuration = cdDuration or 0,
        cdStart = 0,
        isRanged = isRanged or false,
    }
    wowmock.spells[id] = entry
    wowmock.spells[name] = entry
end

function wowmock.triggerSpellCD(nameOrId, duration)
    local s = wowmock.spells[nameOrId]
    if not s then
        wowmock.registerSpell(nameOrId, tostring(nameOrId), "", "", duration or 10)
        s = wowmock.spells[nameOrId]
    end
    if s then
        s.cdStart = wowmock.now
        s.cdDuration = duration or s.cdDuration
    end
end

function wowmock.clearSpellCDs()
    for _, s in pairs(wowmock.spells) do
        if type(s) == "table" then
            s.cdStart = 0
            s.cdDuration = 0
        end
    end
end

function wowmock.getSpellInfo(nameOrId)
    local s = wowmock.spells[nameOrId]
    if s then
        return s.name, s.rank, s.icon, 0, false, 0, 0, (s.isRanged and 0 or nil), (s.isRanged and 30 or nil)
    end
    return tostring(nameOrId), "", "Interface\\Icons\\Spell_Nature_BloodLust", 0, false, 0, 0, nil, nil
end

wowmock.unknownSpells = {}

function wowmock.setSpellUnknown(nameOrId, isUnknown)
    wowmock.unknownSpells[nameOrId] = (isUnknown ~= false)
end

function wowmock.getSpellCooldown(nameOrId)
    if wowmock.unknownSpells and (wowmock.unknownSpells[nameOrId] or (type(nameOrId) == "string" and nameOrId:find("NON_EXISTENT"))) then
        return nil
    end
    if type(nameOrId) == "number" and nameOrId > 9000000 then
        return nil
    end

    -- Check Howling Blast and Scourge Strike against knownSpells and talents.tabs
    if nameOrId == "Howling Blast" or nameOrId == 49143 or nameOrId == 51411 then
        local known = false
        local ks = wowmock.spellbook and wowmock.spellbook.knownSpells
        if ks and (ks[49143] or ks[51411]) then
            known = true
        end
        if wowmock.talents and wowmock.talents.tabs then
            for _, tab in pairs(wowmock.talents.tabs) do
                for _, tal in ipairs(tab.talents or {}) do
                    if (tal.name == "Howling Blast" or tal.spellId == 49143 or tal.spellId == 51411) and (tal.rank or 0) > 0 then
                        known = true
                    end
                end
            end
        end
        if not known then
            return nil
        end
    end

    if nameOrId == "Scourge Strike" or nameOrId == 55090 or nameOrId == 55271 then
        local known = false
        local ks = wowmock.spellbook and wowmock.spellbook.knownSpells
        if ks and (ks[55090] or ks[55271]) then
            known = true
        end
        if wowmock.talents and wowmock.talents.tabs then
            for _, tab in pairs(wowmock.talents.tabs) do
                for _, tal in ipairs(tab.talents or {}) do
                    if (tal.name == "Scourge Strike" or tal.spellId == 55090 or tal.spellId == 55271) and (tal.rank or 0) > 0 then
                        known = true
                    end
                end
            end
        end
        if not known then
            return nil
        end
    end

    local s = wowmock.spells[nameOrId]
    if s and s.cdStart and s.cdStart > 0 and s.cdDuration and (wowmock.now < (s.cdStart + s.cdDuration)) then
        return s.cdStart, s.cdDuration, 1
    end
    -- Fallback to GCD if active
    if wowmock.isGCDActive() then
        return wowmock.gcdStart, wowmock.gcdDuration, 1
    end
    return 0, 0, 1
end

-- ============================================================================
-- 7. FRAME & EVENT SYSTEM
-- ============================================================================

local FrameMethods = {}
FrameMethods.__index = FrameMethods

function FrameMethods:SetScript(handler, fn)
    self.scripts[handler] = fn
end

function FrameMethods:GetScript(handler)
    return self.scripts[handler]
end

function FrameMethods:RegisterEvent(event)
    self.events[event] = true
    if not wowmock.registeredEvents[event] then
        wowmock.registeredEvents[event] = {}
    end
    wowmock.registeredEvents[event][self] = true
end

function FrameMethods:UnregisterEvent(event)
    self.events[event] = nil
    if wowmock.registeredEvents[event] then
        wowmock.registeredEvents[event][self] = nil
    end
end

function FrameMethods:Show() self.visible = true; self.shown = true end
function FrameMethods:Hide() self.visible = false; self.shown = false end
function FrameMethods:IsShown() return self.visible or false end
function FrameMethods:SetSize(w, h) self.width = w; self.height = h end
function FrameMethods:SetPoint(point, relTo, relPoint, x, y)
    self.points = { point or "CENTER", relTo or _G.UIParent, relPoint or "CENTER", x or 0, y or 0 }
end
function FrameMethods:GetPoint(index)
    if self.points then
        return self.points[1], self.points[2], self.points[3], self.points[4], self.points[5]
    end
    return "CENTER", _G.UIParent, "CENTER", 0, 0
end
function FrameMethods:SetBackdrop(bg) self.backdrop = bg end
function FrameMethods:GetBackdrop() return self.backdrop end
function FrameMethods:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
function FrameMethods:GetBackdropColor()
    local c = self.backdropColor or { 0, 0, 0, 1 }
    return c[1], c[2], c[3], c[4]
end
function FrameMethods:SetBackdropBorderColor(r, g, b, a) self.backdropBorderColor = { r, g, b, a } end
function FrameMethods:GetBackdropBorderColor()
    local c = self.backdropBorderColor or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
end
function FrameMethods:SetTextInsets(l, r, t, b) self.textInsets = { l, r, t, b } end
function FrameMethods:GetTextInsets()
    local ins = self.textInsets or { 0, 0, 0, 0 }
    return ins[1], ins[2], ins[3], ins[4]
end
function FrameMethods:StartMoving() self.isMoving = true end
function FrameMethods:StopMovingOrSizing() self.isMoving = false end
function FrameMethods:EnableMouse(val)
    self.mouseEnabled = (val ~= false and val ~= nil)
end
function FrameMethods:IsMouseEnabled() return self.mouseEnabled or false end
function FrameMethods:EnableMouseWheel(val)
    self.mouseWheelEnabled = (val ~= false and val ~= nil)
end
function FrameMethods:IsMouseWheelEnabled() return self.mouseWheelEnabled or false end
function FrameMethods:SetVerticalScroll(val) self.verticalScroll = val end
function FrameMethods:GetVerticalScroll() return self.verticalScroll or 0 end
function FrameMethods:CreateFontString(name, layer, inherits)
    local fs = {
        name = name,
        layer = layer,
        fontObject = inherits,
        font = nil,
        text = "",
        SetPoint = function(...) end,
        ClearAllPoints = function(...) end,
        SetFontObject = function(s, obj)
            s.fontObject = obj
        end,
        GetFontObject = function(s)
            return s.fontObject
        end,
        SetFont = function(s, font, size, flags)
            s.font = font
        end,
        GetFont = function(s)
            return s.font
        end,
        SetText = function(s, t)
            if not s.fontObject and not s.font then
                error(string.format("%s:SetText(): Font not set", s.name or "<unnamed>"), 2)
            end
            s.text = tostring(t or "")
        end,
        GetText = function(s)
            return s.text or ""
        end,
        SetTextColor = function(...) end,
        SetJustifyH = function(...) end,
        SetJustifyV = function(...) end,
        SetWidth = function(...) end,
        SetHeight = function(...) end,
        shown = true,
        Show = function(s) s.shown = true end,
        Hide = function(s) s.shown = false end,
        IsShown = function(s) return s.shown or false end,
        SetAlpha = function(...) end,
    }
    return fs
end
function FrameMethods:SetScrollChild(...) end
function FrameMethods:SetMultiLine(...) end
function FrameMethods:SetMaxLetters(...) end
function FrameMethods:SetAutoFocus(...) end
function FrameMethods:SetFontObject(...) end
function FrameMethods:SetWidth(w) self.width = w end
function FrameMethods:SetHeight(h) self.height = h end
function FrameMethods:ClearAllPoints() end
function FrameMethods:SetAllPoints(...) end
function FrameMethods:SetNumeric(...) end
function FrameMethods:SetMovable(...) end
function FrameMethods:SetClampedToScreen(...) end
function FrameMethods:SetText(t)
    self.text = tostring(t or "")
    if self.scripts and self.scripts["OnTextChanged"] then
        self.scripts["OnTextChanged"](self)
    end
end
function FrameMethods:GetText() return self.text or "" end
function FrameMethods:HighlightText(...) end
function FrameMethods:ClearFocus(...) end
function FrameMethods:CreateTexture(...)
    local tex = {
        shown = false,
        desaturated = false,
        vertexColor = { 1, 1, 1, 1 },
        SetPoint = function(...) end,
        SetTexture = function(...) end,
        SetTexCoord = function(...) end,
        SetAllPoints = function(...) end,
        SetSize = function(...) end,
        SetBlendMode = function(...) end,
        SetVertexColor = function(t, r, g, b, a) t.vertexColor = { r, g, b, a } end,
        GetVertexColor = function(t) if t.vertexColor then return unpack(t.vertexColor) else return 1, 1, 1, 1 end end,
        SetDesaturated = function(t, val) t.desaturated = val and true or false end,
        IsDesaturated = function(t) return t.desaturated or false end,
        Show = function(t) t.shown = true end,
        Hide = function(t) t.shown = false end,
        IsShown = function(t) return t.shown end,
    }
    return tex
end
function FrameMethods:RegisterForClicks(...) end
function FrameMethods:RegisterForDrag(...) self.dragButtons = { ... } end
function FrameMethods:GetCenter() return 200, 200 end
function FrameMethods:GetEffectiveScale() return 1 end
function FrameMethods:SetAlpha(a) self.alpha = a end
function FrameMethods:GetAlpha() return self.alpha or 1.0 end
function FrameMethods:SetDrawEdge(val) self.drawEdge = val end
function FrameMethods:SetFrameStrata(s) self.strata = s end
function FrameMethods:GetChecked() return self.checked end
function FrameMethods:SetChecked(val) self.checked = val and true or false end
function FrameMethods:GetName() return self.name end
function FrameMethods:GetParent() return self.parent end

function wowmock.createFrame(frameType, name, parent, template)
    local frame = setmetatable({
        frameType = frameType,
        name = name,
        parent = parent,
        template = template,
        scripts = {},
        events = {},
        visible = true,
        width = 0,
        height = 0,
    }, FrameMethods)
    table.insert(wowmock.frames, frame)
    return frame
end

function wowmock.fireEvent(eventName, ...)
    local targets = wowmock.registeredEvents[eventName]
    if targets then
        for frame in pairs(targets) do
            local onEvent = frame.scripts["OnEvent"]
            if onEvent then
                onEvent(frame, eventName, ...)
            end
        end
    end
end

-- ============================================================================
-- 8. GLOBAL INJECTION
-- ============================================================================

function wowmock.init()
    wowmock.initRunes()

    wowmock.registerSpell(49213, "Ghoul Frenzy", "Rank 1", "Interface\\Icons\\Ability_GhoulFrenzy", 10.0)
    wowmock.registerSpell(63560, "Ghoul Frenzy", "Rank 1", "Interface\\Icons\\Ability_GhoulFrenzy", 10.0)
    wowmock.registerSpell(46584, "Raise Dead", "", "Interface\\Icons\\Spell_Shadow_AnimateDead", 180.0)
    wowmock.registerSpell(54758, "Hyperspeed Acceleration", "", "Interface\\Icons\\INV_Gizmo_RocketBoots_Destroyed", 120.0)
    wowmock.registerSpell(49143, "Howling Blast", "Rank 1", "Interface\\Icons\\Spell_Frost_ArcticWinds", 8.0)
    wowmock.registerSpell(51411, "Howling Blast", "Rank 2", "Interface\\Icons\\Spell_Frost_ArcticWinds", 8.0)
    wowmock.registerSpell(55090, "Scourge Strike", "Rank 1", "Interface\\Icons\\Spell_DeathKnight_ScourgeStrike", 0.0)
    wowmock.registerSpell(55271, "Scourge Strike", "Rank 4", "Interface\\Icons\\Spell_DeathKnight_ScourgeStrike", 0.0)
    wowmock.registerSpell(53385, "Divine Storm", "", "Interface\\Icons\\Ability_Paladin_DivineStorm", 10.0)
    wowmock.registerSpell(48819, "Consecration", "", "Interface\\Icons\\Spell_Holy_InnerFire", 8.0)
    wowmock.registerSpell(35395, "Crusader Strike", "", "Interface\\Icons\\Spell_Holy_CrusaderStrike", 4.0)
    wowmock.registerSpell(53408, "Judgement of Wisdom", "", "Interface\\Icons\\Spell_Holy_RighteousnessAura", 8.0)
    wowmock.registerSpell(20271, "Judgement of Light", "", "Interface\\Icons\\Spell_Holy_RighteousnessAura", 8.0)
    wowmock.registerSpell(53407, "Judgement of Justice", "", "Interface\\Icons\\Spell_Holy_RighteousnessAura", 8.0)
    wowmock.registerSpell(48817, "Holy Wrath", "", "Interface\\Icons\\Spell_Holy_Excorcism", 30.0)
    wowmock.registerSpell(48806, "Hammer of Wrath", "", "Interface\\Icons\\Ability_ThunderBolt", 6.0)
    wowmock.registerSpell(48801, "Exorcism", "", "Interface\\Icons\\Spell_Holy_Excorcism_02", 15.0)

    _G.GetTime = wowmock.getTime
    _G.CreateFrame = function(...) return wowmock.createFrame(...) end

    _G.GetRuneCooldown = wowmock.getRuneCooldown
    _G.GetRuneType = wowmock.getRuneType

    _G.UnitAura = function(unit, idx, filter) return wowmock.unitAura(unit, idx, filter) end
    _G.UnitBuff = function(unit, idx, filter) return wowmock.unitAura(unit, idx, filter or "HELPFUL") end
    _G.UnitDebuff = function(unit, idx, filter) return wowmock.unitAura(unit, idx, filter or "HARMFUL") end

    _G.UnitPower = function(unit, pType) return wowmock.getPower(unit, pType) end
    _G.UnitPowerMax = function(unit, pType) return wowmock.getPowerMax(unit, pType) end
    _G.UnitMana = function(unit) return wowmock.getPower(unit, 0) end
    _G.UnitManaMax = function(unit) return wowmock.getPowerMax(unit, 0) end

    wowmock.comboPoints = 0
    function wowmock.setComboPoints(cp)
        wowmock.comboPoints = cp or 0
    end
    _G.GetComboPoints = function(unit, target)
        return wowmock.comboPoints or 0
    end

    _G.GetSpellInfo = wowmock.getSpellInfo
    _G.GetSpellCooldown = wowmock.getSpellCooldown
    _G.IsSpellInRange = function(name, unit)
        if unit and MOCK_NP_TOKENS[unit] then
            return nil
        end
        if wowmock.spellInRange and wowmock.spellInRange[unit] ~= nil then
            return wowmock.spellInRange[unit]
        end
        return 1
    end
    _G.IsUsableSpell = function(name) return true, false end

    _G.IsSpellKnown = function(spellId)
        if wowmock.spellbook and wowmock.spellbook.knownSpells then
            return wowmock.spellbook.knownSpells[spellId] and true or false
        end
        return false
    end

    _G.GetNumTalentTabs = function() return 3 end
    _G.GetTalentTabInfo = function(tab)
        local t = wowmock.talents.tabs[tab]
        if t then
            return t.name or ("Tab_" .. tab), t.icon or "Interface\\Icons\\Talent", t.pointsSpent or 0
        end
        return "Tab_" .. tab, "Interface\\Icons\\Talent", 0
    end
    _G.GetNumTalents = function(tab)
        local t = wowmock.talents.tabs[tab]
        if t and t.talents and #t.talents > 0 then
            return #t.talents
        end
        return 5
    end
    _G.GetTalentInfo = function(tab, idx)
        local t = wowmock.talents.tabs[tab]
        if t and t.talents and t.talents[idx] then
            local tal = t.talents[idx]
            return tal.name, tal.icon or "Interface\\Icons\\Talent", tal.tier or 1, tal.col or idx, tal.rank or 0, tal.maxRank or 5
        end
        return "Talent_" .. tab .. "_" .. idx, "Interface\\Icons\\Talent", 1, idx, 1, 5
    end
    _G.GetActiveTalentGroup = function() return wowmock.talents.activeGroup end
    wowmock.glyphs = {}
    function wowmock.setGlyph(idx, spellId, name, icon)
        wowmock.glyphs[idx] = { enabled = true, glyphType = 1, spellId = spellId, icon = icon or "Interface\\Icons\\Glyph" }
        if name and spellId then
            wowmock.spells[spellId] = { name = name, rank = "", icon = icon or "Interface\\Icons\\Glyph" }
            wowmock.spells[name] = { name = name, rank = "", icon = icon or "Interface\\Icons\\Glyph" }
        end
    end
    function wowmock.clearGlyphs()
        wowmock.glyphs = {}
        for i = 1, 6 do wowmock.glyphs[i] = false end
    end
    function wowmock.resetDefaultGlyphs()
        wowmock.glyphs = {}
    end

    _G.GetGlyphSocketInfo = function(idx)
        if wowmock.glyphs and wowmock.glyphs[idx] ~= nil then
            local g = wowmock.glyphs[idx]
            if g == false then return false, 0, 0, nil end
            return g.enabled, g.glyphType, g.spellId, g.icon
        end
        return true, 1, 50000 + idx, "Interface\\Icons\\Glyph"
    end

    -- UIDropDownMenu APIs (WoW 3.3.5a)
    _G.UIDropDownMenu_Initialize = function(frame, initFn)
        if frame then
            frame.initFn = initFn
            if initFn then initFn(frame, 1) end
        end
    end
    _G.UIDropDownMenu_SetWidth = function(frame, width)
        if frame and frame.SetWidth then frame:SetWidth(width) end
    end
    _G.UIDropDownMenu_SetSelectedValue = function(frame, val)
        if frame then frame.selectedValue = val end
    end
    _G.UIDropDownMenu_GetSelectedValue = function(frame)
        return frame and frame.selectedValue
    end
    _G.UIDropDownMenu_SetText = function(frame, text)
        if frame and frame.text and frame.text.SetText then
            frame.text:SetText(text)
        end
    end
    _G.UIDropDownMenu_CreateInfo = function()
        return {}
    end
    _G.UIDropDownMenu_AddButton = function(info, level)
        if not wowmock.dropdownButtons then wowmock.dropdownButtons = {} end
        table.insert(wowmock.dropdownButtons, info)
    end

    _G.GetNumSpellTabs = function() return 2 end
    _G.GetSpellTabInfo = function(tab)
        if tab == 1 then
            return "General", nil, 0, 2
        else
            return "Specialization", nil, 2, 4
        end
    end
    _G.GetSpellName = function(slot, bookType)
        local customId = wowmock.spellbook.spells[slot]
        if customId then
            local s = wowmock.spells[customId]
            if s and s.name then
                return s.name, s.rank or ""
            end
        end
        return "TestSpell_" .. slot, "Rank 1"
    end
    _G.GetSpellLink = function(nameOrSlot, bookType)
        if type(nameOrSlot) == "number" and bookType then
            local spellId = wowmock.spellbook.spells[nameOrSlot] or (49000 + nameOrSlot)
            local spellName = "TestSpell_" .. nameOrSlot
            local s = wowmock.spells[spellId]
            if s and s.name then spellName = s.name end
            return string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", spellId, spellName)
        elseif type(nameOrSlot) == "number" then
            local s = wowmock.spells[nameOrSlot]
            local spellName = s and s.name or ("Spell_" .. nameOrSlot)
            return string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", nameOrSlot, spellName)
        elseif type(nameOrSlot) == "string" then
            local s = wowmock.spells[nameOrSlot]
            local id = s and s.id or 12345
            return string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", id, nameOrSlot)
        end
        return nil
    end
    -- In WoW 3.3.5a standard client, GetSpellBookItemInfo is nil
    _G.GetSpellBookItemInfo = nil

    wowmock.playerName = "Player"
    wowmock.realmName = "Frostmourne"
    _G.UnitName = function(unit)
        if unit == "player" then return wowmock.playerName or "Player" end
        return "Target"
    end
    _G.GetRealmName = function() return wowmock.realmName or "Frostmourne" end
    function wowmock.setCharacter(name, realm)
        wowmock.playerName = name or "Player"
        wowmock.realmName = realm or "Frostmourne"
    end

    _G.UnitClass = function(unit)
        if unit == "player" then
            return wowmock.playerClass[1], wowmock.playerClass[2]
        end
        return "Warrior", "WARRIOR"
    end
    _G.UnitRace = function(unit) return "Human" end

    -- Chaman: totems por slot { name, start, duration } e imbues de arma
    wowmock.totems = {}
    _G.GetTotemInfo = function(slot)
        local t = wowmock.totems[slot]
        if not t then return false, "", 0, 0, nil end
        return true, t.name, t.start or 0, t.duration or 60, nil
    end
    wowmock.weaponEnchant = { main = false, off = false }
    _G.GetWeaponEnchantInfo = function()
        local w = wowmock.weaponEnchant
        return w.main, w.main and 1800000 or nil, 0, w.off, w.off and 1800000 or nil, 0
    end
    wowmock.offhandWeapon = false
    _G.OffhandHasWeapon = function() return wowmock.offhandWeapon end
    wowmock.classification = {}
    _G.UnitClassification = function(unit) return wowmock.classification[unit] or "normal" end
    wowmock.playerSpeed = 0
    _G.GetUnitSpeed = function(unit) return unit == "player" and wowmock.playerSpeed or 0 end
    _G.UnitLevel = function(unit) return 80 end
    _G.UnitExists = function(unit)
        if not unit then return false end
        if unit == "pet" then
            return wowmock.petExists ~= false
        end
        local npIdx = MOCK_NP_TOKENS[unit]
        if npIdx then
            if wowmock.nameplateUnits then
                return wowmock.nameplateUnits[unit] and true or false
            end
            if wowmock.nameplates then
                local numPlates = #wowmock.nameplates
                if numPlates == 0 then return false end
                for idx = 1, numPlates do
                    local p = wowmock.nameplates[idx]
                    if p == unit or (type(p) == "table" and p.unit == unit) or idx == npIdx then
                        return true
                    end
                end
                return false
            end
            return false
        end
        return true
    end
    _G.UnitGUID = function(unit)
        if not unit or not _G.UnitExists(unit) then return nil end
        if wowmock.unitGUIDs and wowmock.unitGUIDs[unit] then
            return wowmock.unitGUIDs[unit]
        end
        if unit == "player" then
            return "0x0000000000000001"
        elseif unit == "target" then
            return wowmock.targetGUID or "0xF130000000000099"
        elseif unit == "pet" then
            return "0xF140000000000001"
        end
        local npGuid = MOCK_NP_GUIDS[unit]
        if npGuid then
            return npGuid
        end
        return "0xF130000000000000"
    end
    _G.UnitName = function(unit)
        if not unit or not _G.UnitExists(unit) then return nil end
        if wowmock.unitNames and wowmock.unitNames[unit] then
            return wowmock.unitNames[unit]
        end
        if unit == "player" then return wowmock.playerName or "Player" end
        if unit == "target" then return "Target Dummy" end
        local npName = MOCK_NP_NAMES[unit]
        if npName then
            return npName
        end
        return "Mob " .. unit
    end
    _G.IsItemInRange = function(itemId, unit)
        if wowmock.itemInRange and wowmock.itemInRange[unit] ~= nil then
            if type(wowmock.itemInRange[unit]) == "table" then
                return wowmock.itemInRange[unit][itemId]
            end
            local val = wowmock.itemInRange[unit]
            if val == "nil" or val == false then return nil end
            return val
        end
        return 1
    end
    _G.GetCVar = function(cvar)
        if wowmock.cvars and wowmock.cvars[cvar] ~= nil then
            local val = wowmock.cvars[cvar]
            if val == "0" or val == 0 or val == false then return "0" end
            return "1"
        end
        return "1"
    end
    _G.UnitIsDead = function(unit)
        if unit == "pet" then
            return wowmock.petDead or false
        end
        if wowmock.deadUnits and wowmock.deadUnits[unit] then
            return true
        end
        return false
    end
    _G.UnitIsDeadOrGhost = function(unit)
        return _G.UnitIsDead(unit)
    end
    _G.UnitAffectingCombat = function(unit)
        if wowmock.combatUnits and wowmock.combatUnits[unit] ~= nil then
            return wowmock.combatUnits[unit]
        end
        if unit == "player" then
            return wowmock.inCombat or false
        end
        return false
    end
    _G.UnitCanAttack = function(u1, u2)
        local target = (u1 == "player") and u2 or u1
        if wowmock.friendlyUnits and wowmock.friendlyUnits[target] then
            return false
        end
        if wowmock.cannotAttack and (wowmock.cannotAttack[u2] or wowmock.cannotAttack[u1]) then
            return false
        end
        return true
    end
    _G.UnitThreatSituation = function(unit, target)
        return (wowmock.threatSituation and wowmock.threatSituation[unit]) or nil
    end
    _G.UnitIsUnit = function(u1, u2)
        if u1 == u2 then return true end
        if (u1 == "target" and u2 == wowmock.targetUnit) or (u2 == "target" and u1 == wowmock.targetUnit) then
            return true
        end
        return false
    end
    _G.CheckInteractDistance = function(unit, distIndex)
        if wowmock.interactDistance then
            if type(wowmock.interactDistance) == "function" then
                return wowmock.interactDistance(unit, distIndex)
            elseif type(wowmock.interactDistance) == "table" then
                if wowmock.interactDistance[unit] ~= nil then
                    if type(wowmock.interactDistance[unit]) == "table" then
                        return wowmock.interactDistance[unit][distIndex]
                    end
                    local val = wowmock.interactDistance[unit]
                    if val == "nil" or val == false then return nil end
                    return val
                end
            end
        end
        return 1
    end

    -- Rebuffed Lua API Mocks
    _G.C_NamePlate = {
        GetNamePlates = function()
            return wowmock.nameplates
        end,
        GetNamePlateForUnit = function(unit)
            if wowmock.nameplates then
                for _, p in ipairs(wowmock.nameplates) do
                    local tok = (type(p) == "table" and (p.namePlateUnitToken or (p.unitFrame and p.unitFrame.unit))) or p
                    if tok == unit then return p end
                end
            end
            return nil
        end,
    }
    _G.UnitIsControlled = function(unit)
        return (wowmock.controlledUnits and wowmock.controlledUnits[unit]) or false
    end
    _G.UnitIsSilenced = function(unit)
        return (wowmock.silencedUnits and wowmock.silencedUnits[unit]) or false
    end
    _G.UnitIsDisarmed = function(unit)
        return (wowmock.disarmedUnits and wowmock.disarmedUnits[unit]) or false
    end
    _G.CopyToClipboard = function(text)
        wowmock.clipboard = text
        return true
    end
    _G.GetSpellBaseCooldown = function(spellId)
        return (wowmock.spellBaseCD and wowmock.spellBaseCD[spellId]) or 30000
    end
    _G.QueueInteract = function()
        return true
    end
    _G.UnitHealth = function(unit) return wowmock.health[unit] or 10000 end
    _G.UnitHealthMax = function(unit) return wowmock.maxHealth[unit] or 10000 end
    _G.IsCurrentSpell = function(nameOrId)
        return (wowmock.currentSpells[nameOrId] and 1) or nil
    end
    _G.GetShapeshiftForm = function() return wowmock.shapeshiftForm or 1 end
    _G.UnitCreatureType = function(unit) return wowmock.creatureTypes[unit] or "Humanoid" end

    -- Inventory / Items
    wowmock.inventoryItems = { [10] = 54758 }
    wowmock.inventoryCooldowns = { [10] = { start = 0, duration = 0, enable = 1 } }
    wowmock.cleuEntriesCleared = 0
    wowmock.inCombat = false
    wowmock.petDead = false
    wowmock.petExists = true

    _G.GetInventoryItemID = function(unit, slot)
        if unit == "player" and wowmock.inventoryItems then
            return wowmock.inventoryItems[slot]
        end
        return nil
    end

    _G.GetInventoryItemCooldown = function(unit, slot)
        if unit == "player" and wowmock.inventoryCooldowns and wowmock.inventoryCooldowns[slot] then
            local cd = wowmock.inventoryCooldowns[slot]
            return cd.start or 0, cd.duration or 0, cd.enable or 1
        end
        return 0, 0, 1
    end

    _G.CombatLogClearEntries = function()
        wowmock.cleuEntriesCleared = (wowmock.cleuEntriesCleared or 0) + 1
    end

    _G.wipe = function(t)
        for k in pairs(t) do
            t[k] = nil
        end
        return t
    end

    wowmock.interfaceCategories = {}
    wowmock.lastOpenedCategory = nil

    _G.Minimap = wowmock.createFrame("Frame", "Minimap")
    _G.GameTooltip = {
        SetOwner = function(...) end,
        AddLine = function(...) end,
        Show = function(...) end,
        Hide = function(...) end,
        ClearLines = function(...) end,
    }
    _G.InterfaceOptions_AddCategory = function(panel)
        table.insert(wowmock.interfaceCategories, panel)
    end
    _G.InterfaceOptionsFrame_OpenToCategory = function(panel)
        wowmock.lastOpenedCategory = panel
    end
    _G.GetCursorPosition = function() return 250, 250 end
    _G.IsShiftKeyDown = function() return false end

    _G.LoadAddOn = function(name)
        if name == "RotaEditor" then
            dofile("RotaEditor/FramePool.lua")
            dofile("RotaEditor/TabBlocks.lua")
            dofile("RotaEditor/TabCode.lua")
            dofile("RotaEditor/TabOverrides.lua")
            dofile("RotaEditor/TabTutorial.lua")
            dofile("RotaEditor/RotaEditor.lua")
            return true, "LOADED"
        elseif name == "RotaClass_DK" then
            dofile("RotaClass_DK/RotaClass_DK.lua")
            dofile("RotaClass_DK/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_PAL" then
            dofile("RotaClass_PAL/RotaClass_PAL.lua")
            dofile("RotaClass_PAL/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_WAR" then
            dofile("RotaClass_WAR/RotaClass_WAR.lua")
            dofile("RotaClass_WAR/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_ROG" then
            dofile("RotaClass_ROG/RotaClass_ROG.lua")
            dofile("RotaClass_ROG/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_SHA" then
            dofile("RotaClass_SHA/RotaClass_SHA.lua")
            dofile("RotaClass_SHA/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_WL" then
            dofile("RotaClass_WL/RotaClass_WL.lua")
            dofile("RotaClass_WL/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_MAG" then
            dofile("RotaClass_MAG/RotaClass_MAG.lua")
            dofile("RotaClass_MAG/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_PRI" then
            dofile("RotaClass_PRI/RotaClass_PRI.lua")
            dofile("RotaClass_PRI/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_HUN" then
            dofile("RotaClass_HUN/RotaClass_HUN.lua")
            dofile("RotaClass_HUN/Presets.lua")
            return true, "LOADED"
        elseif name == "RotaClass_DRU" then
            dofile("RotaClass_DRU/RotaClass_DRU.lua")
            dofile("RotaClass_DRU/Presets.lua")
            return true, "LOADED"
        end
        return false, "NOT_FOUND"
    end

    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(self, msg) end
    }
    _G.UIParent = {}
    _G.SlashCmdList = {}

    local defaultFontObject = {
        GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
    }
    _G.GameFontNormal = defaultFontObject
    _G.GameFontHighlight = defaultFontObject
    _G.GameFontHighlightSmall = {
        GetFont = function() return "Fonts\\FRIZQT__.TTF", 10, "" end,
    }
    _G.GameFontNormalSmall = {
        GetFont = function() return "Fonts\\FRIZQT__.TTF", 10, "" end,
    }
    _G.GameFontNormalLarge = {
        GetFont = function() return "Fonts\\FRIZQT__.TTF", 16, "" end,
    }

    if not _G.bit then
        local function band(a, b)
            local p, c = 1, 0
            while a > 0 and b > 0 do
                local ra, rb = a % 2, b % 2
                if ra == 1 and rb == 1 then c = c + p end
                a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
            end
            return c
        end
        _G.bit = { band = band }
    end
    _G.COMBATLOG_OBJECT_AFFILIATION_MINE = 0x00000001
    _G.COMBATLOG_OBJECT_REACTION_HOSTILE = 0x00000040
end

return wowmock
