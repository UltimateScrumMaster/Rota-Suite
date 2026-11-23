-- RotaCore/Spells.lua — Spell Catalog, SpellID Resolver & Manual Overrides (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Spells = {
    registered = {}, -- [alias] = { name = canonicalName, defaultId = id, overrideId = id, matchById = bool }
    bookSpells = {}, -- [canonicalName] = maxRankSpellId
    bookSpellIds = {}, -- [spellId] = true
    overrides = {},  -- [aliasOrName] = overrideSpellId (manual overrides)
    cache = {},      -- [aliasOrName] = resolvedSpellId
}
RotaCore.Spells = Spells

--- Registers a spell alias and its canonical definition from RotationIR.
-- @param alias string Short key (e.g. "IT", "PS", "BS")
-- @param name string Canonical spell name (e.g. "Icy Touch")
-- @param defaultId number Default 3.3.5a spell ID
-- @param overrideId number|nil Optional IR-level override
-- @param matchById boolean True to prioritize defaultId over book scan
function Spells:RegisterSpell(alias, name, defaultId, overrideId, matchById)
    Spells.registered[alias] = {
        alias = alias,
        name = name,
        defaultId = defaultId,
        overrideId = overrideId,
        matchById = matchById or false,
    }
    Spells.cache[alias] = nil
end

--- Sets a manual runtime override for a spell alias or canonical name.
-- @param aliasOrName string Alias or spell name
-- @param overrideId number Custom server spell ID
function Spells:SetOverride(aliasOrName, overrideId)
    if overrideId and overrideId > 0 then
        Spells.overrides[aliasOrName] = overrideId
    else
        Spells.overrides[aliasOrName] = nil
    end
    Spells.cache[aliasOrName] = nil
end

--- Gets the active override for an alias or name, if any.
function Spells:GetOverride(aliasOrName)
    return Spells.overrides[aliasOrName]
end

--- Clears a manual override.
function Spells:ClearOverride(aliasOrName)
    Spells.overrides[aliasOrName] = nil
    Spells.cache[aliasOrName] = nil
end

--- Scans the player's spellbook to find the highest rank learned for each spell name.
-- Executed on ADDON_LOADED and SPELLS_CHANGED outside hot-paths.
function Spells:ScanSpellBook()
    if not _G.GetNumSpellTabs then return end

    local numTabs = _G.GetNumSpellTabs()
    for tab = 1, numTabs do
        local _, _, offset, numSpells = _G.GetSpellTabInfo(tab)
        if offset and numSpells then
            for slot = (offset + 1), (offset + numSpells) do
                local spellId = nil
                local spellName = nil

                -- 1. Try GetSpellLink (standard WoW 3.3.5a API for spellbook slots: GetSpellLink(slot, "spell"))
                if _G.GetSpellLink then
                    local link = _G.GetSpellLink(slot, "spell")
                    if link then
                        local idStr = link:match("spell:(%d+)")
                        if idStr then
                            spellId = tonumber(idStr)
                        end
                    end
                end

                -- 2. Fallback to GetSpellBookItemInfo (if supported in environment)
                if not spellId and _G.GetSpellBookItemInfo then
                    local spellType, id = _G.GetSpellBookItemInfo(slot, "spell")
                    if (spellType == "SPELL" or not spellType) and id and id > 0 then
                        spellId = id
                    end
                end

                -- 3. Resolve spell name via GetSpellName or GetSpellBookItemName
                if _G.GetSpellName then
                    spellName = _G.GetSpellName(slot, "spell")
                elseif _G.GetSpellBookItemName then
                    spellName = _G.GetSpellBookItemName(slot, "spell")
                end

                if (not spellName or spellName == "") and spellId and _G.GetSpellInfo then
                    spellName = _G.GetSpellInfo(spellId)
                end

                -- 4. Store in bookSpells table (highest rank learned overwrites earlier ranks)
                if spellName and spellId and spellId > 0 then
                    Spells.bookSpells[spellName] = spellId
                    Spells.bookSpellIds[spellId] = true
                end
            end
        end
    end

    -- Invalidate resolution cache after spellbook changes
    for k in pairs(Spells.cache) do
        Spells.cache[k] = nil
    end
end

--- Resolves a spell alias or name into the definitive SpellID to use.
-- Priority:
-- 1. Manual override (`Spells.overrides[aliasOrName]`)
-- 2. IR override (`entry.overrideId`)
-- 3. Match by ID (`entry.defaultId` if `entry.matchById`)
-- 4. Highest rank learned in Spellbook (`Spells.bookSpells[name]`)
-- 5. Default ID from IR catalog (`entry.defaultId`)
-- 6. Numeric passthrough if already a spellId
-- @param aliasOrName string|number
-- @return number|nil resolvedSpellId
function Spells:ResolveID(aliasOrName)
    local cached = Spells.cache[aliasOrName]
    if cached then
        return cached
    end

    -- 1. Manual override by alias or name
    local override = Spells.overrides[aliasOrName]
    if override and override > 0 then
        Spells.cache[aliasOrName] = override
        return override
    end

    local reg = Spells.registered[aliasOrName]
    if reg then
        -- Check manual override by canonical name if registered under alias
        if reg.name and Spells.overrides[reg.name] then
            local nameOverride = Spells.overrides[reg.name]
            Spells.cache[aliasOrName] = nameOverride
            return nameOverride
        end

        -- 2. IR-level override
        if reg.overrideId and reg.overrideId > 0 then
            Spells.cache[aliasOrName] = reg.overrideId
            return reg.overrideId
        end

        -- 3. Match by ID flag
        if reg.matchById and reg.defaultId and reg.defaultId > 0 then
            Spells.cache[aliasOrName] = reg.defaultId
            return reg.defaultId
        end

        -- 4. Spellbook resolution (highest learned rank)
        if reg.name and Spells.bookSpells[reg.name] then
            local bookId = Spells.bookSpells[reg.name]
            Spells.cache[aliasOrName] = bookId
            return bookId
        end

        -- 5. Default ID
        if reg.defaultId and reg.defaultId > 0 then
            Spells.cache[aliasOrName] = reg.defaultId
            return reg.defaultId
        end
    end

    -- If not registered by alias, check if it's a raw canonical name in spellbook
    if type(aliasOrName) == "string" and Spells.bookSpells[aliasOrName] then
        local bId = Spells.bookSpells[aliasOrName]
        Spells.cache[aliasOrName] = bId
        return bId
    end

    -- Raw numeric ID passthrough
    if type(aliasOrName) == "number" then
        Spells.cache[aliasOrName] = aliasOrName
        return aliasOrName
    end

    return nil
end

--- Returns GetSpellInfo for the resolved spell.
function Spells:GetInfo(aliasOrName)
    local spellId = Spells:ResolveID(aliasOrName)
    if spellId and _G.GetSpellInfo then
        return _G.GetSpellInfo(spellId)
    end
    return nil
end

--- Returns cooldown details: start, duration, enabled.
function Spells:GetCooldown(aliasOrName)
    local spellId = Spells:ResolveID(aliasOrName)
    if spellId and _G.GetSpellCooldown then
        local start, duration, enabled = _G.GetSpellCooldown(spellId)
        if start ~= nil then
            return start, duration or 0, enabled or 1
        end
    end
    return 0, 0, 1
end

--- Returns remaining cooldown time in seconds (ignoring GCD <= 1.5s).
-- @param aliasOrName string
-- @param now number Current time from GetTime()
-- @return number Seconds remaining (0 if ready)
function Spells:GetCooldownRemaining(aliasOrName, now)
    local start, duration, enabled = Spells:GetCooldown(aliasOrName)
    if not start or start == 0 or not duration or duration == 0 or not enabled or enabled == 0 then
        return 0
    end
    -- In 3.3.5a, GCD is returned as duration <= 1.5s
    if duration <= 1.5 then
        return 0
    end
    local rem = (start + duration) - (now or 0)
    if rem > 0 then
        return rem
    end
    return 0
end

--- Checks if a spell is off cooldown (or ready as soon as GCD finishes).
function Spells:IsReady(aliasOrName, now, gcdRemains)
    local rem = Spells:GetCooldownRemaining(aliasOrName, now)
    return rem <= (gcdRemains or 0)
end

--- Checks if spell is usable (mana/runes/resources available).
function Spells:IsUsable(aliasOrName)
    local spellId = Spells:ResolveID(aliasOrName)
    if spellId and _G.IsUsableSpell then
        local isUsable, noMana = _G.IsUsableSpell(spellId)
        return isUsable and not noMana
    end
    return true
end

--- Checks if spell is in range of unit.
function Spells:IsInRange(aliasOrName, unit)
    if not _G.IsSpellInRange then return 1 end
    local name = Spells:GetInfo(aliasOrName)
    local targetUnit = unit or "target"
    return _G.IsSpellInRange(name or aliasOrName, targetUnit)
end

--- Checks if a spell is known or present in the spellbook/accessible.
-- Checks scanned spellbook (bookSpells) and GetSpellCooldown(name) ~= nil.
-- @param spellNameOrId string|number Spell alias, canonical name, or spell ID
-- @return boolean
function Spells:HasSpell(spellNameOrId)
    local target = spellNameOrId
    if target == nil and (type(self) == "string" or type(self) == "number") then
        target = self
    end
    if not target then return false end

    -- 1. Numeric Spell ID
    if type(target) == "number" then
        if _G.IsSpellKnown and _G.IsSpellKnown(target) then
            return true
        end
        if Spells.bookSpellIds[target] then
            return true
        end
        if _G.GetSpellCooldown and _G.GetSpellCooldown(target) ~= nil then
            return true
        end
        return false
    end

    -- 2. String alias or canonical name
    if type(target) == "string" then
        local num = tonumber(target)
        if num then
            return Spells:HasSpell(num)
        end

        if Spells.bookSpells[target] then
            return true
        end

        local reg = Spells.registered[target]
        local canonicalName = reg and reg.name or target

        if canonicalName and Spells.bookSpells[canonicalName] then
            return true
        end

        if reg and reg.defaultId then
            if _G.IsSpellKnown and _G.IsSpellKnown(reg.defaultId) then
                return true
            end
            if Spells.bookSpellIds[reg.defaultId] then
                return true
            end
        end

        if _G.GetSpellCooldown then
            if _G.GetSpellCooldown(canonicalName) ~= nil then
                return true
            end
            if canonicalName ~= target and _G.GetSpellCooldown(target) ~= nil then
                return true
            end
        end
    end

    return false
end

Spells.IsSpellKnown = Spells.HasSpell

return Spells
