-- RotaCore/Profiles.lua — Profile Management & Dual Spec Support (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Profiles = {
    presets = {},
    activeProfile = nil,
    activeEvaluator = nil,
}
RotaCore.Profiles = Profiles

local defaultDB = {
    version = 1,
    settings = {
        iconSize = 48,
        offIconSize = 32,
        locked = true,
        showKeybinds = false,
        showMinimap = true,
        minimapPos = 45,
        alpha = 1.0,
        x = 0,
        y = -120,
        aoeMode = "AUTO",
        autoAoE = true,
    },
    aoeFusion = "union",
    aoeSwingSignal = true,
    useCCExclusion = false,
    aoeLogWindow = 4.0,
    activeSpecProfiles = {}, -- [talentGroup] = profileId
    classProfiles = {},      -- [classToken] = profileId
    charProfiles = {},       -- [charKey] = profileId
    classBuilds = {},        -- [classToken] = buildKey
    charBuilds = {},         -- [charKey] = buildKey
    charCustomProfiles = {}, -- [charKey] = { [profileId] = IR table con meta.custom = true }
    spellOverrides = {},     -- [aliasOrName] = overrideSpellId
}

--- Initializes SavedVariables and loads active profile.
function Profiles:InitDB()
    if not _G.RotaCoreDB then
        _G.RotaCoreDB = {}
    end

    local db = _G.RotaCoreDB
    for k, v in pairs(defaultDB) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
                for subK, subV in pairs(v) do
                    db[k][subK] = subV
                end
            else
                db[k] = v
            end
        end
    end

    -- Limpieza: versiones viejas guardaban copias de los presets (sin meta.custom) que tapaban los presets nuevos,
    -- y una copia de cuenta (customProfiles) que se filtraba a los otros PJ. Solo quedan las rotaciones custom por PJ.
    db.customProfiles = nil
    for _, perChar in pairs(db.charCustomProfiles or {}) do
        if type(perChar) == "table" then
            for id, p in pairs(perChar) do
                if type(p) ~= "table" or not (p.meta and p.meta.custom) then perChar[id] = nil end
            end
        end
    end

    -- Restore spell overrides if present
    if db.spellOverrides and RotaCore.Spells then
        for aliasOrName, overrideId in pairs(db.spellOverrides) do
            RotaCore.Spells:SetOverride(aliasOrName, overrideId)
        end
    end
end

--- Registers an official class/spec preset RotationIR.
-- @param presetIR table RotationIR table
function Profiles:RegisterPreset(presetIR)
    if not presetIR or not presetIR.meta or not presetIR.meta.id then
        return
    end
    Profiles.presets[presetIR.meta.id] = presetIR
end

--- Retrieves a preset by ID.
function Profiles:GetPreset(profileId)
    return Profiles.presets[profileId]
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

--- true si la tabla es el preset registrado (no una copia)
local function IsPreset(ir)
    return type(ir) == "table" and ir.meta ~= nil and Profiles.presets[ir.meta.id] == ir
end

--- Copia de trabajo de un preset: el editor modifica la copia, nunca el preset
local function WorkingCopy(preset)
    local c = DeepCopy(preset)
    c.meta.isPresetCopy = true
    return c
end

--- Retrieves current character key ("Name - Realm")
function Profiles:GetCharKey()
    if _G.UnitName then
        local realm = (_G.GetRealmName and _G.GetRealmName()) or "Unknown"
        local charName = _G.UnitName("player") or "Unknown"
        return charName .. " - " .. realm
    end
    return nil
end

--- Guarda una rotacion custom solo para el PJ actual (tapa al preset con el mismo ID en este PJ).
-- Los presets registrados nunca se guardan: asi los cambios del addon siempre llegan.
function Profiles:SaveProfile(profileIR)
    if not profileIR or not profileIR.meta or not profileIR.meta.id then return end
    if IsPreset(profileIR) then return end
    local charKey = self:GetCharKey()
    if not charKey then return end
    if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
    local db = _G.RotaCoreDB
    db.charCustomProfiles = db.charCustomProfiles or {}

    profileIR.meta.custom = true
    profileIR.meta.isPresetCopy = nil
    local id = profileIR.meta.id
    db.charCustomProfiles[charKey] = db.charCustomProfiles[charKey] or {}
    db.charCustomProfiles[charKey][id] = profileIR
    db.charProfiles = db.charProfiles or {}
    db.charProfiles[charKey] = id
end

--- Rotacion custom de este PJ para un ID, o nil
-- Lista armada solo con ganchos a evaluadores de modulo (formato v1)
local function IsV1Hook(ir)
    local main = ir.lists and ir.lists.main
    if type(main) ~= "table" then return false end
    for _, r in ipairs(main) do
        local code = type(r) == "table" and r.code
        if type(code) == "string" and (code:find("state%.evaluate") or code:find("RotaClass_%u+%.Evaluate")) then
            return true
        end
    end
    return false
end

function Profiles:GetCustom(profileId)
    local charKey = self:GetCharKey()
    local db = _G.RotaCoreDB
    local perChar = charKey and db and db.charCustomProfiles and db.charCustomProfiles[charKey]
    local p = perChar and perChar[profileId]
    if type(p) == "table" and p.meta and p.meta.custom then
        -- Custom hecha sobre la v1 (solo el gancho al evaluador del modulo) de un preset que ya es reglas: tapaba
        -- la rotacion nueva. Se descarta una vez; la copia de la v1 sigue disponible con la casilla "usar la vieja".
        local preset = Profiles.presets[profileId]
        if preset and preset.meta and preset.meta.v1 and IsV1Hook(p) then
            perChar[profileId] = nil
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Tu rotacion custom de " .. tostring(preset.meta.name)
                    .. " era de la version vieja: se reemplazo por la nueva (reglas editables).")
            end
            return nil
        end
        return p
    end
    return nil
end

--- Rotacion custom de este PJ si existe; si no, el preset
function Profiles:GetProfile(profileId)
    return self:GetCustom(profileId) or Profiles.presets[profileId]
end

--- Borra la rotacion custom de este PJ y vuelve al preset (si estaba activa)
function Profiles:ResetProfile(profileId)
    local charKey = self:GetCharKey()
    local db = _G.RotaCoreDB
    local perChar = charKey and db and db.charCustomProfiles and db.charCustomProfiles[charKey]
    if perChar then perChar[profileId] = nil end
    local active = Profiles.activeProfile
    if active and active.meta and active.meta.id == profileId and Profiles.presets[profileId] then
        self:SetActiveProfile(profileId)
    end
end

--- Sets the active rotation profile and triggers IR compilation.
-- @param profileIdOrIR string|table
function Profiles:SetActiveProfile(profileIdOrIR)
    local ir = profileIdOrIR
    if type(profileIdOrIR) == "string" then
        -- Casilla "usar rotación vieja": un preset ya migrado vuelve a su versión v1 (meta.v1), si no hay custom
        local p = Profiles.presets[profileIdOrIR]
        local useV1 = _G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.useV1
        if p and p.meta and p.meta.v1 and useV1 and useV1[profileIdOrIR] and Profiles.presets[p.meta.v1]
            and not self:GetCustom(profileIdOrIR) then
            profileIdOrIR = p.meta.v1
        end
        ir = self:GetProfile(profileIdOrIR) or Profiles.presets[profileIdOrIR]
        if IsPreset(ir) then ir = WorkingCopy(ir) end
    elseif type(profileIdOrIR) == "table" then
        if IsPreset(ir) then
            ir = WorkingCopy(ir)
        elseif not (ir.meta and ir.meta.isPresetCopy) then
            self:SaveProfile(ir)     -- tabla nueva (importada o editada): rotacion custom de este PJ
        end
    end

    if not ir then
        return false, "Profile not found"
    end

    Profiles.activeProfile = ir
    -- La versión v1 de un preset migrado se guarda con el id del preset nuevo: la casilla decide al recargar
    local saveId = ir.meta and (ir.meta.v1Of or ir.meta.id)

    if _G.UnitClass then
        local _, classToken = _G.UnitClass("player")
        if classToken and _G.RotaCoreDB then
            _G.RotaCoreDB.classProfiles = _G.RotaCoreDB.classProfiles or {}
            if saveId then
                _G.RotaCoreDB.classProfiles[classToken] = saveId
            end
            if _G.UnitName then
                local realm = (_G.GetRealmName and _G.GetRealmName()) or "Unknown"
                local charName = _G.UnitName("player") or "Unknown"
                local charKey = charName .. " - " .. realm
                _G.RotaCoreDB.charProfiles = _G.RotaCoreDB.charProfiles or {}
                if saveId then
                    _G.RotaCoreDB.charProfiles[charKey] = saveId
                end
            end
        end
    end

    if RotaCore.Compiler then
        local compiled = RotaCore.Compiler:Compile(ir)
        Profiles.activeEvaluator = compiled
        RotaCore.activeEvaluator = compiled
    end

    return true
end

--- Gets the currently active profile IR.
function Profiles:GetActiveProfile()
    return Profiles.activeProfile
end

--- Gets the compiled evaluator bundle { evaluatorMain, evaluatorOff, resetSequences }.
function Profiles:GetActiveEvaluator()
    return Profiles.activeEvaluator
end

--- Handles talent group changes (Dual Spec in 3.3.5a).
function Profiles:OnTalentGroupChanged(newGroup)
    if not _G.RotaCoreDB then return end
    local specProfiles = _G.RotaCoreDB.activeSpecProfiles
    if specProfiles and specProfiles[newGroup] then
        Profiles:SetActiveProfile(specProfiles[newGroup])
    end
end

return Profiles
