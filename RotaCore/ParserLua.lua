-- RotaCore/ParserLua.lua — Structured Lua to RotationIR Parser (Levels A, B and C customLua)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local ParserLua = {}
RotaCore.ParserLua = ParserLua

-- 1. EXPRESSION TOKENIZER

local function Tokenize(src)
    local tokens = {}
    local i = 1
    local len = #src

    while i <= len do
        local c = src:sub(i, i)

        if c:match("%s") then
            i = i + 1
        elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
            -- Skip comments
            local nextNl = src:find("[\r\n]", i + 2)
            if nextNl then
                i = nextNl + 1
            else
                break
            end
        elseif c == '"' or c == "'" then
            local quote = c
            local start = i + 1
            local finish = start
            while finish <= len and src:sub(finish, finish) ~= quote do
                if src:sub(finish, finish) == "\\" then
                    finish = finish + 1 -- skip escaped char
                end
                finish = finish + 1
            end
            local strVal = src:sub(start, finish - 1)
            table.insert(tokens, { type = "STRING", val = strVal })
            i = finish + 1
        elseif c:match("%d") then
            local start = i
            while i <= len and src:sub(i, i):match("[%d%.]") do
                i = i + 1
            end
            local numVal = tonumber(src:sub(start, i - 1)) or 0
            table.insert(tokens, { type = "NUMBER", val = numVal })
        elseif c:match("[%a_]") then
            local start = i
            while i <= len and src:sub(i, i):match("[%w_]") do
                i = i + 1
            end
            local word = src:sub(start, i - 1)
            if word == "and" or word == "or" or word == "not" then
                table.insert(tokens, { type = word:upper(), val = word })
            elseif word == "true" then
                table.insert(tokens, { type = "BOOLEAN", val = true })
            elseif word == "false" then
                table.insert(tokens, { type = "BOOLEAN", val = false })
            elseif word == "nil" then
                table.insert(tokens, { type = "NIL", val = nil })
            else
                table.insert(tokens, { type = "IDENT", val = word })
            end
        elseif c == "=" or c == "~" or c == "!" or c == "<" or c == ">" then
            local two = src:sub(i, i + 1)
            if two == "==" or two == "~=" or two == "!=" or two == "<=" or two == ">=" then
                local op = two
                if op == "!=" then op = "~=" end
                table.insert(tokens, { type = "CMP", val = op })
                i = i + 2
            else
                if c == "<" or c == ">" then
                    table.insert(tokens, { type = "CMP", val = c })
                else
                    table.insert(tokens, { type = "PUNCT", val = c })
                end
                i = i + 1
            end
        elseif c == "(" or c == ")" or c == "," or c == "." or c == "[" or c == "]" then
            table.insert(tokens, { type = "PUNCT", val = c })
            i = i + 1
        else
            i = i + 1
        end
    end

    table.insert(tokens, { type = "EOF", val = "" })
    return tokens
end

-- 2. RECURSIVE DESCENT AST PARSER (Levels A & B)

local function ParserInstance(tokens)
    local pos = 1

    local function Peek()
        return tokens[pos] or { type = "EOF", val = "" }
    end

    local function Consume(expectedType, expectedVal)
        local t = Peek()
        if expectedType and t.type ~= expectedType then
            return nil, string.format("Expected token type %s but got %s", expectedType, t.type)
        end
        if expectedVal and t.val ~= expectedVal then
            return nil, string.format("Expected token %s but got %s", expectedVal, tostring(t.val))
        end
        pos = pos + 1
        return t
    end

    local ParseExpr
    local ParseOr
    local ParseAnd
    local ParseCmp
    local ParseUnary
    local ParsePrimary

    function ParseExpr()
        return ParseOr()
    end

    function ParseOr()
        local left, err = ParseAnd()
        if not left then return nil, err end

        while Peek().type == "OR" do
            Consume("OR")
            local right, rErr = ParseAnd()
            if not right then return nil, rErr end
            left = { op = "or", l = left, r = right }
        end
        return left
    end

    function ParseAnd()
        local left, err = ParseCmp()
        if not left then return nil, err end

        while Peek().type == "AND" do
            Consume("AND")
            local right, rErr = ParseCmp()
            if not right then return nil, rErr end
            left = { op = "and", l = left, r = right }
        end
        return left
    end

    function ParseCmp()
        local left, err = ParseUnary()
        if not left then return nil, err end

        if Peek().type == "CMP" then
            local op = Consume("CMP").val
            local right, rErr = ParseUnary()
            if not right then return nil, rErr end
            return { op = "cmp", cmp = op, l = left, r = right }
        end
        return left
    end

    function ParseUnary()
        if Peek().type == "NOT" then
            Consume("NOT")
            local expr, err = ParseUnary()
            if not expr then return nil, err end
            return { op = "not", expr = expr }
        end
        return ParsePrimary()
    end

    -- Map known camelCase methods back to dot syntax
    local MethodToDot = {
        debuffRemaining = "debuff.remaining",
        debuffCount = "debuff.count",
        buffRemaining = "buff.remaining",
        buffCount = "buff.count",
        spellReady = "spell.ready",
        spellCooldown = "spell.cooldown",
        spellUsable = "spell.usable",
    }

    function ParsePrimary()
        local t = Peek()

        -- Parentheses: ( expr )
        if t.type == "PUNCT" and t.val == "(" then
            Consume("PUNCT", "(")
            local expr, err = ParseExpr()
            if not expr then return nil, err end
            local _, closeErr = Consume("PUNCT", ")")
            if closeErr then return nil, closeErr end
            return expr
        end

        -- Literals
        if t.type == "NUMBER" or t.type == "STRING" or t.type == "BOOLEAN" or t.type == "NIL" then
            Consume()
            return { op = "val", val = t.val }
        end

        -- Identifiers / State access / Method calls / Variables
        if t.type == "IDENT" then
            local root = Consume("IDENT").val

            -- Handle state.xxx
            if root == "state" then
                if Peek().type == "PUNCT" and Peek().val == "." then
                    Consume("PUNCT", ".")
                    local memberToken = Consume("IDENT")
                    if not memberToken then return nil, "Expected identifier after state." end
                    local member = memberToken.val

                    -- Check for call: state.method(...)
                    if Peek().type == "PUNCT" and Peek().val == "(" then
                        Consume("PUNCT", "(")
                        local args = {}
                        if Peek().type ~= "PUNCT" or Peek().val ~= ")" then
                            while true do
                                local argNode, aErr = ParseExpr()
                                if not argNode then return nil, aErr end
                                table.insert(args, argNode)
                                if Peek().type == "PUNCT" and Peek().val == "," then
                                    Consume("PUNCT", ",")
                                else
                                    break
                                end
                            end
                        end
                        local _, cErr = Consume("PUNCT", ")")
                        if cErr then return nil, cErr end

                        local fnName = MethodToDot[member] or member
                        return { op = "call", fn = fnName, args = args }
                    end

                    -- Check for state.vars.xxx
                    if member == "vars" then
                        if Peek().type == "PUNCT" and Peek().val == "." then
                            Consume("PUNCT", ".")
                            local vToken = Consume("IDENT")
                            return { op = "var", name = vToken.val }
                        elseif Peek().type == "PUNCT" and Peek().val == "[" then
                            Consume("PUNCT", "[")
                            local vToken = Consume("STRING")
                            Consume("PUNCT", "]")
                            return { op = "var", name = vToken.val }
                        end
                    end

                    -- Multi-level property path: e.g. state.runes.bloodReady or state.dk.canSpendBloodOnBS
                    local fullPath = member
                    while Peek().type == "PUNCT" and Peek().val == "." do
                        Consume("PUNCT", ".")
                        local nextMember = Consume("IDENT")
                        if nextMember then
                            fullPath = fullPath .. "." .. nextMember.val
                        end
                    end
                    return { op = "state", path = fullPath }
                end
                return { op = "state", path = "" }
            end

            -- Handle vars.xxx or standalone var
            if root == "vars" and Peek().type == "PUNCT" and Peek().val == "." then
                Consume("PUNCT", ".")
                local vToken = Consume("IDENT")
                return { op = "var", name = vToken.val }
            end

            -- Default fallback identifier as val
            return { op = "val", val = root }
        end

        return nil, "Unexpected token in expression: " .. tostring(t.val)
    end

    local ast, err = ParseExpr()
    if not ast then return nil, err end
    return ast
end

function ParserLua:ParseExpression(exprStr)
    if not exprStr or exprStr:match("^%s*$") then
        return nil, "empty_expression"
    end
    -- Clean outer parentheses if any wrapped safely
    local tokens = Tokenize(exprStr)
    local ast, err = ParserInstance(tokens)
    return ast, err
end

-- 3. STRUCTURED RULE PARSER (Levels A, B and C)

--- Parses a raw rule string into a RotationIR rule.
-- If the rule fits "if <cond> then return <action> end", it becomes a "block" rule (Levels A/B).
-- Otherwise or if marked [customLua], it gracefully becomes a "customLua" rule (Level C).
-- @param ruleStr string
-- @param defaultId string
-- @return table
function ParserLua:ParseRule(ruleStr, defaultId)
    local rule = {
        id = defaultId or "rule_custom",
        enabled = true,
        type = "block",
        action = "WAIT",
        note = nil,
    }

    -- 1. Extract comments/metadata from rule header
    local customLuaFlag = false
    local headerNote = ruleStr:match("%-%-%s*%[.-%]%s*(.-)[\r\n]")
    if headerNote and headerNote ~= "" then
        rule.note = headerNote
    end

    local ruleIdMatch = ruleStr:match("%-%-%s*%[rule:%s*([%w_]+)")
    if ruleIdMatch then
        rule.id = ruleIdMatch
    end

    local customMatch = ruleStr:match("%-%-%s*%[customLua:%s*([%w_]+)")
    if customMatch then
        rule.id = customMatch
        customLuaFlag = true
    end

    if ruleStr:find("%[disabled%]") then
        rule.enabled = false
    end

    -- 2. Attempt Level A / B structured parsing: "if <cond> then return <action> end"
    -- Match if ... then return "ACTION" end pattern
    local condStr, retBody = ruleStr:match("if%s+(.-)%s+then%s+(.-)%s+end")
    if condStr and retBody and not customLuaFlag then
        -- Extract return action
        local action = retBody:match('return%s+["\']([%w_]+)["\']')
        if not action then
            action = retBody:match("return%s+([%w_]+)")
        end

        if action then
            rule.action = action
            -- Check for trailing comment as note
            local trailingNote = retBody:match("%-%-%s*(.+)$")
            if trailingNote and not rule.note then
                rule.note = trailingNote
            end

            -- Parse condition AST
            local ast = self:ParseExpression(condStr)
            if ast then
                rule.when = ast
                rule.type = "block"
                return rule
            end
        end
    end

    -- 3. Fallback to Level C: customLua
    rule.type = "customLua"
    -- Strip comment header from executable code
    local cleanedCode = ruleStr:gsub("^%s*%-%-[^\r\n]*[\r\n]+", "")
    rule.code = cleanedCode:gsub("^%s+", ""):gsub("%s+$", "")

    -- Extract action if return "ACTION" present in code
    local act = rule.code:match('return%s+["\']([%w_]+)["\']')
    if act then
        rule.action = act
    else
        rule.action = "CUSTOM"
    end

    return rule
end

-- 4. FULL PROFILE / SCRIPT PARSER

--- Parses a full canonical Lua script or prioritized snippet into a RotationIR table.
-- @param src string canonical Lua source
-- @param baseIR table optional base IR to merge into
-- @return table RotationIR
function ParserLua:Parse(src, baseIR)
    src = src or ""
    local ir = baseIR or {
        meta = {
            id = "imported_lua",
            name = "Imported Lua Profile",
            class = "DEATHKNIGHT",
            spec = "Unknown",
            schema = 1,
            interface = 30300,
        },
        spells = {},
        vars = {},
        sequences = {},
        lists = {
            main = {},
            off = {},
        },
    }

    -- 1. Parse Metadata Headers
    local pId = src:match("%-%-%s*@profile:%s*([%w_]+)")
    if pId then ir.meta.id = pId end
    local pName = src:match("%-%-%s*@name:%s*([^\r\n]+)")
    if pName then ir.meta.name = pName end
    local pClass = src:match("%-%-%s*@class:%s*([%w_]+)")
    if pClass then ir.meta.class = pClass end
    local pSpec = src:match("%-%-%s*@spec:%s*([%w_]+)")
    if pSpec then ir.meta.spec = pSpec end

    -- 2. Parse Spells
    local spellPattern = '%-%-%s*spell:%s*([%w_]+)%s*=%s*{%s*name%s*=%s*["\'](.-)["\'],'
        .. '%s*defaultId%s*=%s*(%d+),%s*overrideId%s*=%s*(%S+),%s*matchById%s*=%s*(%S+)%s*}'
    for alias, name, defId, ovrId, mById in src:gmatch(spellPattern) do
        local dId = tonumber(defId) or 0
        local oId = (ovrId ~= "nil") and tonumber(ovrId) or nil
        local mId = (mById == "true")
        ir.spells[alias] = {
            name = name,
            defaultId = dId,
            overrideId = oId,
            matchById = mId,
        }
    end

    -- 3. Parse Variables
    for varName, varVal in src:gmatch("%-%-%s*var:%s*([%w_]+)%s*=%s*([%w_%.]+)") do
        local num = tonumber(varVal)
        if num ~= nil then
            ir.vars[varName] = num
        elseif varVal == "true" then
            ir.vars[varName] = true
        elseif varVal == "false" then
            ir.vars[varName] = false
        else
            ir.vars[varName] = varVal
        end
    end

    -- 4. Parse Sequences
    local seqTimeout, seqEnabled = src:match("%-%-%s*@sequence:%s*opener%s*%(timeout=(%d+),%s*enabled=([%w_]+)%)")
    local seqStepsStr = src:match("%-%-%s*steps:%s*([^\r\n]+)")
    if seqStepsStr then
        local steps = {}
        for step in seqStepsStr:gmatch("[%w_]+") do
            table.insert(steps, step)
        end
        ir.sequences.opener = {
            enabled = (seqEnabled ~= "false"),
            timeout = tonumber(seqTimeout) or 10,
            resetOnCombatEnd = true,
            steps = steps,
        }
    end

    -- 5. Split lists: main and off
    -- Check if section delimiters exist
    local mainSec = ""
    local offSec = ""

    local mainPos = src:find("%-%-%s*@list:%s*main")
    local offPos = src:find("%-%-%s*@list:%s*off")

    if mainPos and offPos then
        if mainPos < offPos then
            mainSec = src:sub(mainPos, offPos - 1)
            offSec = src:sub(offPos)
        else
            offSec = src:sub(offPos, mainPos - 1)
            mainSec = src:sub(mainPos)
        end
    elseif mainPos then
        mainSec = src:sub(mainPos)
    elseif offPos then
        offSec = src:sub(offPos)
    else
        -- No list markers: entire content is treated as main list
        mainSec = src
    end

    local function ParseListRules(sectionStr, listKey)
        local ruleIndex = 1

        -- 1. Chunk by rule header comments: "-- [rule:" or "-- [customLua:"
        local headerIndices = {}
        local pos = 1
        while true do
            local s, e = sectionStr:find("%-%-%s*%[[%w_]+:", pos)
            if not s then break end
            table.insert(headerIndices, s)
            pos = e + 1
        end

        if #headerIndices > 0 then
            for i = 1, #headerIndices do
                local startPos = headerIndices[i]
                local endPos = (i < #headerIndices) and (headerIndices[i + 1] - 1) or #sectionStr
                local ruleBlock = sectionStr:sub(startPos, endPos)
                local r = self:ParseRule(ruleBlock, listKey .. "_" .. ruleIndex)
                table.insert(ir.lists[listKey], r)
                ruleIndex = ruleIndex + 1
            end
            return
        end

        -- 2. Fallback: match standalone "if ... then ... end"
        local foundAny = false
        for ruleBlock in sectionStr:gmatch("(if%s+.-%s+then%s+.-%s+end)") do
            foundAny = true
            local r = self:ParseRule(ruleBlock, listKey .. "_" .. ruleIndex)
            table.insert(ir.lists[listKey], r)
            ruleIndex = ruleIndex + 1
        end

        -- 3. If still nothing found but text is non-empty and not just comments, treat as single customLua
        if not foundAny then
            local stripped = sectionStr:gsub("%-%-[^\r\n]*", ""):gsub("%s+", "")
            if #stripped > 0 then
                local r = self:ParseRule(sectionStr, listKey .. "_custom")
                table.insert(ir.lists[listKey], r)
            end
        end
    end

    ir.lists.main = {}
    ir.lists.off = {}
    if #mainSec > 0 then
        ParseListRules(mainSec, "main")
    end
    if #offSec > 0 then
        ParseListRules(offSec, "off")
    end

    return ir
end

return ParserLua
