-- RotaCore/CodeGen.lua — Canonical Lua Code Generator from RotationIR (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local CodeGen = {}
RotaCore.CodeGen = CodeGen

local Compiler = RotaCore.Compiler

-- FORMATTERS & HELPERS

local function FormatVal(val)
    if type(val) == "string" then
        return string.format("%q", val)
    elseif type(val) == "boolean" or type(val) == "number" then
        return tostring(val)
    elseif val == nil then
        return "nil"
    else
        return tostring(val)
    end
end

--- Converts an AST condition node into a clean, canonical Lua expression string.
-- Symmetrical with ParserLua expression parser.
-- @param node table AST node
-- @return string
local function ASTToLua(node)
    if type(node) ~= "table" then
        return FormatVal(node)
    end

    local op = node.op

    if op == "val" then
        return FormatVal(node.val)
    elseif op == "var" then
        return string.format("state.vars.%s", tostring(node.name))
    elseif op == "state" then
        return "state." .. tostring(node.path)
    elseif op == "cmp" then
        local cmp = node.cmp
        if cmp == "!=" then cmp = "~=" end
        local l = ASTToLua(node.l)
        local r = ASTToLua(node.r)
        return string.format("%s %s %s", l, cmp, r)
    elseif op == "and" then
        local l = ASTToLua(node.l)
        local r = ASTToLua(node.r)
        -- Wrap complex child binary expressions if needed for clarity
        if type(node.l) == "table" and node.l.op == "or" then l = "(" .. l .. ")" end
        if type(node.r) == "table" and node.r.op == "or" then r = "(" .. r .. ")" end
        return string.format("%s and %s", l, r)
    elseif op == "or" then
        local l = ASTToLua(node.l)
        local r = ASTToLua(node.r)
        return string.format("%s or %s", l, r)
    elseif op == "not" then
        local target = node.expr or node.l
        local exprStr = ASTToLua(target)
        if type(target) == "table" and (target.op == "and" or target.op == "or" or target.op == "cmp") then
            return string.format("not (%s)", exprStr)
        else
            return string.format("not %s", exprStr)
        end
    elseif op == "call" then
        local fn = node.fn
        local args = node.args or {}
        local formattedArgs = {}
        for i, arg in ipairs(args) do
            formattedArgs[i] = ASTToLua(arg)
        end
        local argStr = table.concat(formattedArgs, ", ")

        if fn == "debuff.remaining" then
            return string.format("state.debuffRemaining(%s)", argStr)
        elseif fn == "debuff.count" then
            return string.format("state.debuffCount(%s)", argStr)
        elseif fn == "buff.remaining" then
            return string.format("state.buffRemaining(%s)", argStr)
        elseif fn == "buff.count" then
            return string.format("state.buffCount(%s)", argStr)
        elseif fn == "spell.ready" then
            return string.format("state.spellReady(%s)", argStr)
        elseif fn == "spell.cooldown" then
            return string.format("state.spellCooldown(%s)", argStr)
        elseif fn == "spell.usable" then
            return string.format("state.spellUsable(%s)", argStr)
        elseif fn == "spell.isCurrent" or fn == "isCurrentSpell" then
            return string.format("state.isCurrentSpell(%s)", argStr)
        elseif fn:find("^runes%.") or fn:find("^dk%.") or fn:find("^pal%.") or fn:find("^war%.") then
            return "state." .. fn
        else
            return string.format("state.%s(%s)", fn, argStr)
        end
    end

    if Compiler and Compiler.ASTToLua then
        return Compiler.ASTToLua(node)
    end

    return "false"
end

CodeGen.ASTToLua = ASTToLua

-- RULE SERIALIZATION

--- Converts a single rule into canonical Lua source.
-- @param rule table RotationIR rule
-- @param indent string indentation prefix (default "")
-- @return string
function CodeGen:RuleToLua(rule, indent)
    indent = indent or ""
    local lines = {}

    local ruleId = rule.id or "anon"
    local note = rule.note and (" -- " .. rule.note) or ""
    local enabledFlag = (rule.enabled == false) and " [disabled]" or ""

    if rule.type == "customLua" then
        table.insert(lines, string.format("%s-- [customLua: %s%s]%s", indent, ruleId, enabledFlag, note))
        local code = rule.code or ""
        -- indent custom code lines
        for line in code:gmatch("[^\r\n]+") do
            table.insert(lines, indent .. line)
        end
    else
        -- Block rule (Level A / B)
        table.insert(lines, string.format("%s-- [rule: %s%s]%s", indent, ruleId, enabledFlag, note))
        local condStr
        if rule.when then
            condStr = ASTToLua(rule.when)
        else
            condStr = "true"
        end

        local action = rule.action or "WAIT"
        table.insert(lines, string.format("%sif %s then", indent, condStr))
        table.insert(lines, string.format("%s    return %q", indent, action))
        table.insert(lines, string.format("%send", indent))
    end

    return table.concat(lines, "\n")
end

-- LIST SERIALIZATION

--- Converts a priority list (main or off) into canonical Lua code.
-- @param ruleList table array of rules
-- @param listName string "main" or "off"
-- @return string
function CodeGen:ListToLua(ruleList, listName)
    local lines = {}
    table.insert(lines, string.format("-- @list: %s", listName or "main"))
    if ruleList and #ruleList > 0 then
        for i, rule in ipairs(ruleList) do
            table.insert(lines, self:RuleToLua(rule, ""))
            if i < #ruleList then
                table.insert(lines, "") -- empty line between rules
            end
        end
    else
        table.insert(lines, "-- (empty)")
    end
    return table.concat(lines, "\n")
end

-- PROFILE FULL SERIALIZATION

--- Converts an entire RotationIR profile into a canonical structured Lua script.
-- @param ir table RotationIR profile
-- @return string
function CodeGen:ProfileToLua(ir)
    if not ir then return "" end

    local lines = {}

    -- 1. Metadata
    local meta = ir.meta or {}
    table.insert(lines, string.format("-- @profile: %s", meta.id or "custom_profile"))
    table.insert(lines, string.format("-- @name: %s", meta.name or "Custom Profile"))
    table.insert(lines, string.format("-- @class: %s", meta.class or "DEATHKNIGHT"))
    table.insert(lines, string.format("-- @spec: %s", meta.spec or "Unknown"))
    table.insert(lines, string.format("-- @schema: %d", meta.schema or 1))
    table.insert(lines, string.format("-- @interface: %d", meta.interface or 30300))
    table.insert(lines, "")

    -- 2. Spells catalog
    if ir.spells and next(ir.spells) then
        table.insert(lines, "-- @spells")
        -- sort aliases for deterministic output
        local sortedAliases = {}
        for alias in pairs(ir.spells) do
            table.insert(sortedAliases, alias)
        end
        table.sort(sortedAliases)

        for _, alias in ipairs(sortedAliases) do
            local s = ir.spells[alias]
            local defId = s.defaultId or 0
            local ovrId = s.overrideId and tostring(s.overrideId) or "nil"
            local mById = s.matchById and "true" or "false"
            table.insert(lines, string.format("-- spell: %s = { name = %q, defaultId = %d, overrideId = %s, matchById = %s }",
                alias, s.name or alias, defId, ovrId, mById))
        end
        table.insert(lines, "")
    end

    -- 3. Variables
    if ir.vars and next(ir.vars) then
        table.insert(lines, "-- @vars")
        local sortedVars = {}
        for varName in pairs(ir.vars) do
            table.insert(sortedVars, varName)
        end
        table.sort(sortedVars)

        for _, varName in ipairs(sortedVars) do
            local val = ir.vars[varName]
            table.insert(lines, string.format("-- var: %s = %s", varName, FormatVal(val)))
        end
        table.insert(lines, "")
    end

    -- 4. Sequences
    if ir.sequences and ir.sequences.opener and ir.sequences.opener.steps then
        local op = ir.sequences.opener
        local steps = table.concat(op.steps, ", ")
        table.insert(lines, string.format("-- @sequence: opener (timeout=%d, enabled=%s)",
            op.timeout or 10, op.enabled ~= false and "true" or "false"))
        table.insert(lines, string.format("-- steps: %s", steps))
        table.insert(lines, "")
    end

    -- 5. Main priority list
    table.insert(lines, self:ListToLua((ir.lists and ir.lists.main) or {}, "main"))
    table.insert(lines, "")

    -- 6. Off-GCD priority list
    table.insert(lines, self:ListToLua((ir.lists and ir.lists.off) or {}, "off"))
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

return CodeGen
