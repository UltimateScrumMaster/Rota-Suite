-- RotaCore/Compat.lua — Rebuffed Custom Lua API Compatibility & Feature Detection (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Compat = {
    hasNameplates = false,
    hasCC = false,
    hasSilence = false,
    hasDisarm = false,
    hasClipboard = false,
    hasSpellBaseCD = false,
    hasQueueInteract = false,
}
RotaCore.Compat = Compat

--- Refreshes detected API availability.
function Compat:Refresh()
    self.hasNameplates = (type(_G.C_NamePlate) == "table" and type(_G.C_NamePlate.GetNamePlates) == "function")
    self.hasCC = (type(_G.UnitIsControlled) == "function")
    self.hasSilence = (type(_G.UnitIsSilenced) == "function")
    self.hasDisarm = (type(_G.UnitIsDisarmed) == "function")
    self.hasClipboard = (type(_G.CopyToClipboard) == "function")
    self.hasSpellBaseCD = (type(_G.GetSpellBaseCooldown) == "function")
    self.hasQueueInteract = (type(_G.QueueInteract) == "function")
end

-- Run initial feature detection
Compat:Refresh()

--- Safe check for crowd-control on a unit.
-- @param unit string
-- @return boolean
function Compat.UnitIsControlled(unit)
    if not Compat.hasCC or not _G.UnitIsControlled or not unit then return false end
    local ok, res = pcall(_G.UnitIsControlled, unit)
    return (ok and res == true) or false
end

--- Safe check for silence on a unit.
-- @param unit string
-- @return boolean
function Compat.UnitIsSilenced(unit)
    if not Compat.hasSilence or not _G.UnitIsSilenced or not unit then return false end
    local ok, res = pcall(_G.UnitIsSilenced, unit)
    return (ok and res == true) or false
end

--- Safe check for disarm on a unit.
-- @param unit string
-- @return boolean
function Compat.UnitIsDisarmed(unit)
    if not Compat.hasDisarm or not _G.UnitIsDisarmed or not unit then return false end
    local ok, res = pcall(_G.UnitIsDisarmed, unit)
    return (ok and res == true) or false
end

--- Copies text to system clipboard if supported.
-- @param text string
-- @return boolean true if copied, false if unsupported or failed
function Compat.CopyToClipboard(text)
    if not Compat.hasClipboard or not _G.CopyToClipboard then return false end
    local ok = pcall(_G.CopyToClipboard, tostring(text or ""))
    return ok
end

--- Retrieves normalized base cooldown for a spell (in seconds).
-- Rebuffed client may return milliseconds (>1000) or seconds.
-- @param spellId number
-- @return number|nil normalizedSeconds, number|nil rawValue, string|nil unit
function Compat.GetSpellBaseCooldown(spellId)
    if not Compat.hasSpellBaseCD or not _G.GetSpellBaseCooldown or not spellId then return nil end
    local ok, raw = pcall(_G.GetSpellBaseCooldown, spellId)
    if not ok or type(raw) ~= "number" or raw < 0 then
        return nil
    end
    if raw > 1000 then
        return raw / 1000, raw, "ms"
    end
    return raw, raw, "s"
end

--- Extracts a valid unit token from a nameplate object (supports both frame tables and string tokens).
-- @param plateOrToken any
-- @return string|nil
function Compat.ExtractUnitToken(plateOrToken)
    if type(plateOrToken) == "string" then
        return plateOrToken
    elseif type(plateOrToken) == "table" then
        if type(plateOrToken.namePlateUnitToken) == "string" then
            return plateOrToken.namePlateUnitToken
        elseif plateOrToken.unitFrame and type(plateOrToken.unitFrame.unit) == "string" then
            return plateOrToken.unitFrame.unit
        elseif type(plateOrToken.unit) == "string" then
            return plateOrToken.unit
        elseif type(plateOrToken.namePlateUnit) == "string" then
            return plateOrToken.namePlateUnit
        end
    end
    return nil
end

--- Safely fetches current active nameplates list.
-- @return table|nil
function Compat.GetNamePlates()
    if not Compat.hasNameplates or not _G.C_NamePlate or not _G.C_NamePlate.GetNamePlates then
        return nil
    end
    local ok, plates = pcall(_G.C_NamePlate.GetNamePlates)
    if ok and type(plates) == "table" then
        return plates
    end
    return nil
end

return Compat
