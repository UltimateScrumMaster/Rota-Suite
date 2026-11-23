-- tools/golden.lua — Referencias de la v1 para la migración a reglas legibles (docs/PLAN_V2.md, etapa 0)
--
--   lua5.1 tools/golden.lua record [presetId...] [--force]   graba tools/golden/<preset>.lua (no pisa sin --force)
--   lua5.1 tools/golden.lua check                            reproduce todas las referencias y las compara
--   lua5.1 tools/golden.lua import <WTF/.../RotaCore.lua>    suma lo grabado en el juego a tools/golden/real/
--
-- Una referencia = situaciones (formato de RotaCore/Snapshot.lua) + lo que sugirió la rotación en cada una.
-- Diferencias aceptadas a propósito: tools/golden/allowed.lua { [presetId] = { [nroCaso] = "motivo" } }.
package.path = "./?.lua;" .. package.path
local wowmock = require("tools.wowmock")
wowmock.init()
local Scenario = dofile("tools/scenario.lua")

local CASES = 200
local DIR = "tools/golden/"
local REAL_DIR = DIR .. "real/"

-- Arranque como el juego: núcleo, después cada módulo de clase con su clase puesta
_G.RotaCoreDB = { settings = { aoeMode = "OFF" }, charBuilds = {}, classBuilds = {}, charProfiles = {},
    classProfiles = {}, charCustomProfiles = {} }
wowmock.setCharacter("Golden", "Frostmourne")
for _, f in ipairs({ "Sandbox", "Spells", "Compat", "State", "Compiler", "CodeGen", "ParserLua",
    "Profiles", "Snapshot", "UI", "RotaCore" }) do
    dofile("RotaCore/" .. f .. ".lua")
end
local RotaCore = _G.RotaCore

local CLASSES = {
    { "DEATHKNIGHT", "Death Knight", "RotaClass_DK" }, { "PALADIN", "Paladin", "RotaClass_PAL" },
    { "WARRIOR", "Warrior", "RotaClass_WAR" }, { "ROGUE", "Rogue", "RotaClass_ROG" },
    { "SHAMAN", "Shaman", "RotaClass_SHA" }, { "WARLOCK", "Warlock", "RotaClass_WL" },
    { "MAGE", "Mage", "RotaClass_MAG" }, { "PRIEST", "Priest", "RotaClass_PRI" },
    { "HUNTER", "Hunter", "RotaClass_HUN" }, { "DRUID", "Druid", "RotaClass_DRU" },
}
-- Los módulos resuelven nombres con GetSpellInfo(id) al cargar: registrar antes cada par id/nombre de su código
local function RegisterSpellsOf(addon)
    for _, f in ipairs({ addon .. "/" .. addon .. ".lua", addon .. "/Presets.lua" }) do
        local fh = io.open(f)
        if fh then
            local src = fh:read("*a")
            fh:close()
            for id, name in src:gmatch('(%d%d%d+)%s*,%s*"([^"]+)"') do wowmock.registerSpell(tonumber(id), name) end
            for name, id in src:gmatch('"([^"]+)"%s*,%s*(%d%d%d+)') do wowmock.registerSpell(tonumber(id), name) end
            for name, id in src:gmatch('name%s*=%s*"([^"]+)"%s*,%s*defaultId%s*=%s*(%d+)') do
                wowmock.registerSpell(tonumber(id), name)
            end
        end
    end
end
for _, c in ipairs(CLASSES) do
    wowmock.setClass(c[2], c[1])
    RegisterSpellsOf(c[3])
    _G.LoadAddOn(c[3])
end

local function SetBuild(key)
    local charKey = _G.UnitName("player") .. " - " .. _G.GetRealmName()
    _G.RotaCoreDB.charBuilds[charKey] = key
    _G.RotaCoreDB.settings.selectedBuild = key
end

local function BuildFor(class, presetId)
    local mod = RotaCore:GetClassModule(class)
    for _, b in ipairs(mod and mod.builds or {}) do
        if b.preset == presetId then return b.key end
    end
    return "auto"
end

-- Presets en orden fijo (el estado interno de los módulos pasa de un caso al siguiente: el orden importa)
local function PresetIds()
    local ids = {}
    for id, p in pairs(RotaCore.Profiles.presets) do
        if p.meta and not p.meta.v1Of then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

-- ---------------------------------------------------------------------------
-- Generador de situaciones (azar con semilla propia: mismo resultado en cualquier máquina)
-- ---------------------------------------------------------------------------
local seed = 1
local function Rand()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
end
local function Chance(p) return Rand() < p end
local function Int(a, b) return a + math.floor(Rand() * (b - a + 1)) end
local function Dec(a, b) return math.floor((a + Rand() * (b - a)) * 10 + 0.5) / 10 end
local function Pick(list) return list[Int(1, #list)] end
local function SeedFrom(text)
    local h = 7
    for i = 1, #text do h = (h * 31 + text:byte(i)) % 2147483647 end
    seed = h
end

-- Nombres de auras posibles: todos los textos "Con Mayúscula" del módulo y sus presets
local function Vocabulary(addon)
    local seen, list = {}, {}
    for _, f in ipairs({ addon .. "/" .. addon .. ".lua", addon .. "/Presets.lua" }) do
        local fh = io.open(f)
        if fh then
            local src = fh:read("*a")
            fh:close()
            for name in src:gmatch('"([A-Z][%a\' %-:]+)"') do
                if #name >= 4 and name:find("%l") and not seen[name] then
                    seen[name] = true
                    list[#list + 1] = name
                end
            end
        end
    end
    table.sort(list)
    return list
end

local function AddonFor(class)
    for _, c in ipairs(CLASSES) do if c[1] == class then return c[3] end end
end

local VOCAB = {}
local function Generate(preset, index)
    local meta = preset.meta
    local vocab = Vocabulary(AddonFor(meta.class))
    VOCAB = vocab
    local totems = {}
    for _, n in ipairs(vocab) do if n:find("Totem") then totems[#totems + 1] = n end end

    local sc = {
        v = 1, class = meta.class, preset = meta.id, build = BuildFor(meta.class, meta.id),
        combat = Chance(0.9),
        power = {
            [0] = { 0, 20000 }, [1] = { Int(0, 100), 100 }, [3] = { Int(0, 100), 100 }, [6] = { Int(0, 130), 130 },
        },
        cp = Int(0, 5),
        hp = { Int(3000, 30000), 30000 },
        target = {
            maxHp = 1000000,
            class = Pick({ "normal", "normal", "elite", "worldboss" }),
            ctype = Pick({ "Humanoid", "Undead", "Demon", "Beast" }),
        },
        auras = { player = {}, target = {}, pet = {} },
        spells = {},
        form = Int(0, 4),
        moving = Chance(0.1) or nil,
    }
    sc.power[0][1] = Int(0, 20000)
    local pct = Chance(0.25) and Int(1, 20) or Int(21, 100)
    sc.target.hp = pct * 10000

    for _ = 1, Int(0, 4) do
        local dur = Int(10, 60)
        sc.auras.player[#sc.auras.player + 1] = { name = Pick(vocab), count = Int(1, 5), dur = dur, rem = Dec(0.2, dur), mine = true }
    end
    for _ = 1, Int(0, 4) do
        local dur = Int(10, 30)
        sc.auras.target[#sc.auras.target + 1] = { name = Pick(vocab), count = Int(1, 5), dur = dur, rem = Dec(0.2, dur),
            mine = Chance(0.85) or nil, harmful = true }
    end
    if Chance(0.1) then
        sc.auras.pet[1] = { name = Pick(vocab), count = 1, dur = 30, rem = Dec(0.2, 30), mine = true }
    end

    local names = {}
    for _, s in pairs(preset.spells or {}) do
        if s.name and not names[s.name] then names[s.name] = s.defaultId end
    end
    local sorted = {}
    for n in pairs(names) do sorted[#sorted + 1] = n end
    table.sort(sorted)
    for _, n in ipairs(sorted) do
        local e = { id = names[n] }
        if Chance(0.03) then
            e.unknown = true
        elseif Chance(0.35) then
            e.dur = Int(6, 60)
            e.rem = Dec(0.1, e.dur)
        end
        if Chance(0.05) then e.current = true end
        sc.spells[n] = (e.unknown or e.rem or e.current) and e or e.id -- conocido y sin CD: solo el id
    end
    if Chance(0.3) then sc.gcd = Dec(0.1, 1.4) end

    if meta.class == "DEATHKNIGHT" then
        sc.runes = {}
        local base = { 1, 1, 3, 3, 2, 2 }
        for slot = 1, 6 do
            sc.runes[slot] = { type = Chance(0.25) and 4 or base[slot], rem = Chance(0.5) and 0 or Dec(0.1, 9.9) }
        end
    end
    if meta.class == "SHAMAN" then
        sc.totems = {}
        for slot = 1, 4 do
            if #totems > 0 and Chance(0.6) then sc.totems[slot] = { name = Pick(totems), rem = Dec(1, 59) } end
        end
        sc.enchant = { main = Chance(0.8), off = Chance(0.8) }
        sc.offhand = Chance(0.5)
    end

    -- Reparto fijo: un tercio AoE (3-6 enemigos), un tercio cleave (2), un tercio un solo objetivo
    local kind = (index or 0) % 3
    if kind == 0 then
        sc.aoe, sc.aoeCount = true, Int(3, 6)
    elseif kind == 1 then
        sc.aoe, sc.aoeCount = false, 2
    else
        sc.aoe, sc.aoeCount = false, 1
    end
    sc.plates = sc.aoeCount
    return sc, vocab
end


-- ---------------------------------------------------------------------------
-- Situaciones "a mitad de pelea": se cumplen las primeras sugerencias (CD puesto, aura puesta) antes de grabar.
-- Sin esto casi todo caso cae en la primera regla (sin enfermedades, sin forma...).
-- ---------------------------------------------------------------------------
local learned = {} -- [preset:accion] = { name, unit }: el aura que apagó esa sugerencia la última vez

local function FindAura(list, name)
    for i, a in ipairs(list) do if a.name == name then return i end end
end

local function AddAura(sc, unit, name)
    local list = sc.auras[unit]
    if FindAura(list, name) then return nil end
    local dur = 30
    list[#list + 1] = { name = name, count = 1, dur = dur, rem = Dec(8, dur), mine = true, harmful = unit == "target" or nil }
    return #list
end

-- Hace como si se hubiera usado `action`. true si la sugerencia cambió.
local function Satisfy(preset, sc, action, now)
    local function Moved()
        return (Scenario.evaluate(wowmock, RotaCore, sc, now, SetBuild)) ~= action
    end
    local s = preset.spells and preset.spells[action]
    local name = s and s.name
    if name then
        local e = sc.spells[name]
        if type(e) == "number" then e = { id = e }; sc.spells[name] = e end
        if e and not e.unknown then e.dur = 30; e.rem = Dec(5, 30) end
        if Moved() then return true end
        -- Aura con el nombre del hechizo: solo donde sirve, para no llenar el archivo
        for _, unit in ipairs({ "target", "player" }) do
            local idx = AddAura(sc, unit, name)
            if idx then
                if Moved() then return true end
                table.remove(sc.auras[unit], idx)
            end
        end
    end
    local key = preset.meta.id .. ":" .. action
    local cands = {}
    if learned[key] then
        cands[1] = learned[key]
    elseif learned[key] == nil then
        for _, n in ipairs(VOCAB) do
            cands[#cands + 1] = { n, "target" }
            cands[#cands + 1] = { n, "player" }
        end
    end
    for _, c in ipairs(cands) do
        local idx = AddAura(sc, c[2], c[1])
        if idx then
            if Moved() then
                learned[key] = c
                return true
            end
            table.remove(sc.auras[c[2]], idx)
        end
    end
    if learned[key] == nil then learned[key] = false end -- ninguna aura la apaga: no volver a buscar
    local oldForm = sc.form
    for f = 0, 4 do
        if f ~= oldForm then
            sc.form = f
            if Moved() then return true end
        end
    end
    sc.form = oldForm
    return false
end

-- ---------------------------------------------------------------------------
-- Archivos
-- ---------------------------------------------------------------------------
local function Exists(path)
    local f = io.open(path)
    if f then f:close() return true end
    return false
end

local function WriteCases(path, presetId, cases)
    local f = assert(io.open(path, "w"))
    f:write("-- Referencia de ", presetId, ". Generado por tools/golden.lua: no editar a mano.\n")
    f:write("return {\n")
    for _, c in ipairs(cases) do f:write(Scenario.serialize(c), ",\n") end
    f:write("}\n")
    f:close()
end

local function ReadCases(path)
    local chunk = loadfile(path)
    if not chunk then return {} end
    return chunk() or {}
end

local function ListFiles(dir)
    local out = {}
    local p = io.popen('ls "' .. dir .. '" 2>/dev/null')
    if not p then return out end
    for line in p:lines() do
        if line:match("%.lua$") and line ~= "allowed.lua" then out[#out + 1] = dir .. line end
    end
    p:close()
    table.sort(out)
    return out
end

local function Run(sc, i)
    return Scenario.evaluate(wowmock, RotaCore, sc, 10000 + i * 100, SetBuild)
end

-- ---------------------------------------------------------------------------
-- Comandos
-- ---------------------------------------------------------------------------
local function Record(args)
    local force, wanted = false, {}
    for _, a in ipairs(args) do
        if a == "--force" then force = true else wanted[#wanted + 1] = a end
    end
    if #wanted == 0 then wanted = PresetIds() end
    local recorded = {}
    for _, id in ipairs(wanted) do
        local preset = RotaCore.Profiles.presets[id]
        local path = DIR .. id .. ".lua"
        if not preset then
            print("  no existe el preset " .. id)
        elseif Exists(path) and not force then
            print("  " .. id .. ": ya tiene referencia (usar --force para regrabar a propósito)")
        else
            SeedFrom(id)
            local cases = {}
            for i = 1, CASES do
                local sc = Generate(preset, i)
                local now = 10000 + i * 100
                for _ = 1, Int(0, 8) do
                    local m = Scenario.evaluate(wowmock, RotaCore, sc, now, SetBuild)
                    if not m or m == "WAIT" or not Satisfy(preset, sc, m, now) then break end
                end
                cases[i] = sc
            end
            recorded[#recorded + 1] = id
            WriteCases(path, id, cases)
            print(string.format("  %s: %d situaciones", id, #cases))
        end
    end
    -- Lo esperado se calcula en un proceso nuevo, en el mismo orden que `check`, para que el estado interno
    -- de los módulos sea idéntico al reproducir
    if #recorded > 0 then
        os.execute("lua5.1 tools/golden.lua fill " .. table.concat(recorded, " "))
    end
end

local function Fill(ids)
    local want = {}
    for _, id in ipairs(ids) do want[id] = true end
    for _, path in ipairs(ListFiles(DIR)) do
        local cases = ReadCases(path)
        local id = cases[1] and cases[1].preset
        for i, sc in ipairs(cases) do
            local main, off, wait = Run(sc, i)
            if want[id] then sc.main, sc.off, sc.wait = main, off, wait end
        end
        if want[id] then
            WriteCases(path, id, cases)
            print(string.format("  %s: %d casos grabados", id, #cases))
        end
    end
end

local function Check()
    local allowedChunk = loadfile(DIR .. "allowed.lua")
    local allowed = allowedChunk and allowedChunk() or {}
    local files = ListFiles(DIR)
    for _, f in ipairs(ListFiles(REAL_DIR)) do files[#files + 1] = f end
    local bad, total = 0, 0
    for _, path in ipairs(files) do
        local cases = ReadCases(path)
        local id = cases[1] and cases[1].preset or path
        local ok, shown = 0, 0
        local isReal = path:find(REAL_DIR, 1, true) ~= nil
        for i, sc in ipairs(cases) do
            local main, off, wait = Run(sc, i)
            local okv = main == sc.main and off == sc.off and (isReal or (wait or nil) == (sc.wait or nil))
            local why = allowed[id] and allowed[id][isReal and ("real" .. i) or i]
            if okv or why then
                ok = ok + 1
            else
                bad = bad + 1
                if shown < 5 then
                    shown = shown + 1
                    print(string.format("    caso %d: esperaba %s / %s%s, dio %s / %s%s", i,
                        tostring(sc.main), tostring(sc.off), sc.wait and " (espera)" or "",
                        tostring(main), tostring(off), wait and " (espera)" or ""))
                end
            end
        end
        total = total + #cases
        print(string.format("  %s%s: %d/%d", isReal and "[real] " or "", id, ok, #cases))
    end
    print(string.format("\n  %d casos, %d diferencias sin explicar", total, bad))

    -- Cero basura en el hot path: cada build evaluada 300 veces seguidas (un objetivo y AoE)
    local dirty = 0
    for _, id in ipairs(PresetIds()) do
        local cases = ReadCases(DIR .. id .. ".lua")
        for _, sc in ipairs({ cases[3], cases[1] }) do -- caso 3: un objetivo, caso 1: AoE
            if sc then
                Run(sc, 1)
                local b = RotaCore.Profiles:GetActiveEvaluator()
                local st = RotaCore.State.data
                for _ = 1, 30 do RotaCore.State:Update(GetTime()); b.evaluatorMain(st); b.evaluatorOff(st) end
                collectgarbage("collect"); collectgarbage("collect")
                local before = collectgarbage("count")
                for _ = 1, 300 do RotaCore.State:Update(GetTime()); b.evaluatorMain(st); b.evaluatorOff(st) end
                local garbage = collectgarbage("count") - before
                if garbage > 0.0001 then
                    dirty = dirty + 1
                    print(string.format("  BASURA %s (%s): %.4f KB en 300 evaluaciones", id, sc.aoe and "AoE" or "ST", garbage))
                end
            end
        end
    end
    print(dirty == 0 and "  Cero basura en todas las builds" or string.format("  %d builds crean basura", dirty))
    return bad == 0 and dirty == 0
end

-- Lee el SavedVariables del juego (RotaCoreDB) y suma situaciones grabadas y diferencias a tools/golden/real/
local function Import(path)
    local chunk = assert(loadfile(path), "no se pudo leer " .. tostring(path))
    local env = {}
    setfenv(chunk, env)
    chunk()
    local db = env.RotaCoreDB or {}
    local byPreset = {}
    local function Add(list, isParity)
        for k, sc in pairs(list or {}) do
            if type(k) == "number" and type(sc) == "table" and sc.preset then
                local id = sc.preset
                byPreset[id] = byPreset[id] or {}
                -- de la v1 al nuevo: se guarda lo que esperamos; lo que dio la regla nueva queda como dato
                if isParity then sc.parity = true end
                table.insert(byPreset[id], sc)
            end
        end
    end
    Add(db.capture, false)
    Add(db.parityLog, true)
    os.execute('mkdir -p "' .. REAL_DIR .. '"')
    for id, list in pairs(byPreset) do
        local file = REAL_DIR .. id .. ".lua"
        local cases = ReadCases(file)
        for _, sc in ipairs(list) do cases[#cases + 1] = sc end
        WriteCases(file, id, cases)
        print(string.format("  %s: +%d (total %d)", id, #list, #cases))
    end
end

local cmd = arg[1]
local rest = {}
for i = 2, #arg do rest[#rest + 1] = arg[i] end
if cmd == "record" then
    Record(rest)
elseif cmd == "fill" then
    Fill(rest)
elseif cmd == "check" then
    if not Check() then os.exit(1) end
elseif cmd == "import" then
    Import(rest[1])
else
    print("uso: lua5.1 tools/golden.lua record [presetId...] [--force] | check | import <RotaCore.lua>")
end
