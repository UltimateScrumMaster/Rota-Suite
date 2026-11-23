-- RotaCore/Snapshot.lua — Situaciones reales y comparador v1/nueva (plan v2, etapa 0)
-- Una "situación" es lo que el juego le muestra al addon en un momento (auras, CDs, recursos, runas, talentos...),
-- leído solo por API. tools/scenario.lua la reproduce en los mocks, así un caso del juego se vuelve un test offline.
-- Todo esto crea tablas: solo corre con la opción prendida y muestreado, nunca en cada frame.
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Snapshot = {
    CAPTURE_EVERY = 2.0, -- segundos entre situaciones grabadas en combate
    CAPTURE_MAX = 500,
    PARITY_MAX = 200,
    PARITY_REPEAT = 5.0, -- la misma diferencia seguida se vuelve a anotar recién pasado este tiempo
}
RotaCore.Snapshot = Snapshot

local POWER_TYPES = { 0, 1, 3, 6 } -- mana, ira, energia, poder runico
local AURA_UNITS = { "player", "target", "pet" }

local function Settings()
    return _G.RotaCoreDB and _G.RotaCoreDB.settings
end

local function ReadAuras(unit, filter, now, out)
    if not _G.UnitAura then return end
    for i = 1, 40 do
        local name, _, _, count, dtype, dur, exp, caster = _G.UnitAura(unit, i, filter)
        if not name then break end
        local rem = (exp and exp > 0) and (exp - now) or 0
        out[#out + 1] = {
            name = name, count = count or 0, dur = dur or 0, rem = rem > 0 and rem or 0,
            mine = caster == "player" or nil, dtype = (dtype ~= "" and dtype) or nil,
            harmful = filter == "HARMFUL" or nil,
        }
    end
end

local function ReadTalents()
    if not (_G.GetNumTalents and _G.GetTalentInfo) then return nil end
    local tal = {}
    local tabs = (_G.GetNumTalentTabs and _G.GetNumTalentTabs()) or 3
    for tab = 1, tabs do
        local pts = _G.GetTalentTabInfo and select(3, _G.GetTalentTabInfo(tab)) or 0
        local n = _G.GetNumTalents(tab) or 0
        local t = { pts = pts or 0, n = n, ranks = {} }
        for idx = 1, n do
            local name, _, _, _, rank = _G.GetTalentInfo(tab, idx)
            if rank and rank > 0 then t.ranks[idx] = { name = name, rank = rank } end
        end
        tal[tab] = t
    end
    return tal
end

--- Arma la situación actual leyendo las APIs. `ir` = rotación activa (sus hechizos dicen qué CDs mirar).
function Snapshot:Capture(ir, state)
    local now = (_G.GetTime and _G.GetTime()) or 0
    local class = _G.UnitClass and select(2, _G.UnitClass("player")) or nil
    local sc = {
        v = 1,
        class = class,
        preset = ir and ir.meta and ir.meta.id,
        build = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or nil,
        combat = (state and state.inCombat) and true or false,
        aoe = (state and state.aoeMode) and true or false,
        aoeCount = state and state.aoeCount or 0,
        plates = state and state.aoePlateCount or 0,
        power = {},
        cp = _G.GetComboPoints and _G.GetComboPoints("player", "target") or 0,
        hp = { _G.UnitHealth("player"), _G.UnitHealthMax("player") },
        auras = {},
        spells = {},
        form = _G.GetShapeshiftForm and _G.GetShapeshiftForm() or 0,
        moving = (_G.GetUnitSpeed and (_G.GetUnitSpeed("player") or 0) > 0) or nil,
        talents = ReadTalents(),
    }
    for _, p in ipairs(POWER_TYPES) do
        sc.power[p] = { _G.UnitPower("player", p), _G.UnitPowerMax("player", p) }
    end
    if _G.UnitExists and _G.UnitExists("target") then
        sc.target = {
            hp = _G.UnitHealth("target"), maxHp = _G.UnitHealthMax("target"),
            class = _G.UnitClassification and _G.UnitClassification("target") or "normal",
            ctype = _G.UnitCreatureType and _G.UnitCreatureType("target") or nil,
        }
    end
    for _, unit in ipairs(AURA_UNITS) do
        local list = {}
        ReadAuras(unit, "HELPFUL", now, list)
        ReadAuras(unit, "HARMFUL", now, list)
        sc.auras[unit] = list
    end
    if ir and ir.spells then
        for _, s in pairs(ir.spells) do
            local name = s.name
            if name and not sc.spells[name] then
                local entry = { id = s.defaultId }
                local start, dur = 0, 0
                if _G.GetSpellCooldown then start, dur = _G.GetSpellCooldown(name) end
                if start == nil then
                    entry.unknown = true
                elseif dur and dur > 1.5 then
                    local rem = start + dur - now
                    if rem > 0 then entry.rem, entry.dur = rem, dur end
                end
                if _G.IsCurrentSpell and _G.IsCurrentSpell(name) then entry.current = true end
                -- conocido y sin CD: solo el id
                sc.spells[name] = (entry.unknown or entry.rem or entry.current) and entry or entry.id
            end
        end
    end
    if _G.GetSpellCooldown then
        local gs, gd = _G.GetSpellCooldown(61304)
        if gd and gd > 0 and gd <= 1.5 then
            local rem = gs + gd - now
            if rem > 0 then sc.gcd = rem end
        end
    end
    if class == "DEATHKNIGHT" and _G.GetRuneCooldown then
        sc.runes = {}
        for slot = 1, 6 do
            local start, dur, ready = _G.GetRuneCooldown(slot)
            local rem = (not ready and start and dur) and (start + dur - now) or 0
            sc.runes[slot] = { type = _G.GetRuneType(slot), rem = rem > 0 and rem or 0 }
        end
    end
    if class == "SHAMAN" then
        if _G.GetTotemInfo then
            sc.totems = {}
            for slot = 1, 4 do
                local have, name, start, dur = _G.GetTotemInfo(slot)
                if have and name and name ~= "" then
                    local rem = (start or 0) + (dur or 0) - now
                    sc.totems[slot] = { name = name, rem = rem > 0 and rem or 0 }
                end
            end
        end
        if _G.GetWeaponEnchantInfo then
            local mh, _, _, oh = _G.GetWeaponEnchantInfo()
            sc.enchant = { main = mh and true or false, off = oh and true or false }
        end
        sc.offhand = (_G.OffhandHasWeapon and _G.OffhandHasWeapon()) and true or false
    end
    return sc
end

-- Ring buffer en SavedVariables: list = { ... }, la posición siguiente en list.next
local function Push(list, max, entry)
    local i = list.next or 1
    list[i] = entry
    list.next = (i % max) + 1
end

--- Llamado por UpdateAndEvaluate después de evaluar. Sin opciones prendidas no hace nada (ni crea tablas).
function Snapshot:AfterEvaluate(state, mainAction, offAction)
    local s = Settings()
    if not s or not (s.captureReal or s.compareV1) then return end
    local ir = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if not ir then return end
    local now = state.now or 0

    if s.captureReal and state.inCombat and now - (self.lastCapture or 0) >= self.CAPTURE_EVERY then
        self.lastCapture = now
        local sc = self:Capture(ir, state)
        sc.main, sc.off, sc.wait = mainAction, offAction, state.isWaiting or nil
        _G.RotaCoreDB.capture = _G.RotaCoreDB.capture or {}
        Push(_G.RotaCoreDB.capture, self.CAPTURE_MAX, sc)
    end

    if s.compareV1 then self:Compare(ir, state, mainAction, offAction) end
end

--- Evalúa la rotación vieja (meta.v1 del preset activo) sobre el mismo estado y anota si sugiere otra cosa.
function Snapshot:Compare(ir, state, mainAction, offAction)
    local v1Id = ir.meta and ir.meta.v1
    if not v1Id then return end
    if self.v1For ~= ir then
        self.v1For = ir
        local v1 = RotaCore.Profiles.presets[v1Id]
        self.v1Bundle = v1 and RotaCore.Compiler and RotaCore.Compiler:Compile(v1) or nil
    end
    local b = self.v1Bundle
    if not b then return end

    -- La v1 no debe pisar lo que ya muestra el HUD
    local w, r, wt = state.isWaiting, state.reason, state.waitTime
    state.isWaiting, state.reason, state.waitTime = false, nil, nil
    local m1 = b.evaluatorMain and b.evaluatorMain(state) or nil
    local o1 = b.evaluatorOff and b.evaluatorOff(state) or nil
    state.isWaiting, state.reason, state.waitTime = w, r, wt

    if m1 == mainAction and o1 == offAction then return end
    self.mismatches = (self.mismatches or 0) + 1
    local now = state.now or 0
    local same = self.lastM == mainAction and self.lastO == offAction and self.lastM1 == m1 and self.lastO1 == o1
    if same and now - (self.lastParity or 0) < self.PARITY_REPEAT then return end
    self.lastM, self.lastO, self.lastM1, self.lastO1, self.lastParity = mainAction, offAction, m1, o1, now

    local sc = self:Capture(ir, state)
    sc.main, sc.off = m1, o1            -- lo que esperamos: la v1
    sc.newMain, sc.newOff = mainAction, offAction
    _G.RotaCoreDB.parityLog = _G.RotaCoreDB.parityLog or {}
    Push(_G.RotaCoreDB.parityLog, self.PARITY_MAX, sc)
end

--- Borra lo grabado (situaciones y diferencias).
function Snapshot:Clear()
    if not _G.RotaCoreDB then return end
    _G.RotaCoreDB.capture = nil
    _G.RotaCoreDB.parityLog = nil
    self.mismatches = 0
end

--- Cuántas situaciones y diferencias hay guardadas.
function Snapshot:Counts()
    local db = _G.RotaCoreDB or {}
    local c, p = 0, 0
    for k in pairs(db.capture or {}) do if type(k) == "number" then c = c + 1 end end
    for k in pairs(db.parityLog or {}) do if type(k) == "number" then p = p + 1 end end
    return c, p
end

return Snapshot
