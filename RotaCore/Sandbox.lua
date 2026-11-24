-- RotaCore/Sandbox.lua — Secure Sandbox for User Custom Lua Rules (Lua 5.1 / 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Sandbox = {}
RotaCore.Sandbox = Sandbox

-- Whitelist of safe functions and tables for user code
local SafeEnv = {
    math = {
        abs = math.abs,
        floor = math.floor,
        ceil = math.ceil,
        min = math.min,
        max = math.max,
        sqrt = math.sqrt,
        huge = math.huge,
        sin = math.sin,
        cos = math.cos,
        pi = math.pi,
    },
    string = {
        find = string.find,
        format = string.format,
        sub = string.sub,
        len = string.len,
        lower = string.lower,
        upper = string.upper,
    },
    pairs = pairs,
    ipairs = ipairs,
    next = next,
    type = type,
    tostring = tostring,
    tonumber = tonumber,
    select = select,
    min = math.min,
    max = math.max,
    abs = math.abs,
    floor = math.floor,
}

-- Inject GetTime dynamically if available
if _G.GetTime then
    SafeEnv.GetTime = _G.GetTime
end

-- Allow safe global reference to addon namespaces so rules accessing _G.RotaClass_* don't crash
local safeG = {
    RotaCore = _G.RotaCore,
    RotaClass_PAL = _G.RotaClass_PAL,
    RotaClass_DK = _G.RotaClass_DK,
    RotaClass_WAR = _G.RotaClass_WAR,
    RotaClass_ROG = _G.RotaClass_ROG,
    RotaClass_SHA = _G.RotaClass_SHA,
    RotaClass_WL = _G.RotaClass_WL,
    RotaClass_MAG = _G.RotaClass_MAG,
    RotaClass_PRI = _G.RotaClass_PRI,
    RotaClass_HUN = _G.RotaClass_HUN,
    RotaClass_DRU = _G.RotaClass_DRU,
    GetTime = _G.GetTime,
}
setmetatable(safeG, {
    __index = function(_, k)
        if _G then return _G[k] end
        return nil
    end
})
SafeEnv._G = safeG
SafeEnv.RotaCore = _G.RotaCore

Sandbox.SafeEnv = SafeEnv

-- ----------------------------------------------------------------------------
-- Funciones para escribir rotaciones legibles (todas las clases). Leen el estado de la evaluacion en curso.
-- Ejemplo de regla:  if ready("CS") then return "CS" end
-- ----------------------------------------------------------------------------
Sandbox.current = nil
local function S() return Sandbox.current end

--- true si conoces el hechizo (alias del preset, nombre o ID)
function SafeEnv.known(a)
    local s = S()
    return (s and s.hasSpell and s.hasSpell(a)) and true or false
end
--- segundos de cooldown restantes (0 = listo)
function SafeEnv.cd(a)
    local s = S()
    return (s and s.spellCooldown and s.spellCooldown(a)) or 0
end
--- conocido y fuera de cooldown cuando termina el GCD actual
function SafeEnv.ready(a)
    local s = S()
    if not s or not SafeEnv.known(a) then return false end
    return SafeEnv.cd(a) <= (s.gcdRemains or 0) + 0.1
end
-- Un aura se puede pedir por nombre o por ID de hechizo (el ID funciona con el cliente en cualquier idioma)
local function AuraName(nameOrId)
    if type(nameOrId) == "number" then return _G.GetSpellInfo and _G.GetSpellInfo(nameOrId) or nil end
    return nameOrId
end
--- segundos restantes de un buff (jugador por defecto). Nombre o ID: buff("Shadow Trance") o buff(17941)
function SafeEnv.buff(name, unit)
    local s = S()
    name = AuraName(name)
    return (name and s and s.buffRemaining and s.buffRemaining(name, unit or "player")) or 0
end
--- segundos restantes de un debuff tuyo (objetivo por defecto). Nombre o ID
function SafeEnv.debuff(name, unit)
    local s = S()
    name = AuraName(name)
    return (name and s and s.debuffRemaining and s.debuffRemaining(name, unit or "target", true)) or 0
end
--- tiempo de casteo real en segundos (con haste); 0 si es instantaneo. Alias del catalogo, nombre o ID
function SafeEnv.castTime(a)
    local id = a
    if type(a) == "string" and RotaCore.Spells and RotaCore.Spells.ResolveID then id = RotaCore.Spells:ResolveID(a) or a end
    if not _G.GetSpellInfo then return 0 end
    local _, _, _, _, _, _, ms = _G.GetSpellInfo(id)
    return (ms and ms > 0) and ms / 1000 or 0
end
--- % de mana (0-100). En clases sin mana devuelve 0.
function SafeEnv.mana()
    local max = _G.UnitPowerMax and _G.UnitPowerMax("player", 0) or 0
    if max <= 0 then return 0 end
    return (_G.UnitPower("player", 0) or 0) / max * 100
end
--- valor del recurso principal (rage, energia, runic power, mana)
function SafeEnv.power()
    local s = S()
    return (s and s.power) or 0
end
--- % del recurso principal
function SafeEnv.powerPct()
    local s = S()
    return (s and s.powerPct) or 0
end
function SafeEnv.rage() return _G.UnitPower and _G.UnitPower("player", 1) or 0 end
function SafeEnv.energy() return _G.UnitPower and _G.UnitPower("player", 3) or 0 end
function SafeEnv.runic() return _G.UnitPower and _G.UnitPower("player", 6) or 0 end
--- combo points en el objetivo
function SafeEnv.combo() return _G.GetComboPoints and _G.GetComboPoints("player", "target") or 0 end
--- % de vida propia
function SafeEnv.hp()
    local max = _G.UnitHealthMax and _G.UnitHealthMax("player") or 0
    if max <= 0 then return 100 end
    return (_G.UnitHealth("player") or 0) / max * 100
end
-- Tipos de criatura del cliente en espanol -> nombre en ingles (las reglas comparan siempre en ingles)
local CREATURE_TYPE = {
    ["No-muerto"] = "Undead", ["Demonio"] = "Demon", ["Bestia"] = "Beast", ["Humanoide"] = "Humanoid",
    ["Elemental"] = "Elemental", ["Dragon"] = "Dragonkin", ["Dragón"] = "Dragonkin", ["Gigante"] = "Giant",
    ["Mecánico"] = "Mechanical", ["Mecanico"] = "Mechanical", ["Alimaña"] = "Critter", ["Alimana"] = "Critter",
}
--- tipo de criatura del objetivo en ingles: "Undead", "Demon", "Beast", "Humanoid", "Elemental", "Dragonkin",
--- "Giant", "Mechanical", "Critter" (nil sin objetivo). Ej.: if targetType() == "Undead" then ... end
function SafeEnv.targetType()
    local t = _G.UnitCreatureType and _G.UnitCreatureType("target") or nil
    return t and (CREATURE_TYPE[t] or t)
end
--- el objetivo es un jefe (worldboss)
function SafeEnv.targetBoss()
    return (_G.UnitClassification and _G.UnitClassification("target") == "worldboss") and true or false
end
--- enemigos contados para el AoE
function SafeEnv.enemies()
    local s = S()
    return (s and s.aoeCount) or 0
end
--- cuantos tenes de un objeto en las bolsas (ID de objeto), ej. itemCount(40211) para Potion of Speed
function SafeEnv.itemCount(id)
    return (_G.GetItemCount and _G.GetItemCount(id)) or 0
end
--- poción lista para tomar: la tenés en las bolsas, no está en cooldown y no tenés su buff. Devuelve el alias o nil.
--- potion("SPEED_POT") (Potion of Speed) o potion("WILD_POT") (Potion of Wild Magic)
function SafeEnv.potion(alias)
    local pot = RotaCore.Spells and RotaCore.Spells.POTIONS and RotaCore.Spells.POTIONS[alias]
    if not pot then return nil end
    if not _G.GetItemCount or _G.GetItemCount(pot.item) <= 0 then return nil end
    if _G.GetItemCooldown then
        local start, dur = _G.GetItemCooldown(pot.item)
        local s = S()
        if start and dur and dur > 1.5 and start + dur > ((s and s.now) or 0) then return nil end
    end
    if SafeEnv.buff(pot.buff) > 0 then return nil end
    return alias
end
--- estas canalizando un hechizo (ej. Army of the Dead, Mind Flay)
function SafeEnv.channeling()
    return (_G.UnitChannelInfo and _G.UnitChannelInfo("player")) and true or false
end
--- te estas moviendo
function SafeEnv.moving()
    return (_G.GetUnitSpeed and (_G.GetUnitSpeed("player") or 0) > 0) and true or false
end
--- segundos que faltan del GCD
function SafeEnv.gcd()
    local s = S()
    return (s and s.gcdRemains) or 0
end
--- stacks de un buff (jugador por defecto). Nombre o ID
function SafeEnv.buffStacks(name, unit)
    local s = S()
    name = AuraName(name)
    return (name and s and s.buffCount and s.buffCount(name, unit or "player")) or 0
end
--- stacks de un debuff tuyo (objetivo por defecto). Nombre o ID
function SafeEnv.debuffStacks(name, unit)
    local s = S()
    name = AuraName(name)
    return (name and s and s.debuffCount and s.debuffCount(name, unit or "target", true)) or 0
end
--- segundos restantes de un debuff de cualquiera (objetivo por defecto), ej. Faerie Fire de otro druida. Nombre o ID
function SafeEnv.debuffAny(name, unit)
    local s = S()
    name = AuraName(name)
    return (name and s and s.debuffRemaining and s.debuffRemaining(name, unit or "target", false)) or 0
end
--- variable del preset (las que se ajustan en el editor), con valor por defecto
function SafeEnv.var(name, default)
    local s = S()
    local v = s and s.vars and s.vars[name]
    if v == nil then return default end
    return v
end
--- tenes el glifo puesto (nombre o ID)
function SafeEnv.glyph(nameOrId)
    local s = S()
    return (s and s.glyphs and s.glyphs[nameOrId]) and true or false
end
--- talento con al menos 1 punto (por nombre)
function SafeEnv.talent(name)
    if not (_G.GetNumTalentTabs and _G.GetTalentInfo) then return false end
    for tab = 1, _G.GetNumTalentTabs() do
        for idx = 1, (_G.GetNumTalents(tab) or 0) do
            local n, _, _, _, rank = _G.GetTalentInfo(tab, idx)
            if n == name then return (rank or 0) > 0 end
        end
    end
    return false
end
function SafeEnv.aoe()
    local s = S()
    return (s and (s.aoeMode == true or s.isAoE == true)) and true or false
end
function SafeEnv.burst()
    local s = S()
    return (s and s.burstMode ~= false) and true or false
end
function SafeEnv.combat()
    local s = S()
    return (s and s.inCombat == true) and true or false
end
--- % de vida del objetivo
function SafeEnv.targetHP()
    local s = S()
    return (s and s.targetHealthPct) or 100
end
--- guantes de ingeniero (Hyperspeed Accelerators) listos
function SafeEnv.gloves()
    local s = S()
    return (s and s.areGlovesReady and s.areGlovesReady(s.now)) and true or false
end
--- sugerir "esperar" esta habilidad (el HUD muestra espiral + segundos)
function SafeEnv.wait(a, secs)
    local s = S()
    if s then s.isWaiting = true; s.waitTime = secs end
    return a
end
--- motivo que se ve en modo aprendizaje
function SafeEnv.say(text)
    local s = S()
    if s then s.reason = text end
end
--- de 2 o 3 habilidades conocidas, la que sale de cooldown antes
function SafeEnv.soonest(a, b, c)
    local best, bestCd = nil, nil
    if a and SafeEnv.known(a) then best, bestCd = a, SafeEnv.cd(a) end
    if b and SafeEnv.known(b) and (not bestCd or SafeEnv.cd(b) < bestCd) then best, bestCd = b, SafeEnv.cd(b) end
    if c and SafeEnv.known(c) and (not bestCd or SafeEnv.cd(c) < bestCd) then best = c end
    return best
end

--- Los modulos de clase agregan sus propias funciones (ej. judgement() del Paladin)
function Sandbox:AddHelper(name, fn)
    SafeEnv[name] = fn
end

-- Nombres sin definir caen al estado actual: "pal", "dk", "runes", "power"... se usan sin "state."
setmetatable(SafeEnv, {
    __index = function(_, k)
        local s = Sandbox.current
        return s and s[k]
    end,
})

--- Compiles user Lua code into a sandboxed execution closure with error tracking.
-- If the rule throws an error 3 times, it is disabled and an alert is posted.
-- @param codeString string Lua code string (expression or statements returning action string)
-- @param ruleId string Unique rule identifier
-- @return function Runner function(state) returning action or nil, or (nil, errorMsg) on compilation failure
function Sandbox:Compile(codeString, ruleId)
    if not codeString or codeString == "" then
        return nil, "empty_code"
    end

    -- Clean common repeated boolean operators (e.g. "and and") before execution
    local cleanCode = codeString:gsub("%f[%a]and%s+and%f[%A]", "and"):gsub("%f[%a]or%s+or%f[%A]", "or")

    -- If code doesn't explicitly return a function, wrap it
    local wrappedCode
    if cleanCode:find("^%s*function%s*%(") or cleanCode:find("^%s*return%s+function") then
        wrappedCode = cleanCode
    else
        wrappedCode = "return function(state)\n" .. cleanCode .. "\nend"
    end

    local chunk, err = loadstring(wrappedCode, "RotaSandbox_" .. tostring(ruleId or "anon"))
    if not chunk then
        return nil, err
    end

    if _G.GetTime and not SafeEnv.GetTime then
        SafeEnv.GetTime = _G.GetTime
    end

    -- Create isolated environment with SafeEnv fallback
    local env = {}
    local mt = {
        __index = SafeEnv,
        __newindex = function()
            -- Block writes to sandbox globals
        end,
    }
    setmetatable(env, mt)
    setfenv(chunk, env)

    local ok, compiledFn = pcall(chunk)
    if not ok or type(compiledFn) ~= "function" then
        return nil, "Chunk execution did not yield a valid function: " .. tostring(compiledFn)
    end

    local ruleState = {
        ruleId = ruleId or "anon",
        errorCount = 0,
        disabled_by_error = false,
        lastError = nil,
    }

    local maxErrors = 3

    -- Runner function: Zero allocations in hot path
    local function runner(state)
        if ruleState.disabled_by_error then
            return nil
        end

        Sandbox.current = state
        local success, action = pcall(compiledFn, state)
        if not success then
            ruleState.errorCount = ruleState.errorCount + 1
            ruleState.lastError = action
            if ruleState.errorCount >= maxErrors then
                ruleState.disabled_by_error = true
                if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                    _G.DEFAULT_CHAT_FRAME:AddMessage(
                        string.format("|cFFFF0000[RotaCore]|r Rule '%s' disabled after %d errors: %s",
                            tostring(ruleState.ruleId), maxErrors, tostring(action))
                    )
                end
            end
            return nil
        end

        if type(action) == "string" or action == false then
            return action -- false: la regla corta la lista (no se mira ninguna regla mas)
        end
        return nil
    end

    return runner, ruleState
end

return Sandbox
