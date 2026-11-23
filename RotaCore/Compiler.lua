-- RotaCore/Compiler.lua — RotationIR to Native Zero-Allocation Closures Compiler (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Compiler = {}
RotaCore.Compiler = Compiler

-- AST TO LUA EXPRESSION CODE GENERATOR

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

local function ASTToLua(node)
    if type(node) ~= "table" then
        return FormatVal(node)
    end

    local op = node.op

    if op == "val" then
        return FormatVal(node.val)
    elseif op == "var" then
        return string.format("(state.vars and state.vars[%q] or 0)", tostring(node.name))
    elseif op == "state" then
        return "state." .. tostring(node.path)
    elseif op == "cmp" then
        local cmp = node.cmp
        if cmp == "!=" then cmp = "~=" end
        local l = ASTToLua(node.l)
        local r = ASTToLua(node.r)
        return string.format("(%s %s %s)", l, cmp, r)
    elseif op == "and" then
        return string.format("(%s and %s)", ASTToLua(node.l), ASTToLua(node.r))
    elseif op == "or" then
        return string.format("(%s or %s)", ASTToLua(node.l), ASTToLua(node.r))
    elseif op == "not" then
        return string.format("(not %s)", ASTToLua(node.expr or node.l))
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

    return "false"
end

Compiler.ASTToLua = ASTToLua

-- RULE PRE-COMPILER

local BURST_SPELL_ALIASES = {
    GARG = true,
    AOTD = true,
    UA = true,
    SPEED_POT = true,
    POT = true,
    HYPER = true,
    ENG = true,
    GLOVES = true,
    BF = true,
    BERSERKING = true,
    STONEFORM = true,
    ERW = true,
    RD = true,
}

local function IsActionKnown(state, action)
    if not action or action == "WAIT" then return true end
    if action == "GLOVES" or action == "HYPER" or action == "SPEED_POT" or action == "POT"
        or action == "ENG" or action == "POTION" then
        return true
    end
    if state and state.hasSpell then
        return state.hasSpell(action)
    end
    if RotaCore.Spells and RotaCore.Spells.HasSpell then
        return RotaCore.Spells:HasSpell(action)
    end
    if _G.GetSpellCooldown then
        return _G.GetSpellCooldown(action) ~= nil
    end
    return true
end

local function CompileRule(rule)
    local isAoE = nil
    if rule.isAoE ~= nil then
        isAoE = rule.isAoE
    elseif rule.aoe ~= nil then
        isAoE = rule.aoe
    end

    local compiledRule = {
        id = rule.id or "anon",
        enabled = (rule.enabled ~= false),
        type = rule.type or "block",
        action = rule.action or "WAIT",
        note = rule.note,
        raw = rule,
        isBurst = (rule.isBurst == true or rule.burst == true),
        isAoE = isAoE,
    }

    if compiledRule.type == "customLua" then
        local runner, stateObj = RotaCore.Sandbox:Compile(rule.code, rule.id)
        compiledRule.evalFn = runner
        compiledRule.ruleState = stateObj
    else
        -- Block rule with AST condition
        if rule.when then
            local exprCode = ASTToLua(rule.when)
            local fnSrc = "return function(state) return " .. exprCode .. " end"
            local chunk, err = loadstring(fnSrc, "Rule_" .. tostring(rule.id))
            if chunk then
                compiledRule.evalCond = chunk()
            else
                if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                    _G.DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Compiler Error]|r " .. tostring(err))
                end
                compiledRule.evalCond = function() return false end
            end
        else
            -- Always true if no condition
            compiledRule.evalCond = function() return true end
        end
    end

    return compiledRule
end

-- MAIN & OFF PRIORITY LIST COMPILATION

--- Compiles a full RotationIR profile into high-performance evaluators.
-- @param ir table RotationIR table (docs/SPEC_MAESTRO.md, seccion 3.1)
-- @return table { evaluatorMain = fn(state), evaluatorOff = fn(state), resetSequences = fn() }
--- Regla legible para los presets: R("id", "ACCION", "descripcion", [[ if ready("X") then return "X" end ]])
function RotaCore.Rule(id, action, note, code)
    return { id = id, enabled = true, type = "customLua", action = action, note = note, code = code }
end

--- Lista de reglas donde algunos elementos son grupos de reglas: { r1, { r2, r3 }, r4 } -> { r1, r2, r3, r4 }
function RotaCore.Flatten(list)
    local out = {}
    for _, item in ipairs(list) do
        if item.id then
            out[#out + 1] = item
        else
            for _, r in ipairs(item) do out[#out + 1] = r end
        end
    end
    return out
end

--- Version v1 de un preset migrado: mismo catalogo y variables, pero la lista vieja (gancho al evaluador del
-- modulo). Queda registrada como "<id>_v1" para la casilla "usar la rotacion vieja" y el comparador.
function RotaCore.V1Of(preset, lists)
    local m = preset.meta
    local meta = {}
    for k, v in pairs(m) do meta[k] = v end
    meta.id, meta.v1Of, meta.name = m.id .. "_v1", m.id, (m.name or m.id) .. " (v1)"
    m.v1 = meta.id
    return { meta = meta, spells = preset.spells, vars = preset.vars, sequences = preset.sequences, lists = lists }
end

function Compiler:Compile(ir)
    if not ir then return nil, "missing_ir" end

    -- 1. Register all spells in catalog
    if ir.spells and RotaCore.Spells then
        for alias, s in pairs(ir.spells) do
            RotaCore.Spells:RegisterSpell(alias, s.name, s.defaultId, s.overrideId, s.matchById)
        end
    end

    -- 2. Link IR variables into central State
    if ir.vars and RotaCore.State and RotaCore.State.data then
        for k, v in pairs(ir.vars) do
            RotaCore.State.data.vars[k] = v
        end
    end

    -- 3. Pre-compile rules
    local mainRules = {}
    if ir.lists and ir.lists.main then
        for i, rule in ipairs(ir.lists.main) do
            mainRules[i] = CompileRule(rule)
        end
    end

    local offRules = {}
    if ir.lists and ir.lists.off then
        for i, rule in ipairs(ir.lists.off) do
            offRules[i] = CompileRule(rule)
        end
    end

    -- 4. Sequences (Opener, etc.)
    local seq = ir.sequences and ir.sequences.opener
    local seqEnabled = seq and seq.enabled
    local seqSteps = (seq and seq.steps) or {}
    local seqTimeout = (seq and seq.timeout) or 10
    local seqIndex = 1
    local seqStartTime = 0

    local function ResetSequences()
        seqIndex = 1
        seqStartTime = 0
    end

    local function DisableSequences()
        seqEnabled = false
    end

    local function EnableSequences(force)
        if force ~= nil then
            seqEnabled = force
        else
            seqEnabled = true
        end
    end

    local function GetSequenceAction(state)
        if not seqEnabled or seqIndex > #seqSteps then
            return nil
        end
        if seqStartTime == 0 then
            seqStartTime = state.now
        elseif (state.now - seqStartTime) > seqTimeout then
            seqIndex = #seqSteps + 1
            return nil
        end

        while seqIndex <= #seqSteps do
            local stepAction = seqSteps[seqIndex]
            -- If Burst mode is disabled, skip long burst cooldowns in opener sequence
            -- Blood Tap (BT) is specifically NOT skipped. Also skip unlearned abilities.
            if (state.burstMode == false and BURST_SPELL_ALIASES[stepAction] and stepAction ~= "BT")
                or not IsActionKnown(state, stepAction) then
                seqIndex = seqIndex + 1
            else
                return stepAction
            end
        end

        return nil
    end

    -- 5. Evaluator closures: Zero table allocation in hot path!
    local function EvaluatorMain(state)
        -- Opener Sequence check
        local seqAction = GetSequenceAction(state)
        if seqAction then
            return seqAction
        end

        -- Main Priority List
        for i = 1, #mainRules do
            local r = mainRules[i]
            if r.enabled then
                local burstOk = (not r.isBurst) or (state.burstMode ~= false)
                if state.burstMode == false and BURST_SPELL_ALIASES[r.action] and r.action ~= "BT" then
                    burstOk = false
                end
                local aoeOk = true
                if r.isAoE == true then
                    aoeOk = (state.aoeMode == true or state.isAoE == true)
                elseif r.isAoE == false then
                    aoeOk = not (state.aoeMode or state.isAoE)
                end

                if burstOk and aoeOk then
                    -- La descripcion de la regla que dispara es el motivo del modo aprendizaje (si la regla no puso uno)
                    if r.type == "customLua" then
                        local act = r.evalFn(state)
                        if act == false then return nil end -- "return false" en la regla corta la lista
                        if act and IsActionKnown(state, act) then
                            if not state.reason then state.reason = r.note end
                            return act
                        end
                    else
                        if IsActionKnown(state, r.action) and r.evalCond(state) then
                            if not state.reason then state.reason = r.note end
                            return r.action
                        end
                    end
                end
            end
        end

        return nil
    end

    local function EvaluatorOff(state)
        -- Off-GCD Priority List
        for i = 1, #offRules do
            local r = offRules[i]
            if r.enabled then
                local burstOk = (not r.isBurst) or (state.burstMode ~= false)
                if state.burstMode == false and BURST_SPELL_ALIASES[r.action] and r.action ~= "BT" then
                    burstOk = false
                end
                local aoeOk = true
                if r.isAoE == true then
                    aoeOk = (state.aoeMode == true or state.isAoE == true)
                elseif r.isAoE == false then
                    aoeOk = not (state.aoeMode or state.isAoE)
                end

                if burstOk and aoeOk then
                    if r.type == "customLua" then
                        local act = r.evalFn(state)
                        if act == false then return nil end -- "return false" en la regla corta la lista
                        if act and IsActionKnown(state, act) then
                            return act
                        end
                    else
                        if IsActionKnown(state, r.action) and r.evalCond(state) then
                            return r.action
                        end
                    end
                end
            end
        end

        return nil
    end

    return {
        evaluatorMain = EvaluatorMain,
        evaluatorOff = EvaluatorOff,
        resetSequences = ResetSequences,
        disableSequences = DisableSequences,
        enableSequences = EnableSequences,
        mainRules = mainRules,
        offRules = offRules,
        ir = ir,
    }
end

return Compiler
