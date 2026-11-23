-- tools/scenario.lua — Reproduce una "situación" (RotaCore/Snapshot.lua) en los mocks y evalúa la rotación.
-- Sirve igual para situaciones generadas (tools/golden.lua) y grabadas en el juego.
local Scenario = {}

local CLASS_NAMES = {
    DEATHKNIGHT = "Death Knight", PALADIN = "Paladin", WARRIOR = "Warrior", ROGUE = "Rogue", SHAMAN = "Shaman",
    WARLOCK = "Warlock", MAGE = "Mage", PRIEST = "Priest", HUNTER = "Hunter", DRUID = "Druid",
}

local function DefaultTalents()
    return {
        [1] = { name = "Tab1", pointsSpent = 0, talents = {} },
        [2] = { name = "Tab2", pointsSpent = 0, talents = {} },
        [3] = { name = "Tab3", pointsSpent = 0, talents = {} },
    }
end

--- Deja el mundo de los mocks igual a la situación `sc`, con el reloj en `now`.
function Scenario.apply(wowmock, sc, now)
    wowmock.setTime(now)
    if sc.class then wowmock.setClass(CLASS_NAMES[sc.class] or sc.class, sc.class) end
    wowmock.inCombat = sc.combat and true or false

    wowmock.auras = { player = {}, target = {}, pet = {} }
    for unit, list in pairs(sc.auras or {}) do
        for _, a in ipairs(list) do
            wowmock.setAura(unit, {
                name = a.name, count = a.count, duration = a.dur,
                expirationTime = (a.rem and a.rem > 0) and (now + a.rem) or 0,
                unitCaster = a.mine and "player" or "raid1",
                debuffType = a.dtype, filter = a.harmful and "HARMFUL" or "HELPFUL",
            })
        end
    end

    for p, v in pairs(sc.power or {}) do wowmock.setPower("player", p, v[1], v[2]) end
    wowmock.comboPoints = sc.cp or 0
    if sc.hp then wowmock.setHealth("player", sc.hp[1], sc.hp[2]) end
    local t = sc.target or {}
    wowmock.setHealth("target", t.hp or 50000, t.maxHp or 50000)
    wowmock.classification = { target = t.class or "normal" }
    wowmock.creatureTypes = { target = t.ctype or "Humanoid" }

    wowmock.clearSpellCDs()
    wowmock.unknownSpells = {}
    wowmock.currentSpells = {}
    wowmock.spellbook.knownSpells = {}
    for name, e in pairs(sc.spells or {}) do
        if type(e) == "number" then e = { id = e } end -- conocido y sin CD
        if e.id and not wowmock.spells[name] then wowmock.registerSpell(e.id, name) end
        local entry = wowmock.spells[name]
        if e.unknown then
            wowmock.setSpellUnknown(name)
        elseif e.id then
            wowmock.spellbook.knownSpells[e.id] = true
        end
        if entry and e.rem then
            entry.cdDuration = e.dur
            entry.cdStart = now - (e.dur - e.rem)
        end
        if e.current then wowmock.currentSpells[name] = true end
    end
    if sc.gcd then
        wowmock.gcdStart, wowmock.gcdDuration = now - (1.5 - sc.gcd), 1.5
    else
        wowmock.gcdStart, wowmock.gcdDuration = 0, 0
    end

    wowmock.initRunes()
    for slot, r in ipairs(sc.runes or {}) do
        local rune = wowmock.runes[slot]
        rune.currentType = r.type
        if r.rem and r.rem > 0 then
            rune.start, rune.duration, rune.readyAt, rune.ready = now - (10 - r.rem), 10, now + r.rem, false
        else
            -- Lista desde hace rato: gracia completa
            rune.start, rune.duration, rune.readyAt, rune.ready = now - 20, 10, now - 10, true
        end
    end

    wowmock.shapeshiftForm = sc.form or 0
    wowmock.playerSpeed = sc.moving and 7 or 0
    wowmock.totems = {}
    for slot, tt in pairs(sc.totems or {}) do
        wowmock.totems[slot] = { name = tt.name, start = now - (60 - tt.rem), duration = 60 }
    end
    wowmock.weaponEnchant = { main = sc.enchant and sc.enchant.main or false, off = sc.enchant and sc.enchant.off or false }
    wowmock.offhandWeapon = sc.offhand or false

    local tabs = DefaultTalents()
    for tab, tt in pairs(sc.talents or {}) do
        local list = {}
        for idx = 1, tt.n or 0 do
            local r = tt.ranks and tt.ranks[idx]
            list[idx] = r and { name = r.name, rank = r.rank } or { name = "Talent_" .. tab .. "_" .. idx, rank = 0 }
        end
        tabs[tab] = { name = "Tab" .. tab, pointsSpent = tt.pts or 0, talents = list }
    end
    wowmock.talents.tabs = tabs
end

--- Aplica la situación, activa su preset/build y devuelve main, off, esperando.
-- `setBuild(key)` guarda la build del PJ (igual que en test_runner).
function Scenario.evaluate(wowmock, RotaCore, sc, now, setBuild)
    Scenario.apply(wowmock, sc, now)
    local db = _G.RotaCoreDB
    db.settings.aoeMode = sc.aoe and "ON" or "OFF"
    if setBuild then setBuild(sc.build or "auto") end
    if RotaCore.State.ScanTalentsAndGlyphs then RotaCore.State:ScanTalentsAndGlyphs() end
    local active = RotaCore.Profiles:GetActiveProfile()
    if not active or not active.meta or (active.meta.v1Of or active.meta.id) ~= sc.preset then
        RotaCore.Profiles:SetActiveProfile(sc.preset)
    end

    local state = RotaCore.State:Update(now)
    state.inCombat = sc.combat and true or false
    state.aoeCount = sc.aoeCount or 0
    state.aoePlateCount = sc.plates or 0
    state.isWaiting, state.reason, state.waitTime = false, nil, nil

    local b = RotaCore.Profiles:GetActiveEvaluator()
    -- shortcut: el opener depende del tiempo en combate, no de la situación: se apaga. Un caso grabado en el
    -- juego durante el opener (primeros segundos de pelea) no se puede reproducir.
    if b and b.disableSequences then b.disableSequences() end
    local main = b and b.evaluatorMain and b.evaluatorMain(state) or nil
    local off = b and b.evaluatorOff and b.evaluatorOff(state) or nil
    return main, off, state.isWaiting or nil
end

-- Serializa una tabla como Lua (claves ordenadas, para que el archivo no cambie de una corrida a otra)
local function Ser(v, out)
    local tv = type(v)
    if tv == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta ~= tb then return ta < tb end
            return a < b
        end)
        out[#out + 1] = "{"
        local n = #v
        for i = 1, n do Ser(v[i], out); out[#out + 1] = "," end
        for _, k in ipairs(keys) do
            if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    out[#out + 1] = k .. "="
                else
                    out[#out + 1] = "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]="
                end
                Ser(v[k], out); out[#out + 1] = ","
            end
        end
        out[#out + 1] = "}"
    elseif tv == "number" then
        out[#out + 1] = tostring(math.floor(v * 100 + 0.5) / 100)
    elseif tv == "string" then
        out[#out + 1] = string.format("%q", v)
    else
        out[#out + 1] = tostring(v)
    end
end

function Scenario.serialize(v)
    local out = {}
    Ser(v, out)
    return table.concat(out)
end

return Scenario
