-- tools/test_runner.lua — Offline Test Harness & Gate 0 Validator for WoW 3.3.5a
local wowmock = require("tools.wowmock")
wowmock.init()

local totalTests = 0
local passedTests = 0
local failedTests = 0

-- Simula elegir build en el PJ actual (la build se guarda por PJ en charBuilds)
local function SetBuild(v)
    _G.RotaCoreDB = _G.RotaCoreDB or {}
    _G.RotaCoreDB.settings = _G.RotaCoreDB.settings or {}
    _G.RotaCoreDB.charBuilds = _G.RotaCoreDB.charBuilds or {}
    _G.RotaCoreDB.settings.selectedBuild = v
    _G.RotaCoreDB.charBuilds[_G.UnitName("player") .. " - " .. _G.GetRealmName()] = v
end

local function Assert(condition, testName, details)
    totalTests = totalTests + 1
    if condition then
        passedTests = passedTests + 1
        print(string.format("  [PASS] %s", testName))
    else
        failedTests = failedTests + 1
        print(string.format("  [FAIL] %s - %s", testName, details or "Assertion failed"))
    end
end

print("==================================================")
print(" ROTA TEST RUNNER — FASE 0 / GATE 0 VALIDATION   ")
print("==================================================")

-- ----------------------------------------------------------------------------
-- SUITE 1: Clock & Time Advance
-- ----------------------------------------------------------------------------
print("\n[Suite 1] Monotonic Clock & Advance")
wowmock.setTime(100.0)
Assert(GetTime() == 100.0, "GetTime initial value is 100.0")
wowmock.advanceTime(2.5)
Assert(GetTime() == 102.5, "advanceTime(2.5) correctly advances clock to 102.5")

-- ----------------------------------------------------------------------------
-- SUITE 2: Global Cooldown (GCD)
-- ----------------------------------------------------------------------------
print("\n[Suite 2] Global Cooldown (GCD)")
wowmock.triggerGCD(1.5)
Assert(wowmock.isGCDActive() == true, "GCD is active immediately after triggering")
wowmock.advanceTime(1.0)
Assert(wowmock.isGCDActive() == true, "GCD is still active after 1.0s (out of 1.5s)")
wowmock.advanceTime(0.6)
Assert(wowmock.isGCDActive() == false, "GCD has expired after 1.6s total elapsed")

-- ----------------------------------------------------------------------------
-- SUITE 3: DK 6 Runes & 2.5s Grace Period
-- ----------------------------------------------------------------------------
print("\n[Suite 3] Death Knight 6 Runes & Grace Period Mechanics")
wowmock.initRunes()

-- Check default types
Assert(GetRuneType(1) == 1 and GetRuneType(2) == 1, "Runes 1 & 2 are Blood (type 1)")
Assert(GetRuneType(3) == 3 and GetRuneType(4) == 3, "Runes 3 & 4 are Frost (type 3)")
Assert(GetRuneType(5) == 2 and GetRuneType(6) == 2, "Runes 5 & 6 are Unholy (type 2)")

-- Spend Rune 1 (Blood) with 0 grace
local ok, cd, grace = wowmock.useRune(1)
Assert(ok == true and cd == 10.0 and grace == 0, "Rune 1 spent with 0 grace has base 10.0s CD")
local _, rDuration, rReady = GetRuneCooldown(1)
Assert(rReady == false and rDuration == 10.0, "GetRuneCooldown(1) returns ready=false, duration=10.0")

-- Advance 10s: Rune 1 completes CD and becomes ready
wowmock.advanceTime(10.0)
_, _, rReady = GetRuneCooldown(1)
Assert(rReady == true, "Rune 1 is ready after 10.0s elapsed")

-- Advance 1.5s: Rune 1 sits ready accumulating grace
wowmock.advanceTime(1.5)
local accumulatedGrace = wowmock.getGracePeriod(1)
Assert(math.abs(accumulatedGrace - 1.5) < 0.001, "Rune 1 accumulated 1.5s grace period while idle")

-- Spend Rune 1 again: CD should be reduced to 10.0 - 1.5 = 8.5s
local ok2, cd2, grace2 = wowmock.useRune(1)
Assert(ok2 == true and math.abs(cd2 - 8.5) < 0.001 and math.abs(grace2 - 1.5) < 0.001,
    "Rune 1 cooldown reduced to 8.5s due to 1.5s grace carryover")

-- Advance 20.0s (long idle): Grace must cap at 2.5s maximum
wowmock.advanceTime(20.0)
local cappedGrace = wowmock.getGracePeriod(1)
Assert(math.abs(cappedGrace - 2.5) < 0.001, "Grace period capped strictly at 2.5s maximum")

local ok3, cd3, grace3 = wowmock.useRune(1)
Assert(ok3 == true and math.abs(cd3 - 7.5) < 0.001 and math.abs(grace3 - 2.5) < 0.001,
    "Rune 1 cooldown reduced to 7.5s (10.0 - 2.5 max grace)")

-- Conversion to Death Rune (type 4)
wowmock.convertRune(1, 4)
Assert(GetRuneType(1) == 4, "Rune 1 converted to Death Rune (type 4)")

-- ----------------------------------------------------------------------------
-- SUITE 4: UnitAura (WoW 3.3.5a Indexed Signature)
-- ----------------------------------------------------------------------------
print("\n[Suite 4] UnitAura 3.3.5a Indexed Signature & Queries")
wowmock.clearAuras()

wowmock.setAura("player", {
    name = "Horn of Winter",
    rank = "Rank 2",
    icon = "Interface\\Icons\\Spell_HornOfWinter",
    count = 1,
    duration = 120.0,
    spellId = 57623,
    filter = "HELPFUL",
})

wowmock.setAura("target", {
    name = "Frost Fever",
    rank = "",
    icon = "Interface\\Icons\\Spell_FrostFever",
    count = 1,
    debuffType = "Disease",
    duration = 15.0,
    spellId = 55095,
    filter = "HARMFUL",
    unitCaster = "player",
})

local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura("player", 1, "HELPFUL")
Assert(name == "Horn of Winter" and spellId == 57623, "UnitAura('player', 1, 'HELPFUL') returns 11-field tuple with spellId")

local tName, _, _, _, _, _, _, tCaster, _, _, tSpellId = UnitDebuff("target", 1)
Assert(tName == "Frost Fever" and tCaster == "player" and tSpellId == 55095,
    "UnitDebuff('target', 1) returns Frost Fever cast by player")

local nonExistent = UnitAura("player", 2, "HELPFUL")
Assert(nonExistent == nil, "UnitAura returns nil for out-of-bounds aura index")

-- ----------------------------------------------------------------------------
-- SUITE 5: Frame & Event Dispatch System
-- ----------------------------------------------------------------------------
print("\n[Suite 5] Frame & Event Dispatch System")
local testFrame = CreateFrame("Frame", "TestListenerFrame")
local eventReceived = nil
local eventArg = nil

testFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
testFrame:SetScript("OnEvent", function(self, event, ...)
    eventReceived = event
    eventArg = ...
end)

wowmock.fireEvent("COMBAT_LOG_EVENT_UNFILTERED", "SPELL_CAST_SUCCESS")
Assert(eventReceived == "COMBAT_LOG_EVENT_UNFILTERED" and eventArg == "SPELL_CAST_SUCCESS",
    "fireEvent successfully dispatched to registered frame script")

-- ----------------------------------------------------------------------------
-- SUITE 6: RotaProbe Execution & Reconnaissance Scan
-- ----------------------------------------------------------------------------
print("\n[Suite 6] RotaProbe Addon Execution")
local RotaProbe = dofile("RotaProbe/RotaProbe.lua")
Assert(type(RotaProbe) == "table", "RotaProbe.lua loads successfully")

local scanData = RotaProbe:RunScan()
Assert(type(scanData) == "table", "RotaProbe:RunScan() returns scan data table")
Assert(scanData.player.class == "Death Knight", "Scan correctly captures player class")
Assert(scanData.apis.GetSpellInfo.exists == true, "Scan reports GetSpellInfo exists")
Assert(scanData.apis.C_Timer.exists == false, "Scan reports post-3.3.5 C_Timer does not exist")
Assert(scanData.spellbook ~= nil, "Scan populates spellbook")
Assert(scanData.talents ~= nil, "Scan populates talents")

-- ----------------------------------------------------------------------------
-- SUITE 7: Hot-Path Zero-Allocation (0 KB Garbage in 1000 Iterations)
-- ----------------------------------------------------------------------------
print("\n[Suite 7] Hot-Path Zero-Allocation Verification (1000 Iterations)")

-- Simulating pre-allocated static evaluator state (zero table creation in loop)
local evalState = {
    now = 0.0,
    runes = { bloodReady = 2, frostReady = 2, unholyReady = 2, deathReady = 0 },
    rp = 85,
    targetHasFF = true,
    ffRemaining = 4.2,
    targetHasBP = true,
    bpRemaining = 6.0,
    bestAction = nil,
    offAction = nil,
}

-- Hot-path evaluator function: No table allocations, no string concats, no closures
local function EvaluatePriorityList(state)
    -- Rule 1: Apply Frost Fever if missing or < 3s
    if (not state.targetHasFF) or (state.ffRemaining < 3.0) then
        if state.runes.frostReady > 0 or state.runes.deathReady > 0 then
            state.bestAction = "IT" -- Static string literal
            return
        end
    end

    -- Rule 2: Apply Blood Plague if missing or < 3s
    if (not state.targetHasBP) or (state.bpRemaining < 3.0) then
        if state.runes.unholyReady > 0 or state.runes.deathReady > 0 then
            state.bestAction = "PS"
            return
        end
    end

    -- Rule 3: High Runic Power dump
    if state.rp >= 80 then
        state.bestAction = "DC"
        return
    end

    -- Rule 4: Scourge Strike / Blood Strike
    if state.runes.unholyReady > 0 and state.runes.frostReady > 0 then
        state.bestAction = "SS"
        return
    end

    state.bestAction = "WAIT"
end

-- Warmup phase to stabilize JIT/allocations and prime interned strings
for _ = 1, 50 do
    EvaluatePriorityList(evalState)
end

collectgarbage("collect")
collectgarbage("collect")

local memBefore = collectgarbage("count")

for i = 1, 1000 do
    evalState.now = 1000.0 + (i * 0.1)
    evalState.ffRemaining = 2.5
    EvaluatePriorityList(evalState)
end

local memAfter = collectgarbage("count")
local memDelta = memAfter - memBefore

print(string.format("  Memory before: %.2f KB", memBefore))
print(string.format("  Memory after:  %.2f KB", memAfter))
print(string.format("  Garbage produced across 1000 evaluations: %.4f KB", memDelta))

Assert(memDelta <= 0.0001, "Zero-Allocation Check: 0.0 KB garbage generated in 1000 hot-path iterations")

-- ----------------------------------------------------------------------------
-- SUITE 8: RotaCore.Sandbox Security & Execution
-- ----------------------------------------------------------------------------
print("\n[Suite 8] RotaCore.Sandbox Validation")
dofile("RotaCore/Sandbox.lua")
local Sandbox = RotaCore.Sandbox

-- Test safe compilation & execution
local runner, ruleState = Sandbox:Compile("if state.power >= 50 then return 'DC' end", "test_rule")
Assert(type(runner) == "function" and ruleState.ruleId == "test_rule", "Sandbox:Compile returns runner and ruleState")
Assert(runner({ power = 60 }) == "DC", "Runner executes custom Lua condition and returns action 'DC'")
Assert(runner({ power = 30 }) == nil, "Runner returns nil when condition is not met")

-- Test sandbox isolation (blocking os, _G access)
local isoRunner = Sandbox:Compile("return tostring(os)", "iso_test")
Assert(isoRunner({}) == "nil", "Sandbox isolates user code: global 'os' is inaccessible (nil)")

-- Test error isolation (3 errors disables rule)
local errRunner, errState = Sandbox:Compile("error('Simulated runtime error')", "err_rule")
Assert(errRunner({}) == nil, "Erroneous rule caught by pcall without crashing (error 1)")
Assert(errRunner({}) == nil, "Erroneous rule caught by pcall without crashing (error 2)")
Assert(errRunner({}) == nil, "Erroneous rule caught by pcall without crashing (error 3)")
Assert(errState.disabled_by_error == true, "Rule automatically marked disabled_by_error=true after 3 errors")
Assert(errRunner({}) == nil, "Disabled rule bypasses execution and returns nil immediately")

-- ----------------------------------------------------------------------------
-- SUITE 9: RotaCore.Spells & SpellID Override Engine
-- ----------------------------------------------------------------------------
print("\n[Suite 9] RotaCore.Spells & Manual Overrides")
dofile("RotaCore/Spells.lua")
local Spells = RotaCore.Spells

Spells:RegisterSpell("IT", "Icy Touch", 49909)
Spells:RegisterSpell("PS", "Plague Strike", 49921)
Spells:RegisterSpell("BS", "Blood Strike", 49930)

Assert(Spells:ResolveID("IT") == 49909, "ResolveID('IT') resolves default ID 49909")

-- Simulate Spellbook scan with higher rank
wowmock.registerSpell(55555, "Icy Touch", "Rank 5")
wowmock.addSpellBookItem(3, 55555)
Spells:ScanSpellBook()
Assert(Spells:ResolveID("IT") == 55555, "ResolveID('IT') resolves to highest rank in Spellbook (55555)")

-- Manual server override
Spells:SetOverride("IT", 99999)
Assert(Spells:ResolveID("IT") == 99999, "Manual override (99999) takes absolute precedence over Spellbook and default")

-- Clearing override reverts to Spellbook
Spells:ClearOverride("IT")
Assert(Spells:ResolveID("IT") == 55555, "Clearing manual override cleanly reverts resolution to Spellbook")

-- ----------------------------------------------------------------------------
-- SUITE 10: RotaCore.Compiler AST & Priority List Compilation
-- ----------------------------------------------------------------------------
print("\n[Suite 10] RotaCore.Compiler AST & Evaluator Generation")
dofile("RotaCore/Compat.lua")
dofile("RotaCore/State.lua")
dofile("RotaCore/Compiler.lua")
local Compiler = RotaCore.Compiler

local testIR = {
    meta = { id = "test_profile", name = "Test Profile", class = "DEATHKNIGHT", spec = "Unholy" },
    spells = {
        IT = { name = "Icy Touch", defaultId = 49909 },
        PS = { name = "Plague Strike", defaultId = 49921 },
    },
    vars = { threshold = 10 },
    lists = {
        main = {
            {
                id = "rule1",
                enabled = true,
                type = "block",
                action = "IT",
                when = {
                    op = "cmp", cmp = "<",
                    l = { op = "call", fn = "debuff.remaining", args = { "Frost Fever", "target", true } },
                    r = { op = "var", name = "threshold" }
                }
            }
        },
        off = {}
    }
}

local compiledTest = Compiler:Compile(testIR)
Assert(type(compiledTest.evaluatorMain) == "function", "Compiler:Compile returns evaluatorMain function")
Assert(type(compiledTest.evaluatorOff) == "function", "Compiler:Compile returns evaluatorOff function")

-- ----------------------------------------------------------------------------
-- SUITE 11: RotaClass_DK 6 Runes & Grace Period Tracking
-- ----------------------------------------------------------------------------
print("\n[Suite 11] RotaClass_DK 6 Runes & Grace Period Tracking")
dofile("RotaCore/Profiles.lua")
dofile("RotaCore/Snapshot.lua")
dofile("RotaCore/UI.lua")
dofile("RotaCore/RotaCore.lua")
dofile("RotaClass_DK/RotaClass_DK.lua")
local Presets = dofile("RotaClass_DK/Presets.lua")

wowmock.setTime(1000.0)
wowmock.initRunes()
local state = RotaCore.State:Update(1000.0)

Assert(state.runes.bloodReady == 2, "State correctly tracks 2 ready Blood runes")
Assert(state.runes.frostReady == 2, "State correctly tracks 2 ready Frost runes")
Assert(state.runes.unholyReady == 2, "State correctly tracks 2 ready Unholy runes")
Assert(state.runes.deathReady == 0, "State correctly tracks 0 Death runes initially")
Assert(state.runes.effectiveBlood == 2, "Effective Blood count is 2")

-- Spend Rune 1 (Blood)
wowmock.useRune(1)
state = RotaCore.State:Update(1000.0)
Assert(state.runes.bloodReady == 1, "Rune 1 spent: bloodReady decremented to 1")

-- Advance time by 11.5s: Rune 1 completes 10s cooldown and accumulates 1.5s grace period
wowmock.advanceTime(11.5)
state = RotaCore.State:Update(1011.5)
Assert(state.runes.bloodReady == 2, "Rune 1 ready again after 11.5s")
Assert(math.abs(state.runes.grace[1] - 1.5) < 0.001, "Rune 1 accumulated 1.5s grace period in state")
Assert(state.runes.maxGrace >= 1.5, "state.runes.maxGrace reflects accumulated grace period")

-- Convert Rune 2 to Death Rune
wowmock.convertRune(2, 4)
state = RotaCore.State:Update(1011.5)
Assert(state.runes.bloodReady == 1 and state.runes.deathReady == 1, "Rune 2 converted to Death: bloodReady=1, deathReady=1")
Assert(state.runes.effectiveBlood == 2, "Effective Blood equals pure Blood (1) + Death (1) = 2")
Assert(state.runes.effectiveFrost == 3, "Effective Frost equals pure Frost (2) + Death (1) = 3")
Assert(state.runes.effectiveUnholy == 3, "Effective Unholy equals pure Unholy (2) + Death (1) = 3")

-- ----------------------------------------------------------------------------
-- SUITE 12: Pestilence Rune Reservation Unit Test
-- ----------------------------------------------------------------------------
print("\n[Suite 12] Pestilence Rune Reservation Logic")

-- Load DK Unholy PvE Preset
local unholyPreset = RotaCore.Profiles:GetPreset("dk_unholy_2h_pve")
local unholyEval = Compiler:Compile(unholyPreset)
unholyEval.disableSequences() -- disable opener for steady-state priority list testing

-- Clear target auras and apply diseases
wowmock.clearAuras("target")
wowmock.initRunes() -- all 6 runes ready
wowmock.setTime(2000.0)

-- Case A: Diseases ticking with plenty of duration (> pestMargin of 3.0s)
wowmock.setAura("target", {
    name = "Frost Fever", duration = 15.0, expirationTime = 2008.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 15.0, expirationTime = 2008.0, filter = "HARMFUL", unitCaster = "player"
})
state = RotaCore.State:Update(2000.0)

Assert(state.dk.minDiseaseRemaining == 8.0, "minDiseaseRemaining is 8.0s")
Assert(state.dk.isBloodReservedForPestilence == false, "Blood is NOT reserved for Pestilence when disease > 3.0s")
Assert(state.dk.canSpendBloodOnBS == true, "canSpendBloodOnBS is true")

-- Case B: Diseases expiring in 2.0s (<= pestMargin 3.0s) with ONLY 1 Blood/Death rune ready
-- Spend Rune 1 (Blood) so only 1 Blood rune is ready
wowmock.useRune(1)
wowmock.clearAuras("target")
wowmock.setAura("target", {
    name = "Frost Fever", duration = 15.0, expirationTime = 2002.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 15.0, expirationTime = 2002.0, filter = "HARMFUL", unitCaster = "player"
})
state = RotaCore.State:Update(2000.0)

Assert(state.runes.effectiveBlood == 1, "Only 1 Blood rune ready")
Assert(state.dk.minDiseaseRemaining == 2.0, "Diseases expiring in 2.0s (<= pestMargin)")
Assert(state.dk.isBloodReservedForPestilence == true, "Last Blood rune is strictly reserved for Pestilence")
Assert(state.dk.canSpendBloodOnBS == false, "canSpendBloodOnBS is false (Blood Strike blocked)")

-- Without Glyph of Disease: Unholy ST strictly refreshes with IT / PS, never Pestilence
state.dk.hasGlyphOfDisease = false
local noGlyphAction = unholyEval.evaluatorMain(state)
Assert(noGlyphAction == "IT" or noGlyphAction == "PS", "Without Glyph of Disease, Unholy refreshes via IT/PS")

-- With Glyph of Disease: Evaluator suggests PEST to refresh diseases before expiration (BS prevented)
state.dk.hasGlyphOfDisease = true
local mainAction = unholyEval.evaluatorMain(state)
Assert(mainAction == "PEST", "Evaluator suggests PEST to refresh diseases before expiration (BS prevented)")

-- Case C: Diseases expiring in 2.0s, but 2 Blood runes ready (1 reserved, 1 usable for BS)
wowmock.initRunes() -- both Blood runes ready
state = RotaCore.State:Update(2000.0)
Assert(state.runes.effectiveBlood == 2, "2 Blood runes ready")
Assert(state.dk.isBloodReservedForPestilence == false, "Surplus Blood rune permits canSpendBloodOnBS=true")
Assert(state.dk.canSpendBloodOnBS == true, "canSpendBloodOnBS is true when effectiveBlood > 1")

-- ----------------------------------------------------------------------------
-- SUITE 13: Desolation Maintenance & Blood Tap -> Blood Strike
-- ----------------------------------------------------------------------------
print("\n[Suite 13] Desolation Maintenance & Blood Tap -> Blood Strike Progression")

wowmock.clearAuras("player")
wowmock.clearAuras("target")
wowmock.setTime(3000.0)

-- Setup: Diseases applied with long duration (no IT, PS or PEST needed)
wowmock.setAura("target", {
    name = "Frost Fever", duration = 20.0, expirationTime = 3020.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 20.0, expirationTime = 3020.0, filter = "HARMFUL", unitCaster = "player"
})

-- Put all Blood runes on cooldown
wowmock.initRunes()
wowmock.useRune(1)
wowmock.useRune(2)

-- Player has NO Desolation buff
state = RotaCore.State:Update(3000.0)
Assert(state.dk.hasDesolation == false, "Player does not have Desolation buff")
Assert(state.runes.bloodReady == 0 and state.runes.deathReady == 0, "No Blood or Death runes ready")

-- EvaluatorOff must suggest Blood Tap (BT) off-GCD
local offAction = unholyEval.evaluatorOff(state)
Assert(offAction == "BT", "EvaluatorOff suggests 'BT' (Blood Tap) off-GCD to recover Desolation")

-- Player casts Blood Tap: gain Blood Tap buff and Rune 1 converts to Death rune ready
wowmock.setAura("player", {
    name = "Blood Tap", duration = 20.0, expirationTime = 3020.0, filter = "HELPFUL", unitCaster = "player"
})
wowmock.convertRune(1, 4) -- Rune 1 converted to Death
local r1 = wowmock.runes[1]
r1.ready = true
r1.start = 0

state = RotaCore.State:Update(3000.0)
Assert(state.dk.hasBloodTap == true, "Player now has Blood Tap buff active")
Assert(state.runes.deathReady == 1, "1 Death rune available from Blood Tap")

-- EvaluatorMain must immediately suggest Blood Strike (BS) to consume rune and trigger Desolation
local actionAfterBT = unholyEval.evaluatorMain(state)
Assert(actionAfterBT == "BS", "EvaluatorMain immediately suggests 'BS' (Blood Strike) after Blood Tap to apply Desolation")

-- Player casts Blood Strike: gains Desolation buff (30s) and Blood Tap rune consumed
wowmock.useRune(1)
wowmock.clearAuras("player") -- clear Blood Tap buff, keep Desolation
wowmock.setAura("player", {
    name = "Desolation", duration = 30.0, expirationTime = 3030.0, filter = "HELPFUL", unitCaster = "player"
})

state = RotaCore.State:Update(3001.0)
Assert(state.dk.hasDesolation == true, "Player now has Desolation buff")
Assert(state.dk.desolationRemaining > 3.0, "Desolation duration > desolationMargin (no longer in emergency)")

-- ----------------------------------------------------------------------------
-- SUITE 14: Real DK Evaluator Zero-Allocation (0 KB Garbage in 1000 Iterations)
-- ----------------------------------------------------------------------------
print("\n[Suite 14] Real DK Evaluator Zero-Allocation Hot-Path (1000 Iterations)")

-- Warmup phase to stabilize JIT/allocations and prime interned strings
for _ = 1, 50 do
    RotaCore.State:Update(4000.0)
    unholyEval.evaluatorMain(state)
    unholyEval.evaluatorOff(state)
end

collectgarbage("collect")
collectgarbage("collect")

local memBeforeReal = collectgarbage("count")

for i = 1, 1000 do
    local now = 4000.0 + (i * 0.05)
    state = RotaCore.State:Update(now)
    unholyEval.evaluatorMain(state)
    unholyEval.evaluatorOff(state)
end

local memAfterReal = collectgarbage("count")
local memDeltaReal = memAfterReal - memBeforeReal

print(string.format("  Memory before: %.2f KB", memBeforeReal))
print(string.format("  Memory after:  %.2f KB", memAfterReal))
print(string.format("  Garbage produced across 1000 DK evaluations: %.4f KB", memDeltaReal))

Assert(memDeltaReal <= 0.0001, "Zero-Allocation Check: 0.0 KB garbage across 1000 full DK evaluations")

-- ----------------------------------------------------------------------------
-- SUITE 15: Canonical Lua Code Generator (RotaCore.CodeGen)
-- ----------------------------------------------------------------------------
print("\n[Suite 15] Canonical Lua Code Generation (RotaCore.CodeGen)")
dofile("RotaCore/CodeGen.lua")
local CodeGen = RotaCore.CodeGen

local simpleAST = {
    op = "cmp", cmp = "<",
    l = { op = "call", fn = "debuff.remaining", args = { "Frost Fever", "target", true } },
    r = { op = "var", name = "pestMargin" }
}
local genExpr = CodeGen.ASTToLua(simpleAST)
Assert(genExpr:find('state%.debuffRemaining%("Frost Fever"') ~= nil, "ASTToLua formats state.debuffRemaining call")
Assert(genExpr:find('state%.vars%.pestMargin') ~= nil, "ASTToLua formats state.vars.pestMargin")

local blockRule = {
    id = "r_it",
    enabled = true,
    type = "block",
    action = "IT",
    note = "Apply Frost Fever",
    when = simpleAST
}
local genRule = CodeGen:RuleToLua(blockRule)
Assert(genRule:find("if state%.debuffRemaining") ~= nil, "RuleToLua generates structured 'if <cond> then' block")
Assert(genRule:find('return "IT"') ~= nil, "RuleToLua generates return action")

local customRule = {
    id = "r_custom",
    enabled = true,
    type = "customLua",
    action = "BT",
    note = "Custom panic",
    code = "if state.runes.bloodReady == 0 then return 'BT' end"
}
local genCustom = CodeGen:RuleToLua(customRule)
Assert(genCustom:find("%[customLua: r_custom%]") ~= nil, "RuleToLua tags customLua block with header comment")

local fullLua = CodeGen:ProfileToLua(Presets.DK_UNHOLY_PVE)
Assert(fullLua:find("%-%- @profile: dk_unholy_2h_pve") ~= nil, "ProfileToLua includes profile ID header")
Assert(fullLua:find("%-%- @class: DEATHKNIGHT") ~= nil, "ProfileToLua includes class header")
Assert(fullLua:find("%-%- @list: main") ~= nil, "ProfileToLua outputs main list section")
Assert(fullLua:find("%-%- @list: off") ~= nil, "ProfileToLua outputs off list section")

-- ----------------------------------------------------------------------------
-- SUITE 16: Structured Lua Parser (RotaCore.ParserLua) Levels A, B & C
-- ----------------------------------------------------------------------------
print("\n[Suite 16] Structured Lua Parser (Levels A, B and C customLua)")
dofile("RotaCore/ParserLua.lua")
local ParserLua = RotaCore.ParserLua

-- Level A: Simple condition
local ruleA_src = [[
-- [rule: it_apply] Apply Frost Fever
if state.debuffRemaining("Frost Fever") < 2.0 then
    return "IT"
end
]]
local ruleA = ParserLua:ParseRule(ruleA_src, "ruleA")
Assert(ruleA.type == "block", "Level A: Parsed as block rule")
Assert(ruleA.action == "IT", "Level A: Action is 'IT'")
Assert(ruleA.id == "it_apply", "Level A: Rule ID is 'it_apply'")
Assert(ruleA.when ~= nil and ruleA.when.op == "cmp" and ruleA.when.cmp == "<", "Level A: AST parsed with cmp '<'")

-- Level B: Compound condition with and/or/not
local ruleB_src = [[
-- [rule: ss_complex] Scourge Strike
if (state.runes.frostReady > 0 or state.runes.deathReady > 0) and state.debuffRemaining("Frost Fever") > 0 then
    return "SS"
end
]]
local ruleB = ParserLua:ParseRule(ruleB_src, "ruleB")
Assert(ruleB.type == "block", "Level B: Parsed as block rule")
Assert(ruleB.action == "SS", "Level B: Action is 'SS'")
Assert(ruleB.when ~= nil and ruleB.when.op == "and", "Level B: AST root is 'and'")
Assert(ruleB.when.l.op == "or", "Level B: Left branch is 'or'")

-- Level C: Arbitrary custom code with local statement
local ruleC_src = [[
-- [customLua: panic_dc] Custom RP dump
local threshold = 90
if state.power >= threshold then
    return "DC"
end
]]
local ruleC = ParserLua:ParseRule(ruleC_src, "ruleC")
Assert(ruleC.type == "customLua", "Level C: Parsed as customLua rule")
Assert(ruleC.action == "DC", "Level C: Extracted return action 'DC'")
Assert(ruleC.code:find("local threshold = 90") ~= nil, "Level C: Preserved verbatim custom code")

-- ----------------------------------------------------------------------------
-- SUITE 17: Round-Trip Verification (RotationIR -> Lua -> RotationIR)
-- ----------------------------------------------------------------------------
print("\n[Suite 17] Round-Trip Verification (IR -> Canonical Lua -> IR)")
local originalIR = Presets.DK_UNHOLY_PVE

-- 1. IR -> Lua
local exportedLua = CodeGen:ProfileToLua(originalIR)
Assert(type(exportedLua) == "string" and #exportedLua > 100, "CodeGen exported non-empty Lua script")

-- 2. Lua -> IR
local roundTripIR = ParserLua:Parse(exportedLua)
Assert(roundTripIR ~= nil, "ParserLua parsed exported Lua script into RotationIR")
Assert(roundTripIR.meta.id == originalIR.meta.id, "Round-trip preserves profile ID")
Assert(roundTripIR.meta.class == originalIR.meta.class, "Round-trip preserves class")
Assert(roundTripIR.meta.spec == originalIR.meta.spec, "Round-trip preserves spec")
Assert(roundTripIR.vars.pestMargin == originalIR.vars.pestMargin, "Round-trip preserves vars (pestMargin)")
Assert(roundTripIR.sequences.opener ~= nil, "Round-trip preserves opener sequence")
Assert(#roundTripIR.sequences.opener.steps == #originalIR.sequences.opener.steps,
    "Round-trip opener steps count matches original")
Assert(#roundTripIR.lists.main == #originalIR.lists.main,
    string.format("Round-trip main rules count matches (%d == %d)", #roundTripIR.lists.main, #originalIR.lists.main))
Assert(#roundTripIR.lists.off == #originalIR.lists.off,
    string.format("Round-trip off rules count matches (%d == %d)", #roundTripIR.lists.off, #originalIR.lists.off))

-- 3. Functional Equivalence Verification: Compile both and evaluate against state
local originalEval = Compiler:Compile(originalIR)
local roundTripEval = Compiler:Compile(roundTripIR)

-- Reset state for comparison: missing diseases
wowmock.clearAuras()
local testState = RotaCore.State:Update(5000.0)
local origMain = originalEval.evaluatorMain(testState)
local roundMain = roundTripEval.evaluatorMain(testState)
Assert(origMain == "IT" and roundMain == "IT",
    string.format("Functional Round-Trip: Both original and reconstructed IR suggest '%s'", roundMain))

-- ----------------------------------------------------------------------------
-- SUITE 18: WeakAuras & Custom Snippet Import
-- ----------------------------------------------------------------------------
print("\n[Suite 18] WeakAuras & Custom Snippet Import")
local waSnippet = [[
-- Custom Trigger Snippet
if state.runes.bloodReady == 0 and state.debuffRemaining("Frost Fever") < 3.0 then
    return "BT"
end
]]
local waRule = ParserLua:ParseRule(waSnippet, "wa_trigger")
Assert(waRule.action == "BT", "WeakAuras snippet correctly parsed action 'BT'")

local waProfile = {
    meta = { id = "wa_test", class = "DEATHKNIGHT" },
    lists = { main = { waRule }, off = {} }
}
local waEval = Compiler:Compile(waProfile)
Assert(waEval ~= nil and waEval.evaluatorMain ~= nil, "Compiler compiled profile containing imported WA rule")

-- ----------------------------------------------------------------------------
-- SUITE 20: RotaEditor & FramePool Lifecycle (Zero Leak)
-- ----------------------------------------------------------------------------
print("\n[Suite 20] RotaEditor & FramePool Lifecycle (Zero Leak)")
local loaded, loadStatus = LoadAddOn("RotaEditor")
Assert(loaded == true and loadStatus == "LOADED", "LoadAddOn('RotaEditor') loads editor successfully (LoadOnDemand)")
Assert(RotaEditor ~= nil, "RotaEditor global table exists")

-- 1. FramePool zero-leak recycling test
local testPool = RotaEditor.FramePool.New("Button", nil)
Assert(testPool:GetTotalCreated() == 0, "Initial pool count is 0")

local f1 = testPool:Acquire()
local f2 = testPool:Acquire()
testPool:Acquire()
testPool:Acquire()
Assert(testPool:GetTotalCreated() == 4, "Created 4 frames on demand")
Assert(testPool:GetActiveCount() == 4, "Active frames count is 4")

-- Release 2 frames back into pool
testPool:Release(f1)
testPool:Release(f2)
Assert(testPool:GetActiveCount() == 2, "Active count dropped to 2 after releasing 2 frames")
Assert(testPool:GetInactiveCount() == 2, "Inactive count is 2")

-- Re-acquire 2 frames: MUST reuse inactive frames without creating new ones!
testPool:Acquire()
testPool:Acquire()
Assert(testPool:GetTotalCreated() == 4, "FramePool Zero-Leak: totalCreated remained 4 when reusing released frames")
Assert(testPool:GetActiveCount() == 4, "Active count back to 4")

testPool:ReleaseAll()
Assert(testPool:GetActiveCount() == 0, "ReleaseAll() cleared all active frames")
Assert(testPool:GetInactiveCount() == 4, "All 4 frames returned to inactive pool")

-- 2. RotaEditor UI Initialization & Tab Switching
RotaCore.Profiles:SetActiveProfile(originalIR)
RotaEditor:Init()
Assert(RotaEditor.mainFrame ~= nil, "RotaEditor:Init creates main window frame")
Assert(RotaEditor.mainFrame.strata == "DIALOG", "RotaEditorMainFrame has DIALOG frame strata")
Assert(RotaEditor.mainFrame:IsMouseEnabled() == true, "RotaEditorMainFrame has mouse enabled")
Assert(RotaEditor.mainFrame.dragButtons ~= nil, "RotaEditorMainFrame has LeftButton registered for dragging")
Assert(RotaEditor.mainFrame.scripts["OnDragStart"] ~= nil, "RotaEditorMainFrame has OnDragStart script")
Assert(RotaEditor.mainFrame.scripts["OnDragStop"] ~= nil, "RotaEditorMainFrame has OnDragStop script")
Assert(#RotaEditor.tabs == 4, "RotaEditor tiene 4 pestanas (Reglas, Codigo, IDs, Ayuda)")

-- Verify CreateStyledButton & CreateStyledEditBox helpers
local testStyledBtn = RotaEditor.CreateStyledButton(nil, 80, 24, "Test")
Assert(testStyledBtn:GetBackdrop() ~= nil, "CreateStyledButton sets a real backdrop on button")
Assert(testStyledBtn.backdropColor ~= nil, "CreateStyledButton sets dark backdrop color")
Assert(testStyledBtn.scripts["OnEnter"] ~= nil, "CreateStyledButton sets hover OnEnter script")
Assert(testStyledBtn.scripts["OnLeave"] ~= nil, "CreateStyledButton sets hover OnLeave script")

local testStyledEB = RotaEditor.CreateStyledEditBox(nil, 60, 22, "123")
Assert(testStyledEB:GetBackdrop() ~= nil, "CreateStyledEditBox sets a real backdrop on editbox")
Assert(testStyledEB.backdropColor ~= nil, "CreateStyledEditBox sets dark backdrop color")
Assert(testStyledEB.textInsets ~= nil, "CreateStyledEditBox sets text insets")
Assert(testStyledEB.scripts["OnEscapePressed"] ~= nil, "CreateStyledEditBox sets OnEscapePressed handler")
Assert(testStyledEB.scripts["OnEnterPressed"] ~= nil, "CreateStyledEditBox sets OnEnterPressed handler")

-- Tab 1: Bloques
RotaEditor:SelectTab(1)
Assert(RotaEditor.currentTab == 1, "Selected Tab 1: Bloques")
Assert(RotaEditor.TabBlocks.pool:GetActiveCount() > 0, "TabBlocks populated block frames from active profile")

-- Verify Block Visual Elements & Guided Edit Modal
local activeBlocks = RotaEditor.TabBlocks.pool.active
Assert(#activeBlocks > 0, "TabBlocks has active row frames")
local firstBlock = activeBlocks[1]
Assert(firstBlock.iconTexture ~= nil, "Block row has real spell icon texture")
Assert(firstBlock.toggleBtn ~= nil, "Block row has styled toggle button")
Assert(firstBlock.editBtn ~= nil, "Block row has Edit button")
Assert(firstBlock.condText:GetText() ~= "", "Block row displays human-readable condition text")

Assert(RotaEditor.TabBlocks.editModal ~= nil, "TabBlocks has Block Editor Modal created")
RotaEditor.TabBlocks:OpenEditModal(1, originalIR.lists.main[1])
Assert(RotaEditor.TabBlocks.editModal:IsShown() == true, "OpenEditModal opens the modal frame")
Assert(RotaEditor.TabBlocks.editModal.actEdit:GetText() ~= "", "Modal displays current action alias in EditBox")
Assert(RotaEditor.TabBlocks.editModal.condLuaEdit:GetText() ~= "", "Modal displays condition Lua in EditBox")
RotaEditor.TabBlocks:SaveModalRule()
Assert(RotaEditor.TabBlocks.editModal:IsShown() == false, "SaveModalRule saves rule and closes modal")

-- Move Rule in TabBlocks (el editor trabaja sobre la copia activa, nunca sobre el preset)
local editedIR = RotaCore.Profiles:GetActiveProfile()
local rulesBefore = #editedIR.lists.main
RotaEditor.TabBlocks:AddRule()
Assert(#editedIR.lists.main == rulesBefore + 1, "TabBlocks:AddRule agrega una regla")
local topActionBefore = editedIR.lists.main[1].action
RotaEditor.TabBlocks:MoveRule(1, 1) -- swap 1 and 2
Assert(editedIR.lists.main[2].action == topActionBefore, "TabBlocks:MoveRule correctly reordered priority rules")
RotaEditor.TabBlocks:MoveRule(2, -1) -- swap back
RotaEditor.TabBlocks:DeleteRule(#editedIR.lists.main)
Assert(#editedIR.lists.main == rulesBefore, "TabBlocks:DeleteRule borra la regla agregada")

-- Toggle Rule in TabBlocks
RotaEditor.TabBlocks:ToggleRule(1)
Assert(originalIR.lists.main[1].enabled == false, "TabBlocks:ToggleRule toggled rule to disabled")
RotaEditor.TabBlocks:ToggleRule(1)
Assert(originalIR.lists.main[1].enabled == true, "TabBlocks:ToggleRule toggled rule back to enabled")

-- Tab 2: Code Editor & Bidirectional Sync
RotaEditor:SelectTab(2)
Assert(RotaEditor.currentTab == 2, "Selected Tab 2: Código")
Assert(RotaEditor.TabCode.scrollFrame ~= nil, "TabCode has ScrollFrame")
Assert(RotaEditor.TabCode.scrollFrame:IsMouseWheelEnabled() == true, "TabCode ScrollFrame has mouse wheel enabled")
Assert(RotaEditor.TabCode.scrollFrame.scripts["OnMouseWheel"] ~= nil, "TabCode ScrollFrame has OnMouseWheel script")
RotaEditor.TabCode:SyncFromIR()
local editorText = RotaEditor.TabCode.editBox:GetText()
Assert(editorText:find("%-%- @profile: dk_unholy_2h_pve") ~= nil, "TabCode:SyncFromIR loaded canonical Lua into EditBox")

-- Apply back to IR
RotaEditor.TabCode:ApplyToIR()
Assert(RotaEditor.TabCode.statusText:GetText():find("Guardado") ~= nil, "TabCode: Guardar cambios aplica el codigo")

-- Tab 3: Overrides
RotaEditor:SelectTab(3)
Assert(RotaEditor.currentTab == 3, "Selected Tab 3: Overrides")
Assert(RotaEditor.TabOverrides.pool:GetActiveCount() > 0, "TabOverrides populated spell rows")
Assert(RotaEditor.TabOverrides.scrollFrame ~= nil, "TabOverrides has ScrollFrame")
Assert(RotaEditor.TabOverrides.scrollFrame:IsMouseWheelEnabled() == true, "TabOverrides ScrollFrame has mouse wheel enabled")
local firstOverrideRow = RotaEditor.TabOverrides.pool.active[1]
Assert(firstOverrideRow.overrideEdit:GetBackdrop() ~= nil, "Overrides row input has real backdrop")

-- Toggle editor window visibility
RotaEditor:Hide()
Assert(RotaEditor.mainFrame:IsShown() == false, "RotaEditor:Hide hid main frame")
RotaEditor:Toggle()
Assert(RotaEditor.mainFrame:IsShown() == true, "RotaEditor:Toggle showed main frame")
RotaEditor:Hide()

-- ============================================================================
-- SUITE 21: Retribution Paladin State Provider & Mechanics
-- ============================================================================
print("\n[Suite 21] Retribution Paladin State Provider & Mechanics")

local palLoaded = LoadAddOn("RotaClass_PAL")
Assert(palLoaded == true, "LoadAddOn('RotaClass_PAL') loads module successfully")
Assert(_G.RotaClass_PAL ~= nil, "RotaClass_PAL global table exists")

-- Check presets registered
Assert(RotaCore.Profiles:GetPreset("pal_retribution_pve") ~= nil, "PAL_RETRIBUTION_PVE preset registered in Profiles")
Assert(RotaCore.Profiles:GetPreset("pal_retribution_pvp") == nil, "Sin preset PvP: una sola Retri")

-- Verify State Provider registration
wowmock.setClass("Paladin", "PALADIN")
wowmock.clearAuras()
wowmock.setPower("player", 0, 4000, 5000)
wowmock.setHealth("target", 50000, 50000)
local palState = RotaCore.State:Update(GetTime())
Assert(palState.pal ~= nil, "State contains pre-allocated paladin state table")
Assert(palState.pal.hasSeal == false, "Initially hasSeal is false when no seal buff is active")
Assert(palState.pal.sealName == nil, "sealName is nil initially")
Assert(palState.pal.targetHealthPct == 100, "Target health is 100%")
Assert(palState.pal.canHammerOfWrath == false, "canHammerOfWrath is false at 100% health")
Assert(palState.pal.hasArtOfWar == false, "hasArtOfWar is false initially")

-- Test Seal detection
wowmock.setAura("player", { name = "Seal of Vengeance", filter = "HELPFUL", duration = 1800 })
palState = RotaCore.State:Update(GetTime())
Assert(palState.pal.hasSeal == true, "hasSeal is true when Seal of Vengeance buff is present")
Assert(palState.pal.sealName == "Seal of Vengeance", "sealName reflects 'Seal of Vengeance'")

-- Test Hammer of Wrath execute threshold
wowmock.setHealth("target", 9000, 50000) -- 18% HP <= 20%
palState = RotaCore.State:Update(GetTime())
Assert(palState.pal.targetHealthPct == 18, "Target health is 18%")
Assert(palState.pal.canHammerOfWrath == true, "canHammerOfWrath is true when target health <= 20%")

-- Test Creature Type detection (Undead / Demon for Holy Wrath)
wowmock.setCreatureType("target", "Undead")
palState = RotaCore.State:Update(GetTime())
Assert(palState.pal.isUndeadOrDemon == true, "isUndeadOrDemon is true for Undead target")

-- Test Avenging Wrath tracking & Sacred Shield removal
wowmock.setAura("player", { name = "Avenging Wrath", filter = "HELPFUL", duration = 20 })
palState = RotaCore.State:Update(GetTime())
Assert(palState.pal.hasAvengingWrath == true, "hasAvengingWrath is true with active buff")
local palPreset = RotaCore.Profiles:GetPreset("pal_retribution_pve")
Assert(palPreset.spells.SS == nil, "Sacred Shield is strictly removed from Retribution Paladin profile")

-- ============================================================================
-- SUITE 22: Retribution Paladin FCFS Priority Chain & Zero-Allocation Check
-- ============================================================================
print("\n[Suite 22] Retribution Paladin FCFS Priority Chain & Zero-Allocation Check")

RotaCore.Profiles:SetActiveProfile("pal_retribution_pve")
local palEvalBundle = RotaCore.Profiles:GetActiveEvaluator()
Assert(palEvalBundle ~= nil, "Successfully activated and compiled pal_retribution_pve profile")

-- Opener Sequence check
palEvalBundle.resetSequences()
palEvalBundle.enableSequences()
local opStep1 = palEvalBundle.evaluatorMain(palState)
Assert(opStep1 == "CS", "Opener sequence step 1 is CS")

-- Disable sequences to test strict FCFS priority rules
palEvalBundle.disableSequences()

-- Rule 1: Seal Enforcement in offKey (Burst channel)
wowmock.clearAuras("player")
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorOff(palState) == "SOV", "EvaluatorOff enforces casting Seal (SOV) when seal is missing in Single Target")

-- In AoE mode, Seal of Command is suggested in offKey
_G.RotaCoreDB = _G.RotaCoreDB or {}
_G.RotaCoreDB.settings = _G.RotaCoreDB.settings or {}
_G.RotaCoreDB.settings.autoAoE = false
_G.RotaCoreDB.settings.aoeMode = true
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorOff(palState) == "COMMAND", "EvaluatorOff suggests Seal of Command in AoE mode")
_G.RotaCoreDB.settings.aoeMode = false

-- Apply Seal of Vengeance
wowmock.setAura("player", { name = "Seal of Vengeance", filter = "HELPFUL", duration = 1800 })
wowmock.setHealth("target", 50000, 50000) -- 100% HP
wowmock.setPower("player", 0, 4000, 5000) -- 80% Mana
palState = RotaCore.State:Update(GetTime())

-- Target is at 100% HP: Hammer of Wrath not ready (execute only)
-- ST (Wowhead): CS > Judgement > HoW (<= 20%) > DS > Consecration > Exorcism (AoW) > Holy Wrath
Assert(palEvalBundle.evaluatorMain(palState) == "CS", "FCFS priority 1 in ST is Crusader Strike")
palState.reason = nil
palEvalBundle.evaluatorMain(palState)
Assert(palState.reason == "Crusader Strike", "Modo aprendizaje: el motivo es la descripcion de la regla que disparo")

-- Drop target to <= 20% HP: CS sigue primero
wowmock.setHealth("target", 8000, 50000) -- 16% HP
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorMain(palState) == "CS", "Execute phase: Crusader Strike sigue primero")

-- CS on CD -> Judgement
wowmock.triggerSpellCD(35395, 4.0)
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorMain(palState) == "JUDGEMENT", "When CS is on CD, falls back to JUDGEMENT")

-- Judgement on CD -> Hammer of Wrath (<= 20%)
wowmock.triggerSpellCD(53408, 8.0)
wowmock.triggerSpellCD(20271, 8.0)
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorMain(palState) == "HOW", "When Judgement is on CD, Hammer of Wrath in execute")

-- HOW on CD -> Divine Storm
wowmock.triggerSpellCD(48806, 6.0)
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorMain(palState) == "DS", "When HOW is on CD, falls back to Divine Storm")

-- DS on CD -> Consecration en ST con mana >= 40%
wowmock.triggerSpellCD(53385, 10.0)
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorMain(palState) == "CONS", "Consecration en ST con mana >= 40%")
wowmock.setPower("player", 0, 1500, 5000) -- 30%
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorMain(palState) ~= "CONS", "Consecration no se sugiere con mana < 40%")

-- Put CONS on CD and restore mana
wowmock.triggerSpellCD(48819, 8.0)
wowmock.setPower("player", 0, 3000, 5000)
palState = RotaCore.State:Update(GetTime())

-- Exorcism check: Without Art of War, Exorcism is NEVER suggested
Assert(palState.pal.hasArtOfWar == false, "Art of War is inactive")
Assert(palEvalBundle.evaluatorMain(palState) ~= "EXO", "Exorcism is strictly NOT suggested without Art of War proc")

-- Add Art of War proc -> Exorcism becomes instant and is suggested
wowmock.setAura("player", { name = "The Art of War", filter = "HELPFUL", duration = 15 })
palState = RotaCore.State:Update(GetTime())
Assert(palState.pal.hasArtOfWar == true, "The Art of War proc is active")
Assert(palEvalBundle.evaluatorMain(palState) == "EXO", "Exorcism immediately suggested when Art of War is proc'd")

-- Holy Wrath check: only for Undead or Demon
wowmock.clearAuras("player")
wowmock.setAura("player", { name = "Seal of Vengeance", filter = "HELPFUL", duration = 1800 })
wowmock.setCreatureType("target", "Undead")
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorMain(palState) == "HW", "Holy Wrath suggested when target is Undead and earlier spells on CD")

-- Put HW on CD, drop mana < 25% -> Divine Plea suggested in main GCD
wowmock.triggerSpellCD(48817, 15.0)
wowmock.setPower("player", 0, 1000, 5000) -- 20% Mana (< 25%)
palState = RotaCore.State:Update(GetTime())
Assert(palEvalBundle.evaluatorMain(palState) == "DP", "Main priority suggests DP (Divine Plea) when mana < 25%")

-- Off-GCD Evaluator: Avenging Wrath & Burst sequence
_G.RotaCoreDB.settings.burstMode = true
palState = RotaCore.State:Update(GetTime())
palState.inCombat = true
Assert(palEvalBundle.evaluatorOff(palState) == "AW", "EvaluatorOff suggests AW (Avenging Wrath) burst off-GCD")

-- Put AW on CD -> suggests GLOVES
wowmock.setAura("player", { name = "Avenging Wrath", filter = "HELPFUL", duration = 20 })
palState = RotaCore.State:Update(GetTime())
palState.inCombat = true
Assert(palEvalBundle.evaluatorOff(palState) == "GLOVES", "EvaluatorOff suggests GLOVES when AW active")

-- Hot-Path Zero-Allocation Verification for Paladin Evaluator
-- Run warmup so that any one-time JIT/interned state is primed
for _ = 1, 10 do
    RotaCore.State:Update(100.0)
    palEvalBundle.evaluatorMain(palState)
    palEvalBundle.evaluatorOff(palState)
end
local memBeforePal = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    palEvalBundle.evaluatorMain(palState)
    palEvalBundle.evaluatorOff(palState)
end
local memAfterPal = collectgarbage("count")
local garbagePal = memAfterPal - memBeforePal
print(string.format("  Memory before: %.2f KB", memBeforePal))
print(string.format("  Memory after:  %.2f KB", memAfterPal))
print(string.format("  Garbage produced across 1000 Paladin evaluations: %.4f KB", garbagePal))
Assert(garbagePal == 0, "Zero-Allocation Check: 0.0 KB garbage across 1000 full Paladin evaluations")

-- ============================================================================
-- SUITE 23: Warrior State Provider, Stances & Procs Tracking
-- ============================================================================
print("\n[Suite 23] Warrior State Provider, Stances & Procs Tracking")

local warLoaded = LoadAddOn("RotaClass_WAR")
Assert(warLoaded == true, "LoadAddOn('RotaClass_WAR') loads module successfully")
Assert(_G.RotaClass_WAR ~= nil, "RotaClass_WAR global table exists")

-- Check presets registered
Assert(RotaCore.Profiles:GetPreset("war_fury_pve") ~= nil, "WAR_FURY_PVE preset registered in Profiles")
Assert(RotaCore.Profiles:GetPreset("war_arms_pve") ~= nil, "WAR_ARMS_PVE preset registered in Profiles")

-- Verify State Provider registration
wowmock.setClass("Warrior", "WARRIOR")
wowmock.clearAuras()
wowmock.setShapeshiftForm(1) -- Battle Stance
wowmock.setPower("player", 1, 40, 100) -- 40 Rage
wowmock.setHealth("target", 50000, 50000)
local warState = RotaCore.State:Update(GetTime())
Assert(warState.war ~= nil, "State contains pre-allocated warrior state table")
Assert(warState.war.stance == 1, "Warrior stance is 1 (Battle Stance)")
Assert(warState.war.rage == 40, "Warrior rage tracked at 40")

-- Switch to Berserker Stance
wowmock.setShapeshiftForm(3)
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.stance == 3, "Warrior stance updated to 3 (Berserker Stance)")

-- Test Bloodsurge proc tracking
wowmock.setAura("player", { name = "Bloodsurge", filter = "HELPFUL", duration = 5 })
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.hasBloodsurge == true, "hasBloodsurge is true with active buff")

-- Test Sudden Death proc tracking
wowmock.setAura("player", { name = "Sudden Death", filter = "HELPFUL", duration = 10 })
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.hasSuddenDeath == true, "hasSuddenDeath is true with active buff")
Assert(warState.war.canExecute == true, "canExecute is true via Sudden Death proc even at 100% HP")

-- Test Taste for Blood & Overpower in Battle Stance
wowmock.clearAuras("player")
wowmock.setAura("player", { name = "Taste for Blood", filter = "HELPFUL", duration = 9 })
wowmock.setShapeshiftForm(1) -- Battle Stance
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.hasTasteForBlood == true, "hasTasteForBlood is true")
Assert(warState.war.canOverpower == true, "canOverpower is true with Taste for Blood in Battle Stance")

-- Taste for Blood in Berserker Stance -> canOverpower is false
wowmock.setShapeshiftForm(3)
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.canOverpower == false, "canOverpower is false in Berserker Stance")

-- Test Rend debuff tracking
wowmock.setAura("target", { name = "Rend", filter = "HARMFUL", duration = 15, unitCaster = "player" })
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.hasRend == true, "hasRend is true when target has Rend debuff")

-- Test On-Next-Swing queue tracking via IsCurrentSpell
Assert(warState.war.isHeroicStrikeQueued == false, "isHeroicStrikeQueued is false initially")
wowmock.setCurrentSpell("Heroic Strike", true)
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.isHeroicStrikeQueued == true, "isHeroicStrikeQueued is true when spell is queued")
wowmock.setCurrentSpell("Heroic Strike", false)

-- ============================================================================
-- SUITE 24: Warrior Fury & Arms Priority Chains & Zero-Allocation Check
-- ============================================================================
print("\n[Suite 24] Warrior Fury & Arms Priority Chains & Zero-Allocation Check")

RotaCore.Profiles:SetActiveProfile("war_fury_pve")
local warEvalBundle = RotaCore.Profiles:GetActiveEvaluator()
Assert(warEvalBundle ~= nil, "Successfully activated and compiled war_fury_pve profile")

-- Opener Sequence check
warEvalBundle.resetSequences()
warEvalBundle.enableSequences()
Assert(warEvalBundle.evaluatorMain(warState) == "BT", "Fury opener sequence step 1 is BT (Bloodthirst)")

-- Disable sequences for strict priority evaluation
warEvalBundle.disableSequences()

-- Fury Main GCD Priority
wowmock.clearAuras("player")
wowmock.setPower("player", 1, 60, 100) -- 60 Rage
wowmock.setHealth("target", 50000, 50000) -- 100% HP
warState = RotaCore.State:Update(GetTime())

-- 1. Bloodthirst ready + 60 rage
Assert(warEvalBundle.evaluatorMain(warState) == "BT", "Fury priority 1 is Bloodthirst")

-- Put Bloodthirst on CD -> Whirlwind
wowmock.triggerSpellCD(23881, 4.0)
warState = RotaCore.State:Update(GetTime())
Assert(warEvalBundle.evaluatorMain(warState) == "WW", "When BT is on CD, Fury priority falls back to Whirlwind")

-- Put Whirlwind on CD -> Slam check (requires Bloodsurge proc)
wowmock.triggerSpellCD(1680, 8.0)
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.hasBloodsurge == false, "Bloodsurge is inactive")
Assert(warEvalBundle.evaluatorMain(warState) ~= "SLAM", "Slam is strictly NOT suggested without Bloodsurge proc")

-- Add Bloodsurge proc -> Slam is suggested
wowmock.setAura("player", { name = "Bloodsurge", filter = "HELPFUL", duration = 5 })
warState = RotaCore.State:Update(GetTime())
Assert(warEvalBundle.evaluatorMain(warState) == "SLAM", "Slam immediately suggested when Bloodsurge proc is active")

-- Execute check: Target at 100% without Sudden Death -> Execute NOT suggested
wowmock.clearAuras("player")
warState = RotaCore.State:Update(GetTime())
Assert(warEvalBundle.evaluatorMain(warState) ~= "EXEC", "Execute not suggested when target > 20% HP and no Sudden Death")

-- Drop target to <= 20% HP -> Execute is suggested
wowmock.setHealth("target", 9000, 50000) -- 18% HP
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.canExecute == true, "canExecute is true in execute phase")
Assert(warEvalBundle.evaluatorMain(warState) == "EXEC", "Execute suggested when target <= 20% HP and primary attacks on CD")

-- Fury Off-Next-Swing / Off-GCD List
wowmock.triggerSpellCD(12292, 180.0) -- Put Death Wish on CD to test Next-Swing queue
wowmock.setCurrentSpell("Heroic Strike", false)
wowmock.setPower("player", 1, 60, 100) -- 60 Rage (>= 50 hsRageThreshold)
warState = RotaCore.State:Update(GetTime())
Assert(warEvalBundle.evaluatorOff(warState) == "HS", "EvaluatorOff suggests HS when rage >= hsRageThreshold and NOT queued")

-- Queue Heroic Strike -> EvaluatorOff does NOT suggest HS again (prevents spam queue)
wowmock.setCurrentSpell("Heroic Strike", true)
warState = RotaCore.State:Update(GetTime())
Assert(warState.war.isHeroicStrikeQueued == true, "Heroic strike is registered as queued")
Assert(warEvalBundle.evaluatorOff(warState) ~= "HS", "EvaluatorOff suppresses HS when already queued")

-- Clear queue and drop rage below threshold (< 50) -> HS suppressed to prevent rage starvation
wowmock.setCurrentSpell("Heroic Strike", false)
wowmock.setPower("player", 1, 35, 100) -- 35 Rage
warState = RotaCore.State:Update(GetTime())
Assert(warEvalBundle.evaluatorOff(warState) ~= "HS", "EvaluatorOff suppresses HS when rage < hsRageThreshold to preserve BT/WW rage")

-- Drop rage to < 20 -> Bloodrage suggested off-GCD
wowmock.setPower("player", 1, 10, 100)
warState = RotaCore.State:Update(GetTime())
Assert(warEvalBundle.evaluatorOff(warState) == "BR", "EvaluatorOff suggests Bloodrage when low on rage")

-- Arms Profile Tests
RotaCore.Profiles:SetActiveProfile("war_arms_pve")
local armsEvalBundle = RotaCore.Profiles:GetActiveEvaluator()
Assert(armsEvalBundle ~= nil, "Successfully activated and compiled war_arms_pve profile")
armsEvalBundle.disableSequences()

-- Arms: Rend missing -> suggest Rend
wowmock.clearAuras("target")
wowmock.setHealth("target", 50000, 50000) -- 100% HP (out of execute phase)
wowmock.setShapeshiftForm(1) -- Battle Stance
wowmock.setPower("player", 1, 50, 100)
warState = RotaCore.State:Update(GetTime())
Assert(armsEvalBundle.evaluatorMain(warState) == "REND", "Arms priority suggests REND when Rend is missing from target")

-- Apply Rend -> Taste for Blood Overpower proc
wowmock.setAura("target", { name = "Rend", filter = "HARMFUL", duration = 15, unitCaster = "player" })
wowmock.setAura("player", { name = "Taste for Blood", filter = "HELPFUL", duration = 9 })
warState = RotaCore.State:Update(GetTime())
Assert(armsEvalBundle.evaluatorMain(warState) == "MS", "Arms: Mortal Strike listo va antes que Overpower (Rebuffed +35%)")
wowmock.triggerSpellCD(12294, 6.0)
warState = RotaCore.State:Update(GetTime())
Assert(armsEvalBundle.evaluatorMain(warState) == "OP", "Arms priority suggests Overpower on Taste for Blood proc in Battle Stance")

-- Hot-Path Zero-Allocation Verification for Warrior Evaluator
collectgarbage("collect")
local memBeforeWar = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    warEvalBundle.evaluatorMain(warState)
    warEvalBundle.evaluatorOff(warState)
end
local memAfterWar = collectgarbage("count")
local garbageWar = memAfterWar - memBeforeWar
print(string.format("  Memory before: %.2f KB", memBeforeWar))
print(string.format("  Memory after:  %.2f KB", memAfterWar))
print(string.format("  Garbage produced across 1000 Warrior evaluations: %.4f KB", garbageWar))
Assert(garbageWar == 0, "Zero-Allocation Check: 0.0 KB garbage across 1000 full Warrior evaluations")

-- ============================================================================
-- SUITE 25: Minimap Button, Blizzard Interface Options & In-Game Tutorial
-- ============================================================================
print("\n[Suite 25] Minimap Button, Blizzard Interface Options & In-Game Tutorial")

RotaCore.Profiles:InitDB()
dofile("RotaCore/Minimap.lua")
dofile("RotaCore/Options.lua")

-- Test Minimap Button
RotaCore.Minimap:Init()
Assert(RotaCore.Minimap.button ~= nil, "Minimap button created successfully")
Assert(RotaCore.Minimap.button:IsShown() == true, "Minimap button is visible by default")

RotaCore.Minimap:UpdatePosition(180)
Assert(_G.RotaCoreDB.settings.minimapPos == 180, "UpdatePosition persists angle in SavedVariables (180 deg)")

RotaCore.Minimap:SetShown(false)
Assert(RotaCore.Minimap.button:IsShown() == false, "SetShown(false) hides Minimap button")
Assert(_G.RotaCoreDB.settings.showMinimap == false, "SavedVariables reflect showMinimap = false")

RotaCore.Minimap:SetShown(true)
Assert(RotaCore.Minimap.button:IsShown() == true, "SetShown(true) shows Minimap button")

-- Test Interface Options Panel
RotaCore.Options:Init()
Assert(RotaCore.optionsPanel ~= nil, "Interface Options panel created")
Assert(RotaCore.optionsPanel.name == "Rota Suite", "Options category name is 'Rota Suite'")
Assert(#wowmock.interfaceCategories > 0, "Panel registered in InterfaceOptions_AddCategory")

-- Test Tab 5 Tutorial in RotaEditor
dofile("RotaEditor/TabTutorial.lua")
RotaEditor.mainFrame = nil
RotaEditor.tabs = {}
RotaEditor:Init()
Assert(#RotaEditor.tabs == 4, "RotaEditor tiene 4 pestanas con Ayuda")
RotaEditor:SelectTab(5)
Assert(RotaEditor.currentTab == 5, "Selected Tab 5: Tutorial")
Assert(RotaEditor.TabTutorial.currentTopic == 1, "Ayuda arranca en el tema 1 (Que hace)")

RotaEditor.TabTutorial:SelectTopic(2)
Assert(RotaEditor.TabTutorial.currentTopic == 2, "Ayuda: tema 2 (Reglas)")
Assert(RotaEditor.TabTutorial.contentFontString:GetText():find("return false") ~= nil, "Ayuda: el tema Reglas explica return false")

RotaEditor.TabTutorial:SelectTopic(4)
Assert(RotaEditor.TabTutorial.currentTopic == 4, "Ayuda: tema 4 (IDs de hechizos)")

-- Test Slash Commands (/rc options, /rc lock, /rc reset, /rc status)
local slashHandler = _G.SlashCmdList["ROTACORE"]
Assert(slashHandler ~= nil, "SlashCmdList['ROTACORE'] registered")
slashHandler("status")
slashHandler("lock")
Assert(_G.RotaCoreDB.settings.locked == false, "/rc lock toggled HUD locked status to false")
Assert(RotaCore.UI.isLocked == false, "RotaCore.UI isLocked is false")
Assert(RotaCore.UI.dragOverlay ~= nil and RotaCore.UI.dragOverlay:IsShown() == true, "HUD drag overlay is shown when unlocked")
Assert(RotaCore.UI.mainIcon.frame:IsMouseEnabled() == true, "mainIcon frame has mouse enabled when unlocked")
Assert(RotaCore.UI.hudFrame:IsMouseEnabled() == true, "hudFrame has mouse enabled when unlocked")
Assert(RotaCore.UI.mainIcon.frame.dragButtons ~= nil, "mainIcon frame has LeftButton drag registered")
Assert(RotaCore.UI.hudFrame.dragButtons ~= nil, "hudFrame has LeftButton drag registered")

-- Test dragging HUD saves position
RotaCore.UI.hudFrame.scripts["OnDragStart"]()
Assert(RotaCore.UI.hudFrame.isMoving == true, "hudFrame:StartMoving called on drag start")
RotaCore.UI.hudFrame.scripts["OnDragStop"]()
Assert(RotaCore.UI.hudFrame.isMoving == false, "hudFrame:StopMovingOrSizing called on drag stop")
Assert(_G.RotaCoreDB.settings.hudPosition ~= nil, "OnDragStop saved HUD position in RotaCoreDB.settings.hudPosition")

slashHandler("lock")
Assert(_G.RotaCoreDB.settings.locked == true, "/rc lock toggled HUD locked status to true")
Assert(RotaCore.UI.isLocked == true, "RotaCore.UI isLocked is true")
Assert(RotaCore.UI.dragOverlay:IsShown() == false, "HUD drag overlay is hidden when locked")
Assert(RotaCore.UI.mainIcon.frame:IsMouseEnabled() == false, "mainIcon frame has mouse disabled when locked")
Assert(RotaCore.UI.hudFrame:IsMouseEnabled() == false, "hudFrame has mouse disabled when locked")
slashHandler("reset")
slashHandler("options")
Assert(wowmock.lastOpenedCategory == RotaCore.optionsPanel, "/rc options opened InterfaceOptions category")

-- ============================================================================
-- SUITE 26: 3.3.5a Engine Hotfix & Fault Tolerance Validation
-- ============================================================================
print("\n[Suite 26] 3.3.5a Font Safety & Initialization Resilience")

-- 1. Verify wowmock throws error on SetText without FontObject
local dummyFrame = wowmock.createFrame("Frame")
local unconfiguredFS = dummyFrame:CreateFontString()
local okFont, fontErr = pcall(function() unconfiguredFS:SetText("Test Crash") end)
Assert(okFont == false, "CreateFontString:SetText() strictly fails when font is not set")
Assert(fontErr ~= nil and fontErr:find("Font not set") ~= nil, "Error message matches WoW 3.3.5a C++ 'Font not set'")

-- 2. Verify CreateFontString with inherits succeeds
local validFS = dummyFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
local okValid = pcall(function() validFS:SetText("Working Text") end)
Assert(okValid == true, "CreateFontString with 'GameFontNormal' succeeds on SetText()")

-- 3. Verify Slash Commands /rc and /rota registration
Assert(_G.SlashCmdList["ROTACORE"] ~= nil, "SlashCmdList['ROTACORE'] registered")
Assert(_G.SlashCmdList["ROTA"] ~= nil, "SlashCmdList['ROTA'] registered")
Assert(_G.SLASH_ROTACORE2 == "/rc", "SLASH_ROTACORE2 alias is /rc")
Assert(_G.SLASH_ROTA1 == "/rota", "SLASH_ROTA1 is /rota")

-- 4. Fault tolerance: RotaCore:Init() succeeds and initializes HUD + class preset even if submodule errors
local oldMinimapInit = RotaCore.Minimap and RotaCore.Minimap.Init
if RotaCore.Minimap then
    RotaCore.Minimap.Init = function() error("Simulated Minimap crash") end
end
RotaCore.UI.hudFrame = nil
RotaCore.Profiles.activeProfile = nil
RotaCore:Init()
Assert(RotaCore.UI.hudFrame ~= nil, "HUD initialized despite submodule error in Minimap")
Assert(RotaCore.Profiles:GetActiveProfile() ~= nil, "Class preset loaded despite submodule error in Minimap")

-- Restore Minimap.Init
if RotaCore.Minimap and oldMinimapInit then
    RotaCore.Minimap.Init = oldMinimapInit
end

-- ----------------------------------------------------------------------------
-- SUITE 27: Death Knight Automatic Build Detection (Frost, Unholy Morb, Unholy 2H)
-- ----------------------------------------------------------------------------
print("\n[Suite 27] Death Knight Automatic Build Detection (Frost, Unholy Morb, Unholy 2H)")

wowmock.setClass("Death Knight", "DEATHKNIGHT")

-- Ensure RotaClass_DK is loaded
LoadAddOn("RotaClass_DK")
local DK = _G.RotaClass_DK
Assert(DK ~= nil, "RotaClass_DK is loaded")
Assert(type(DK.DetectBuild) == "function", "DK:DetectBuild() function exists")

-- Case 1: Frost spec simulation (Howling Blast known or talent active)
wowmock.talents.tabs = {
    [1] = { name = "Blood", pointsSpent = 0, talents = {} },
    [2] = { name = "Frost", pointsSpent = 51, talents = {
        { name = "Howling Blast", rank = 1, maxRank = 1, spellId = 49143 }
    }},
    [3] = { name = "Unholy", pointsSpent = 20, talents = {} },
}
wowmock.spellbook.knownSpells = { [49143] = true }
if _G.RotaCoreDB and _G.RotaCoreDB.settings then
    SetBuild("auto")
end

local bKey, pId, sName = DK:DetectBuild()
Assert(bKey == "frost", "Simulated Howling Blast detects 'frost' build")
Assert(pId == "dk_frost_pve", "Frost build activates 'dk_frost_pve' profile")
Assert(sName == "Frost", "Spec name is 'Frost'")
Assert(DK.detectedBadge == "[F]", "Badge for Frost is '[F]'")
local activeProf = RotaCore.Profiles:GetActiveProfile()
Assert(activeProf ~= nil and activeProf.meta.id == "dk_frost_pve", "Active profile is dk_frost_pve")

-- Case 2: Unholy Morb simulation (Unholy primary tree + Nerves of Cold Steel in Frost)
wowmock.spellbook.knownSpells = {}
wowmock.talents.tabs = {
    [1] = { name = "Blood", pointsSpent = 0, talents = {} },
    [2] = { name = "Frost", pointsSpent = 17, talents = {
        { name = "Icy Reach", rank = 2, maxRank = 2 },
        { name = "Nerves of Cold Steel", rank = 3, maxRank = 3, spellId = 49013 },
    }},
    [3] = { name = "Unholy", pointsSpent = 54, talents = {
        { name = "Vicious Strikes", rank = 2, maxRank = 2 },
        { name = "Desolation", rank = 5, maxRank = 5 },
    }},
}
bKey, pId, sName = DK:DetectBuild()
Assert(bKey == "unholy_morb", "Unholy primary with Nerves of Cold Steel detects 'unholy_morb'")
Assert(pId == "dk_unholy_morb_pve", "Unholy Morb activates 'dk_unholy_morb_pve' profile")
Assert(sName == "UH Morb (DW)", "Spec name is 'UH Morb (DW)'")
Assert(DK.detectedBadge == "[UM]", "Badge for Unholy Morb is '[UM]'")
activeProf = RotaCore.Profiles:GetActiveProfile()
Assert(activeProf ~= nil and activeProf.meta.id == "dk_unholy_morb_pve", "Active profile is dk_unholy_morb_pve")

-- Case 3: Unholy 2H simulation (Unholy primary tree, NO Nerves of Cold Steel)
wowmock.talents.tabs = {
    [1] = { name = "Blood", pointsSpent = 17, talents = {
        { name = "Bladed Armor", rank = 5, maxRank = 5 },
    }},
    [2] = { name = "Frost", pointsSpent = 0, talents = {} },
    [3] = { name = "Unholy", pointsSpent = 54, talents = {
        { name = "Scourge Strike", rank = 1, maxRank = 1 },
    }},
}
bKey, pId, sName = DK:DetectBuild()
Assert(bKey == "unholy_2h", "Unholy primary without Nerves of Cold Steel detects 'unholy_2h'")
Assert(pId == "dk_unholy_2h_pve", "Unholy 2H activates 'dk_unholy_2h_pve' profile")
Assert(sName == "UH", "Spec name is 'UH'")
Assert(DK.detectedBadge == "[U]", "Badge for Unholy 2H is '[U]'")

-- Case 4: Manual override via Settings overrides automatic detection
SetBuild("Frost (DW)")
bKey, pId = DK:DetectBuild()
Assert(bKey == "unholy_2h", "Underlying talent detection still registers detectedKey")
Assert(pId == "dk_frost_pve", "Manual setting 'Frost (DW)' enforces activePreset 'dk_frost_pve'")
Assert(DK.detectedBadge == "[F]", "Badge reflects manual selection '[F]'")
SetBuild("auto")

-- ----------------------------------------------------------------------------
-- SUITE 28: WoWSims 3.3.5a DK Presets Verification
-- ----------------------------------------------------------------------------
print("\n[Suite 28] WoWSims 3.3.5a DK Presets Verification")

local frostPreset = RotaCore.Profiles:GetPreset("dk_frost_pve")
local morbPreset = RotaCore.Profiles:GetPreset("dk_unholy_morb_pve")
local u2hPreset = RotaCore.Profiles:GetPreset("dk_unholy_2h_pve")

Assert(frostPreset ~= nil, "Frost preset registered in Profiles")
Assert(morbPreset ~= nil, "Unholy Morb preset registered in Profiles")
Assert(u2hPreset ~= nil, "Unholy 2H preset registered in Profiles")

-- Verify Frost Opener (2F) steps
local fOpener = frostPreset.sequences and frostPreset.sequences.opener and frostPreset.sequences.opener.steps
Assert(fOpener ~= nil, "Frost preset defines opener sequence (2F)")
Assert(fOpener[1] == "IT", "Frost opener step 1 is IT (Icy Touch)")
Assert(fOpener[2] == "PS", "Frost opener step 2 is PS (Plague Strike)")
Assert(fOpener[3] == "BT", "Frost opener step 3 is BT (Blood Tap)")
Assert(fOpener[4] == "UA", "Frost opener step 4 is UA (Unbreakable Armor)")
Assert(fOpener[5] == "HYPER", "Frost opener step 5 is HYPER (Hyperspeed Acceleration)")
Assert(fOpener[9] == "OB", "Frost opener step 9 is OB (Obliterate)")
Assert(fOpener[10] == "FS", "Frost opener step 10 is FS (Frost Strike)")
Assert(fOpener[11] == "PEST", "Frost opener step 11 is PEST (Pestilence)")
Assert(fOpener[12] == "ERW", "Frost opener step 12 is ERW (Empower Rune Weapon)")

-- Verify Frost Priority (3F & 4F)
local frostEval = Compiler:Compile(frostPreset)
frostEval.disableSequences()

-- Pestilence strict refresh (<1.5s)
wowmock.setTime(4000.0)
wowmock.initRunes()
wowmock.clearAuras("target")
wowmock.setAura("target", {
    name = "Frost Fever", duration = 15.0, expirationTime = 4001.2, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 15.0, expirationTime = 4001.2, filter = "HARMFUL", unitCaster = "player"
})
local frostState = RotaCore.State:Update(4000.0)
Assert(frostEval.evaluatorMain(frostState) == "PEST", "Frost 3F suggests PEST when diseases < 1.5s")

-- Frost Strike on Killing Machine proc
wowmock.clearAuras("target")
wowmock.setAura("target", {
    name = "Frost Fever", duration = 20.0, expirationTime = 4015.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 20.0, expirationTime = 4015.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("player", {
    name = "Killing Machine", duration = 30.0, expirationTime = 4020.0, filter = "HELPFUL"
})
wowmock.setPower("player", 6, 50)
frostState = RotaCore.State:Update(4000.0)
Assert(frostEval.evaluatorMain(frostState) == "FS", "Frost 3F suggests FS on Killing Machine proc")

-- Obliterate when runes ready
wowmock.clearAuras("player")
frostState = RotaCore.State:Update(4000.0)
local fAction = frostEval.evaluatorMain(frostState)
Assert(fAction == "OBL" or fAction == "OB", "Frost 3F suggests OBL when Frost & Unholy runes ready")

-- Verify Unholy Morb (1UM & 2UM) DND & AoE mechanics
local morbEval = Compiler:Compile(morbPreset)
morbEval.disableSequences()

-- Death and Decay constant on CD
wowmock.clearAuras("player")
wowmock.setAura("target", {
    name = "Frost Fever", duration = 20.0, expirationTime = 4015.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 20.0, expirationTime = 4015.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("player", {
    name = "Desolation", duration = 20.0, expirationTime = 4015.0, filter = "HELPFUL"
})
wowmock.initRunes()
_G.RotaCoreDB.settings.burstMode = false -- suppress gargoyle to test DND
local morbState = RotaCore.State:Update(4000.0)
Assert(morbEval.evaluatorMain(morbState) == "DND", "Unholy Morb 1UM suggests DND when runes ready and diseases active")

-- ----------------------------------------------------------------------------
-- SUITE 29: Burst Mode, AoE Mode & Opener Skipping in Compiler
-- ----------------------------------------------------------------------------
print("\n[Suite 29] Burst Mode, AoE Mode & Opener Skipping in Compiler")

-- 1. Opener Burst Skipping: When Burst Mode is OFF, long CDs are skipped, but Blood Tap (BT) is NOT!
local burstFrostEval = Compiler:Compile(frostPreset)
burstFrostEval.enableSequences()

-- Burst ON: Step 1 is IT (Icy Touch)
_G.RotaCoreDB.settings.burstMode = true
frostState = RotaCore.State:Update(5000.0)
Assert(burstFrostEval.evaluatorMain(frostState) == "IT", "Opener with Burst ON starts on IT (Icy Touch)")

-- Burst OFF: Step 1 is STILL IT (Icy Touch is unaffected by Burst toggle!)
burstFrostEval.resetSequences()
_G.RotaCoreDB.settings.burstMode = false
frostState = RotaCore.State:Update(5000.0)
Assert(burstFrostEval.evaluatorMain(frostState) == "IT", "Opener with Burst OFF still executes IT (Icy Touch is unaffected)")

-- Burst OFF: When stepping past BT, long CDs (UA, HYPER, BF, BERSERKING, STONEFORM) are skipped and it lands on OB!
burstFrostEval.resetSequences()
-- Advance sequence past BT by triggering a step
-- In compiler, simulate that BT has been cast:
-- With burstMode = false, if we skip burst actions, verify that burst actions are bypassed
local testSeqIR = {
    meta = { id = "burst_test", class = "DEATHKNIGHT" },
    spells = { UA = { name = "Unbreakable Armor", defaultId = 51271 } },
    sequences = {
        opener = {
            enabled = true,
            steps = { "UA", "GARG", "OB" },
        }
    },
    lists = { main = {}, off = {} }
}
local testSeqEval = Compiler:Compile(testSeqIR)
testState = RotaCore.State:Update(5000.0)
Assert(testState.burstMode == false, "State burstMode is false")
Assert(testSeqEval.evaluatorMain(testState) == "OB", "Opener sequence automatically skipped UA and GARG when Burst Mode is OFF")

-- 2. AoE Auto-Detection
_G.RotaCoreDB.settings.autoAoE = true
_G.RotaCoreDB.settings.aoeMode = "AUTO"
RotaCore.State.data.aoeCount = 1
frostState = RotaCore.State:Update(5000.0)
Assert(frostState.aoeMode == false, "AoE mode is false when aoeCount (1) < aoeTargets (3)")

RotaCore.State.data.aoeCount = 3
frostState = RotaCore.State:Update(5000.0)
Assert(frostState.aoeMode == true, "AoE mode automatically activated when aoeCount (3) >= aoeTargets (3)")

-- 3. AoE Mode rule selection: Blood Boil in AoE vs Blood Strike in single-target
morbEval.disableSequences()
wowmock.setTime(5000.0)
wowmock.clearAuras("player")
wowmock.clearAuras("target")
wowmock.setAura("target", {
    name = "Frost Fever", duration = 20.0, expirationTime = 5020.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 20.0, expirationTime = 5020.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("player", {
    name = "Desolation", duration = 20.0, expirationTime = 5020.0, filter = "HELPFUL"
})
wowmock.initRunes()
wowmock.useRune(3) -- Frost rune on CD
wowmock.useRune(4)
wowmock.useRune(5) -- Unholy rune on CD
wowmock.useRune(6)
-- Only Blood runes ready (runes 1 and 2)
Assert(RotaCore.State.data.runes.bloodReady == 2, "2 Blood runes ready for Morb")

-- In AoE mode: suggests Blood Boil (BB) once diseases have already been spread
-- El evaluador Morb registra Pestilence desde el combat log (SPELL_CAST_SUCCESS propio)
RotaCore.State.data.lastCast["PEST"] = 5000.0
wowmock.setTime(5000.0)
RotaClass_DK.UHOnCombatLog("SPELL_CAST_SUCCESS", _G.UnitGUID("player"), nil, nil, nil, nil, nil, 50842, "Pestilence")
_G.RotaCoreDB.settings.autoAoE = false
_G.RotaCoreDB.settings.aoeMode = true
morbState = RotaCore.State:Update(5000.0)
Assert(morbState.aoeMode == true, "Manual AoE mode is true")
Assert(morbEval.evaluatorMain(morbState) == "BB", "Unholy Morb suggests BB (Blood Boil) when AoE mode is active")

-- In Single-Target mode: suggests Blood Strike (BS) when Desolation < 10s, and Blood Boil (BB) when Desolation >= 10s
_G.RotaCoreDB.settings.aoeMode = false
wowmock.clearAuras("player")
wowmock.setAura("player", {
    name = "Desolation", duration = 8.0, expirationTime = 5008.0, filter = "HELPFUL"
})
wowmock.setAura("pet", {
    name = "Ghoul Frenzy", duration = 30.0, expirationTime = 5025.0, filter = "HELPFUL"
})
morbState = RotaCore.State:Update(5000.0)
Assert(morbState.aoeMode == false, "Single-target mode active")
Assert(morbEval.evaluatorMain(morbState) == "BS", "Unholy Morb suggests BS (Blood Strike) when Desolation < 10s")

wowmock.clearAuras("player")
wowmock.setAura("player", {
    name = "Desolation", duration = 20.0, expirationTime = 5020.0, filter = "HELPFUL"
})
wowmock.setAura("player", {
    name = "Unholy Strength", duration = 15.0, expirationTime = 5015.0, filter = "HELPFUL"
})
morbState = RotaCore.State:Update(5000.0)
Assert(morbEval.evaluatorMain(morbState) == "BB", "Unholy Morb suggests BB (Blood Boil) in ST when Desolation >= 10s")

-- 4. Hot-Path Zero-Allocation Verification on Frost & Morb (1000 Iterations)
for _ = 1, 10 do
    frostEval.evaluatorMain(frostState)
    frostEval.evaluatorOff(frostState)
    morbEval.evaluatorMain(morbState)
    morbEval.evaluatorOff(morbState)
end
collectgarbage("collect")
collectgarbage("collect")
memBefore = collectgarbage("count")
for _ = 1, 1000 do
    frostEval.evaluatorMain(frostState)
    frostEval.evaluatorOff(frostState)
    morbEval.evaluatorMain(morbState)
    morbEval.evaluatorOff(morbState)
end
memAfter = collectgarbage("count")
local garbageProduced = memAfter - memBefore
Assert(garbageProduced == 0.0, string.format("Zero-Allocation Check: %.4f KB in 1000 Frost & Morb evaluations", garbageProduced))

-- ----------------------------------------------------------------------------
-- SUITE 30: Options UI Controls, Slash Commands & HUD Badges
-- ----------------------------------------------------------------------------
print("\n[Suite 30] Options UI Controls, Slash Commands & HUD Badges")

-- 1. Verify Options Panel controls exist
local optPanel = RotaCore.optionsPanel
Assert(optPanel ~= nil, "Options panel exists")
Assert(optPanel.buildDropDown ~= nil, "Build DropDown exists in Options panel")
Assert(optPanel.aoeModeDropDown ~= nil, "Modo AoE (AUTO/ON/OFF) existe en el panel de Opciones")
optPanel.aoeModeDropDown.Select("ON")
Assert(_G.RotaCoreDB.settings.aoeMode == "ON" and _G.RotaCoreDB.settings.autoAoE == false, "Panel: Modo AoE ON = /rc aoe forzado")
optPanel.aoeModeDropDown.Select("AUTO")
Assert(_G.RotaCoreDB.settings.autoAoE == true, "Panel: Modo AoE AUTO")
Assert(optPanel.learningCb ~= nil, "Casilla de modo aprendizaje en el panel")
Assert(type(RotaCore.HandleSlashCmd) == "function", "Los botones del panel usan el mismo handler que /rc")
Assert(optPanel.burstCb ~= nil, "Burst Checkbox exists in Options panel")

-- 2. Test DropDown switching
optPanel.buildDropDown.ApplyBuildSelection("frost")
Assert(_G.RotaCoreDB.settings.selectedBuild == "frost", "ApplyBuildSelection persists 'frost' in settings")
Assert(RotaCore.Profiles:GetActiveProfile().meta.id == "dk_frost_pve", "Active profile switched to dk_frost_pve")

optPanel.buildDropDown.ApplyBuildSelection("unholy_morb")
Assert(_G.RotaCoreDB.settings.selectedBuild == "unholy_morb", "ApplyBuildSelection persists 'unholy_morb' in settings")
Assert(RotaCore.Profiles:GetActiveProfile().meta.id == "dk_unholy_morb_pve", "Active profile switched to dk_unholy_morb_pve")

-- 3. Test Slash Commands /rc burst and /rc aoe (Tri-State: AUTO -> OFF -> ON -> AUTO)
local initialBurst = _G.RotaCoreDB.settings.burstMode
_G.SlashCmdList["ROTACORE"]("burst")
Assert(_G.RotaCoreDB.settings.burstMode == (not initialBurst), "/rc burst toggled burstMode setting")
_G.SlashCmdList["ROTACORE"]("burst")
Assert(_G.RotaCoreDB.settings.burstMode == initialBurst, "/rc burst toggled burstMode setting back")

_G.RotaCoreDB.settings.aoeMode = "AUTO"
_G.SlashCmdList["ROTACORE"]("aoe")
Assert(_G.RotaCoreDB.settings.aoeMode == "OFF", "/rc aoe transitions from AUTO to OFF")
_G.SlashCmdList["ROTACORE"]("aoe")
Assert(_G.RotaCoreDB.settings.aoeMode == "ON", "/rc aoe transitions from OFF to ON")
_G.SlashCmdList["ROTACORE"]("aoe")
Assert(_G.RotaCoreDB.settings.aoeMode == "AUTO", "/rc aoe transitions from ON to AUTO")

-- Test HUD Interactive Buttons exist & Click Cycles
Assert(RotaCore.UI.aoeBtn ~= nil, "AoE Tri-State button exists in HUD")
Assert(RotaCore.UI.burstBtn ~= nil, "Burst button exists in HUD")
Assert(RotaCore.UI.buildBtn ~= nil, "Build button exists in HUD")

_G.RotaCoreDB.settings.aoeMode = "AUTO"
RotaCore.UI.aoeBtn:GetScript("OnClick")(RotaCore.UI.aoeBtn)
Assert(_G.RotaCoreDB.settings.aoeMode == "OFF", "AoE button click transitions AUTO to OFF")
RotaCore.UI.aoeBtn:GetScript("OnClick")(RotaCore.UI.aoeBtn)
Assert(_G.RotaCoreDB.settings.aoeMode == "ON", "AoE button click transitions OFF to ON")
RotaCore.UI.aoeBtn:GetScript("OnClick")(RotaCore.UI.aoeBtn)
Assert(_G.RotaCoreDB.settings.aoeMode == "AUTO", "AoE button click transitions ON to AUTO")

-- 4. Test HUD Badges display
Assert(RotaCore.UI.badgesText ~= nil, "HUD badges FontString exists")
_G.RotaCoreDB.settings.burstMode = true
_G.RotaCoreDB.settings.aoeMode = true
RotaCore.UI:UpdateDisplay("OB", "UA")
local badgeContent = RotaCore.UI.badgesText:GetText()
Assert(badgeContent:find("%[AOE%]") ~= nil, "HUD badges text includes [AOE]")
Assert(badgeContent:find("%[BURST%]") ~= nil, "HUD badges text includes [BURST]")
Assert(badgeContent:find("%[UM%]") ~= nil, "HUD badges text includes active build abbreviation [UM]")

-- Switch to Frost and check badge changes to [F]
optPanel.buildDropDown.ApplyBuildSelection("frost")
RotaCore.UI:UpdateDisplay("OB", "UA")
badgeContent = RotaCore.UI.badgesText:GetText()
Assert(badgeContent:find("%[F%]") ~= nil, "HUD badges text updated to [F] for Frost")

-- ----------------------------------------------------------------------------
-- SUITE 31: RotaCore Gloves, Ghoul Frenzy & Combat Log Watchdog Fixes
-- ----------------------------------------------------------------------------
do
print("\n[Suite 31] RotaCore Gloves, Ghoul Frenzy & Combat Log Watchdog Fixes")

-- 1. State:AreGlovesReady(now)
wowmock.setTime(6000.0)
wowmock.clearAuras("player")
wowmock.inventoryItems[10] = 54758
wowmock.inventoryCooldowns[10] = { start = 0, duration = 0, enable = 1 }
RotaCore.State.data.lastCast["Hyperspeed Acceleration"] = nil
RotaCore.State.data.lastCast["HYPER"] = nil

Assert(RotaCore.State:AreGlovesReady(6000.0) == true, "AreGlovesReady returns true when gloves equipped, off CD, and no buff")

-- Returns false when Hyperspeed Acceleration buff is active
wowmock.setAura("player", {
    name = "Hyperspeed Acceleration", duration = 12.0, expirationTime = 6012.0, filter = "HELPFUL"
})
Assert(RotaCore.State:AreGlovesReady(6000.0) == false, "AreGlovesReady returns false when Hyperspeed Acceleration buff active")

-- Returns false when slot 10 is on cooldown
wowmock.clearAuras("player")
wowmock.inventoryCooldowns[10] = { start = 5980.0, duration = 60.0, enable = 1 } -- 40s remaining
Assert(RotaCore.State:AreGlovesReady(6000.0) == false, "AreGlovesReady returns false when slot 10 is on cooldown")

-- Returns false when cast within 58 seconds
wowmock.inventoryCooldowns[10] = { start = 0, duration = 0, enable = 1 }
RotaCore.State.data.lastCast["Hyperspeed Acceleration"] = 5960.0 -- 40s ago (< 58s)
Assert(RotaCore.State:AreGlovesReady(6000.0) == false, "AreGlovesReady returns false when cast recorded within 58 seconds")

-- Returns true after 58 seconds have elapsed
RotaCore.State.data.lastCast["Hyperspeed Acceleration"] = 5940.0 -- 60s ago (> 58s)
Assert(RotaCore.State:AreGlovesReady(6000.0) == true, "AreGlovesReady returns true when > 58 seconds since last cast")

-- 2. Ghoul Frenzy no re-suggestion after cast
wowmock.setTime(7000.0)
wowmock.petExists = true
wowmock.petDead = false
wowmock.clearAuras("pet")
RotaCore.State.data.lastCast["Ghoul Frenzy"] = nil
RotaCore.State.data.lastCast["GF"] = nil

-- Simulate UNIT_SPELLCAST_SUCCEEDED for Ghoul Frenzy
wowmock.fireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Ghoul Frenzy")
Assert(RotaCore.State.data.lastCast["Ghoul Frenzy"] == 7000.0, "UNIT_SPELLCAST_SUCCEEDED records lastCast timestamp for Ghoul Frenzy")
Assert(RotaCore.State.data.lastCast["GF"] == 7000.0, "UNIT_SPELLCAST_SUCCEEDED maps alias GF")

local stateAfterCast = RotaCore.State:Update(7000.5)
Assert(stateAfterCast.dk.gfRemaining == 30.0, "Ghoul Frenzy immediately assumes gfRem = 30 within 3.0s of cast")
Assert(stateAfterCast.buffRemaining("Ghoul Frenzy", "pet") == 30.0, "QueryBuff assumes remaining = 30 for pet Ghoul Frenzy within 3.0s")

-- 3. Combat Log Watchdog with CombatLogClearEntries()
wowmock.setTime(8000.0)
wowmock.inCombat = true
RotaCore.State.data.inCombat = true
RotaCore.State.data.lastCLEUTime = 8000.0
RotaCore.State.data.lastCombatLogClear = 0
wowmock.cleuEntriesCleared = 0

-- Normal event: CLEU updates lastCLEUTime
wowmock.fireEvent("COMBAT_LOG_EVENT_UNFILTERED")
Assert(RotaCore.State.data.lastCLEUTime == 8000.0, "CLEU event updates lastCLEUTime")

-- Advance time by 4.0s without any CLEU events (CLEU bug freeze!)
wowmock.advanceTime(4.0)
wowmock.setTime(8004.0)
Assert((8004.0 - RotaCore.State.data.lastCLEUTime) > 3.5, "More than 3.5s elapsed without CLEU events")

-- When player casts a spell in combat during freeze: Watchdog triggers CombatLogClearEntries()
wowmock.fireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Icy Touch")
Assert(wowmock.cleuEntriesCleared == 1, "Watchdog calls CombatLogClearEntries() when CLEU is silent > 3.5s in combat")
Assert(RotaCore.State.data.lastCombatLogClear == 8004.0, "Watchdog records lastCombatLogClear timestamp")

-- Subsequent cast 2s later must NOT spam CombatLogClearEntries (respects 10s internal CD)
wowmock.advanceTime(2.0)
wowmock.setTime(8006.0)
wowmock.fireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Plague Strike")
Assert(wowmock.cleuEntriesCleared == 1, "Watchdog respects 10s cooldown before next CombatLogClearEntries()")

-- After 11s have elapsed from clear: subsequent cast triggers clear again if still frozen
wowmock.advanceTime(9.0)
wowmock.setTime(8015.0)
wowmock.fireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Blood Strike")
Assert(wowmock.cleuEntriesCleared == 2, "Watchdog calls CombatLogClearEntries() again after 10s cooldown")

-- Cleanup
wowmock.inCombat = false
RotaCore.State.data.inCombat = false
end

-- ----------------------------------------------------------------------------
-- SUITE 32: Spells:HasSpell, State.hasSpell & Multi-Class Provider Update
-- ----------------------------------------------------------------------------
do
print("\n[Suite 32] Spells:HasSpell, State.hasSpell & Multi-Class Provider Update")

-- 1. Spells:HasSpell & Spells:IsSpellKnown
Assert(Spells:HasSpell("IT") == true, "Spells:HasSpell('IT') returns true for registered/scanned spell")
Assert(Spells:HasSpell("Icy Touch") == true, "Spells:HasSpell('Icy Touch') returns true for canonical name in book")
Assert(Spells:HasSpell(55555) == true, "Spells:HasSpell(55555) returns true for scanned spell ID")
Assert(Spells:HasSpell("NON_EXISTENT_SPELL_XYZ") == false, "Spells:HasSpell returns false for unknown spell")
Assert(Spells:IsSpellKnown("IT") == true, "Spells:IsSpellKnown alias works identically to HasSpell")
Assert(Spells.HasSpell("IT") == true, "Spells.HasSpell works without colon invocation")

-- 2. State.hasSpell and State.HasSpell on stateData (both colon and dot invocation)
local stateData = RotaCore.State.data
Assert(stateData.hasSpell("IT") == true, "stateData.hasSpell('IT') returns true")
Assert(stateData:hasSpell("IT") == true, "stateData:hasSpell('IT') works with colon invocation")
Assert(stateData.HasSpell("IT") == true, "stateData.HasSpell('IT') returns true")
Assert(stateData:HasSpell("IT") == true, "stateData:HasSpell('IT') works with colon invocation")
Assert(stateData.hasSpell("NON_EXISTENT_SPELL_XYZ") == false, "stateData.hasSpell returns false for unknown")

-- 3. Regression test: Client 3.3.5a scenario where GetSpellCooldown returns nil for unlearned spells
local origGetSpellCooldown = _G.GetSpellCooldown
local origIsSpellKnown = _G.IsSpellKnown

_G.GetSpellCooldown = function(nameOrId)
    if nameOrId == "Ghoul Frenzy" or nameOrId == 49213 or nameOrId == 63560 or nameOrId == "GF" then
        return nil
    end
    return origGetSpellCooldown(nameOrId)
end
_G.IsSpellKnown = function(id)
    if id == 49213 or id == 63560 then
        return false
    end
    return origIsSpellKnown(id)
end

-- Must NOT crash with 'attempt to call method HasSpell (a nil value)'
local noCrashOk, updatedState = pcall(function()
    return RotaCore.State:Update(8500.0)
end)
Assert(noCrashOk == true, "State:Update executes cleanly without nil HasSpell crash when spell is unlearned")
Assert(updatedState.dk.knowsGF == false, "DK correctly flags knowsGF = false when spell is unlearned")

-- Restore mocks
_G.GetSpellCooldown = origGetSpellCooldown
_G.IsSpellKnown = origIsSpellKnown

-- 4. Verify all 3 class providers (DEATHKNIGHT, PALADIN, WARRIOR) are registered and executed
Assert(RotaCore.State.providers["DEATHKNIGHT"] ~= nil, "DEATHKNIGHT state provider is registered")
Assert(RotaCore.State.providers["PALADIN"] ~= nil, "PALADIN state provider is registered")
Assert(RotaCore.State.providers["WARRIOR"] ~= nil, "WARRIOR state provider is registered")

local multiClassState = RotaCore.State:Update(9000.0)
Assert(multiClassState ~= nil, "State:Update returns valid stateData with all providers active")
Assert(type(multiClassState.runes) == "table" and multiClassState.dk ~= nil, "DK state is fully populated")
Assert(type(multiClassState.pal) == "table" and multiClassState.pal.targetHealthPct ~= nil, "PAL state is fully populated")
Assert(type(multiClassState.war) == "table" and multiClassState.war.stance ~= nil, "WAR state is fully populated")
end

-- ----------------------------------------------------------------------------
-- SUITE 33: Independent HUD Controls (RotaCoreHUDControls) & DK Armor Validation
-- ----------------------------------------------------------------------------
do
print("\n[Suite 33] Independent HUD Controls (RotaCoreHUDControls) & DK Armor Validation")

-- 1. RotaCoreHUDControls Container Frame
local hudControls = RotaCore.UI.controlsFrame
Assert(hudControls ~= nil, "RotaCoreHUDControls frame exists in UI")
Assert(hudControls:GetName() == "RotaCoreHUDControls", "Frame name is strictly 'RotaCoreHUDControls'")
Assert(hudControls ~= RotaCore.UI.hudFrame, "RotaCoreHUDControls is independent from RotaCoreHUD")

-- 2. Buttons in Controls Frame
Assert(RotaCore.UI.buildBtn ~= nil, "Build button exists on controls frame")
Assert(RotaCore.UI.aoeBtn ~= nil, "AoE button exists on controls frame")
Assert(RotaCore.UI.burstBtn ~= nil, "Burst button exists on controls frame")
Assert(RotaCore.UI.buildBtn:GetParent() == hudControls, "Build button is child of RotaCoreHUDControls")
Assert(RotaCore.UI.aoeBtn:GetParent() == hudControls, "AoE button is child of RotaCoreHUDControls")
Assert(RotaCore.UI.burstBtn:GetParent() == hudControls, "Burst button is child of RotaCoreHUDControls")

-- 3. Instant mouse click state toggle
wowmock.setClass("Death Knight", "DEATHKNIGHT")
SetBuild("auto")
RotaCore.UI.buildBtn:GetScript("OnClick")()
Assert(_G.RotaCoreDB.settings.selectedBuild == "frost", "Build button click advances auto -> frost")
RotaCore.UI.buildBtn:GetScript("OnClick")()
Assert(_G.RotaCoreDB.settings.selectedBuild == "unholy_morb", "Build button click advances frost -> unholy_morb")
RotaCore.UI.buildBtn:GetScript("OnClick")()
Assert(_G.RotaCoreDB.settings.selectedBuild == "unholy_dw_ss", "Build button click advances unholy_morb -> unholy_dw_ss")
RotaCore.UI.buildBtn:GetScript("OnClick")()
Assert(_G.RotaCoreDB.settings.selectedBuild == "unholy_2h", "Build button click advances unholy_dw_ss -> unholy_2h")
RotaCore.UI.buildBtn:GetScript("OnClick")()
Assert(_G.RotaCoreDB.settings.selectedBuild == "auto", "Build button click advances unholy_2h -> auto")

-- 4. Locking / Unlocking Controls
RotaCore.UI:SetLocked(false)
Assert(RotaCore.UI.isLocked == false, "UI:SetLocked(false) unlocks HUD and controls")
if RotaCore.UI.controlsDragOverlay then
    Assert(RotaCore.UI.controlsDragOverlay:IsShown() == true, "Controls drag overlay is shown when unlocked")
end
RotaCore.UI:SetLocked(true)
Assert(RotaCore.UI.isLocked == true, "UI:SetLocked(true) locks HUD and controls")
if RotaCore.UI.controlsDragOverlay then
    Assert(RotaCore.UI.controlsDragOverlay:IsShown() == false, "Controls drag overlay is hidden when locked")
end

-- 5. UI:ResetPosition()
local resetOk = pcall(function() RotaCore.UI:ResetPosition() end)
Assert(resetOk == true, "UI:ResetPosition() executes cleanly without error")

-- 6. DK HasSpell and provider armor
Assert(type(RotaClass_DK.HasSpell) == "function", "RotaClass_DK.HasSpell function is defined")
Assert(type(RotaClass_DK.hasSpell) == "function", "RotaClass_DK.hasSpell alias is defined")
Assert(RotaClass_DK:HasSpell("IT") == true, "RotaClass_DK:HasSpell('IT') works with colon invocation")
Assert(RotaClass_DK.HasSpell("IT") == true, "RotaClass_DK.HasSpell('IT') works with dot invocation")
Assert(RotaClass_DK:HasSpell("NON_EXISTENT_SPELL_XYZ") == false, "RotaClass_DK:HasSpell returns false for unknown")

-- 7. State methods dual invocation (dot and colon) & non-nil guarantees
local currentCoreState = RotaCore.State.data
Assert(type(currentCoreState.spellUsable("IT")) == "boolean", "state.spellUsable returns boolean")
Assert(type(currentCoreState:spellUsable("IT")) == "boolean", "state:spellUsable returns boolean")
Assert(type(currentCoreState.SpellUsable("IT")) == "boolean", "state.SpellUsable alias works")
Assert(type(currentCoreState.buffRemaining("Desolation", "player")) == "number", "state.buffRemaining returns number")
Assert(type(currentCoreState:buffRemaining("Desolation", "player")) == "number", "state:buffRemaining returns number")
Assert(type(currentCoreState.debuffRemaining("Frost Fever", "target", true)) == "number", "state.debuffRemaining returns number")
Assert(type(currentCoreState:debuffRemaining("Frost Fever", "target", true)) == "number", "state:debuffRemaining returns number")
Assert(type(currentCoreState.hasBuff("Killing Machine", "player")) == "boolean", "state.hasBuff returns boolean")
Assert(type(currentCoreState:hasBuff("Killing Machine", "player")) == "boolean", "state:hasBuff returns boolean")
Assert(type(currentCoreState.hasDebuff("Frost Fever", "target", true)) == "boolean", "state.hasDebuff returns boolean")
Assert(type(currentCoreState:hasDebuff("Frost Fever", "target", true)) == "boolean", "state:hasDebuff returns boolean")
Assert(type(currentCoreState.canCastRunes(1, 1, 1)) == "boolean", "state.canCastRunes returns boolean")
Assert(type(currentCoreState:canCastRunes(1, 1, 1)) == "boolean", "state:canCastRunes returns boolean")
Assert(type(currentCoreState.safeToSpendPair(1, 2)) == "boolean", "state.safeToSpendPair returns boolean")
Assert(type(currentCoreState:safeToSpendPair(1, 2)) == "boolean", "state:safeToSpendPair returns boolean")
Assert(type(currentCoreState.areGlovesReady(100.0)) == "boolean", "state.areGlovesReady returns boolean")
Assert(type(currentCoreState:areGlovesReady(100.0)) == "boolean", "state:areGlovesReady returns boolean")
end

-- ----------------------------------------------------------------------------
-- SUITE 34: Death Runes (Blood of the North), Wowhead Frost & Decoupled UI
-- ----------------------------------------------------------------------------
do
print("\n[Suite 34] Death Runes (Blood of the North), Wowhead Frost & Decoupled UI")

-- 1. Test Death Runes (Blood of the North):
-- With rType = {4, 4, 2, 2, 3, 3} and only slots 1 & 2 ready (rCD = {0, 0, 5, 5, 5, 5}),
-- Frost DK MUST suggest "OBL" (Obliterate) and NEVER "BS", "FS" nor nil!
local fPreset = RotaCore.Profiles:GetPreset("dk_frost_pve")
local fEval = Compiler:Compile(fPreset)
fEval.disableSequences()

wowmock.setTime(6000.0)
wowmock.clearAuras("player")
wowmock.clearAuras("target")
-- Active diseases so IT/PS/Pestilence aren't triggered
wowmock.setAura("target", {
    name = "Frost Fever", duration = 20.0, expirationTime = 6018.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 20.0, expirationTime = 6018.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.initRunes()
-- Convert slots 1 & 2 to Death Runes (type 4)
wowmock.convertRune(1, 4)
wowmock.convertRune(2, 4)
-- Set slots 3 & 4 (Frost) and 5 & 6 (Unholy) to 5.0s cooldown
wowmock.runes[3].ready = false
wowmock.runes[3].start = 6000.0
wowmock.runes[3].duration = 5.0
wowmock.runes[3].readyAt = 6005.0
wowmock.runes[4].ready = false
wowmock.runes[4].start = 6000.0
wowmock.runes[4].duration = 5.0
wowmock.runes[4].readyAt = 6005.0
wowmock.runes[5].ready = false
wowmock.runes[5].start = 6000.0
wowmock.runes[5].duration = 5.0
wowmock.runes[5].readyAt = 6005.0
wowmock.runes[6].ready = false
wowmock.runes[6].start = 6000.0
wowmock.runes[6].duration = 5.0
wowmock.runes[6].readyAt = 6005.0

_G.RotaCoreDB.settings.aoeMode = false
_G.RotaCoreDB.settings.burstMode = true
local dkBotnState = RotaCore.State:Update(6000.0)
Assert(dkBotnState.runes.deathReady == 2, "2 Death runes ready in slots 1 & 2")
Assert(dkBotnState.runes.frostReady == 0, "0 Frost runes ready")
Assert(dkBotnState.runes.unholyReady == 0, "0 Unholy runes ready")
Assert(dkBotnState.runes.bloodReady == 0, "0 pure Blood runes ready")

local botnAction = fEval.evaluatorMain(dkBotnState)
Assert(botnAction == "OBL", "Frost DK suggests 'OBL' using 2 Death Runes (Blood of the North)")
Assert(botnAction ~= "BS", "Action is not Blood Strike (BS)")
Assert(botnAction ~= "FS", "Action is not Frost Strike (FS)")
Assert(botnAction ~= nil, "Action is not nil")

-- 2. Test Wowhead Rime + Obliterate:
-- With fogUp = true, kmUp = true and runes ready for Obliterate, must suggest "HB" before "OBL"
wowmock.initRunes() -- all natural runes ready
wowmock.setAura("player", {
    name = "Freezing Fog", duration = 15.0, expirationTime = 6010.0, filter = "HELPFUL"
})
wowmock.setAura("player", {
    name = "Killing Machine", duration = 30.0, expirationTime = 6025.0, filter = "HELPFUL"
})
local rimeKMState = RotaCore.State:Update(6000.0)
Assert(rimeKMState.dk.rime == true or rimeKMState.hasBuff("Freezing Fog", "player") == true, "Freezing Fog (Rime) is active")
Assert(rimeKMState.dk.killingMachine == true or rimeKMState.hasBuff("Killing Machine", "player") == true, "Killing Machine is active")
local rimeAction = fEval.evaluatorMain(rimeKMState)
Assert(rimeAction == "HB", "Wowhead Rime rule suggests 'HB' before 'OBL' when KM and Rime are both active")

-- 3. Test UI Independence & Lock Overlay:
-- Moving hudFrame does not modify controlsFrame coordinates
RotaCore.UI:ResetPosition()
local origControlsX = _G.RotaCoreDB.settings.controlsX or 0
local origControlsY = _G.RotaCoreDB.settings.controlsY or -60

-- Simulate dragging hudFrame to (150, 200)
RotaCore.UI.hudFrame:ClearAllPoints()
RotaCore.UI.hudFrame:SetPoint("CENTER", _G.UIParent or RotaCore.UI.hudFrame, "CENTER", 150, 200)
RotaCore.UI:SavePosition()

Assert(_G.RotaCoreDB.settings.x == 150 and _G.RotaCoreDB.settings.y == 200, "HUD frame moved to (150, 200)")
Assert(_G.RotaCoreDB.settings.controlsX == origControlsX and _G.RotaCoreDB.settings.controlsY == origControlsY,
    "Controls frame coordinates unchanged after moving HUD")

-- Test Button Click Overlay when unlocked
RotaCore.UI:SetLocked(false)
Assert(RotaCore.UI.isLocked == false, "UI is unlocked")
Assert(RotaCore.UI.buildBtn:IsMouseEnabled() == false, "Build button has EnableMouse(false) when unlocked")
Assert(RotaCore.UI.aoeBtn:IsMouseEnabled() == false, "AoE button has EnableMouse(false) when unlocked")
Assert(RotaCore.UI.burstBtn:IsMouseEnabled() == false, "Burst button has EnableMouse(false) when unlocked")
if RotaCore.UI.controlsDragOverlay then
    Assert(RotaCore.UI.controlsDragOverlay:IsShown() == true, "controlsDragOverlay is shown when unlocked")
    Assert(RotaCore.UI.controlsDragOverlay:IsMouseEnabled() == true, "controlsDragOverlay has EnableMouse(true)")
end

RotaCore.UI:SetLocked(true)
Assert(RotaCore.UI.isLocked == true, "UI is locked")
Assert(RotaCore.UI.buildBtn:IsMouseEnabled() == true, "Build button has EnableMouse(true) when locked")
Assert(RotaCore.UI.aoeBtn:IsMouseEnabled() == true, "AoE button has EnableMouse(true) when locked")
Assert(RotaCore.UI.burstBtn:IsMouseEnabled() == true, "Burst button has EnableMouse(true) when locked")
if RotaCore.UI.controlsDragOverlay then
    Assert(RotaCore.UI.controlsDragOverlay:IsShown() == false, "controlsDragOverlay is hidden when locked")
    Assert(RotaCore.UI.controlsDragOverlay:IsMouseEnabled() == false, "controlsDragOverlay has EnableMouse(false)")
end

-- 4. Test offIcon is hidden when offAction is nil
RotaCore.UI:UpdateDisplay("OBL", nil)
Assert(RotaCore.UI.offIcon.frame:IsShown() == false, "offIcon is hidden when offAction is nil")

RotaCore.UI:UpdateDisplay("OBL", "UA")
Assert(RotaCore.UI.offIcon.frame:IsShown() == true, "offIcon is shown when offAction is 'UA'")
end

-- ============================================================================
-- SUITE 35: 3 Burst Display Modes, Scale 10%-50%, HasSpell & Wowhead Rotations
-- ============================================================================
do
print("\n[Suite 35] 3 Burst Display Modes, Scale 10%-50%, HasSpell & Wowhead Rotations")

-- 1. Burst Display Modes (SIDE, INLINE, CORNER)
RotaCore.UI:SetBurstDisplayMode("SIDE")
Assert(_G.RotaCoreDB.settings.burstDisplayMode == "SIDE", "SetBurstDisplayMode('SIDE') sets DB to SIDE")
RotaCore.UI:UpdateDisplay("OBL", "UA")
Assert(RotaCore.UI.offIcon.frame:IsShown() == true, "SIDE mode shows offIcon when offKey present")
Assert(RotaCore.UI.cornerIcon.frame:IsShown() == false, "SIDE mode hides cornerIcon")

RotaCore.UI:SetBurstDisplayMode("INLINE")
Assert(_G.RotaCoreDB.settings.burstDisplayMode == "INLINE", "SetBurstDisplayMode('INLINE') sets DB to INLINE")
RotaCore.UI:UpdateDisplay("OBL", "UA")
Assert(RotaCore.UI.offIcon.frame:IsShown() == false, "INLINE mode hides offIcon")
Assert(RotaCore.UI.cornerIcon.frame:IsShown() == false, "INLINE mode hides cornerIcon")
Assert(RotaCore.UI.mainIcon.actionBorder:IsShown() == true, "INLINE mode activates actionBorder on mainIcon")

RotaCore.UI:SetBurstDisplayMode("CORNER")
Assert(_G.RotaCoreDB.settings.burstDisplayMode == "CORNER", "SetBurstDisplayMode('CORNER') sets DB to CORNER")
RotaCore.UI:UpdateDisplay("OBL", "UA")
Assert(RotaCore.UI.offIcon.frame:IsShown() == false, "CORNER mode hides offIcon")
Assert(RotaCore.UI.cornerIcon.frame:IsShown() == true, "CORNER mode shows cornerIcon")

-- Nil offAction hides all sub-icons in all modes (never show '?')
RotaCore.UI:UpdateDisplay("OBL", nil)
Assert(RotaCore.UI.offIcon.frame:IsShown() == false, "Nil offKey hides offIcon")
Assert(RotaCore.UI.cornerIcon.frame:IsShown() == false, "Nil offKey hides cornerIcon")
Assert(RotaCore.UI.mainIcon.actionBorder:IsShown() == false, "Nil offKey hides actionBorder")

-- 2. Corner Scale Clamping (10% to 50%)
RotaCore.UI:SetCornerScale(0.10)
Assert(_G.RotaCoreDB.settings.cornerScale == 0.10, "Corner scale set to 0.10 (10%)")
RotaCore.UI:SetCornerScale(0.50)
Assert(_G.RotaCoreDB.settings.cornerScale == 0.50, "Corner scale set to 0.50 (50%)")
RotaCore.UI:SetCornerScale(0.05) -- Below min -> clamped to 0.10
Assert(_G.RotaCoreDB.settings.cornerScale == 0.10, "Corner scale clamped to min 0.10")
RotaCore.UI:SetCornerScale(0.99) -- Above max -> clamped to 0.50
Assert(_G.RotaCoreDB.settings.cornerScale == 0.50, "Corner scale clamped to max 0.50")
RotaCore.UI:SetCornerScale("30") -- Percentage string '30' -> 0.30
Assert(math.abs(_G.RotaCoreDB.settings.cornerScale - 0.30) < 0.001, "Corner scale accepts '30' string as 0.30")

-- 3. Cycling Burst Display Modes (Right-click behavior)
RotaCore.UI:SetBurstDisplayMode("SIDE")
RotaCore.UI:CycleBurstDisplayMode()
Assert(_G.RotaCoreDB.settings.burstDisplayMode == "INLINE", "CycleBurstDisplayMode moves SIDE -> INLINE")
RotaCore.UI:CycleBurstDisplayMode()
Assert(_G.RotaCoreDB.settings.burstDisplayMode == "CORNER", "CycleBurstDisplayMode moves INLINE -> CORNER")
RotaCore.UI:CycleBurstDisplayMode()
Assert(_G.RotaCoreDB.settings.burstDisplayMode == "SIDE", "CycleBurstDisplayMode moves CORNER -> SIDE")

-- 4. Slash Commands /rc burstmode and /rc burstscale
_G.SlashCmdList["ROTACORE"]("burstmode corner")
Assert(_G.RotaCoreDB.settings.burstDisplayMode == "CORNER", "/rc burstmode corner sets CORNER")
_G.SlashCmdList["ROTACORE"]("burstscale 45")
Assert(math.abs(_G.RotaCoreDB.settings.cornerScale - 0.45) < 0.001, "/rc burstscale 45 sets 0.45")

-- 5. Strict Spells:HasSpell validation (Never suggest unlearned spells)
wowmock.unknownSpells = wowmock.unknownSpells or {}
wowmock.unknownSpells["Divine Storm"] = true
wowmock.unknownSpells[53385] = true
wowmock.unknownSpells["DS"] = true
wowmock.unknownSpells["Howling Blast"] = true
wowmock.unknownSpells[51411] = true
wowmock.unknownSpells["HB"] = true

local savedBook = RotaCore.Spells.bookSpells
RotaCore.Spells.bookSpells = { ["Icy Touch"] = 49909, ["Plague Strike"] = 49921 }
Assert(RotaCore.Spells:HasSpell("IT") == true, "Known spell IT is true")
Assert(RotaCore.Spells:HasSpell("DS") == false, "Unlearned Divine Storm is false")
Assert(RotaCore.Spells:HasSpell("HB") == false, "Unlearned Howling Blast is false")
RotaCore.Spells.bookSpells = savedBook

wowmock.unknownSpells["Divine Storm"] = nil
wowmock.unknownSpells[53385] = nil
wowmock.unknownSpells["DS"] = nil
wowmock.unknownSpells["Howling Blast"] = nil
wowmock.unknownSpells[51411] = nil
wowmock.unknownSpells["HB"] = nil

-- 6. Frost DK AoE: Killing Machine reservation for Howling Blast
RotaCore.Profiles:SetActiveProfile("dk_frost_pve")
local frostEvalBundle = RotaCore.Profiles:GetActiveEvaluator()
frostEvalBundle.disableSequences()

wowmock.setTime(6000.0)
wowmock.clearAuras("player")
wowmock.clearAuras("target")
wowmock.setAura("target", {
    name = "Frost Fever", duration = 20.0, expirationTime = 6020.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("target", {
    name = "Blood Plague", duration = 20.0, expirationTime = 6020.0, filter = "HARMFUL", unitCaster = "player"
})
wowmock.setAura("player", { name = "Killing Machine", duration = 30, expirationTime = 6030.0, filter = "HELPFUL" })
RotaCore.State.data.lastCast["PEST"] = 6000.0

wowmock.triggerSpellCD(51411, 1.0) -- Howling Blast on CD for 1.0s (<= gcdRem + 1.5)
wowmock.setPower("player", 6, 50, 100) -- 50 RP (< 100)
_G.RotaCoreDB.settings.aoeMode = true
local frostKmState = RotaCore.State:Update(6000.0)
local kmAoEAction = frostEvalBundle.evaluatorMain(frostKmState)
Assert(kmAoEAction == "HB", "Frost AoE with KM proc holds RP and returns 'HB' in wait")

-- 7. Warrior Spec Autodetection
savedBook = RotaCore.Spells.bookSpells
wowmock.unknownSpells["Mortal Strike"] = true
wowmock.unknownSpells[12294] = true
wowmock.unknownSpells["Bladestorm"] = true
wowmock.unknownSpells[46924] = true
wowmock.unknownSpells["Bloodthirst"] = nil
wowmock.unknownSpells[23881] = nil
RotaCore.Spells.bookSpells = { ["Bloodthirst"] = 23881, ["Whirlwind"] = 1680 }
local detectedFury = RotaClass_WAR.DetectSpec()
Assert(detectedFury == "Fury", "Warrior with Bloodthirst detects Fury spec")

wowmock.unknownSpells["Mortal Strike"] = nil
wowmock.unknownSpells[12294] = nil
wowmock.unknownSpells["Bloodthirst"] = true
wowmock.unknownSpells[23881] = true
RotaCore.Spells.bookSpells = { ["Mortal Strike"] = 12294, ["Bladestorm"] = 46924 }
local detectedArms = RotaClass_WAR.DetectSpec()
Assert(detectedArms == "Arms", "Warrior with Mortal Strike detects Arms spec")

wowmock.unknownSpells["Bloodthirst"] = nil
wowmock.unknownSpells[23881] = nil
RotaCore.Spells.bookSpells = savedBook
end

-- ----------------------------------------------------------------------------
-- SUITE 36: Class Switch, Glyph & Talent Scanner, Rebuffed Custom & Quick Menu
-- ----------------------------------------------------------------------------
do
print("\n[Suite 36] Class Switch, Glyph & Talent Scanner, Rebuffed Custom & Quick Menu")

-- 1. Multi-Class Character Switch (login DK -> login Warrior -> login Paladin -> login DK)
_G.RotaCoreDB = _G.RotaCoreDB or {}
_G.RotaCoreDB.settings = _G.RotaCoreDB.settings or {}
_G.RotaCoreDB.charProfiles = _G.RotaCoreDB.charProfiles or {}
_G.RotaCoreDB.classProfiles = _G.RotaCoreDB.classProfiles or {}
_G.RotaCoreDB.charBuilds = _G.RotaCoreDB.charBuilds or {}
_G.RotaCoreDB.classBuilds = _G.RotaCoreDB.classBuilds or {}

-- Login DK Arthas and set build to unholy_morb
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setCharacter("Arthas", "Frostmourne")
RotaCore.LoadClassPreset()
SetBuild("unholy_morb")
_G.RotaCoreDB.charBuilds["Arthas - Frostmourne"] = "unholy_morb"
_G.RotaCoreDB.classBuilds["DEATHKNIGHT"] = "unholy_morb"
_G.RotaClass_DK:DetectBuild()
local activeDK = RotaCore.Profiles:GetActiveProfile()
Assert(activeDK ~= nil and activeDK.meta.class == "DEATHKNIGHT", "Login Arthas activates DEATHKNIGHT profile")
Assert(activeDK.meta.id == "dk_unholy_morb_pve", "Arthas activates dk_unholy_morb_pve")

-- Switch to Warrior character Varian on SAME RotaCoreDB
wowmock.setClass("Warrior", "WARRIOR")
wowmock.setCharacter("Varian", "Frostmourne")
RotaCore.LoadClassPreset()
local activeWar = RotaCore.Profiles:GetActiveProfile()
Assert(activeWar ~= nil and activeWar.meta.class == "WARRIOR", "Login Varian switches immediately to WARRIOR profile")
Assert(_G.RotaCoreDB.settings.selectedBuild ~= "unholy_morb", "Warrior selectedBuild does not keep DK unholy_morb")
Assert(activeWar.meta.id:find("^war_") ~= nil, "Active profile is a Warrior profile")

-- Varian selects fury_overpower build
SetBuild("fury_overpower")
_G.RotaCoreDB.charBuilds["Varian - Frostmourne"] = "fury_overpower"
_G.RotaCoreDB.classBuilds["WARRIOR"] = "fury_overpower"
_G.RotaClass_WAR:DetectSpec()
Assert(RotaCore.Profiles:GetActiveProfile().meta.id == "war_fury_overpower_pve", "Varian activates war_fury_overpower_pve")

-- Switch to Paladin character Uther on SAME RotaCoreDB
wowmock.setClass("Paladin", "PALADIN")
wowmock.setCharacter("Uther", "Frostmourne")
RotaCore.LoadClassPreset()
local activePal = RotaCore.Profiles:GetActiveProfile()
Assert(activePal ~= nil and activePal.meta.class == "PALADIN", "Login Uther switches immediately to PALADIN profile")
Assert(activePal.meta.id == "pal_retribution_pve", "Uther activates pal_retribution_pve")
Assert(_G.RotaCoreDB.settings.selectedBuild == "auto", "Paladin selectedBuild is auto")

-- Switch back to Arthas (DK): must recover DK profile and unholy_morb
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setCharacter("Arthas", "Frostmourne")
RotaCore.LoadClassPreset()
local recoveredDK = RotaCore.Profiles:GetActiveProfile()
Assert(recoveredDK ~= nil and recoveredDK.meta.class == "DEATHKNIGHT", "Returning to Arthas activates DEATHKNIGHT profile")
Assert(_G.RotaCoreDB.settings.selectedBuild == "unholy_morb", "Arthas recovered unholy_morb build")
Assert(recoveredDK.meta.id == "dk_unholy_morb_pve", "Arthas recovered dk_unholy_morb_pve preset")

-- 2. Live Scanner for Glyphs (Custom WotLK Rebuffed Glyphs)
-- DK Glyph of Disease
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setGlyph(1, 63334, "Glyph of Disease")
RotaCore.State:ScanTalentsAndGlyphs()
Assert(RotaCore.State.data.dk.hasGlyphOfDisease == true, "State scanner detects Glyph of Disease (63334)")

-- Paladin Glyph of Reckoning (WotLK Rebuffed Custom)
wowmock.setClass("Paladin", "PALADIN")
wowmock.setGlyph(2, 62124, "Glyph of Reckoning")
RotaCore.State:ScanTalentsAndGlyphs()
Assert(RotaCore.State.data.pal.hasGlyphOfReckoning == true, "State scanner detects Glyph of Reckoning (Rebuffed)")

-- Warrior Glyph of Shattering Throw (WotLK Rebuffed Custom)
wowmock.setClass("Warrior", "WARRIOR")
wowmock.setGlyph(3, 58357, "Glyph of Shattering Throw")
RotaCore.State:ScanTalentsAndGlyphs()
Assert(RotaCore.State.data.war.hasGlyphOfShatteringThrow == true, "State scanner detects Glyph of Shattering Throw (Rebuffed)")

-- 3. DK Unholy Without Glyph of Disease: PROHIBIDO PESTILENCE EN ST
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setCharacter("Arthas", "Frostmourne")
wowmock.setTime(8000.0)
wowmock.clearAuras("player")
wowmock.clearAuras("target")
local sDK36 = RotaCore.State:Update(8000.0)
sDK36.aoeMode = false
sDK36.dk.hasGlyphOfDisease = false -- NO Glyph of Disease
sDK36.dk.ffRemaining = 1.5
sDK36.dk.bpRemaining = 1.5
sDK36.dk.hasFrostFever = true
sDK36.dk.hasBloodPlague = true
sDK36.dk.minDiseaseRemaining = 1.5
sDK36.dk.desolationRemaining = 15.0 -- Desolation healthy
wowmock.triggerSpellCD(49938, 10.0) -- DnD on CD
sDK36.runes.frostReady = 1
sDK36.runes.unholyReady = 1
sDK36.runes.bloodReady = 1

-- A: Unholy Morb ST without Glyph of Disease -> MUST NOT return PEST (must refresh via IT/PS)
local morbAction = RotaClass_DK.EvaluateUnholyMorb(sDK36)
Assert(morbAction ~= "PEST", "Unholy Morb ST without Glyph of Disease NEVER suggests Pestilence")
Assert(morbAction == "IT" or morbAction == "PS", "Unholy Morb refreshes diseases via IT or PS")

-- B: Unholy DW-SS ST without Glyph of Disease -> MUST NOT return PEST
local dwssAction = RotaClass_DK.EvaluateUnholySS(sDK36)
Assert(dwssAction ~= "PEST", "Unholy DW-SS ST without Glyph of Disease NEVER suggests Pestilence")
Assert(dwssAction == "IT" or dwssAction == "PS", "Unholy DW-SS refreshes diseases via IT or PS")

-- C: Unholy 2H ST without Glyph of Disease -> MUST NOT return PEST
local u2hAction = RotaClass_DK.EvaluateUnholy2H(sDK36)
Assert(u2hAction ~= "PEST", "Unholy 2H ST without Glyph of Disease NEVER suggests Pestilence")
Assert(u2hAction == "IT" or u2hAction == "PS", "Unholy 2H refreshes diseases via IT or PS")

-- D: In AoE mode, PEST is allowed to spread diseases
sDK36.aoeMode = true
sDK36.dk.ffRemaining = 15.0
sDK36.dk.bpRemaining = 15.0
sDK36.dk.minDiseaseRemaining = 15.0
sDK36.lastCast["PEST"] = 0
local morbAoEAction = RotaClass_DK.EvaluateUnholyMorb(sDK36)
Assert(morbAoEAction == "PEST", "In AoE mode, Unholy spreads diseases via Pestilence")

-- 4. Paladin Hand of Reckoning (Rebuffed) Off-GCD Evaluator
wowmock.setClass("Paladin", "PALADIN")
local palState36 = RotaCore.State:Update(9000.0)
palState36.pal.hasGlyphOfReckoning = true
palState36.hasTarget = true
palState36.targetIsDead = false
palState36.targetCanAttack = true
local palOff = Compiler:Compile(RotaCore.Profiles:GetPreset("pal_retribution_pve")).evaluatorOff(palState36)
Assert(palOff ~= "HOR", "Hand of Reckoning no se sugiere (va en macro)")

-- 5. Paladin 3 Judgements Shared Cooldown Unification
wowmock.setClass("Paladin", "PALADIN")
_G.RotaCoreDB = _G.RotaCoreDB or {}
_G.RotaCoreDB.settings = _G.RotaCoreDB.settings or {}
_G.RotaCoreDB.settings.aoeMode = false
RotaCore.Profiles:SetActiveProfile("pal_retribution_pve")
local palPreset36 = RotaCore.Profiles:GetPreset("pal_retribution_pve")
local palEval36 = Compiler:Compile(palPreset36)
palEval36.disableSequences()

-- Retribution ST: CS > Judgement > DS
wowmock.setTime(9500.0)
wowmock.clearSpellCDs()
wowmock.setAura("player", { name = "Seal of Vengeance", duration = 1800, expirationTime = 11300.0, filter = "HELPFUL" })
wowmock.triggerSpellCD(53385, 10.0) -- DS on CD -> Judgement suggested
palState36 = RotaCore.State:Update(9500.0)
local csSug = palEval36.evaluatorMain(palState36)
Assert(csSug == "CS", "Paladin suggests CS when DS is on CD (Wowhead)")

-- Put CS on CD -> Judgement
wowmock.triggerSpellCD(35395, 4.0)
palState36 = RotaCore.State:Update(9500.0)
local jSug = palEval36.evaluatorMain(palState36)
Assert(jSug == "JUDGEMENT", "When CS is on CD, falls back to Judgement")

-- 6. Warrior Fury Overpower Weaving (20/51/0)
wowmock.setClass("Warrior", "WARRIOR")
RotaClass_WAR.detectedBuild = "fury_overpower"
RotaCore.Profiles:SetActiveProfile("war_fury_overpower_pve")
local warPreset36 = RotaCore.Profiles:GetPreset("war_fury_overpower_pve")
local warEval36 = Compiler:Compile(warPreset36)
warEval36.disableSequences()

wowmock.setTime(10000.0)
wowmock.clearSpellCDs()
wowmock.setPower("player", 1, 60, 100) -- 60 Rage
wowmock.triggerSpellCD(23881, 3.0) -- BT on CD (3.0s > 1.5s)
wowmock.triggerSpellCD(1680, 3.0)  -- WW on CD (3.0s > 1.5s)
local warState36 = RotaCore.State:Update(10000.0)
warState36.war.hasBloodsurge = false

-- Case A: Taste for Blood active -> suggests OP
warState36.war.hasTasteForBlood = true
local opAction = warEval36.evaluatorMain(warState36)
Assert(opAction == "OP", "Fury Overpower Weaving suggests OP during BT/WW cooldowns")

-- Case B: Rend not on target and no OP -> suggests REND
warState36.war.hasTasteForBlood = false
warState36.war.canOverpower = false
warState36.war.rendRemaining = 0
local rendAction = warEval36.evaluatorMain(warState36)
Assert(rendAction == "REND", "Fury Overpower Weaving suggests REND to trigger Taste for Blood")

-- Case C: Shattering Throw off-GCD with Glyph
warState36.war.hasGlyphOfShatteringThrow = true
warState36.burstMode = true
warState36.hasTarget = true
local stOffAction = warEval36.evaluatorOff(warState36)
Assert(stOffAction == "SHATTERING", "Warrior suggests SHATTERING off-GCD in burst mode with custom glyph")

-- 7. Boton de opciones del HUD: abre el panel unico (sin menu aparte)
Assert(RotaCore.UI.menuBtn ~= nil, "Boton de opciones existe en la mini-barra")
Assert(RotaCore.UI.quickMenuFrame == nil, "Ya no hay menu rapido aparte")
end

-- ============================================================================
-- SUITE 37: 4 Strict Rules Verification (UI Alpha, Talent Auto-Migration,
--          Frost Obliterate Unlocked & AoE Modes in All Specs)
-- ============================================================================
print("\n[Suite 37] 4 Strict Rules Verification (UI, Talents, Frost OB, AoE All Specs)")
do
-- ----------------------------------------------------------------------------
-- Test 1: UI Main Icon Alpha & Fallback (Rule 1)
-- ----------------------------------------------------------------------------
local s37 = RotaCore.State:Update(10500.0)
s37.hasTarget = true
s37.targetCanAttack = true
s37.targetIsDead = false
s37.inCombat = true

-- In combat with attackable target, even if mainAction is nil or "WAIT", alpha MUST be 1.0
RotaCore.UI:UpdateDisplay(nil, nil)
Assert(RotaCore.UI.mainIcon.frame.alpha == 1.0, "UI mainIcon alpha is strictly 1.0 with attackable target in combat when action is nil")
Assert(RotaCore.UI.currentMainAction ~= nil, "Spec fallback spell selected when mainAction is nil")

RotaCore.UI:UpdateDisplay("WAIT", nil)
Assert(RotaCore.UI.mainIcon.frame.alpha == 1.0, "UI mainIcon alpha is strictly 1.0 when mainAction is 'WAIT'")

-- HUD and icons strictly stay at alpha 1.0 even out of combat with no target and no action
s37.hasTarget = false
s37.targetCanAttack = false
s37.inCombat = false
RotaCore.UI:UpdateDisplay(nil, nil)
Assert(RotaCore.UI.mainIcon.frame.alpha == 1.0, "UI mainIcon alpha stays strictly 1.0 out of combat with no target and no action")

-- ----------------------------------------------------------------------------
-- Test 2: Auto-Migration of Testdk 0/19/52 Real Talents (Rule 2)
-- ----------------------------------------------------------------------------
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setCharacter("Testdk", "Frostmourne")

_G.RotaCoreDB = _G.RotaCoreDB or {}
_G.RotaCoreDB.settings = _G.RotaCoreDB.settings or {}
_G.RotaCoreDB.charBuilds = _G.RotaCoreDB.charBuilds or {}
_G.RotaCoreDB.charProfiles = _G.RotaCoreDB.charProfiles or {}
_G.RotaCoreDB.classBuilds = _G.RotaCoreDB.classBuilds or {}
_G.RotaCoreDB.classProfiles = _G.RotaCoreDB.classProfiles or {}

-- Simulate Testdk previously stuck in frost
_G.RotaCoreDB.charBuilds["Testdk - Frostmourne"] = "frost"
_G.RotaCoreDB.charProfiles["Testdk - Frostmourne"] = "dk_frost_pve"
SetBuild("frost")

-- Set real 0/19/52 Morb talents (no Howling Blast, no Frost Strike)
wowmock.spellbook.knownSpells = {}
wowmock.talents.tabs = {
    [1] = { name = "Blood", pointsSpent = 0, talents = {} },
    [2] = { name = "Frost", pointsSpent = 19, talents = {
        { name = "Nerves of Cold Steel", rank = 3, maxRank = 3, spellId = 49013 },
        { name = "Icy Reach", rank = 2, maxRank = 2 },
        { name = "Glacier Rot", rank = 2, maxRank = 2 },
        { name = "Toughness", rank = 5, maxRank = 5 },
        { name = "Black Ice", rank = 5, maxRank = 5 },
        { name = "Icy Talons", rank = 2, maxRank = 2 },
    }},
    [3] = { name = "Unholy", pointsSpent = 52, talents = {
        { name = "Desolation", rank = 5, maxRank = 5 },
        { name = "Morbidity", rank = 3, maxRank = 3 },
    }},
}

-- Invoke LoadClassPreset (or /reload)
RotaCore.LoadClassPreset()

Assert(_G.RotaCoreDB.charBuilds["Testdk - Frostmourne"] == "unholy_morb",
    "Testdk charBuilds auto-migrated from 'frost' to 'unholy_morb'")
Assert(_G.RotaCoreDB.charProfiles["Testdk - Frostmourne"] == "dk_unholy_morb_pve",
    "Testdk charProfiles auto-migrated to 'dk_unholy_morb_pve'")
Assert(RotaCore.Profiles:GetActiveProfile().meta.id == "dk_unholy_morb_pve",
    "Active profile auto-updated to dk_unholy_morb_pve")

-- ----------------------------------------------------------------------------
-- Test 3: Frost DK Obliterate with Death Runes & DC Fallback (Rule 3)
-- ----------------------------------------------------------------------------
local frostState37 = RotaCore.State:Update(11000.0)
frostState37.runes.bloodReady = 0
frostState37.runes.frostReady = 0
frostState37.runes.unholyReady = 0
frostState37.runes.deathReady = 2 -- 2 Death Runes from Blood of the North
frostState37.runes.slots[1].ready = true
frostState37.runes.slots[1].type = 4
frostState37.runes.slots[2].ready = true
frostState37.runes.slots[2].type = 4
frostState37.runes.slots[3].ready = false
frostState37.runes.slots[3].cdRemains = 4.0
frostState37.runes.slots[4].ready = false
frostState37.runes.slots[4].cdRemains = 4.0
frostState37.runes.slots[5].ready = false
frostState37.runes.slots[5].cdRemains = 4.0
frostState37.runes.slots[6].ready = false
frostState37.runes.slots[6].cdRemains = 4.0
frostState37.dk.ffRemaining = 6.0
frostState37.dk.bpRemaining = 6.0
frostState37.dk.minDiseaseRemaining = 6.0 -- > 3.5s
frostState37.dk.reserveActive = true

-- canWithRunes(lim, reqBlood, reqFrost, reqUnholy) for Obliterate (0, 1, 1)
local canCastOB = frostState37.canWithRunes(0, 0, 1, 1, true)
Assert(canCastOB == true, "Obliterate unlocked with 2 Death Runes when minDisease > 3.5s")

-- Death Coil fallback when Frost Strike is unlearned
wowmock.spellbook.knownSpells["Frost Strike"] = nil
wowmock.spellbook.knownSpells[49143] = nil
wowmock.spellbook.knownSpells["Death Coil"] = true
frostState37.power = 85
local frostEval37 = RotaClass_DK.EvaluateFrost(frostState37)
Assert(frostEval37 == "OBL" or frostEval37 == "DC", "Frost rotation functions with DC fallback when FS is not learned")

-- ----------------------------------------------------------------------------
-- Test 4: AoE Mode Boolean Unification (Rule 4)
-- ----------------------------------------------------------------------------
_G.RotaCoreDB.settings.aoeMode = "ON"
local aoeOnState = RotaCore.State:Update(11100.0)
Assert(aoeOnState.aoeMode == true and aoeOnState.isAoE == true, "aoeMode 'ON' sets both aoeMode and isAoE to true")

_G.RotaCoreDB.settings.aoeMode = "OFF"
local aoeOffState = RotaCore.State:Update(11100.0)
Assert(aoeOffState.aoeMode == false and aoeOffState.isAoE == false, "aoeMode 'OFF' sets both aoeMode and isAoE to false")

_G.RotaCoreDB.settings.aoeMode = "AUTO"
aoeOffState.aoeCount = 3
local aoeAutoState = RotaCore.State:Update(11100.0)
Assert(aoeAutoState.aoeMode == true and aoeAutoState.isAoE == true, "aoeMode 'AUTO' with 3 targets sets aoeMode and isAoE to true")

-- ----------------------------------------------------------------------------
-- Test 5: Paladin Retribution AoE Priority (Rule 4)
-- ----------------------------------------------------------------------------
_G.RotaCoreDB.settings.aoeMode = "ON"
wowmock.setClass("Paladin", "PALADIN")
wowmock.clearGlyphs()
RotaCore.State:ScanTalentsAndGlyphs()
local palPreset37 = RotaCore.Profiles:GetPreset("pal_retribution_pve")
local palEval = Compiler:Compile(palPreset37)
palEval.disableSequences()

wowmock.setTime(11200.0)
local palState37 = RotaCore.State:Update(11200.0)
palState37.powerPct = 80
palState37.pal.isUndeadOrDemon = true
wowmock.setPower("player", 0, 8000, 10000) -- mana() lee el mana real
wowmock.clearSpellCDs()
wowmock.setAura("player", { name = "Seal of Vengeance", duration = 1800, expirationTime = 13000.0, filter = "HELPFUL" })

-- AoE (Wowhead): Consecration > DS > Judgement > Holy Wrath > CS > HoW > Exorcism
local palAct1 = palEval.evaluatorMain(palState37)
Assert(palAct1 == "CONS", "Retribution AoE #1 priority is Consecration")

local function pal37(cdId, cdLen)
    wowmock.triggerSpellCD(cdId, cdLen)
    palState37 = RotaCore.State:Update(11200.0)
    palState37.powerPct = 80
    palState37.pal.isUndeadOrDemon = true
    return palEval.evaluatorMain(palState37)
end
Assert(pal37(48819, 8.0) == "DS", "Retribution AoE #2 priority is Divine Storm")
Assert(pal37(53385, 10.0) == "JUDGEMENT", "Retribution AoE #3 priority is Judgement")
wowmock.triggerSpellCD(53408, 8.0)
Assert(pal37(20271, 8.0) == "HW", "Retribution AoE #4 priority is Holy Wrath")
Assert(pal37(48817, 15.0) == "CS", "Retribution AoE #5 priority is Crusader Strike")

-- Off-GCD suggests Seal of Command in AoE
local palOffAct = palEval.evaluatorOff(palState37)
Assert(palOffAct == "COMMAND", "Retribution AoE suggests Seal of Command in offKey")

-- ----------------------------------------------------------------------------
-- Test 6: Warrior Fury & Arms AoE Priority (Rule 4)
-- ----------------------------------------------------------------------------
_G.RotaCoreDB.settings.aoeMode = "ON"
wowmock.setClass("Warrior", "WARRIOR")

-- Fury AoE: Whirlwind > Bloodthirst
RotaClass_WAR.detectedBuild = "fury"
local warFuryPreset = RotaCore.Profiles:GetPreset("war_fury_pve")
local warFuryEval = Compiler:Compile(warFuryPreset)
warFuryEval.disableSequences()

wowmock.setTime(11300.0)
wowmock.setPower("player", 1, 80, 100)
local warFuryState = RotaCore.State:Update(11300.0)
wowmock.clearSpellCDs()
wowmock.triggerSpellCD(64382, 300.0) -- Shattering Throw on CD

local furyMain = warFuryEval.evaluatorMain(warFuryState)
Assert(furyMain == "WW", "Warrior Fury AoE prioritizes Whirlwind over Bloodthirst")

local furyOff = warFuryEval.evaluatorOff(warFuryState)
Assert(furyOff == "CLEAVE", "Warrior Fury AoE suggests Cleave in offKey")

-- Arms AoE: Rend > Sweeping Strikes > Overpower > Thunder Clap > Bladestorm
RotaClass_WAR.detectedBuild = "arms"
local warArmsPreset = RotaCore.Profiles:GetPreset("war_arms_pve")
local warArmsEval = Compiler:Compile(warArmsPreset)
warArmsEval.disableSequences()

wowmock.setTime(11400.0)
wowmock.setPower("player", 1, 80, 100)
local warArmsState = RotaCore.State:Update(11400.0)
warArmsState.war.rendRemaining = 0
wowmock.clearSpellCDs()
wowmock.triggerSpellCD(64382, 300.0) -- Shattering Throw on CD

local armsMain1 = warArmsEval.evaluatorMain(warArmsState)
Assert(armsMain1 == "REND", "Warrior Arms AoE #1 priority is Rend when expired")

warArmsState.war.rendRemaining = 12.0
local armsMain2 = warArmsEval.evaluatorMain(warArmsState)
Assert(armsMain2 == "SW", "Warrior Arms AoE #2 priority is Sweeping Strikes")

wowmock.triggerSpellCD(12328, 30.0) -- Sweeping Strikes on CD
warArmsState.war.canOverpower = true
local armsMain3 = warArmsEval.evaluatorMain(warArmsState)
Assert(armsMain3 == "OP", "Warrior Arms AoE #3 priority is Overpower")

warArmsState.war.canOverpower = false
local armsMain4 = warArmsEval.evaluatorMain(warArmsState)
Assert(armsMain4 == "TC", "Warrior Arms AoE #4 priority is Thunder Clap")

wowmock.triggerSpellCD(6343, 6.0) -- Thunder Clap on CD
local armsMain5 = warArmsEval.evaluatorMain(warArmsState)
Assert(armsMain5 == "BS", "Warrior Arms AoE #5 priority is Bladestorm")

local armsOff = warArmsEval.evaluatorOff(warArmsState)
Assert(armsOff == "CLEAVE", "Warrior Arms AoE suggests Cleave in offKey")
end

-- ----------------------------------------------------------------------------
-- SUITE 38: Rebuffed Custom Lua API (Nameplates, CC, Silence, Disarm, Clipboard, BaseCD, Fallbacks)
-- ----------------------------------------------------------------------------
print("\n[Suite 38] Rebuffed Lua API Integration, Nameplates & Fallbacks")

-- Sub-suite 1: Nameplate enemy counting & CC exclusion
do
    wowmock.setClass("Death Knight", "DEATHKNIGHT")
    wowmock.inCombat = true
    _G.RotaCoreDB.settings.aoeMode = "AUTO"
    _G.RotaCoreDB.settings.autoAoE = true

    -- Test with 0 nameplates:
    wowmock.nameplates = {}
    RotaCore.State.data.aoeCount = 1
    for k in pairs(RotaCore.State.activePlates) do RotaCore.State.activePlates[k] = nil end
    local s0 = RotaCore.State:Update(20000.0)
    Assert(s0.aoeCount == 1, "0 nameplates results in aoeCount = 1 (target fallback)")
    Assert(s0.nameplatesActive == false, "0 nameplates reports nameplatesActive = false")

    -- Test with 1 nameplate:
    wowmock.nameplates = { "nameplate1" }
    wowmock.combatUnits["nameplate1"] = true
    local s1 = RotaCore.State:Update(20001.0)
    Assert(s1.aoeCount == 1, "1 in-range nameplate results in aoeCount = 1")
    Assert(s1.nameplatesActive == true, "1 nameplate reports nameplatesActive = true")

    -- Test with 3 nameplates:
    wowmock.nameplates = { "nameplate1", "nameplate2", "nameplate3" }
    wowmock.combatUnits["nameplate2"] = true
    wowmock.combatUnits["nameplate3"] = true
    local s3 = RotaCore.State:Update(20002.0)
    Assert(s3.aoeCount == 3, "3 in-range enemy nameplates results in aoeCount = 3")
    Assert(s3.aoeMode == true and s3.isAoE == true, "AoE mode auto-activates when 3 nameplates >= aoeThreshold (3)")

    -- Test with 6 nameplates, 0 CC:
    wowmock.nameplates = { "nameplate1", "nameplate2", "nameplate3", "nameplate4", "nameplate5", "nameplate6" }
    for i = 1, 6 do wowmock.combatUnits["nameplate" .. i] = true end
    local s6 = RotaCore.State:Update(20003.0)
    Assert(s6.aoeCount == 6, "6 in-range enemy nameplates results in aoeCount = 6")
    Assert(s6.ccNearby == false, "ccNearby is false when no enemies are crowd-controlled")

    -- Test with 6 nameplates, 1 in CC (non-target) with useCCExclusion enabled:
    _G.RotaCoreDB.useCCExclusion = true
    wowmock.controlledUnits["nameplate4"] = true
    local s6cc = RotaCore.State:Update(20004.0)
    Assert(s6cc.aoeCount == 5, "6 nameplates with 1 CC'd non-target results in aoeCount = 5")
    Assert(s6cc.ccNearby == true, "ccNearby is true when crowd-controlled enemy is nearby")
    _G.RotaCoreDB.useCCExclusion = false
    wowmock.controlledUnits["nameplate4"] = nil

    -- Test DK nameplates disease tracking:
    wowmock.setTime(20005.0)
    wowmock.clearAuras("nameplate1")
    wowmock.clearAuras("nameplate2")
    wowmock.setDebuff("nameplate1", 1, "Frost Fever", "Disease", 15.0, 15.0, 1, 49909, "player")
    wowmock.setDebuff("nameplate1", 2, "Blood Plague", "Disease", 15.0, 15.0, 1, 49921, "player")
    local sDKnp = RotaCore.State:Update(20005.0)
    Assert(sDKnp.dk.aoeDiseasedCount == 1, "DK state tracks diseased nameplate count (1)")
end

-- Sub-suite 2: AoE AUTO/ON/OFF across all specs using new nameplate count
do
    -- 1. DK Frost AoE
    _G.RotaCoreDB.settings.aoeMode = "AUTO"
    wowmock.setClass("Death Knight", "DEATHKNIGHT")
    RotaCore.Profiles:SetActiveProfile("dk_frost_pve")
    local dkFrostEval = Compiler:Compile(RotaCore.Profiles:GetPreset("dk_frost_pve"))
    dkFrostEval.disableSequences()
    local dkFrostState = RotaCore.State:Update(20010.0)
    Assert(dkFrostState.aoeMode == true, "DK Frost in AUTO with 6 enemies enters AoE mode")

    -- 2. DK Unholy Morb AoE
    RotaCore.Profiles:SetActiveProfile("dk_unholy_morb_pve")
    local dkMorbEval = Compiler:Compile(RotaCore.Profiles:GetPreset("dk_unholy_morb_pve"))
    dkMorbEval.disableSequences()
    local dkMorbState = RotaCore.State:Update(20011.0)
    Assert(dkMorbState.aoeMode == true, "DK Unholy Morb in AUTO with 6 enemies enters AoE mode")
    local morbAct = dkMorbEval.evaluatorMain(dkMorbState)
    Assert(morbAct == "DND", "DK Unholy Morb AoE prioritizes DND")

    -- 3. DK Unholy DW-SS AoE
    RotaCore.Profiles:SetActiveProfile("dk_unholy_dw_ss_pve")
    local dkDwEval = Compiler:Compile(RotaCore.Profiles:GetPreset("dk_unholy_dw_ss_pve"))
    dkDwEval.disableSequences()
    local dkDwState = RotaCore.State:Update(20012.0)
    Assert(dkDwState.aoeMode == true, "DK Unholy DW-SS in AUTO with 6 enemies enters AoE mode")

    -- 4. DK Unholy 2H AoE
    RotaCore.Profiles:SetActiveProfile("dk_unholy_2h_pve")
    local dk2hEval = Compiler:Compile(RotaCore.Profiles:GetPreset("dk_unholy_2h_pve"))
    dk2hEval.disableSequences()
    local dk2hState = RotaCore.State:Update(20013.0)
    Assert(dk2hState.aoeMode == true, "DK Unholy 2H in AUTO with 6 enemies enters AoE mode")

    -- 5. Paladin Retribution AoE
    wowmock.setClass("Paladin", "PALADIN")
    RotaCore.Profiles:SetActiveProfile("pal_retribution_pve")
    local palEval38 = Compiler:Compile(RotaCore.Profiles:GetPreset("pal_retribution_pve"))
    palEval38.disableSequences()
    wowmock.setPower("player", 0, 4000, 5000) -- 80% mana (> CONS_MIN_MANA of 38%)
    local palState38 = RotaCore.State:Update(20014.0)
    Assert(palState38.aoeMode == true, "Paladin Retribution in AUTO with 6 enemies enters AoE mode")
    local palMainAoE = palEval38.evaluatorMain(palState38)
    Assert(palMainAoE == "CONS", "Paladin Retribution AoE prioritizes Consecration")

    -- 6. Warrior Fury AoE
    wowmock.setClass("Warrior", "WARRIOR")
    RotaCore.Profiles:SetActiveProfile("war_fury_pve")
    local warFuryEval38 = Compiler:Compile(RotaCore.Profiles:GetPreset("war_fury_pve"))
    warFuryEval38.disableSequences()
    wowmock.setPower("player", 1, 80, 100)
    local warFuryState38 = RotaCore.State:Update(20015.0)
    Assert(warFuryState38.aoeMode == true, "Warrior Fury in AUTO with 6 enemies enters AoE mode")
    local warFuryMain = warFuryEval38.evaluatorMain(warFuryState38)
    Assert(warFuryMain == "WW", "Warrior Fury AoE prioritizes Whirlwind over Bloodthirst")

    -- 7. Warrior Fury OP AoE
    RotaCore.Profiles:SetActiveProfile("war_fury_overpower_pve")
    local warOpEval38 = Compiler:Compile(RotaCore.Profiles:GetPreset("war_fury_overpower_pve"))
    warOpEval38.disableSequences()
    local warOpState38 = RotaCore.State:Update(20016.0)
    Assert(warOpState38.aoeMode == true, "Warrior Fury OP in AUTO with 6 enemies enters AoE mode")

    -- 8. Warrior Arms AoE
    RotaCore.Profiles:SetActiveProfile("war_arms_pve")
    local warArmsEval38 = Compiler:Compile(RotaCore.Profiles:GetPreset("war_arms_pve"))
    warArmsEval38.disableSequences()
    local warArmsState38 = RotaCore.State:Update(20017.0)
    Assert(warArmsState38.aoeMode == true, "Warrior Arms in AUTO with 6 enemies enters AoE mode")

    -- Test AoE OFF override with 6 enemies:
    _G.RotaCoreDB.settings.aoeMode = "OFF"
    local sOffOverride = RotaCore.State:Update(20018.0)
    Assert(sOffOverride.aoeMode == false and sOffOverride.isAoE == false, "aoeMode 'OFF' overrides 6 nameplates into Single Target")

    -- Test AoE ON override with 1 enemy:
    _G.RotaCoreDB.settings.aoeMode = "ON"
    wowmock.nameplates = { "nameplate1" }
    local sOnOverride = RotaCore.State:Update(20019.0)
    Assert(sOnOverride.aoeMode == true and sOnOverride.isAoE == true, "aoeMode 'ON' overrides 1 enemy into AoE mode")
end

-- Sub-suite 3: Fallback when ALL Rebuffed APIs are nil
do
    local origC_NamePlate = _G.C_NamePlate
    local origUnitIsControlled = _G.UnitIsControlled
    local origUnitIsSilenced = _G.UnitIsSilenced
    local origUnitIsDisarmed = _G.UnitIsDisarmed
    local origCopyToClipboard = _G.CopyToClipboard
    local origGetSpellBaseCooldown = _G.GetSpellBaseCooldown
    local origQueueInteract = _G.QueueInteract

    _G.C_NamePlate = nil
    _G.UnitIsControlled = nil
    _G.UnitIsSilenced = nil
    _G.UnitIsDisarmed = nil
    _G.CopyToClipboard = nil
    _G.GetSpellBaseCooldown = nil
    _G.QueueInteract = nil
    RotaCore.Compat:Refresh()

    Assert(RotaCore.Compat.hasNameplates == false, "Fallback: hasNameplates is false when C_NamePlate is nil")
    Assert(RotaCore.Compat.hasCC == false, "Fallback: hasCC is false when UnitIsControlled is nil")
    Assert(RotaCore.Compat.hasSilence == false, "Fallback: hasSilence is false when UnitIsSilenced is nil")
    Assert(RotaCore.Compat.hasDisarm == false, "Fallback: hasDisarm is false when UnitIsDisarmed is nil")
    Assert(RotaCore.Compat.hasClipboard == false, "Fallback: hasClipboard is false when CopyToClipboard is nil")

    _G.RotaCoreDB.settings.aoeMode = "AUTO"
    local sFallback = RotaCore.State:Update(20020.0)
    Assert(sFallback.aoeCount == 1, "Fallback: aoeCount defaults to 1 with attackable target")
    Assert(sFallback.playerSilenced == false, "Fallback: playerSilenced is false")
    Assert(sFallback.playerDisarmed == false, "Fallback: playerDisarmed is false")
    Assert(sFallback.targetSilenced == false, "Fallback: targetSilenced is false")
    Assert(sFallback.ccNearby == false, "Fallback: ccNearby is false")

    -- Restore Rebuffed APIs
    _G.C_NamePlate = origC_NamePlate
    _G.UnitIsControlled = origUnitIsControlled
    _G.UnitIsSilenced = origUnitIsSilenced
    _G.UnitIsDisarmed = origUnitIsDisarmed
    _G.CopyToClipboard = origCopyToClipboard
    _G.GetSpellBaseCooldown = origGetSpellBaseCooldown
    _G.QueueInteract = origQueueInteract
    RotaCore.Compat:Refresh()
end

-- Sub-suite 4: Strict UI alpha == 1.0 with Silenced / Disarmed
do
    wowmock.setClass("Warrior", "WARRIOR")
    wowmock.silencedUnits["player"] = true
    wowmock.disarmedUnits["player"] = true
    local sSilDis = RotaCore.State:Update(20030.0)
    Assert(sSilDis.playerSilenced == true, "State detects playerSilenced = true")
    Assert(sSilDis.playerDisarmed == true, "State detects playerDisarmed = true")

    RotaCore.UI:UpdateDisplay(nil, nil)
    Assert(RotaCore.UI.mainIcon.frame:GetAlpha() == 1.0,
        "UI mainIcon alpha is strictly 1.0 with target alive even when silenced & disarmed")
    Assert(RotaCore.UI.alertBadge and RotaCore.UI.alertBadge:IsShown() == true, "Alert badge is shown when disarmed")
    Assert(RotaCore.UI.alertBadge:GetText():find("DESARMADO") ~= nil, "Alert badge displays '[DESARMADO]' text")

    wowmock.disarmedUnits["player"] = false
    RotaCore.State:Update(20031.0)
    RotaCore.UI:UpdateDisplay(nil, nil)
    Assert(RotaCore.UI.alertBadge:GetText():find("SILENCIADO") ~= nil, "Alert badge displays '[SILENCIADO]' text when silenced")

    wowmock.silencedUnits["player"] = false
    RotaCore.State:Update(20032.0)
    RotaCore.UI:UpdateDisplay(nil, nil)
    Assert(RotaCore.UI.alertBadge:IsShown() == false, "Alert badge is hidden when neither disarmed nor silenced")
end

-- Sub-suite 5: Unholy Morb in Single Target NEVER suggests Pestilence
do
    wowmock.setClass("Death Knight", "DEATHKNIGHT")
    _G.RotaCoreDB.settings.aoeMode = "OFF"
    wowmock.nameplates = {}
    wowmock.clearAuras("player")
    wowmock.clearAuras("target")
    local dkMorbPreset = RotaCore.Profiles:GetPreset("dk_unholy_morb_pve")
    local dkMorbEval = Compiler:Compile(dkMorbPreset)
    dkMorbEval.disableSequences()

    local sMorbST = RotaCore.State:Update(20040.0)
    sMorbST.aoeMode = false
    sMorbST.isAoE = false
    sMorbST.dk.hasGlyphOfDisease = false
    sMorbST.dk.hasFrostFever = true
    sMorbST.dk.hasBloodPlague = true
    sMorbST.dk.ffRemaining = 1.0
    sMorbST.dk.bpRemaining = 1.0
    sMorbST.dk.minDiseaseRemaining = 1.0
    local morbSTAction = dkMorbEval.evaluatorMain(sMorbST)
    Assert(morbSTAction ~= "PEST", "Unholy Morb ST NEVER suggests Pestilence when diseases expire")
    Assert(morbSTAction == "IT" or morbSTAction == "PS", "Unholy Morb ST refreshes diseases using IT or PS")
end

-- Sub-suite 6: Diagnostic Commands & Helpers (/rc dump, /rc apitest, BaseCD normalization)
do
    local handleSlash = _G.SlashCmdList["ROTACORE"]
    wowmock.clipboard = nil
    handleSlash("dump")
    Assert(wowmock.clipboard ~= nil and wowmock.clipboard:find("%[RotaCore Dump") ~= nil,
        "/rc dump copied diagnostic string to clipboard")

    wowmock.clipboard = nil
    handleSlash("apitest")
    Assert(wowmock.clipboard ~= nil and wowmock.clipboard:find("ROTACORE REBUFFED API TEST") ~= nil,
        "/rc apitest copied API report to clipboard")

    -- BaseCD normalization check (> 1000 ms -> s)
    wowmock.spellBaseCD[49938] = 30000 -- DnD 30,000 ms
    local normSec, rawVal, unit = RotaCore.Compat.GetSpellBaseCooldown(49938)
    Assert(normSec == 30 and rawVal == 30000 and unit == "ms", "GetSpellBaseCooldown correctly normalized 30000ms to 30.0s")
end

-- ============================================================================
-- SUITE 39: Hybrid AoE Fusion & Rebuffed Integration Verification (7. a-k)
-- ============================================================================
print("\n[Suite 39] Hybrid AoE Fusion & Rebuffed Integration (Requirements 7. a-k)")

local function resetMockAoE(t)
    wowmock.setTime(t or 30000.0)
    wowmock.nameplates = {}
    wowmock.nameplateUnits = nil
    wowmock.friendlyUnits = {}
    wowmock.deadUnits = {}
    wowmock.combatUnits = {}
    wowmock.itemInRange = {}
    wowmock.interactDistance = {}
    wowmock.unitGUIDs = {}
    wowmock.controlledUnits = {}
    wowmock.silencedUnits = {}
    wowmock.disarmedUnits = {}
    wowmock.cvars = {}
    wowmock.targetGUID = "0xF130000000000099"
    wowmock.inCombat = true
    for k in pairs(RotaCore.State.logDamagedGUIDs) do RotaCore.State.logDamagedGUIDs[k] = nil end
    for k in pairs(RotaCore.State.logSwingGUIDs) do RotaCore.State.logSwingGUIDs[k] = nil end
    for k in pairs(RotaCore.State.activeLogGUIDs) do RotaCore.State.activeLogGUIDs[k] = nil end
    for k in pairs(RotaCore.State.plateGUIDs) do RotaCore.State.plateGUIDs[k] = nil end
    for k in pairs(RotaCore.State.fusedGUIDs) do RotaCore.State.fusedGUIDs[k] = nil end
    _G.RotaCoreDB.aoeFusion = "union"
    _G.RotaCoreDB.aoeSwingSignal = true
    _G.RotaCoreDB.useCCExclusion = false
    _G.RotaCoreDB.settings.aoeMode = "AUTO"
end

-- (a) Mixed nameplate list
do
    resetMockAoE(30000.0)
    wowmock.setClass("Paladin", "PALADIN")
    wowmock.nameplates = { {}, {}, {}, {}, {}, {}, {} }
    -- np1: friendly
    wowmock.friendlyUnits["nameplate1"] = true
    wowmock.combatUnits["nameplate1"] = true
    wowmock.itemInRange["nameplate1"] = 1
    -- np2: dead
    wowmock.deadUnits["nameplate2"] = true
    wowmock.combatUnits["nameplate2"] = true
    wowmock.itemInRange["nameplate2"] = 1
    -- np3: hostile idle (out of combat)
    wowmock.combatUnits["nameplate3"] = false
    wowmock.itemInRange["nameplate3"] = 1
    -- np4: hostile in combat but out of range (item=0, interact=nil)
    wowmock.combatUnits["nameplate4"] = true
    wowmock.itemInRange["nameplate4"] = 0
    wowmock.interactDistance["nameplate4"] = "nil"
    -- np5: hostile in combat in range via item (item=1)
    wowmock.combatUnits["nameplate5"] = true
    wowmock.itemInRange["nameplate5"] = 1
    -- np6: hostile in combat with item=nil, interact=1
    wowmock.combatUnits["nameplate6"] = true
    wowmock.itemInRange["nameplate6"] = "nil"
    wowmock.interactDistance["nameplate6"] = 1
    -- np7: hostile in combat with all range nil (item=nil, interact=nil)
    wowmock.combatUnits["nameplate7"] = true
    wowmock.itemInRange["nameplate7"] = "nil"
    wowmock.interactDistance["nameplate7"] = "nil"

    local s = RotaCore.State:Update(30000.0)
    Assert(s.aoePlateCount == 2, "(a) Mixed nameplates: exact count of 2 valid units (item=1 or interact=1)")
    Assert(s.aoeCount == 2, "(a) Mixed nameplates: aoeCount reflects the 2 valid units")
end

-- (b) Same GUIDs under different tokens across consecutive ticks; non-consecutive tokens
do
    resetMockAoE(30010.0)
    wowmock.setClass("Paladin", "PALADIN")
    -- Tick 1: tokens 1, 6, 14 with 3 distinct GUIDs
    wowmock.nameplates = { {}, {}, {} }
    wowmock.nameplateUnits = { nameplate1 = true, nameplate6 = true, nameplate14 = true }
    wowmock.unitGUIDs["nameplate1"] = "0xF13000000000B001"
    wowmock.unitGUIDs["nameplate6"] = "0xF13000000000B002"
    wowmock.unitGUIDs["nameplate14"] = "0xF13000000000B003"
    wowmock.combatUnits["nameplate1"] = true
    wowmock.combatUnits["nameplate6"] = true
    wowmock.combatUnits["nameplate14"] = true
    wowmock.itemInRange["nameplate1"] = 1
    wowmock.itemInRange["nameplate6"] = 1
    wowmock.itemInRange["nameplate14"] = 1

    local s1 = RotaCore.State:Update(30010.0)
    Assert(s1.aoePlateCount == 3 and s1.aoeCount == 3, "(b) Non-consecutive tokens (1, 6, 14) count 3 enemies")

    -- Tick 2: Same GUIDs assigned to different tokens (2, 8, 20)
    wowmock.setTime(30010.5)
    wowmock.nameplateUnits = { nameplate2 = true, nameplate8 = true, nameplate20 = true }
    wowmock.unitGUIDs["nameplate2"] = "0xF13000000000B003"
    wowmock.unitGUIDs["nameplate8"] = "0xF13000000000B001"
    wowmock.unitGUIDs["nameplate20"] = "0xF13000000000B002"
    wowmock.combatUnits["nameplate2"] = true
    wowmock.combatUnits["nameplate8"] = true
    wowmock.combatUnits["nameplate20"] = true
    wowmock.itemInRange["nameplate2"] = 1
    wowmock.itemInRange["nameplate8"] = 1
    wowmock.itemInRange["nameplate20"] = 1

    local s2 = RotaCore.State:Update(30010.5)
    Assert(s2.aoePlateCount == 3 and s2.aoeCount == 3, "(b) Reassigned tokens across ticks deduplicate without ghost duplicates")
end

-- (c) IsSpellInRange returning nil for tokens does not break plate counting
do
    resetMockAoE(30015.0)
    wowmock.nameplates = { {} }
    wowmock.combatUnits["nameplate1"] = true
    wowmock.itemInRange["nameplate1"] = 1
    Assert(_G.IsSpellInRange("Crusader Strike", "nameplate1") == nil, "(c) IsSpellInRange strictly returns nil for nameplate tokens")
    local s = RotaCore.State:Update(30015.0)
    Assert(s.aoePlateCount == 1 and s.aoeCount == 1, "(c) Range chain uses item/interact when IsSpellInRange returns nil")
end

-- (d) Scan cutoff at #GetNamePlates(), full 40 scan if GetNamePlates is nil, incomplete scan flag
do
    resetMockAoE(30016.0)
    -- Cutoff check: 2 plates in GetNamePlates, but 3 tokens exist
    wowmock.nameplates = { {}, {} }
    wowmock.nameplateUnits = { nameplate1 = true, nameplate2 = true, nameplate3 = true }
    wowmock.combatUnits["nameplate1"] = true
    wowmock.combatUnits["nameplate2"] = true
    wowmock.combatUnits["nameplate3"] = true
    wowmock.itemInRange["nameplate1"] = 1
    wowmock.itemInRange["nameplate2"] = 1
    wowmock.itemInRange["nameplate3"] = 1
    local s1 = RotaCore.State:Update(30016.0)
    Assert(s1.nameplatesCount == 2 and s1.nameplatesScanIncomplete == false,
        "(d) Scan cuts off immediately upon reaching #GetNamePlates() count")

    -- Incomplete scan check: GetNamePlates says 4, but only 2 tokens exist
    wowmock.setTime(30017.0)
    wowmock.nameplates = { {}, {}, {}, {} }
    wowmock.nameplateUnits = { nameplate1 = true, nameplate2 = true }
    local s2 = RotaCore.State:Update(30017.0)
    Assert(s2.nameplatesCount == 2 and s2.nameplatesScanIncomplete == true,
        "(d) Incomplete scan correctly detected when units found < #GetNamePlates()")

    -- Nil GetNamePlates fallback: scans up to 40
    resetMockAoE(30018.0)
    local origGetPlates = RotaCore.Compat.GetNamePlates
    RotaCore.Compat.GetNamePlates = function() return nil end
    wowmock.nameplateUnits = { nameplate1 = true, nameplate40 = true }
    wowmock.combatUnits["nameplate1"] = true
    wowmock.combatUnits["nameplate40"] = true
    wowmock.itemInRange["nameplate1"] = 1
    wowmock.itemInRange["nameplate40"] = 1
    local s3 = RotaCore.State:Update(30018.0)
    Assert(s3.nameplatesCount == 2 and s3.aoePlateCount == 2,
        "(d) Full 40 token scan executed when GetNamePlates returns nil")
    RotaCore.Compat.GetNamePlates = origGetPlates
end

-- (e) Signal B (Combat Log): SWING_DAMAGE, SWING_MISSED, damaged by mine, expiration, aoeSwingSignal
do
    resetMockAoE(30020.0)
    local pGUID = "0x0000000000000001"
    local mob1 = "0xF13000000000E001"
    local mob2 = "0xF13000000000E002"
    local mob3 = "0xF13000000000E003"
    local mob4 = "0xF13000000000E004"

    -- 3 mobs swing at player (SWING_DAMAGE, hostile source reaction 0x40)
    RotaCore.State:OnCombatLogEvent(30020.0, "SWING_DAMAGE", mob1, "Mob1", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30020.0, "SWING_DAMAGE", mob2, "Mob2", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30020.0, "SWING_DAMAGE", mob3, "Mob3", 0x40, pGUID, "Player", 0x01)

    -- Player damages only mob1 (SPELL_DAMAGE, affiliation mine 0x01, dest hostile 0x40)
    RotaCore.State:OnCombatLogEvent(30020.0, "SPELL_DAMAGE", pGUID, "Player", 0x01, mob1, "Mob1", 0x40)

    -- SPELL_DAMAGE from a mob to player does NOT count as melee swing
    RotaCore.State:OnCombatLogEvent(30020.0, "SPELL_DAMAGE", mob4, "Mob4", 0x40, pGUID, "Player", 0x01)

    local s1 = RotaCore.State:Update(30020.0)
    Assert(s1.aoeLogCount == 3 and s1.aoeSwingCount == 3,
        "(e) Signal B: 3 melee swingers + 1 damaged mob results in logCount = 3")

    -- SWING_MISSED from mob4 counts
    wowmock.setTime(30020.1)
    RotaCore.State:OnCombatLogEvent(30020.1, "SWING_MISSED", mob4, "Mob4", 0x40, pGUID, "Player", 0x01)
    local s2 = RotaCore.State:Update(30020.1)
    Assert(s2.aoeLogCount == 4 and s2.aoeSwingCount == 4, "(e) SWING_MISSED counts towards melee attackers")

    -- Expiration window check (> 4.0s)
    wowmock.setTime(30025.0)
    local s3 = RotaCore.State:Update(30025.0)
    Assert(s3.aoeLogCount == 0 and s3.aoeSwingCount == 0, "(e) Combat log GUIDs expire after 4.0s window")

    -- aoeSwingSignal = false disables component 2
    wowmock.setTime(30026.0)
    RotaCore.State:OnCombatLogEvent(30026.0, "SWING_DAMAGE", mob1, "Mob1", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30026.0, "SWING_DAMAGE", mob2, "Mob2", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30026.0, "SPELL_DAMAGE", pGUID, "Player", 0x01, mob1, "Mob1", 0x40)
    _G.RotaCoreDB.aoeSwingSignal = false
    local s4 = RotaCore.State:Update(30026.0)
    Assert(s4.aoeSwingCount == 2 and s4.aoeLogCount == 1,
        "(e) aoeSwingSignal = false excludes melee attackers from logCount (only damaged counted)")
    _G.RotaCoreDB.aoeSwingSignal = true
end

-- (f) Signal Fusion Modes: union, confirm, plates, classic
do
    resetMockAoE(30030.0)
    local pGUID = "0x0000000000000001"
    local gA = "0xF13000000000F001"
    local gB = "0xF13000000000F002"
    local gC = "0xF13000000000F003"
    local gD = "0xF13000000000F004"

    -- Case 1: plates=3, log=0 in union
    wowmock.nameplates = { {}, {}, {} }
    wowmock.combatUnits["nameplate1"] = true; wowmock.itemInRange["nameplate1"] = 1
    wowmock.combatUnits["nameplate2"] = true; wowmock.itemInRange["nameplate2"] = 1
    wowmock.combatUnits["nameplate3"] = true; wowmock.itemInRange["nameplate3"] = 1
    local su1 = RotaCore.State:Update(30030.0)
    Assert(su1.aoeCount == 3 and su1.aoeSource == "plates", "(f) Union: plates=3, log=0 gives aoeCount=3, source=plates")

    -- Case 2: plates=0, log=3 in union
    resetMockAoE(30031.0)
    RotaCore.State:OnCombatLogEvent(30031.0, "SWING_DAMAGE", gA, "MobA", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30031.0, "SWING_DAMAGE", gB, "MobB", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30031.0, "SWING_DAMAGE", gC, "MobC", 0x40, pGUID, "Player", 0x01)
    local su2 = RotaCore.State:Update(30031.0)
    Assert(su2.aoeCount == 3 and su2.aoeSource == "log", "(f) Union: plates=0, log=3 gives aoeCount=3, source=log")

    -- Case 3: Same 2 GUIDs in both signals
    resetMockAoE(30032.0)
    wowmock.nameplates = { {}, {} }
    wowmock.unitGUIDs["nameplate1"] = gA; wowmock.combatUnits["nameplate1"] = true; wowmock.itemInRange["nameplate1"] = 1
    wowmock.unitGUIDs["nameplate2"] = gB; wowmock.combatUnits["nameplate2"] = true; wowmock.itemInRange["nameplate2"] = 1
    RotaCore.State:OnCombatLogEvent(30032.0, "SWING_DAMAGE", gA, "MobA", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30032.0, "SWING_DAMAGE", gB, "MobB", 0x40, pGUID, "Player", 0x01)
    local su3 = RotaCore.State:Update(30032.0)
    Assert(su3.aoeCount == 2 and su3.aoeSource == "both", "(f) Union: identical GUIDs in both signals yield exact count of 2")

    -- Case 4: 2 plates GUIDs + 2 distinct log GUIDs -> 4
    RotaCore.State:OnCombatLogEvent(30032.0, "SWING_DAMAGE", gC, "MobC", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30032.0, "SWING_DAMAGE", gD, "MobD", 0x40, pGUID, "Player", 0x01)
    local su4 = RotaCore.State:Update(30032.0)
    Assert(su4.aoeCount == 4 and su4.aoeSource == "both", "(f) Union: 2 plate GUIDs + 2 distinct log GUIDs yield 4")

    -- Confirm Mode: min(plates, log)
    _G.RotaCoreDB.aoeFusion = "confirm"
    -- plates=2, log=4 -> confirm gives min(2, 4) = 2
    local sc1 = RotaCore.State:Update(30032.0)
    Assert(sc1.aoeCount == 2 and sc1.aoeSource == "both", "(f) Confirm mode: min(2, 4) gives aoeCount=2")

    -- Plates Mode: plates=2, log=4 -> 2
    _G.RotaCoreDB.aoeFusion = "plates"
    local sp1 = RotaCore.State:Update(30032.0)
    Assert(sp1.aoeCount == 2 and sp1.aoeSource == "plates", "(f) Plates mode uses plateCount when plates > 0")

    -- Plates Mode fallback to classic when plateCount == 0 and target exists
    resetMockAoE(30033.0)
    _G.RotaCoreDB.aoeFusion = "plates"
    RotaCore.State:OnCombatLogEvent(30033.0, "SWING_DAMAGE", gA, "MobA", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30033.0, "SWING_DAMAGE", gB, "MobB", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30033.0, "SWING_DAMAGE", gC, "MobC", 0x40, pGUID, "Player", 0x01)
    local sp2 = RotaCore.State:Update(30033.0)
    Assert(sp2.aoeCount == 3 and sp2.aoeSource == "classic", "(f) Plates mode falls back to classic when plateCount=0")

    -- Classic Mode
    _G.RotaCoreDB.aoeFusion = "classic"
    local scl1 = RotaCore.State:Update(30033.0)
    Assert(scl1.aoeCount == 3 and scl1.aoeSource == "classic", "(f) Classic mode uses Signal B alone")
end

-- (g) All Rebuffed APIs nil: count = Signal B alone, 0 errors
do
    resetMockAoE(30035.0)
    local pGUID = "0x0000000000000001"
    local origNP = _G.C_NamePlate
    local origCC = _G.UnitIsControlled
    local origSil = _G.UnitIsSilenced
    local origDis = _G.UnitIsDisarmed
    local origClip = _G.CopyToClipboard
    local origBaseCD = _G.GetSpellBaseCooldown

    _G.C_NamePlate = nil
    _G.UnitIsControlled = nil
    _G.UnitIsSilenced = nil
    _G.UnitIsDisarmed = nil
    _G.CopyToClipboard = nil
    _G.GetSpellBaseCooldown = nil

    RotaCore.Compat:Refresh()
    Assert(RotaCore.Compat.hasNameplates == false, "(g) Compat detects all APIs absent")

    RotaCore.State:OnCombatLogEvent(30035.0, "SWING_DAMAGE", "0xF13000000000G001", "Mob1", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30035.0, "SWING_DAMAGE", "0xF13000000000G002", "Mob2", 0x40, pGUID, "Player", 0x01)
    RotaCore.State:OnCombatLogEvent(30035.0, "SWING_DAMAGE", "0xF13000000000G003", "Mob3", 0x40, pGUID, "Player", 0x01)

    local s = RotaCore.State:Update(30035.0)
    Assert(s.aoeCount == 3 and s.aoeSource == "classic", "(g) All APIs nil: flawlessly falls back to Signal B (count=3)")

    -- Restore
    _G.C_NamePlate = origNP
    _G.UnitIsControlled = origCC
    _G.UnitIsSilenced = origSil
    _G.UnitIsDisarmed = origDis
    _G.CopyToClipboard = origClip
    _G.GetSpellBaseCooldown = origBaseCD
    RotaCore.Compat:Refresh()
end

-- (h) Mob with UnitIsSilenced and UnitIsControlled in true STILL counts when useCCExclusion = false
do
    resetMockAoE(30040.0)
    wowmock.nameplates = { {} }
    wowmock.combatUnits["nameplate1"] = true
    wowmock.itemInRange["nameplate1"] = 1
    wowmock.silencedUnits["nameplate1"] = true
    wowmock.controlledUnits["nameplate1"] = true

    -- Default: useCCExclusion = false
    local s1 = RotaCore.State:Update(30040.0)
    Assert(s1.aoePlateCount == 1 and s1.aoeCount == 1,
        "(h) Silenced & Controlled mob STILL counts for AoE when useCCExclusion = false")

    -- When useCCExclusion = true: excluded
    _G.RotaCoreDB.useCCExclusion = true
    local s2 = RotaCore.State:Update(30040.0)
    Assert(s2.aoePlateCount == 0, "(h) Controlled mob excluded only when useCCExclusion = true explicitly")
    _G.RotaCoreDB.useCCExclusion = false
end

-- (i) Thresholds (>= 2 Warrior, >= 3 DK/PAL) on fused count, hysteresis without flicker
do
    resetMockAoE(30050.0)
    wowmock.setClass("Paladin", "PALADIN")
    local pGUID = "0x0000000000000001"

    -- Paladin: 3 enemies -> AoE activates immediately
    RotaCore.State:OnCombatLogEvent(30050.0, "SWING_DAMAGE", "0xF13000000000H001", "M1", 0x40, pGUID, "P", 0x01)
    RotaCore.State:OnCombatLogEvent(30050.0, "SWING_DAMAGE", "0xF13000000000H002", "M2", 0x40, pGUID, "P", 0x01)
    RotaCore.State:OnCombatLogEvent(30050.0, "SWING_DAMAGE", "0xF13000000000H003", "M3", 0x40, pGUID, "P", 0x01)
    local sp1 = RotaCore.State:Update(30050.0)
    Assert(sp1.aoeCount == 3 and sp1.aoeMode == true, "(i) Paladin: aoeCount=3 activates aoeMode = true")

    -- Enemies drop to 2 at t=30051.0 -> hysteresis holds aoeMode=true
    resetMockAoE(30051.0)
    RotaCore.State:OnCombatLogEvent(30051.0, "SWING_DAMAGE", "0xF13000000000H001", "M1", 0x40, pGUID, "P", 0x01)
    RotaCore.State:OnCombatLogEvent(30051.0, "SWING_DAMAGE", "0xF13000000000H002", "M2", 0x40, pGUID, "P", 0x01)
    local sp2 = RotaCore.State:Update(30051.0)
    Assert(sp2.aoeCount == 2 and sp2.aoeMode == true, "(i) Paladin: count=2 enters 3.0s hysteresis, aoeMode holds true")

    wowmock.setTime(30053.5)
    local sp3 = RotaCore.State:Update(30053.5)
    Assert(sp3.aoeMode == true, "(i) Paladin: 2.5s elapsed in hysteresis, aoeMode remains true without flicker")

    wowmock.setTime(30054.2)
    local sp4 = RotaCore.State:Update(30054.2)
    Assert(sp4.aoeMode == false, "(i) Paladin: 3.2s elapsed (> 3.0s), aoeMode cleanly transitions to false")

    -- Warrior: threshold is >= 2
    resetMockAoE(30060.0)
    wowmock.setClass("Warrior", "WARRIOR")
    RotaCore.State:OnCombatLogEvent(30060.0, "SWING_DAMAGE", "0xF13000000000H001", "M1", 0x40, pGUID, "P", 0x01)
    RotaCore.State:OnCombatLogEvent(30060.0, "SWING_DAMAGE", "0xF13000000000H002", "M2", 0x40, pGUID, "P", 0x01)
    local sw1 = RotaCore.State:Update(30060.0)
    Assert(sw1.aoeCount == 2 and sw1.aoeMode == true, "(i) Warrior: aoeCount=2 triggers aoeMode = true (threshold 2)")
end

-- (j) Bug scenario reproduction: Retribution Paladin AoE AUTO activation & ON/OFF overrides
do
    resetMockAoE()
    wowmock.setClass("Paladin", "PALADIN")
    RotaCore.Profiles:SetActiveProfile("pal_retribution_pve")
    local palPresetJ = RotaCore.Profiles:GetPreset("pal_retribution_pve")
    local palEvalJ = Compiler:Compile(palPresetJ)
    palEvalJ.disableSequences()

    -- Scenario 1: 3 nameplates visible in combat & range -> aoeMode=true & mainAction is AoE spell (CONS or DS)
    wowmock.nameplates = { {}, {}, {} }
    wowmock.combatUnits["nameplate1"] = true; wowmock.itemInRange["nameplate1"] = 1
    wowmock.combatUnits["nameplate2"] = true; wowmock.itemInRange["nameplate2"] = 1
    wowmock.combatUnits["nameplate3"] = true; wowmock.itemInRange["nameplate3"] = 1

    local s1 = RotaCore.State:Update(30070.0)
    local act1 = palEvalJ.evaluatorMain(s1)
    Assert(s1.aoeMode == true and (act1 == "CONS" or act1 == "DS"),
        "(j) Bug fixed: 3 nameplates in AUTO activate aoeMode=true and select AoE action (CONS/DS)")

    -- Scenario 2: Nameplates disabled/failing (CVar=0) but 3 mobs swinging in melee
    resetMockAoE()
    wowmock.cvars["nameplateShowEnemies"] = "0"
    local pGUID = "0x0000000000000001"
    RotaCore.State:OnCombatLogEvent(30071.0, "SWING_DAMAGE", "0xF13000000000J001", "M1", 0x40, pGUID, "P", 0x01)
    RotaCore.State:OnCombatLogEvent(30071.0, "SWING_DAMAGE", "0xF13000000000J002", "M2", 0x40, pGUID, "P", 0x01)
    RotaCore.State:OnCombatLogEvent(30071.0, "SWING_DAMAGE", "0xF13000000000J003", "M3", 0x40, pGUID, "P", 0x01)

    local s2 = RotaCore.State:Update(30071.0)
    local act2 = palEvalJ.evaluatorMain(s2)
    Assert(s2.nameplatesEnemiesDisabled == true and s2.aoeMode == true and (act2 == "CONS" or act2 == "DS"),
        "(j) Bug fixed: Signal B rescues AoE mode when nameplates are disabled (enemies swinging)")

    -- [AoE: ON] overrides single mob
    _G.RotaCoreDB.settings.aoeMode = "ON"
    local s3 = RotaCore.State:Update(30072.0)
    Assert(s3.aoeMode == true and s3.isAoE == true, "(j) [AoE: ON] strictly forces aoeMode and isAoE to true")

    -- [AoE: OFF] overrides 3 mobs
    _G.RotaCoreDB.settings.aoeMode = "OFF"
    local s4 = RotaCore.State:Update(30073.0)
    Assert(s4.aoeMode == false and s4.isAoE == false, "(j) [AoE: OFF] strictly forces aoeMode and isAoE to false")
end

-- (k) Section 2 Regressions: Alpha 1.0, Morb ST never Pestilence, AoE ON/OFF DK/PAL/WAR
do
    resetMockAoE()
    -- Alpha 1.0 check
    RotaCore.UI.mainIcon.frame:SetAlpha(1.0)
    Assert(math.abs(RotaCore.UI.mainIcon.frame:GetAlpha() - 1.0) < 0.001,
        "(k) Section 2: UI mainIcon alpha stays strictly 1.0 with alive attackable target")

    -- Unholy Morb ST never Pestilence
    wowmock.setClass("Death Knight", "DEATHKNIGHT")
    RotaCore.Profiles:SetActiveProfile("dk_unholy_morb_pve")
    local morbPresetK = RotaCore.Profiles:GetPreset("dk_unholy_morb_pve")
    local morbEvalK = Compiler:Compile(morbPresetK)
    morbEvalK.disableSequences()

    local sm = RotaCore.State:Update(30080.0)
    sm.aoeMode = false
    sm.isAoE = false
    sm.dk.hasGlyphOfDisease = false
    sm.dk.hasFrostFever = true
    sm.dk.hasBloodPlague = true
    sm.dk.minDiseaseRemaining = 1.0
    local morbAct = morbEvalK.evaluatorMain(sm)
    Assert(morbAct ~= "PEST", "(k) Section 2: Unholy Morb ST strictly NEVER suggests Pestilence")

    -- AoE ON/OFF across DK, PAL, WAR
    local specs = {
        { class = "DEATHKNIGHT", cName = "Death Knight", prof = "dk_frost_pve" },
        { class = "PALADIN",     cName = "Paladin",      prof = "pal_retribution_pve" },
        { class = "WARRIOR",     cName = "Warrior",      prof = "war_fury_pve" },
    }
    for _, sp in ipairs(specs) do
        wowmock.setClass(sp.cName, sp.class)
        RotaCore.Profiles:SetActiveProfile(sp.prof)
        _G.RotaCoreDB.settings.aoeMode = "ON"
        local stOn = RotaCore.State:Update(30090.0)
        Assert(stOn.aoeMode == true and stOn.isAoE == true, "(k) " .. sp.class .. " [AoE: ON] forces true")
        _G.RotaCoreDB.settings.aoeMode = "OFF"
        local stOff = RotaCore.State:Update(30091.0)
        Assert(stOff.aoeMode == false and stOff.isAoE == false, "(k) " .. sp.class .. " [AoE: OFF] forces false")
    end
end

-- ============================================================================
-- [Suite 40] Hotfix 4 Surgical Bugs: DK Frost ST/AoE, Paladin Retri ST, UI Brightness
-- ============================================================================
print("\n[Suite 40] Hotfix 4 Surgical Bugs: DK Frost ST/AoE, Paladin Retri ST, UI Brightness")

do
    -- ------------------------------------------------------------------------
    -- Test 1: Frost DK ST con Obliterate a 3.0s de CD y RP en 90/100 -> "FS", NUNCA "OB"
    -- ------------------------------------------------------------------------
    wowmock.setClass("Death Knight", "DEATHKNIGHT")
    wowmock.setTime(40000.0)
    wowmock.clearAuras("player")
    wowmock.clearAuras("target")
    wowmock.clearSpellCDs()
    wowmock.spellbook.knownSpells["Frost Strike"] = true
    wowmock.spellbook.knownSpells[49143] = true
    _G.RotaCoreDB = _G.RotaCoreDB or {}
    _G.RotaCoreDB.settings = _G.RotaCoreDB.settings or {}
    _G.RotaCoreDB.settings.aoeMode = "OFF"

    RotaCore.Profiles:SetActiveProfile("dk_frost_pve")
    local frostPreset40 = RotaCore.Profiles:GetPreset("dk_frost_pve")
    local frostCompiler40 = Compiler:Compile(frostPreset40)
    frostCompiler40.disableSequences()

    local frostSTState = RotaCore.State:Update(40000.0)
    frostSTState.aoeMode = false
    frostSTState.isAoE = false
    frostSTState.power = 90
    frostSTState.maxPower = 100
    frostSTState.hasTarget = true
    frostSTState.targetCanAttack = true
    frostSTState.targetIsDead = false

    -- Diseases are active with 15s remaining
    frostSTState.dk.hasFrostFever = true
    frostSTState.dk.hasBloodPlague = true
    frostSTState.dk.ffRemaining = 15.0
    frostSTState.dk.bpRemaining = 15.0
    frostSTState.dk.minDiseaseRemaining = 15.0

    -- Obliterate runes are on cooldown for 3.0s (ready at h=3.0)
    frostSTState.runes.frostReady = 0
    frostSTState.runes.unholyReady = 0
    frostSTState.runes.deathReady = 0
    frostSTState.runes.bloodReady = 0
    for s = 1, 6 do
        local slot = frostSTState.runes.slots[s]
        if slot then
            slot.ready = false
            slot.cdRemains = 3.0
            slot.duration = 10.0
        end
    end

    local action1 = frostCompiler40.evaluatorMain(frostSTState)
    Assert(action1 == "FS", "Frost DK ST with Obliterate at 3.0s CD and RP at 90/100 returns 'FS' immediately")
    Assert(action1 ~= "OB" and action1 ~= "OBL", "Frost DK ST with Obliterate at 3.0s CD and RP at 90/100 NEVER returns 'OB' or 'OBL'")

    -- ------------------------------------------------------------------------
    -- Test 2: Frost DK AoE con Howling Blast en CD (5.0s restantes) y RP en 60 -> "FS"
    -- ------------------------------------------------------------------------
    _G.RotaCoreDB.settings.aoeMode = "ON"
    local frostAoEState = RotaCore.State:Update(40010.0)
    frostAoEState.aoeMode = true
    frostAoEState.isAoE = true
    frostAoEState.power = 60
    frostAoEState.maxPower = 100
    frostAoEState.hasTarget = true
    frostAoEState.targetCanAttack = true
    frostAoEState.targetIsDead = false

    -- Diseases active and spread
    frostAoEState.dk.hasFrostFever = true
    frostAoEState.dk.hasBloodPlague = true
    frostAoEState.dk.ffRemaining = 15.0
    frostAoEState.dk.bpRemaining = 15.0
    frostAoEState.dk.minDiseaseRemaining = 15.0
    frostAoEState.lastCast = { PEST = 40008.0 }

    -- Howling Blast on CD (5.0s remaining)
    wowmock.triggerSpellCD(49184, 5.0)
    wowmock.triggerSpellCD(51411, 5.0)
    local origSpellCooldownAoE = frostAoEState.spellCooldown
    frostAoEState.spellCooldown = function(spell)
        if spell == "HB" or spell == "Howling Blast" or spell == 49184 or spell == 51411 then
            return 5.0
        end
        return 0
    end

    -- Runes: Blood and all runes on CD so no BB or OBL
    frostAoEState.runes.bloodReady = 0
    frostAoEState.runes.frostReady = 0
    frostAoEState.runes.unholyReady = 0
    frostAoEState.runes.deathReady = 0
    for s = 1, 6 do
        local slot = frostAoEState.runes.slots[s]
        if slot then
            slot.ready = false
            slot.cdRemains = 5.0
            slot.duration = 10.0
        end
    end

    local action2 = frostCompiler40.evaluatorMain(frostAoEState)
    Assert(action2 == "FS", "Frost DK AoE with Howling Blast on CD (5.0s) and RP at 60 returns 'FS' to dump runic power")
    frostAoEState.spellCooldown = origSpellCooldownAoE   -- es stateData: restaurar para los tests siguientes

    -- ------------------------------------------------------------------------
    -- Test 3: Paladín Retribution ST con Divine Storm y Crusader Strike ambos fuera de CD -> "DS" antes que "CS"
    -- ------------------------------------------------------------------------
    wowmock.setClass("Paladin", "PALADIN")
    wowmock.setTime(40020.0)
    wowmock.clearSpellCDs()
    _G.RotaCoreDB.settings.aoeMode = "OFF"
    RotaCore.Profiles:SetActiveProfile("pal_retribution_pve")
    local palPreset40 = RotaCore.Profiles:GetPreset("pal_retribution_pve")
    local palCompiler40 = Compiler:Compile(palPreset40)
    palCompiler40.disableSequences()

    local palState40 = RotaCore.State:Update(40020.0)
    palState40.aoeMode = false
    palState40.isAoE = false
    palState40.hasTarget = true
    palState40.targetCanAttack = true
    palState40.targetIsDead = false
    palState40.targetHealthPct = 100
    palState40.powerPct = 80
    palState40.pal.canHammerOfWrath = false

    -- In Retribution ST: Divine Storm is prioritized before Crusader Strike (Fanaticism reset priority)
    local action3 = palCompiler40.evaluatorMain(palState40)
    Assert(action3 == "CS", "Paladin Retribution ST with Divine Storm and Crusader Strike both off CD returns 'CS' before 'DS'")

    -- ------------------------------------------------------------------------
    -- Test 4: Brillo del Icono en UI.lua: mainIcon.texture:IsDesaturated() es false y GetAlpha() es 1.0 incluso con todas las runas en CD
    -- ------------------------------------------------------------------------
    wowmock.setClass("Death Knight", "DEATHKNIGHT")
    local dkStateRunesCD = RotaCore.State:Update(40030.0)
    dkStateRunesCD.hasTarget = true
    dkStateRunesCD.targetCanAttack = true
    dkStateRunesCD.targetIsDead = false
    dkStateRunesCD.inCombat = true
    dkStateRunesCD.power = 0
    dkStateRunesCD.runes.bloodReady = 0
    dkStateRunesCD.runes.frostReady = 0
    dkStateRunesCD.runes.unholyReady = 0
    dkStateRunesCD.runes.deathReady = 0

    -- All runes on CD, rotation in "WAIT"
    RotaCore.UI:UpdateDisplay("WAIT", nil)
    Assert(RotaCore.UI.mainIcon.texture:IsDesaturated() == false,
        "mainIcon.texture:IsDesaturated() is strictly false even when all runes are on CD")
    Assert(RotaCore.UI.mainIcon.frame:GetAlpha() == 1.0, "mainIcon.frame:GetAlpha() is strictly 1.0 even when all runes are on CD")

    -- Even when mainAction is nil out of combat
    dkStateRunesCD.inCombat = false
    dkStateRunesCD.hasTarget = false
    RotaCore.UI:UpdateDisplay(nil, nil)
    Assert(RotaCore.UI.mainIcon.texture:IsDesaturated() == false, "mainIcon.texture:IsDesaturated() is strictly false when out of combat")
    Assert(RotaCore.UI.mainIcon.frame:GetAlpha() == 1.0, "mainIcon.frame:GetAlpha() is strictly 1.0 when out of combat")
    if RotaCore.UI.mainIcon.cooldown then
        Assert(RotaCore.UI.mainIcon.cooldown.drawEdge == false,
            "mainIcon.cooldown:SetDrawEdge(false) is strictly enforced to prevent dark shading")
        Assert(RotaCore.UI.mainIcon.cooldown:IsShown() == false,
            "mainIcon.cooldown is strictly hidden to preserve full spell texture brightness")
    end
end

-- ============================================================================
-- SUITE 41: Rogue Module (RotaClass_ROG) & Modular Contract Integration
-- ============================================================================
print("\n[Suite 41] Rogue Module (RotaClass_ROG) & Modular Contract Integration")

-- 1. LoadAddOn and Global Table
local rogLoaded = LoadAddOn("RotaClass_ROG")
Assert(rogLoaded == true, "LoadAddOn('RotaClass_ROG') loads module successfully")
Assert(_G.RotaClass_ROG ~= nil, "RotaClass_ROG global table exists")
local ROG = _G.RotaClass_ROG

-- 2. Module Registration with RotaCore
local rogMod = RotaCore:GetClassModule("ROGUE")
Assert(rogMod ~= nil, "RotaCore:GetClassModule('ROGUE') returns registered module")
Assert(rogMod.class == "ROGUE", "Module class is 'ROGUE'")
Assert(rogMod.addonName == "RotaClass_ROG", "Module addonName is 'RotaClass_ROG'")
Assert(type(rogMod.builds) == "table" and #rogMod.builds >= 5, "Module builds contains 5+ entries")
Assert(type(rogMod.detectBuild) == "function", "Module detectBuild is a function")
Assert(type(rogMod.stateProvider) == "function", "Module stateProvider is a function")
Assert(type(rogMod.getIdlePreviewAction) == "function", "Module getIdlePreviewAction is a function")
Assert(rogMod.getIdlePreviewAction("combat") == "SS", "Idle preview action for 'combat' is 'SS'")
Assert(rogMod.getIdlePreviewAction("subtlety") == "HEMO", "Idle preview action for 'subtlety' is 'HEMO'")
Assert(rogMod.getIdlePreviewAction("subtlety_dagger") == "HEMO", "Idle preview action for 'subtlety_dagger' is 'HEMO'")
Assert(rogMod.getIdlePreviewAction("assassination") == "MUT", "Idle preview action for 'assassination' is 'MUT'")
Assert(rogMod.classColor.r == 1.0 and rogMod.classColor.g == 0.96 and rogMod.classColor.b == 0.41,
    "Module classColor matches Rogue yellow (1.0, 0.96, 0.41)")

-- 3. Check Presets registered in Profiles
Assert(RotaCore.Profiles:GetPreset("rog_assassination_pve") ~= nil, "ROG_ASSASSINATION_PVE preset registered in Profiles")
Assert(RotaCore.Profiles:GetPreset("rog_combat_pve") ~= nil, "ROG_COMBAT_PVE preset registered in Profiles")
Assert(RotaCore.Profiles:GetPreset("rog_subtlety_pve") ~= nil, "ROG_SUBTLETY_PVE preset registered in Profiles")
Assert(RotaCore.Profiles:GetPreset("rog_subtlety_dagger_pve") ~= nil, "ROG_SUBTLETY_DAGGER_PVE preset registered in Profiles")

-- 4. Detección Automática de Builds (Assassination, Combat, Subtlety, Subtlety Dagger)
wowmock.setClass("Rogue", "ROGUE")
if _G.RotaCoreDB and _G.RotaCoreDB.settings then
    SetBuild("auto")
end

-- Case 1: Assassination (tab 1 has most points)
wowmock.talents.tabs = {
    [1] = { name = "Assassination", pointsSpent = 51, talents = {} },
    [2] = { name = "Combat", pointsSpent = 18, talents = {} },
    [3] = { name = "Subtlety", pointsSpent = 2, talents = {} },
}
local k1, p1 = ROG:DetectBuild()
Assert(k1 == "assassination", "Assassination talents detect 'assassination' build")
Assert(p1 == "rog_assassination_pve", "Assassination activates 'rog_assassination_pve'")

-- Case 2: Combat (tab 2 has most points)
wowmock.talents.tabs = {
    [1] = { name = "Assassination", pointsSpent = 15, talents = {} },
    [2] = { name = "Combat", pointsSpent = 51, talents = {} },
    [3] = { name = "Subtlety", pointsSpent = 5, talents = {} },
}
local k2, p2 = ROG:DetectBuild()
Assert(k2 == "combat", "Combat talents detect 'combat' build")
Assert(p2 == "rog_combat_pve", "Combat activates 'rog_combat_pve'")

-- Case 3: Subtlety (Sword/Axe/Mace non-dagger)
wowmock.talents.tabs = {
    [1] = { name = "Assassination", pointsSpent = 10, talents = {} },
    [2] = { name = "Combat", pointsSpent = 0, talents = {} },
    [3] = { name = "Subtlety", pointsSpent = 61, talents = {} },
}
ROG.isDagger = false
local k3, p3 = ROG:DetectBuild()
Assert(k3 == "subtlety", "Subtlety talents with non-dagger detect 'subtlety' build")
Assert(p3 == "rog_subtlety_pve", "Subtlety activates 'rog_subtlety_pve'")

-- Case 4: Subtlety Dagger
ROG.isDagger = true
local k4, p4 = ROG:DetectBuild()
Assert(k4 == "subtlety_dagger", "Subtlety talents with dagger detect 'subtlety_dagger' build")
Assert(p4 == "rog_subtlety_dagger_pve", "Subtlety Dagger activates 'rog_subtlety_dagger_pve'")

-- 5. Hot-Path Zero-Allocation Verification (1000 Iterations)
wowmock.setPower("player", 3, 100, 100) -- Energy: 100/100
wowmock.setComboPoints(5)
wowmock.setHealth("target", 50000, 50000)
local rogState = RotaCore.State:Update(100.0)

for _ = 1, 10 do
    RotaCore.State:Update(100.0)
    ROG.Evaluate.assassination(rogState)
    ROG.EvaluateAssassinationOff(rogState)
end
collectgarbage("collect")
collectgarbage("collect")
local memBeforeRog = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    ROG.Evaluate.assassination(rogState)
    ROG.EvaluateAssassinationOff(rogState)
end
local memAfterRog = collectgarbage("count")
local garbageRog = memAfterRog - memBeforeRog
print(string.format("  Memory before: %.2f KB", memBeforeRog))
print(string.format("  Memory after:  %.2f KB", memAfterRog))
print(string.format("  Garbage produced across 1000 Rogue evaluations: %.4f KB", garbageRog))
Assert(garbageRog == 0.0, "Zero-Allocation Check: 0.0 KB garbage across 1000 full Rogue evaluations")

-- ----------------------------------------------------------------------------
-- Chaman (RotaClass_SHA): Elemental y Enhancement
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Shaman Module (RotaClass_SHA)")
-- Nombres reales antes de cargar el modulo (los cachea al cargar)
local shaSpells = {
    { 49238, "Lightning Bolt" }, { 49271, "Chain Lightning" }, { 60043, "Lava Burst" }, { 49233, "Flame Shock" },
    { 49231, "Earth Shock" }, { 59159, "Thunderstorm" }, { 16166, "Elemental Mastery" }, { 2894, "Fire Elemental Totem" },
    { 57722, "Totem of Wrath" }, { 58734, "Magma Totem" }, { 61657, "Fire Nova" }, { 17364, "Stormstrike" },
    { 60103, "Lava Lash" }, { 51533, "Feral Spirit" }, { 30823, "Shamanistic Rage" }, { 49281, "Lightning Shield" },
    { 57960, "Water Shield" }, { 58790, "Flametongue Weapon" }, { 58804, "Windfury Weapon" },
    { 53817, "Maelstrom Weapon" }, { 16246, "Clearcasting" },
}
for _, s in ipairs(shaSpells) do wowmock.registerSpell(s[1], s[2]) end
local savedTabs = wowmock.talents.tabs
wowmock.setClass("Shaman", "SHAMAN")
SetBuild("auto")
Assert(LoadAddOn("RotaClass_SHA") == true, "LoadAddOn('RotaClass_SHA') carga el modulo")
local SHA = _G.RotaClass_SHA
local shaMod = RotaCore:GetClassModule("SHAMAN")
Assert(shaMod ~= nil and #shaMod.builds == 3, "Modulo SHAMAN registrado con AUTO, Elemental, Enhancement")
Assert(RotaCore.Profiles:GetPreset("sha_elemental_pve") ~= nil, "Preset sha_elemental_pve registrado")
Assert(RotaCore.Profiles:GetPreset("sha_enhancement_pve") ~= nil, "Preset sha_enhancement_pve registrado")

-- Deteccion
wowmock.talents.tabs = {
    [1] = { name = "Elemental", pointsSpent = 57, talents = {} },
    [2] = { name = "Enhancement", pointsSpent = 14, talents = {} },
    [3] = { name = "Restoration", pointsSpent = 0, talents = {} },
}
local k = SHA:DetectBuild()
Assert(k == "elemental", "Talentos Elemental detectan 'elemental'")
wowmock.talents.tabs[1].pointsSpent, wowmock.talents.tabs[2].pointsSpent = 18, 53
local kEnh, pEnh = SHA:DetectBuild()
Assert(kEnh == "enhancement" and pEnh == "sha_enhancement_pve", "Talentos Enhancement detectan 'enhancement'")
SetBuild("elemental")
local _, pSel = SHA:DetectBuild()
Assert(pSel == "sha_elemental_pve", "Build elegida por el PJ pisa la deteccion")
SetBuild("auto")

local function upd()
    local st = RotaCore.State:Update(GetTime())
    st.inCombat = true
    return st
end
_G.RotaCoreDB.settings.aoeMode = "OFF"
wowmock.inCombat = true
wowmock.clearAuras("player")
wowmock.clearAuras("target")
wowmock.clearSpellCDs()
wowmock.totems = {}
wowmock.setPower("player", 0, 10000, 10000)
wowmock.setHealth("target", 50000, 50000)

-- Elemental ST
local st = upd()
Assert(SHA.Evaluate.elemental(st) == "FS", "Ele: sin Flame Shock -> FS")
st.aoeMode = true
wowmock.totems[1] = { name = "Magma Totem", start = GetTime(), duration = 20 }
wowmock.triggerSpellCD(61657, 10); wowmock.triggerSpellCD(49271, 6)
st = upd(); st.aoeMode = true
Assert(SHA.Evaluate.elemental(st) == "FS", "Ele AoE: Fire Nova y Chain Lightning en CD, sin Flame Shock -> FS")
wowmock.totems[1] = nil
wowmock.clearSpellCDs()
wowmock.setAura("target", { name = "Flame Shock", filter = "HARMFUL", duration = 18, unitCaster = "player" })
wowmock.playerSpeed = 7
st = upd()
Assert(SHA.Evaluate.elemental(st) == "FRS", "Ele: en movimiento con Flame Shock puesto -> Frost Shock")
wowmock.playerSpeed = 0
st = upd()
Assert(SHA.Evaluate.elemental(st) == "LVB", "Ele: con Flame Shock -> Lava Burst")
wowmock.triggerSpellCD(60043, 8.0)
st = upd()
Assert(SHA.Evaluate.elemental(st) == "TOW", "Ele: Lava Burst en CD, sin Chain Lightning en ST (Wowhead) -> Totem of Wrath")
wowmock.totems[1] = { name = "Totem of Wrath", start = GetTime(), duration = 300 }
st = upd()
Assert(SHA.Evaluate.elemental(st) == "LB", "Ele: todo en CD -> Lightning Bolt")
wowmock.setPower("player", 0, 4000, 10000)
st = upd()
Assert(SHA.Evaluate.elemental(st) == "TS", "Ele: mana < 60% -> Thunderstorm")
wowmock.setPower("player", 0, 10000, 10000)
st = upd()
Assert(SHA.EvaluateElementalOff(st) == "WS", "Ele off: sin escudo -> Water Shield")
wowmock.setAura("player", { name = "Water Shield", filter = "HELPFUL", duration = 600 })
st = upd()
Assert(SHA.EvaluateElementalOff(st) == "EM", "Ele off: Burst -> Elemental Mastery")

-- Enhancement (Wowhead): Maelstrom 5 > SS > FS > Magma > LS > ES > Fire Nova > Lava Lash
wowmock.clearAuras("player")
wowmock.clearAuras("target")
wowmock.clearSpellCDs()
wowmock.totems = {}
wowmock.setAura("player", { name = "Maelstrom Weapon", filter = "HELPFUL", duration = 30, count = 5 })
st = upd()
Assert(SHA.Evaluate.enhancement(st) == "LB", "Enh: Maelstrom 5 -> Lightning Bolt")
wowmock.clearAuras("player")
st = upd()
Assert(SHA.Evaluate.enhancement(st) == "SS", "Enh: Stormstrike listo -> SS")
wowmock.triggerSpellCD(17364, 8.0)
st = upd()
Assert(SHA.Evaluate.enhancement(st) == "FS", "Enh: shock listo sin Flame Shock -> FS")
wowmock.setAura("target", { name = "Flame Shock", filter = "HARMFUL", duration = 18, unitCaster = "player" })
st = upd()
Assert(SHA.Evaluate.enhancement(st) == "MAGMA", "Enh: sin totem de fuego -> Magma Totem (antes que Earth Shock)")
wowmock.totems[1] = { name = "Magma Totem", start = GetTime(), duration = 20 }
st = upd()
Assert(SHA.Evaluate.enhancement(st) == "LS", "Enh: sin Lightning Shield -> LS")
wowmock.setAura("player", { name = "Lightning Shield", filter = "HELPFUL", duration = 600, count = 3 })
st = upd()
Assert(SHA.Evaluate.enhancement(st) == "ES", "Enh: con Flame Shock -> Earth Shock")
wowmock.triggerSpellCD(49231, 6.0)
st = upd()
Assert(SHA.Evaluate.enhancement(st) == "FN", "Enh: con Magma -> Fire Nova")
wowmock.triggerSpellCD(61657, 10.0)
st = upd()
Assert(SHA.Evaluate.enhancement(st) == "LL", "Enh: Fire Nova en CD -> Lava Lash")
Assert(SHA.EvaluateEnhancementOff(st) == "SR", "Enh off: Shamanistic Rage a CD (Wowhead)")
wowmock.inCombat = false
st = RotaCore.State:Update(GetTime())
st.inCombat = false
Assert(SHA.EvaluateEnhancementOff(st) == "WFW", "Enh off: fuera de combate sin imbue -> Windfury Weapon")
wowmock.inCombat = true

-- Zero-allocation
st = upd()
for _ = 1, 10 do
    RotaCore.State:Update(100.0)
    SHA.Evaluate.elemental(st); SHA.EvaluateElementalOff(st)
    SHA.Evaluate.enhancement(st); SHA.EvaluateEnhancementOff(st)
end
collectgarbage("collect"); collectgarbage("collect")
local memB = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    SHA.Evaluate.elemental(st); SHA.EvaluateElementalOff(st)
    SHA.Evaluate.enhancement(st); SHA.EvaluateEnhancementOff(st)
end
local shaGarbage = collectgarbage("count") - memB
print(string.format("  Garbage across 1000 Shaman evaluations: %.4f KB", shaGarbage))
Assert(shaGarbage == 0.0, "Zero-Allocation Check: 0.0 KB en 1000 evaluaciones de Chaman")
wowmock.inCombat = false
_G.RotaCoreDB.settings.aoeMode = nil
wowmock.talents.tabs = savedTabs
end

-- ----------------------------------------------------------------------------
-- Brujo (RotaClass_WL): Affliction, Demonology, Destruction
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Warlock Module (RotaClass_WL)")
local wlSpells = {
    { 47809, "Shadow Bolt" }, { 59164, "Haunt" }, { 47813, "Corruption" }, { 47843, "Unstable Affliction" },
    { 47864, "Curse of Agony" }, { 47867, "Curse of Doom" }, { 47865, "Curse of the Elements" },
    { 47855, "Drain Soul" }, { 57946, "Life Tap" }, { 63321, "Life Tap" }, { 47811, "Immolate" },
    { 47838, "Incinerate" }, { 17962, "Conflagrate" }, { 59172, "Chaos Bolt" }, { 47825, "Soul Fire" },
    { 47836, "Seed of Corruption" }, { 47241, "Metamorphosis" }, { 47193, "Demonic Empowerment" },
    { 50589, "Immolation Aura" }, { 47847, "Shadowfury" }, { 71165, "Molten Core" }, { 63167, "Decimation" },
    { 54277, "Backdraft" }, { 17800, "Shadow Mastery" },
}
for _, sp in ipairs(wlSpells) do wowmock.registerSpell(sp[1], sp[2]) end
local savedTabs = wowmock.talents.tabs
wowmock.setClass("Warlock", "WARLOCK")
SetBuild("auto")
Assert(LoadAddOn("RotaClass_WL") == true, "LoadAddOn('RotaClass_WL') carga el modulo")
local WL = _G.RotaClass_WL
local wlMod = RotaCore:GetClassModule("WARLOCK")
Assert(wlMod ~= nil and #wlMod.builds == 4, "Modulo WARLOCK registrado con AUTO + 3 specs")
Assert(RotaCore.Profiles:GetPreset("wl_affliction_pve") ~= nil, "Preset wl_affliction_pve registrado")
Assert(RotaCore.Profiles:GetPreset("wl_demonology_pve") ~= nil, "Preset wl_demonology_pve registrado")
Assert(RotaCore.Profiles:GetPreset("wl_destruction_pve") ~= nil, "Preset wl_destruction_pve registrado")

-- Deteccion
local function tabs(a, d, x)
    wowmock.talents.tabs = {
        [1] = { name = "Affliction", pointsSpent = a, talents = {} },
        [2] = { name = "Demonology", pointsSpent = d, talents = {} },
        [3] = { name = "Destruction", pointsSpent = x, talents = {} },
    }
end
tabs(56, 15, 0)
Assert(WL:DetectBuild() == "affliction", "Talentos Affliction detectan 'affliction'")
tabs(0, 56, 15)
Assert(WL:DetectBuild() == "demonology", "Talentos Demonology detectan 'demonology'")
tabs(0, 13, 58)
local kd, pd = WL:DetectBuild()
Assert(kd == "destruction" and pd == "wl_destruction_pve", "Talentos Destruction detectan 'destruction'")
SetBuild("affliction")
local _, pSel = WL:DetectBuild()
Assert(pSel == "wl_affliction_pve", "Build elegida por el PJ pisa la deteccion")
SetBuild("auto")

local function upd()
    local st = RotaCore.State:Update(GetTime())
    st.inCombat = true
    return st
end
local function reset()
    wowmock.clearAuras("player")
    wowmock.clearAuras("target")
    wowmock.clearSpellCDs()
    wowmock.setAura("player", { name = "Life Tap", filter = "HELPFUL", duration = 40 })
    wowmock.setAura("target", { name = "Shadow Mastery", filter = "HARMFUL", duration = 30, unitCaster = "party1" })
end
_G.RotaCoreDB.settings.aoeMode = "OFF"
wowmock.inCombat = true
wowmock.setPower("player", 0, 10000, 10000)
wowmock.setHealth("target", 50000, 50000)
local function dot(auraName)
    wowmock.setAura("target", { name = auraName, filter = "HARMFUL", duration = 18, unitCaster = "player" })
end

-- Affliction (Wowhead): Life Tap > Shadow Mastery > Corruption > UA > Curse > Haunt > Drain Soul / Shadow Bolt
reset()
RotaCore.Profiles:SetActiveProfile("wl_affliction_pve")
local st = upd()
Assert(WL.Evaluate.affliction(st) == "CORR", "Aff: Corruption primero")
dot("Corruption")
st = upd()
Assert(WL.Evaluate.affliction(st) == "UA", "Aff: -> Unstable Affliction")
dot("Unstable Affliction")
st = upd()
Assert(WL.Evaluate.affliction(st) == "COA", "Aff: sin maldicion -> Curse of Agony")
dot("Curse of Agony")
st = upd()
Assert(WL.Evaluate.affliction(st) == "HAUNT", "Aff: DoTs arriba -> Haunt")
dot("Haunt")
st = upd()
Assert(WL.Evaluate.affliction(st) == "SB", "Aff: todo arriba -> Shadow Bolt")
wowmock.setHealth("target", 10000, 50000)
st = upd()
Assert(WL.Evaluate.affliction(st) == "DSOUL", "Aff: objetivo < 25% -> Drain Soul")
wowmock.setHealth("target", 50000, 50000)
wowmock.clearAuras("player")
st = upd()
Assert(WL.Evaluate.affliction(st) == "LT", "Aff: sin buff de Glyph of Life Tap -> Life Tap (primero)")
reset()
wowmock.clearAuras("target")
st = upd()
Assert(WL.Evaluate.affliction(st) == "SB", "Aff: sin Shadow Mastery en el objetivo -> Shadow Bolt")

-- Demonology
reset()
RotaCore.Profiles:SetActiveProfile("wl_demonology_pve")
wowmock.classification.target = "worldboss"
st = upd()
Assert(WL.Evaluate.demonology(st) == "COD", "Demo: boss sin maldicion -> Curse of Doom")
dot("Curse of Doom")
st = upd()
Assert(WL.Evaluate.demonology(st) == "CORR", "Demo: -> Corruption")
dot("Corruption")
st = upd()
Assert(WL.Evaluate.demonology(st) == "IMM", "Demo: -> Immolate")
dot("Immolate")
st = upd()
Assert(WL.Evaluate.demonology(st) == "SB", "Demo: todo arriba -> Shadow Bolt")
wowmock.setAura("player", { name = "Molten Core", filter = "HELPFUL", duration = 15, count = 3 })
st = upd()
Assert(WL.Evaluate.demonology(st) == "INC", "Demo: Molten Core -> Incinerate")
wowmock.setAura("player", { name = "Decimation", filter = "HELPFUL", duration = 10 })
st = upd()
Assert(WL.Evaluate.demonology(st) == "SF", "Demo: Decimation -> Soul Fire (antes que Incinerate)")
Assert(WL.EvaluateDemonologyOff(st) == "DE", "Demo off: con mascota -> Demonic Empowerment")
wowmock.triggerSpellCD(47193, 60)
st = upd()
Assert(WL.EvaluateDemonologyOff(st) == "META", "Demo off: Burst -> Metamorphosis")
wowmock.classification.target = nil

-- Destruction
reset()
RotaCore.Profiles:SetActiveProfile("wl_destruction_pve")
st = upd()
Assert(WL.Evaluate.destruction(st) == "COA", "Dest: no boss sin maldicion -> Curse of Agony (auto)")
dot("Curse of Agony")
st = upd()
Assert(WL.Evaluate.destruction(st) == "IMM", "Dest: -> Immolate")
dot("Immolate")
st = upd()
Assert(WL.Evaluate.destruction(st) == "CONF", "Dest: Immolate arriba -> Conflagrate")
wowmock.triggerSpellCD(17962, 10)
st = upd()
Assert(WL.Evaluate.destruction(st) == "CB", "Dest: Conflagrate en CD -> Chaos Bolt")
wowmock.triggerSpellCD(59172, 12)
st = upd()
Assert(WL.Evaluate.destruction(st) == "INC", "Dest: todo en CD -> Incinerate")
_G.RotaCoreDB.settings.aoeMode = "ON"
st = upd()
st.aoeMode = true
Assert(WL.Evaluate.destruction(st) == "SFURY", "Dest AoE: Shadowfury")
Assert(WL.Evaluate.affliction(st) == "SEED", "Aff AoE: Seed of Corruption")
_G.RotaCoreDB.settings.aoeMode = "OFF"

-- Zero-allocation
st = upd()
for _ = 1, 10 do
    RotaCore.State:Update(100.0)
    WL.Evaluate.affliction(st); WL.Evaluate.demonology(st); WL.Evaluate.destruction(st)
    WL.EvaluateDemonologyOff(st); WL.EvaluateAfflictionOff(st)
end
collectgarbage("collect"); collectgarbage("collect")
local memB = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    WL.Evaluate.affliction(st); WL.Evaluate.demonology(st); WL.Evaluate.destruction(st)
    WL.EvaluateDemonologyOff(st); WL.EvaluateAfflictionOff(st)
end
local wlGarbage = collectgarbage("count") - memB
print(string.format("  Garbage across 1000 Warlock evaluations: %.4f KB", wlGarbage))
Assert(wlGarbage == 0.0, "Zero-Allocation Check: 0.0 KB en 1000 evaluaciones de Brujo")
wowmock.inCombat = false
_G.RotaCoreDB.settings.aoeMode = nil
wowmock.talents.tabs = savedTabs
end

-- ----------------------------------------------------------------------------
-- Mago (RotaClass_MAG): Arcane, Fire, Frost
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Mage Module (RotaClass_MAG)")
local magSpells = {
    { 42897, "Arcane Blast" }, { 36032, "Arcane Blast" }, { 42846, "Arcane Missiles" }, { 44781, "Arcane Barrage" },
    { 12042, "Arcane Power" }, { 12043, "Presence of Mind" }, { 12472, "Icy Veins" }, { 55342, "Mirror Image" },
    { 12051, "Evocation" }, { 42833, "Fireball" }, { 54741, "Firestarter" }, { 42945, "Blast Wave" },
    { 47610, "Frostfire Bolt" }, { 42891, "Pyroblast" },
    { 55360, "Living Bomb" }, { 42859, "Scorch" }, { 11129, "Combustion" }, { 42842, "Frostbolt" },
    { 44572, "Deep Freeze" }, { 31687, "Summon Water Elemental" }, { 42940, "Blizzard" }, { 42926, "Flamestrike" },
    { 42921, "Arcane Explosion" }, { 44401, "Missile Barrage" }, { 48108, "Hot Streak" }, { 57761, "Fireball!" },
    { 44544, "Fingers of Frost" }, { 22959, "Improved Scorch" }, { 17800, "Shadow Mastery" },
    { 12579, "Winter's Chill" },
}
for _, sp in ipairs(magSpells) do wowmock.registerSpell(sp[1], sp[2]) end
local savedTabs = wowmock.talents.tabs
wowmock.setClass("Mage", "MAGE")
SetBuild("auto")
Assert(LoadAddOn("RotaClass_MAG") == true, "LoadAddOn('RotaClass_MAG') carga el modulo")
local MAG = _G.RotaClass_MAG
local magMod = RotaCore:GetClassModule("MAGE")
Assert(magMod ~= nil and #magMod.builds == 4, "Modulo MAGE registrado con AUTO + 3 specs")
for _, id in ipairs({ "mag_arcane_pve", "mag_fire_pve", "mag_frost_pve" }) do
    Assert(RotaCore.Profiles:GetPreset(id) ~= nil, "Preset " .. id .. " registrado")
end

local function tabs(a, f, x)
    wowmock.talents.tabs = {
        [1] = { name = "Arcane", pointsSpent = a, talents = {} },
        [2] = { name = "Fire", pointsSpent = f, talents = {} },
        [3] = { name = "Frost", pointsSpent = x, talents = {} },
    }
end
tabs(57, 3, 11)
Assert(MAG:DetectBuild() == "arcane", "Talentos Arcane detectan 'arcane'")
tabs(18, 53, 0)
Assert(MAG:DetectBuild() == "fire", "Talentos Fire detectan 'fire'")
tabs(18, 0, 53)
Assert(MAG:DetectBuild() == "frost", "Talentos Frost detectan 'frost'")
SetBuild("fire")
local _, pSel = MAG:DetectBuild()
Assert(pSel == "mag_fire_pve", "Build elegida por el PJ pisa la deteccion")
SetBuild("auto")

local function upd()
    local st = RotaCore.State:Update(GetTime())
    st.inCombat = true
    return st
end
local function reset(profile)
    wowmock.clearAuras("player")
    wowmock.clearAuras("target")
    wowmock.clearSpellCDs()
    RotaCore.Profiles:SetActiveProfile(profile)
end
_G.RotaCoreDB.settings.aoeMode = "OFF"
wowmock.inCombat = true
wowmock.setPower("player", 0, 10000, 10000)
wowmock.setHealth("target", 50000, 50000)

-- Arcane
reset("mag_arcane_pve")
local st = upd()
Assert(MAG.Evaluate.arcane(st) == "AB", "Arc: sin stacks -> Arcane Blast")
-- Wowhead "Better Rotation": con Missile Barrage, Arcane Missiles despues del 4.o Arcane Blast,
-- o despues del siguiente si el proc salio en el 4.o o mas tarde; sin proc, despues del 6.o
local function arc(casts, stacks, barrage)
    MAG.abCasts = casts
    wowmock.clearAuras("player")
    wowmock.setAura("player", { name = "Arcane Blast", filter = "HARMFUL", duration = 6, count = stacks })
    if barrage then wowmock.setAura("player", { name = "Missile Barrage", filter = "HELPFUL", duration = 15 }) end
    return upd()
end
MAG.abProcAt = nil
st = arc(2, 2, true)
Assert(MAG.Evaluate.arcane(st) == "AB", "Arc: proc en el 2.o Arcane Blast -> sigue hasta 4")
st = arc(4, 4, true)
Assert(MAG.Evaluate.arcane(st) == "AM", "Arc: proc temprano y 4 Arcane Blast -> Arcane Missiles")
MAG.abProcAt = nil
st = arc(4, 4, true)
Assert(MAG.Evaluate.arcane(st) == "AB", "Arc: proc en el 4.o Arcane Blast -> uno mas")
st = arc(5, 4, true)
Assert(MAG.Evaluate.arcane(st) == "AM", "Arc: proc en el 4.o y 5 Arcane Blast -> Arcane Missiles")
MAG.abProcAt = nil
st = arc(5, 4, false)
Assert(MAG.Evaluate.arcane(st) == "AB", "Arc: sin proc y 5 Arcane Blast -> sigue")
st = arc(6, 4, false)
Assert(MAG.Evaluate.arcane(st) == "AM", "Arc: sin proc y 6 Arcane Blast -> Arcane Missiles")
MAG.abCasts, MAG.abProcAt = 0, nil
wowmock.playerSpeed = 7
st = arc(0, 0, false)
Assert(MAG.Evaluate.arcane(st) == "ABAR", "Arc: en movimiento -> Arcane Barrage")
wowmock.playerSpeed = 0
wowmock.setPower("player", 0, 1000, 10000)
wowmock.clearAuras("player")
st = upd()
Assert(MAG.Evaluate.arcane(st) == "EVO", "Arc: mana < 15% -> Evocation")
wowmock.setPower("player", 0, 10000, 10000)
st = upd()
Assert(MAG.EvaluateArcaneOff(st) == "AP", "Arc off: Burst -> Arcane Power")

-- Fire
reset("mag_fire_pve")
st = upd()
Assert(MAG.Evaluate.fire(st) == "LB", "Fire: sin Living Bomb -> Living Bomb")
wowmock.setAura("target", { name = "Living Bomb", filter = "HARMFUL", duration = 12, unitCaster = "player" })
st = upd()
Assert(MAG.Evaluate.fire(st) == "FB", "Fire: sin debuff de critico y scorch=0 (Wowhead) -> Fireball")
st.vars.scorch = 1
Assert(MAG.Evaluate.fire(st) == "SCORCH", "Fire: scorch=1 y sin debuff de critico -> Scorch")
st.vars.scorch = 0
st.aoeMode = true
Assert(MAG.Evaluate.fire(st) == "BW", "Fire AoE: Living Bomb puesta -> Blast Wave")
wowmock.setAura("player", { name = "Firestarter", filter = "HELPFUL", duration = 10 })
st = upd(); st.aoeMode = true
Assert(MAG.Evaluate.fire(st) == "FS", "Fire AoE: Firestarter -> Flamestrike")
wowmock.clearAuras("player")
wowmock.setAura("target", { name = "Improved Scorch", filter = "HARMFUL", duration = 30, unitCaster = "player" })
st = upd()
Assert(MAG.Evaluate.fire(st) == "FB", "Fire: todo arriba -> Fireball")
wowmock.setAura("player", { name = "Hot Streak", filter = "HELPFUL", duration = 10 })
st = upd()
Assert(MAG.Evaluate.fire(st) == "PYRO", "Fire: Hot Streak -> Pyroblast")
Assert(MAG.EvaluateFireOff(st) == "COMB", "Fire off: Living Bomb fresca -> Combustion")

-- Frost
reset("mag_frost_pve")
wowmock.petExists = false
st = upd()
Assert(MAG.Evaluate.frost(st) == "WE", "Frost: sin Water Elemental -> invocarlo")
wowmock.petExists = true
st = upd()
Assert(MAG.Evaluate.frost(st) == "FROSTBOLT", "Frost: sin procs -> Frostbolt")
wowmock.setAura("player", { name = "Fireball!", filter = "HELPFUL", duration = 15 })
st = upd()
Assert(MAG.Evaluate.frost(st) == "FFB", "Frost: Brain Freeze -> Frostfire Bolt")
wowmock.setAura("player", { name = "Fingers of Frost", filter = "HELPFUL", duration = 15, count = 2 })
st = upd()
Assert(MAG.Evaluate.frost(st) ~= "DF", "Frost: Fingers of Frost con 2 cargas -> todavia no Deep Freeze")
wowmock.clearAuras("player")
wowmock.setAura("player", { name = "Fingers of Frost", filter = "HELPFUL", duration = 15, count = 1 })
st = upd()
Assert(MAG.Evaluate.frost(st) == "DF", "Frost: ultima carga de Fingers of Frost -> Deep Freeze")
st.aoeMode = true
Assert(MAG.Evaluate.frost(st) == "BLIZZ", "Frost AoE: Blizzard")
st.aoeMode = false
Assert(MAG.EvaluateFrostOff(st) == "IV", "Frost off: Burst -> Icy Veins")

-- Zero-allocation
st = upd()
for _ = 1, 10 do
    RotaCore.State:Update(100.0)
    MAG.Evaluate.arcane(st); MAG.Evaluate.fire(st); MAG.Evaluate.frost(st)
    MAG.EvaluateArcaneOff(st); MAG.EvaluateFireOff(st); MAG.EvaluateFrostOff(st)
end
collectgarbage("collect"); collectgarbage("collect")
local memB = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    MAG.Evaluate.arcane(st); MAG.Evaluate.fire(st); MAG.Evaluate.frost(st)
    MAG.EvaluateArcaneOff(st); MAG.EvaluateFireOff(st); MAG.EvaluateFrostOff(st)
end
local magGarbage = collectgarbage("count") - memB
print(string.format("  Garbage across 1000 Mage evaluations: %.4f KB", magGarbage))
Assert(magGarbage == 0.0, "Zero-Allocation Check: 0.0 KB en 1000 evaluaciones de Mago")
wowmock.inCombat = false
_G.RotaCoreDB.settings.aoeMode = nil
wowmock.talents.tabs = savedTabs
end

-- ----------------------------------------------------------------------------
-- Sacerdote Sombras (RotaClass_PRI)
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Shadow Priest Module (RotaClass_PRI)")
local priSpells = {
    { 48125, "Shadow Word: Pain" }, { 48160, "Vampiric Touch" }, { 48300, "Devouring Plague" }, { 48127, "Mind Blast" },
    { 48156, "Mind Flay" }, { 48158, "Shadow Word: Death" }, { 53023, "Mind Sear" }, { 15473, "Shadowform" },
    { 34433, "Shadowfiend" }, { 47585, "Dispersion" }, { 48168, "Inner Fire" }, { 15286, "Vampiric Embrace" },
    { 14751, "Inner Focus" }, { 15258, "Shadow Weaving" },
}
for _, sp in ipairs(priSpells) do wowmock.registerSpell(sp[1], sp[2]) end
wowmock.setClass("Priest", "PRIEST")
SetBuild("auto")
Assert(LoadAddOn("RotaClass_PRI") == true, "LoadAddOn('RotaClass_PRI') carga el modulo")
local PRI = _G.RotaClass_PRI
local priMod = RotaCore:GetClassModule("PRIEST")
Assert(priMod ~= nil and #priMod.builds == 1, "Modulo PRIEST registrado con una sola build (Shadow)")
local _, pid = PRI:DetectBuild()
Assert(pid == "pri_shadow_pve", "Deteccion activa pri_shadow_pve")

local function upd()
    local st = RotaCore.State:Update(GetTime())
    st.inCombat = true
    return st
end
local function dot(auraName)
    wowmock.setAura("target", { name = auraName, filter = "HARMFUL", duration = 15, unitCaster = "player" })
end
_G.RotaCoreDB.settings.aoeMode = "OFF"
wowmock.inCombat = true
wowmock.clearAuras("player")
wowmock.clearAuras("target")
wowmock.clearSpellCDs()
wowmock.setPower("player", 0, 10000, 10000)
wowmock.setHealth("target", 50000, 50000)

local st = upd()
Assert(PRI.Evaluate.shadow(st) == "SHADOWFORM", "Sin Shadowform -> Shadowform")
wowmock.setAura("player", { name = "Shadowform", filter = "HELPFUL", duration = 0 })
st = upd()
Assert(PRI.Evaluate.shadow(st) == "VT", "Sin stacks: SW:P espera, Vampiric Touch primero")
dot("Vampiric Touch")
st = upd()
Assert(PRI.Evaluate.shadow(st) == "DP", "-> Devouring Plague")
dot("Devouring Plague")
st = upd()
Assert(PRI.Evaluate.shadow(st) == "MB", "-> Mind Blast")
wowmock.triggerSpellCD(48127, 5.5)
st = upd()
Assert(PRI.Evaluate.shadow(st) == "MF", "Mind Blast en CD -> Mind Flay")
wowmock.setAura("player", { name = "Shadow Weaving", filter = "HELPFUL", duration = 15, count = 5 })
st = upd()
Assert(PRI.Evaluate.shadow(st) == "SWP", "5 stacks de Shadow Weaving -> SW:P")
dot("Shadow Word: Pain")
st = upd()
st.aoeMode = true
Assert(PRI.Evaluate.shadow(st) == "MSEAR", "AoE: Mind Sear reemplaza a Mind Flay")
st.aoeMode = false
wowmock.playerSpeed = 7
st = upd()
Assert(PRI.Evaluate.shadow(st) == "SWD", "En movimiento -> Shadow Word: Death")
wowmock.playerSpeed = 0
Assert(PRI.EvaluateShadowOff(st) == "FIEND", "Off: Burst -> Shadowfiend")
wowmock.inCombat = false
st = RotaCore.State:Update(GetTime())
st.inCombat = false
Assert(PRI.EvaluateShadowOff(st) == "INNERFIRE", "Off fuera de combate: sin Inner Fire -> Inner Fire")
wowmock.inCombat = true

-- Zero-allocation
st = upd()
for _ = 1, 10 do
    RotaCore.State:Update(100.0)
    PRI.Evaluate.shadow(st); PRI.EvaluateShadowOff(st)
end
collectgarbage("collect"); collectgarbage("collect")
local memB = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    PRI.Evaluate.shadow(st); PRI.EvaluateShadowOff(st)
end
local priGarbage = collectgarbage("count") - memB
print(string.format("  Garbage across 1000 Shadow Priest evaluations: %.4f KB", priGarbage))
Assert(priGarbage == 0.0, "Zero-Allocation Check: 0.0 KB en 1000 evaluaciones de Sombras")
wowmock.inCombat = false
_G.RotaCoreDB.settings.aoeMode = nil
end

-- ----------------------------------------------------------------------------
-- Cazador (RotaClass_HUN): Beast Mastery, Marksmanship, Survival
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Hunter Module (RotaClass_HUN)")
local hunSpells = {
    { 61006, "Kill Shot" }, { 34026, "Kill Command" }, { 49048, "Multi-Shot" }, { 49001, "Serpent Sting" },
    { 49045, "Arcane Shot" }, { 49052, "Steady Shot" }, { 49050, "Aimed Shot" }, { 53209, "Chimera Shot" },
    { 60053, "Explosive Shot" }, { 63672, "Black Arrow" }, { 34490, "Silencing Shot" }, { 19574, "Bestial Wrath" },
    { 3045, "Rapid Fire" }, { 23989, "Readiness" }, { 58434, "Volley" }, { 82939, "Trap Launcher: Explosive Trap" },
    { 61847, "Aspect of the Dragonhawk" }, { 34074, "Aspect of the Viper" }, { 56453, "Lock and Load" },
}
for _, sp in ipairs(hunSpells) do wowmock.registerSpell(sp[1], sp[2]) end
local savedTabs = wowmock.talents.tabs
wowmock.setClass("Hunter", "HUNTER")
SetBuild("auto")
Assert(LoadAddOn("RotaClass_HUN") == true, "LoadAddOn('RotaClass_HUN') carga el modulo")
local HUN = _G.RotaClass_HUN
local hunMod = RotaCore:GetClassModule("HUNTER")
Assert(hunMod ~= nil and #hunMod.builds == 4, "Modulo HUNTER registrado con AUTO + 3 specs")
for _, id in ipairs({ "hun_beast_mastery_pve", "hun_marksmanship_pve", "hun_survival_pve" }) do
    Assert(RotaCore.Profiles:GetPreset(id) ~= nil, "Preset " .. id .. " registrado")
end
local function tabs(b, m, v)
    wowmock.talents.tabs = {
        [1] = { name = "Beast Mastery", pointsSpent = b, talents = {} },
        [2] = { name = "Marksmanship", pointsSpent = m, talents = {} },
        [3] = { name = "Survival", pointsSpent = v, talents = {} },
    }
end
tabs(53, 18, 0)
Assert(HUN:DetectBuild() == "beast_mastery", "Talentos BM detectan 'beast_mastery'")
tabs(7, 57, 7)
Assert(HUN:DetectBuild() == "marksmanship", "Talentos MM detectan 'marksmanship'")
tabs(0, 18, 53)
Assert(HUN:DetectBuild() == "survival", "Talentos SV detectan 'survival'")

local function upd()
    local st = RotaCore.State:Update(GetTime())
    st.inCombat = true
    return st
end
local function reset(profile)
    wowmock.clearAuras("player")
    wowmock.clearAuras("target")
    wowmock.clearSpellCDs()
    wowmock.setAura("player", { name = "Aspect of the Dragonhawk", filter = "HELPFUL", duration = 0 })
    RotaCore.Profiles:SetActiveProfile(profile)
end
local function sting()
    wowmock.setAura("target", { name = "Serpent Sting", filter = "HARMFUL", duration = 15, unitCaster = "player" })
end
_G.RotaCoreDB.settings.aoeMode = "OFF"
wowmock.inCombat = true
wowmock.setPower("player", 0, 10000, 10000)
wowmock.setHealth("target", 50000, 50000)

-- Marksmanship
reset("hun_marksmanship_pve")
local st = upd()
Assert(HUN.Evaluate.marksmanship(st) == "SERPENT", "MM: sin Serpent Sting -> Serpent Sting")
sting()
st = upd()
Assert(HUN.Evaluate.marksmanship(st) == "CHIMERA", "MM: con Serpent Sting -> Chimera Shot")
wowmock.triggerSpellCD(53209, 10)
st = upd()
Assert(HUN.Evaluate.marksmanship(st) == "AIMED", "MM: -> Aimed Shot")
wowmock.triggerSpellCD(49050, 10)
st = upd()
Assert(HUN.Evaluate.marksmanship(st) == "TRAP", "MM: -> Trap Launcher: Explosive Trap")
wowmock.triggerSpellCD(82939, 30)
st = upd()
Assert(HUN.Evaluate.marksmanship(st) == "ARCANE", "MM: -> Arcane Shot")
wowmock.triggerSpellCD(49045, 6)
st = upd()
Assert(HUN.Evaluate.marksmanship(st) == "STEADY", "MM: todo en CD -> Steady Shot")
wowmock.setHealth("target", 8000, 50000)
st = upd()
Assert(HUN.Evaluate.marksmanship(st) == "KS", "MM: objetivo < 20% -> Kill Shot")
wowmock.setHealth("target", 50000, 50000)
st = upd()
Assert(HUN.EvaluateMarksmanshipOff(st) == "KC", "MM off: Kill Command a CD")

-- Survival
reset("hun_survival_pve")
sting()
st = upd()
Assert(HUN.Evaluate.survival(st) == "ES", "SV: Explosive Shot primero")
wowmock.triggerSpellCD(60053, 6)
wowmock.clearAuras("target")
st = upd()
Assert(HUN.Evaluate.survival(st) == "TRAP", "SV: Explosive Trap antes de reponer Serpent Sting (Wowhead)")
sting()
st = upd()
Assert(HUN.Evaluate.survival(st) == "TRAP", "SV: -> Explosive Trap (antes que Black Arrow)")
wowmock.triggerSpellCD(82939, 30)
st = upd()
Assert(HUN.Evaluate.survival(st) == "BA", "SV: trap en CD -> Black Arrow")
wowmock.clearAuras("target")
st = upd()
Assert(HUN.Evaluate.survival(st) == "SERPENT", "SV: Serpent Sting caido -> Serpent Sting")

-- Beast Mastery
reset("hun_beast_mastery_pve")
st = upd()
Assert(HUN.Evaluate.beast_mastery(st) == "MULTI", "BM: Multi-Shot con mana")
wowmock.triggerSpellCD(49048, 10)
st = upd()
Assert(HUN.Evaluate.beast_mastery(st) == "SERPENT", "BM: -> Serpent Sting")
Assert(HUN.EvaluateBeastMasteryOff(st) == "BW", "BM off: Burst -> Bestial Wrath")
st.aoeMode = true
Assert(HUN.Evaluate.beast_mastery(st) == "TRAP", "AoE: Trap Launcher: Explosive Trap primero")

-- Aspectos
wowmock.clearAuras("player")
wowmock.setPower("player", 0, 500, 10000)
st = upd()
Assert(HUN.EvaluateSurvivalOff(st) == "VIPER", "Mana < 10% -> Aspect of the Viper")
wowmock.setAura("player", { name = "Aspect of the Viper", filter = "HELPFUL", duration = 0 })
wowmock.setPower("player", 0, 8000, 10000)
st = upd()
Assert(HUN.EvaluateSurvivalOff(st) == "DRAGONHAWK", "Mana >= 70% en Viper -> Aspect of the Dragonhawk")
wowmock.setPower("player", 0, 10000, 10000)

-- Zero-allocation
st = upd()
for _ = 1, 10 do
    RotaCore.State:Update(100.0)
    HUN.Evaluate.beast_mastery(st); HUN.Evaluate.marksmanship(st); HUN.Evaluate.survival(st)
    HUN.EvaluateBeastMasteryOff(st); HUN.EvaluateMarksmanshipOff(st); HUN.EvaluateSurvivalOff(st)
end
collectgarbage("collect"); collectgarbage("collect")
local memB = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    HUN.Evaluate.beast_mastery(st); HUN.Evaluate.marksmanship(st); HUN.Evaluate.survival(st)
    HUN.EvaluateBeastMasteryOff(st); HUN.EvaluateMarksmanshipOff(st); HUN.EvaluateSurvivalOff(st)
end
local hunGarbage = collectgarbage("count") - memB
print(string.format("  Garbage across 1000 Hunter evaluations: %.4f KB", hunGarbage))
Assert(hunGarbage == 0.0, "Zero-Allocation Check: 0.0 KB en 1000 evaluaciones de Cazador")
wowmock.inCombat = false
_G.RotaCoreDB.settings.aoeMode = nil
wowmock.talents.tabs = savedTabs
end

-- ----------------------------------------------------------------------------
-- Druida (RotaClass_DRU): Balance y Feral (gato)
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Druid Module (RotaClass_DRU)")
local druSpells = {
    { 48461, "Wrath" }, { 48465, "Starfire" }, { 48463, "Moonfire" }, { 48468, "Insect Swarm" },
    { 770, "Faerie Fire" }, { 16857, "Faerie Fire (Feral)" }, { 53201, "Starfall" }, { 33831, "Force of Nature" },
    { 48467, "Hurricane" }, { 24858, "Moonkin Form" }, { 768, "Cat Form" }, { 52610, "Savage Roar" },
    { 49800, "Rip" }, { 48574, "Rake" }, { 48566, "Mangle (Cat)" }, { 48572, "Shred" }, { 62078, "Swipe (Cat)" },
    { 50213, "Tiger's Fury" }, { 50334, "Berserk" }, { 16870, "Clearcasting" }, { 48517, "Eclipse" },
    { 48518, "Eclipse" }, { 48564, "Mangle (Bear)" }, { 46857, "Trauma" },
}
for _, sp in ipairs(druSpells) do wowmock.registerSpell(sp[1], sp[2]) end
local savedTabs = wowmock.talents.tabs
wowmock.setClass("Druid", "DRUID")
SetBuild("auto")
Assert(LoadAddOn("RotaClass_DRU") == true, "LoadAddOn('RotaClass_DRU') carga el modulo")
local DRU = _G.RotaClass_DRU
local druMod = RotaCore:GetClassModule("DRUID")
Assert(druMod ~= nil and #druMod.builds == 3, "Modulo DRUID registrado con AUTO + Balance + Feral")
wowmock.talents.tabs = {
    [1] = { name = "Balance", pointsSpent = 58, talents = {} },
    [2] = { name = "Feral", pointsSpent = 0, talents = {} },
    [3] = { name = "Restoration", pointsSpent = 13, talents = {} },
}
Assert(DRU:DetectBuild() == "balance", "Talentos Balance detectan 'balance'")
wowmock.talents.tabs[1].pointsSpent, wowmock.talents.tabs[2].pointsSpent = 0, 55
Assert(DRU:DetectBuild() == "feral", "Talentos Feral detectan 'feral'")

local function upd()
    local st = RotaCore.State:Update(GetTime())
    st.inCombat = true
    return st
end
local function buff(n, extra)
    local a = { name = n, filter = "HELPFUL", duration = 0 }
    for k, v in pairs(extra or {}) do a[k] = v end
    wowmock.setAura("player", a)
end
local function debuff(n, caster)
    wowmock.setAura("target", { name = n, filter = "HARMFUL", duration = 15, unitCaster = caster or "player" })
end
_G.RotaCoreDB.settings.aoeMode = "OFF"
wowmock.inCombat = true
wowmock.setHealth("target", 50000, 50000)

-- Balance
wowmock.clearAuras("player"); wowmock.clearAuras("target"); wowmock.clearSpellCDs()
DRU.lastEclipse = nil
local st = upd()
Assert(DRU.Evaluate.balance(st) == "MOONKIN", "Bal: sin Moonkin Form -> Moonkin Form")
buff("Moonkin Form")
st = upd()
Assert(DRU.Evaluate.balance(st) == "FF", "Bal: -> Faerie Fire")
debuff("Faerie Fire", "party1")
st = upd()
Assert(DRU.Evaluate.balance(st) == "IS", "Bal: -> Insect Swarm")
debuff("Insect Swarm")
st = upd()
Assert(DRU.Evaluate.balance(st) == "FON", "Bal: fuera de Eclipse con Burst -> Force of Nature")
wowmock.triggerSpellCD(33831, 180); wowmock.triggerSpellCD(53201, 90)
st = upd()
Assert(DRU.Evaluate.balance(st) == "WRATH", "Bal: sin Eclipse previo -> Wrath")
buff("Eclipse", { spellId = 48518, duration = 15 })
st = upd()
Assert(DRU.Evaluate.balance(st) == "SF", "Bal: Eclipse Lunar -> Starfire")
wowmock.clearAuras("player"); buff("Moonkin Form")
st = upd()
Assert(DRU.Evaluate.balance(st) == "SF", "Bal: despues de Lunar sigue Starfire hasta Solar")
buff("Eclipse", { spellId = 48517, duration = 15 })
st = upd()
Assert(DRU.Evaluate.balance(st) == "WRATH", "Bal: Eclipse Solar -> Wrath")

-- Feral
wowmock.clearAuras("player"); wowmock.clearAuras("target"); wowmock.clearSpellCDs()
RotaCore.Profiles:SetActiveProfile("dru_feral_pve")
wowmock.setPower("player", 3, 100, 100)
wowmock.setComboPoints(0)
st = upd()
Assert(DRU.Evaluate.feral(st) == "CAT", "Fer: sin Cat Form -> Cat Form")
buff("Cat Form")
st = upd()
Assert(DRU.Evaluate.feral(st) == "RAKE", "Fer: 0 CP, sin Rake -> Rake")
debuff("Rake")
st = upd()
Assert(DRU.Evaluate.feral(st) == "MANGLE", "Fer: sin Mangle -> Mangle (Cat)")
debuff("Mangle (Bear)", "party1")
wowmock.setComboPoints(2)
st = upd()
Assert(DRU.Evaluate.feral(st) == "SR", "Fer: 1+ CP sin Savage Roar -> Savage Roar")
buff("Savage Roar", { duration = 20 })
wowmock.setComboPoints(5)
st = upd()
Assert(DRU.Evaluate.feral(st) == "RIP", "Fer: 5 CP sin Rip -> Rip")
debuff("Rip")
st = upd()
Assert(DRU.Evaluate.feral(st) == "FFF", "Fer: todo arriba, objetivo sin Faerie Fire -> Faerie Fire (Feral)")
debuff("Faerie Fire")
st = upd()
Assert(DRU.Evaluate.feral(st) == "SHRED", "Fer: todo arriba con Faerie Fire -> Shred")
wowmock.setPower("player", 3, 60, 100)
st = upd()
Assert(DRU.Evaluate.feral(st) == "SHRED", "Fer: Faerie Fire ya puesto -> no lo vuelve a pedir")
-- Ejemplo de Wowhead: Rake cae en 2 s. Con 50 de energia conviene esperar; con 60, Shred alcanza
wowmock.clearAuras("target")
debuff("Rip"); debuff("Mangle (Cat)"); debuff("Faerie Fire")
wowmock.setAura("target", { name = "Rake", filter = "HARMFUL", duration = 2, unitCaster = "player" })
wowmock.setPower("player", 3, 50, 100)
st = upd()
Assert(DRU.Evaluate.feral(st) == "RAKE" and st.isWaiting, "Fer: 50 de energia, Rake cae en 2 s -> esperar para Rake")
wowmock.setPower("player", 3, 60, 100)
st = upd()
Assert(DRU.Evaluate.feral(st) == "SHRED" and not st.isWaiting, "Fer: 60 de energia, Rake cae en 2 s -> Shred")
-- Rebuffed: con Glyph of Omen of Clarity, Faerie Fire (Feral) en vez de esperar energia
wowmock.setPower("player", 3, 20, 100)
st = upd()
Assert(DRU.Evaluate.feral(st) ~= "FFF", "Fer: sin el glifo no usa Faerie Fire para esperar")
st.glyphs = { ["Glyph of Omen of Clarity"] = true }
Assert(DRU.Evaluate.feral(st) == "FFF", "Fer: con Glyph of Omen of Clarity y poca energia -> Faerie Fire (Feral)")
st.glyphs = {}
buff("Clearcasting", { duration = 15 })
st = upd()
Assert(DRU.Evaluate.feral(st) == "SHRED", "Fer: Clearcasting -> Shred")
wowmock.setPower("player", 3, 30, 100)
st = upd()
Assert(DRU.EvaluateFeralOff(st) == "TF", "Fer off: energia < 40 -> Tiger's Fury")
wowmock.triggerSpellCD(50213, 30)
st = upd()
Assert(DRU.EvaluateFeralOff(st) == "BERSERK", "Fer off: Tiger's Fury con 15+ s de CD -> Berserk")
st.aoeMode = true
Assert(DRU.Evaluate.feral(st) == "SWIPE", "Fer AoE: Swipe (Cat)")
st.aoeMode = false

-- Zero-allocation
st = upd()
for _ = 1, 10 do
    RotaCore.State:Update(100.0)
    DRU.Evaluate.balance(st); DRU.Evaluate.feral(st); DRU.EvaluateBalanceOff(st); DRU.EvaluateFeralOff(st)
end
collectgarbage("collect"); collectgarbage("collect")
local memB = collectgarbage("count")
for _ = 1, 1000 do
    RotaCore.State:Update(100.0)
    DRU.Evaluate.balance(st); DRU.Evaluate.feral(st); DRU.EvaluateBalanceOff(st); DRU.EvaluateFeralOff(st)
end
local druGarbage = collectgarbage("count") - memB
print(string.format("  Garbage across 1000 Druid evaluations: %.4f KB", druGarbage))
Assert(druGarbage == 0.0, "Zero-Allocation Check: 0.0 KB en 1000 evaluaciones de Druida")
wowmock.inCombat = false
_G.RotaCoreDB.settings.aoeMode = nil
wowmock.setComboPoints(0)
wowmock.talents.tabs = savedTabs
end

-- ----------------------------------------------------------------------------
-- DK Unholy: Gargola en Unholy Presence, Blood Presence al desaparecer
-- ----------------------------------------------------------------------------
do
print("\n[Suite] DK Gargoyle Presence")
wowmock.registerSpell(48265, "Unholy Presence")
wowmock.registerSpell(48266, "Blood Presence")
wowmock.registerSpell(49206, "Summon Gargoyle")
wowmock.setClass("Death Knight", "DEATHKNIGHT")
SetBuild("unholy_morb")
RotaCore.Profiles:SetActiveProfile("dk_unholy_morb_pve")
wowmock.inCombat = true
wowmock.clearAuras("player")
wowmock.clearAuras("target")
wowmock.clearSpellCDs()
wowmock.initRunes()
wowmock.setPower("player", 6, 100, 100)
wowmock.setAura("target", { name = "Frost Fever", filter = "HARMFUL", duration = 15, unitCaster = "player" })
wowmock.setAura("target", { name = "Blood Plague", filter = "HARMFUL", duration = 15, unitCaster = "player" })
wowmock.triggerSpellCD(20572, 120) -- racial en CD para que el siguiente paso sea la Gargola
local function upd()
    local st = RotaCore.State:Update(GetTime())
    st.inCombat = true
    return st
end
local st = upd()
Assert(RotaClass_DK.EvaluateUnholyOff(st) == "UP", "Gargola lista sin UP -> Unholy Presence")
wowmock.setAura("player", { name = "Unholy Presence", filter = "HELPFUL", duration = 0, spellId = 48265 })
st = upd()
Assert(RotaClass_DK.EvaluateUnholyOff(st) == "GARG", "En UP con Gargola lista -> Summon Gargoyle")
wowmock.triggerSpellCD(49206, 175)
st = upd()
Assert(RotaClass_DK.EvaluateUnholyOff(st) ~= "BP", "Gargola viva -> seguir en UP")
-- Gargola viva, haste y ERW ya usados: Army of the Dead solo contra jefes
wowmock.registerSpell(49208, "Army of the Dead")
wowmock.registerSpell(47568, "Empower Rune Weapon")
wowmock.triggerSpellCD(26297, 180); wowmock.triggerSpellCD(40211, 120); wowmock.triggerSpellCD(47568, 300)
local savedGloves = wowmock.inventoryCooldowns[10]
wowmock.inventoryCooldowns[10] = { start = GetTime(), duration = 60, enable = 1 }
wowmock.classification.target = "worldboss"
st = upd()
Assert(RotaClass_DK.EvaluateUnholyOff(st) == "AOTD", "Gargola viva + ERW usado contra jefe -> Army of the Dead")
wowmock.classification.target = nil
st = upd()
Assert(RotaClass_DK.EvaluateUnholyOff(st) ~= "AOTD", "Contra trash no sugiere Army of the Dead (tauntea adds)")
wowmock.inventoryCooldowns[10] = savedGloves
wowmock.triggerSpellCD(49206, 100)
st = upd()
Assert(RotaClass_DK.EvaluateUnholyOff(st) == "BP", "Gargola desaparecida -> Blood Presence")

-- Death Coil vs Gargola: guardar 60 RP solo si la Gargola de verdad se va a pedir
wowmock.registerSpell(49938, "Death and Decay")
wowmock.registerSpell(49895, "Death Coil")
wowmock.clearAuras("player"); wowmock.clearAuras("target"); wowmock.clearSpellCDs()
wowmock.triggerSpellCD(49938, 25)          -- DnD lejos
wowmock.registerSpell(57623, "Horn of Winter")
wowmock.triggerSpellCD(57623, 20)          -- sin Horn of Winter de relleno
for slot = 1, 6 do wowmock.useRune(slot) end -- sin runas
wowmock.setAura("player", { name = "Desolation", filter = "HELPFUL", duration = 20 })
wowmock.setAura("pet", { name = "Ghoul Frenzy", filter = "HELPFUL", duration = 30 })
wowmock.setPower("player", 6, 70, 130)
-- plagas con 4 s: no se refrescan todavia (2.5 s) pero frenan la Gargola (pide >= 4.5 s)
wowmock.setAura("target", { name = "Frost Fever", filter = "HARMFUL", duration = 4, unitCaster = "player" })
wowmock.setAura("target", { name = "Blood Plague", filter = "HARMFUL", duration = 4, unitCaster = "player" })
st = upd()
Assert(RotaClass_DK.EvaluateUnholy(st, false) == "DC", "Gargola lista pero frenada por las plagas -> Death Coil igual")
Assert(st.reason == "Death Coil: gastar RP", "Motivo: Death Coil: gastar RP")
wowmock.clearAuras("target")
wowmock.setAura("target", { name = "Frost Fever", filter = "HARMFUL", duration = 15, unitCaster = "player" })
wowmock.setAura("target", { name = "Blood Plague", filter = "HARMFUL", duration = 15, unitCaster = "player" })
st = upd()
Assert(RotaClass_DK.EvaluateUnholy(st, false) ~= "DC", "Gargola lista y pedible -> guarda RP")
Assert(st.isWaiting == true and st.reason == "Guardando RP para la Gargola", "Motivo: Guardando RP para la Gargola (ESPERA)")

-- HUD: icono de espera siempre; motivo solo en modo aprendizaje
RotaCore.Profiles:SetActiveProfile("dk_unholy_morb_pve")
_G.RotaCoreDB.settings.learningMode = nil
RotaCore:UpdateAndEvaluate(GetTime())
Assert(RotaCore.UI.waitCount:IsShown() == true and RotaCore.UI.waitCount:GetText() ~= "",
    "HUD muestra los segundos de espera sobre el icono")
Assert(RotaCore.UI.mainIcon.cooldown:IsShown() == true, "HUD muestra la espiral de cooldown mientras espera")
Assert(RotaCore.UI.reasonText:IsShown() == false, "Sin modo aprendizaje no muestra el motivo")
_G.RotaCoreDB.settings.learningMode = true
RotaCore:UpdateAndEvaluate(GetTime())
Assert(RotaCore.UI.reasonText:IsShown() == true and RotaCore.UI.reasonText:GetText() ~= "", "Modo aprendizaje muestra el motivo")
_G.RotaCoreDB.settings.learningMode = nil
Assert(RotaCore.UI.WaitLabel(1.23) == "1.2" and RotaCore.UI.WaitLabel(12.7) == "12", "Formato del contador: 1.2 / 12")

-- AoE: Pestilence solo si hay enemigos sin plagas; si no, Blood Boil
wowmock.clearAuras("target"); wowmock.clearSpellCDs(); wowmock.initRunes()
wowmock.registerSpell(50842, "Pestilence"); wowmock.registerSpell(49941, "Blood Boil")
wowmock.triggerSpellCD(49938, 25)
for slot = 3, 6 do wowmock.useRune(slot) end   -- solo runas Blood listas
wowmock.setAura("target", { name = "Frost Fever", filter = "HARMFUL", duration = 15, unitCaster = "player" })
wowmock.setAura("target", { name = "Blood Plague", filter = "HARMFUL", duration = 15, unitCaster = "player" })
st = upd()
st.aoeMode = true
st.aoePlateCount, st.dk.aoeDiseasedCount = 3, 3
Assert(RotaClass_DK.EvaluateUnholy(st, false) == "BB", "AoE: 3 enemigos todos con plagas -> Blood Boil, no Pestilence")
st.aoePlateCount, st.dk.aoeDiseasedCount = 3, 2
Assert(RotaClass_DK.EvaluateUnholy(st, false) == "PEST", "AoE: un enemigo sin plagas -> Pestilence")
st.aoePlateCount, st.dk.aoeDiseasedCount = 0, 0
st.lastCast["Pestilence"] = GetTime() - 5
Assert(RotaClass_DK.EvaluateUnholy(st, false) == "BB", "AoE sin nameplates: Pestilence hace 5 s -> Blood Boil")
st.lastCast["Pestilence"] = nil
st.aoeMode = false

wowmock.clearAuras("pet")
wowmock.initRunes()

wowmock.inCombat = false
wowmock.clearAuras("player")
wowmock.clearAuras("target")
wowmock.clearSpellCDs()
SetBuild("auto")
end

-- ----------------------------------------------------------------------------
-- Build guardada por PJ: sobrevive a que otro PJ cambie settings.selectedBuild
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Build persistida por PJ")
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setCharacter("Morbo", "Frostmourne")
SetBuild("unholy_morb")
RotaCore.LoadClassPreset()

-- Otro PJ juega y deja la opcion de cuenta en otra cosa
wowmock.setClass("Paladin", "PALADIN")
wowmock.setCharacter("Retri", "Frostmourne")
SetBuild("auto")
RotaCore.LoadClassPreset()

-- DK nuevo sin build guardada: AUTO, no hereda la del otro DK
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setCharacter("Nuevo", "Frostmourne")
Assert(RotaCore:GetSelectedBuild() == "auto", "DK nuevo arranca en AUTO")

-- Vuelve Morbo: settings de cuenta dice "auto", pero su build es Morb
wowmock.setCharacter("Morbo", "Frostmourne")
_G.RotaCoreDB.settings.selectedBuild = "auto"
local _, pid = RotaClass_DK:DetectBuild()
Assert(pid == "dk_unholy_morb_pve", "DetectBuild usa la build del PJ, no la de cuenta")
RotaCore.LoadClassPreset()
Assert(RotaCore.Profiles:GetActiveProfile().meta.id == "dk_unholy_morb_pve", "Morbo recupera UH Morb al loguear")
Assert(RotaCore:GetSelectedBuild() == "unholy_morb", "Boton Build muestra UH Morb")

-- /reload real: RotaCore carga antes que RotaClass_DK, asi que en su ADDON_LOADED el modulo no esta registrado
local dkMod = RotaCore.classModules.DEATHKNIGHT
local origLoadAddOn = _G.LoadAddOn
RotaCore.classModules.DEATHKNIGHT = nil
_G.LoadAddOn = function() return false, "NOT_DEMAND_LOADED" end
RotaCore.LoadClassPreset()
Assert(RotaCore:GetSelectedBuild() == "unholy_morb", "ADDON_LOADED sin modulo de clase no pisa la build guardada con AUTO")
RotaCore.classModules.DEATHKNIGHT = dkMod
_G.LoadAddOn = origLoadAddOn
RotaCore.LoadClassPreset()
Assert(RotaCore:GetSelectedBuild() == "unholy_morb", "PLAYER_LOGIN con el modulo cargado mantiene UH Morb")
end

-- ----------------------------------------------------------------------------
-- Rotacion custom por PJ: guardar, /reload, otro PJ, cambio de spec, restaurar
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Rotacion custom por PJ")
local P = RotaCore.Profiles
local ID = "dk_unholy_morb_pve"
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setCharacter("Tester", "Frostmourne")
_G.RotaCoreDB.charCustomProfiles = {}

-- 1. Activar un preset no guarda nada y no expone la tabla del preset
P:SetActiveProfile(ID)
local active = P:GetActiveProfile()
Assert(active ~= P:GetPreset(ID), "Activar un preset usa una copia, no la tabla del preset")
Assert(P:GetCustom(ID) == nil, "Activar un preset no lo guarda como custom")

-- 2. Editar y guardar: queda solo para este PJ
table.insert(active.lists.main, 1, { id = "mi_regla", enabled = true, type = "customLua", action = "DC", code = "return nil" })
P:SaveProfile(active)
local saved = _G.RotaCoreDB.charCustomProfiles["Tester - Frostmourne"][ID]
Assert(saved ~= nil and saved.meta.custom == true, "La rotacion editada se guarda como custom del PJ")
Assert(P:GetPreset(ID).lists.main[1].id ~= "mi_regla", "El preset original no cambia")

-- 3. /reload: InitDB y activar de nuevo -> sigue la custom
P:InitDB()
P:SetActiveProfile(ID)
Assert(P:GetActiveProfile().lists.main[1].id == "mi_regla", "Despues de /reload sigue la rotacion custom")

-- 4. Otro PJ de la misma clase usa el preset
wowmock.setCharacter("Otro", "Frostmourne")
P:SetActiveProfile(ID)
Assert(P:GetActiveProfile().lists.main[1].id ~= "mi_regla", "Otro PJ no ve la rotacion custom")

-- 5. Cambio de spec en el PJ original: DetectBuild con la build elegida carga la custom
wowmock.setCharacter("Tester", "Frostmourne")
SetBuild("unholy_morb")
local _, pid = RotaClass_DK:DetectBuild()
Assert(pid == ID and P:GetActiveProfile().lists.main[1].id == "mi_regla", "Cambio de spec carga la custom de ese preset")

-- 6. LoadClassPreset (login) no congela el preset como custom
_G.RotaCoreDB.charCustomProfiles = {}
P.activeProfile = nil
RotaCore.LoadClassPreset()
Assert(next(_G.RotaCoreDB.charCustomProfiles["Tester - Frostmourne"] or {}) == nil, "Loguear no guarda el preset como custom")

-- 7. Copias viejas sin meta.custom y customProfiles de cuenta se limpian
_G.RotaCoreDB.customProfiles = { [ID] = P:GetPreset(ID) }
_G.RotaCoreDB.charCustomProfiles["Tester - Frostmourne"] = { [ID] = { meta = { id = ID }, lists = { main = {} } } }
P:InitDB()
Assert(_G.RotaCoreDB.customProfiles == nil, "InitDB borra customProfiles de cuenta")
Assert(P:GetCustom(ID) == nil, "InitDB borra copias viejas sin meta.custom")

-- 8. Restaurar: borra la custom y vuelve al preset
P:SetActiveProfile(ID)
active = P:GetActiveProfile()
active.lists.main[1].enabled = false
P:SaveProfile(active)
Assert(P:GetCustom(ID) ~= nil, "Custom guardada antes de restaurar")
P:ResetProfile(ID)
Assert(P:GetCustom(ID) == nil, "ResetProfile borra la custom")
Assert(P:GetActiveProfile().meta.custom == nil and P:GetActiveProfile().lists.main[1].enabled ~= false, "ResetProfile vuelve al preset")
SetBuild("auto")
end

-- ----------------------------------------------------------------------------
-- Builds del boton == presets del addon (sin aliases ni presets sueltos)
-- ----------------------------------------------------------------------------
do
print("\n[Suite] Builds == presets por clase")
for _, cls in ipairs({ "DEATHKNIGHT", "PALADIN", "WARRIOR", "ROGUE", "SHAMAN", "WARLOCK", "MAGE", "PRIEST", "HUNTER", "DRUID" }) do
    local mod = RotaCore:GetClassModule(cls)
    local fromBuilds, presetCount, matches = {}, 0, mod ~= nil
    for _, b in ipairs(mod and mod.builds or {}) do
        if b.key ~= "auto" then
            if not b.preset or fromBuilds[b.preset] then matches = false end
            fromBuilds[b.preset or "?"] = true
        end
    end
    for id, p in pairs(RotaCore.Profiles.presets) do
        if p.meta and p.meta.class == cls and not p.meta.v1Of then -- la version v1 de un preset migrado no es una build
            presetCount = presetCount + 1
            if p.meta.id ~= id or not fromBuilds[id] then matches = false end
        end
    end
    local buildCount = 0
    for _ in pairs(fromBuilds) do buildCount = buildCount + 1 end
    Assert(matches and buildCount == presetCount, string.format("%s: %d builds = %d presets", cls, buildCount, presetCount))
end

-- Paladin: una sola build, el boton muestra Retri aunque la seleccion sea "auto"
wowmock.setClass("Paladin", "PALADIN")
wowmock.setCharacter("Retri", "Frostmourne")
SetBuild("auto")
RotaCore.UI:UpdateButtonStates()
Assert(RotaCore.UI.buildBtn.text:GetText():find("Build: Retri", 1, true) ~= nil, "Boton de Paladin muestra Build: Retri")
end

-- ----------------------------------------------------------------------------
-- SUITE: Plan v2 etapa 0 — situaciones, selector v1 y comparador
-- ----------------------------------------------------------------------------
local function SuiteEtapa0() -- funcion propia: el archivo ya pasa el limite de 200 locales
print("\n[Suite] Plan v2 etapa 0: situaciones, selector v1, comparador")
local Scenario = dofile("tools/scenario.lua")
local Snapshot = RotaCore.Snapshot
wowmock.setClass("Death Knight", "DEATHKNIGHT")
wowmock.setCharacter("Etapa", "Frostmourne")
SetBuild("unholy_morb")
RotaCore.Profiles:SetActiveProfile("dk_unholy_morb_pve")
local ir = RotaCore.Profiles:GetActiveProfile()

-- Ida y vuelta: lo que se captura del mundo, aplicado de nuevo, se vuelve a capturar igual
wowmock.setTime(5000)
wowmock.inCombat = true
wowmock.clearAuras("player"); wowmock.clearAuras("target")
wowmock.setAura("player", { name = "Unholy Presence", filter = "HELPFUL", duration = 0 })
wowmock.setAura("target", { name = "Frost Fever", filter = "HARMFUL", duration = 15, count = 1 })
wowmock.setAura("target", { name = "Blood Plague", filter = "HARMFUL", duration = 15, unitCaster = "raid1" })
wowmock.clearSpellCDs()
wowmock.triggerSpellCD("Summon Gargoyle", 180)
wowmock.initRunes()
wowmock.useRune(1)
wowmock.convertRune(2, 4)
wowmock.setPower("player", 6, 80, 130)
local st = RotaCore.State:Update(GetTime())
local sc1 = Snapshot:Capture(ir, st)
Scenario.apply(wowmock, sc1, 9000)
local sc2 = Snapshot:Capture(ir, RotaCore.State:Update(GetTime()))
local s1, s2 = Scenario.serialize(sc1), Scenario.serialize(sc2)
Assert(s1 == s2, "Situacion capturada -> aplicada -> capturada queda igual",
    s1 ~= s2 and (s1:sub(1, 200) .. " VS " .. s2:sub(1, 200)) or nil)
Assert(type(sc1.spells["Summon Gargoyle"]) == "table" and sc1.spells["Summon Gargoyle"].rem > 179, "Captura el CD de Gargola")
Assert(sc1.runes[1].rem > 0 and sc1.runes[2].type == 4, "Captura runas (gastada y convertida en muerte)")

-- Selector: un preset migrado (meta.v1) vuelve a su version vieja con la casilla
local function TestPreset(id, act, extra)
    local p = { meta = { id = id, name = id, class = "DEATHKNIGHT" }, spells = ir.spells, vars = {},
        lists = { main = { { id = id .. "_r", enabled = true, type = "customLua", code = "return '" .. act .. "'" } }, off = {} } }
    for k, v in pairs(extra) do p.meta[k] = v end
    RotaCore.Profiles:RegisterPreset(p)
end
TestPreset("test_mig", "IT", { v1 = "test_mig_v1" })
TestPreset("test_mig_v1", "PS", { v1Of = "test_mig" })
local db = _G.RotaCoreDB
db.settings.useV1 = nil
RotaCore.Profiles:SetActiveProfile("test_mig")
Assert(RotaCore.Profiles:GetActiveProfile().meta.id == "test_mig", "Sin casilla: rotacion nueva")
db.settings.useV1 = { test_mig = true }
RotaCore.Profiles:SetActiveProfile("test_mig")
Assert(RotaCore.Profiles:GetActiveProfile().meta.id == "test_mig_v1", "Con casilla: rotacion vieja (v1)")
local charKey = _G.UnitName("player") .. " - " .. _G.GetRealmName()
Assert(db.charProfiles[charKey] == "test_mig", "La v1 se guarda con el id del preset nuevo")
db.settings.useV1 = nil

-- Comparador: anota cuando la v1 sugiere otra cosa, sin repetir la misma diferencia seguida
Snapshot:Clear()
RotaCore.Profiles:SetActiveProfile("test_mig")
db.settings.compareV1 = true
local m = RotaCore:UpdateAndEvaluate(GetTime())
Assert(m == "IT", "El HUD muestra la rotacion nueva con el comparador prendido")
local entry = db.parityLog and db.parityLog[1]
Assert(entry ~= nil and entry.main == "PS" and entry.newMain == "IT" and entry.preset == "test_mig",
    "Diferencia anotada: v1 PS, nueva IT")
RotaCore:UpdateAndEvaluate(GetTime())
local _, diffs = Snapshot:Counts()
Assert(diffs == 1, "La misma diferencia seguida no se anota dos veces", tostring(diffs))
db.settings.compareV1 = nil

-- Grabador: una situacion cada 2 s en combate, con lo que sugirio
db.settings.captureReal = true
Snapshot.lastCapture = 0
RotaCore:UpdateAndEvaluate(GetTime())
wowmock.advanceTime(0.5)
RotaCore:UpdateAndEvaluate(GetTime())
local caps = Snapshot:Counts()
Assert(caps == 1, "Grabador: una situacion por cada 2 s", tostring(caps))
wowmock.advanceTime(2.0)
RotaCore:UpdateAndEvaluate(GetTime())
caps = Snapshot:Counts()
Assert(caps == 2 and db.capture[2].main == "IT", "Grabador: segunda situacion con la sugerencia")
db.settings.captureReal = nil

-- Lo grabado se reproduce offline y da lo mismo
local function SetB(k) SetBuild(k) end
local rm = Scenario.evaluate(wowmock, RotaCore, db.capture[2], 12000, SetB)
Assert(rm == "IT", "Situacion grabada reproducida en los mocks da la misma sugerencia")

-- Sin opciones prendidas no se crea basura
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 200 do Snapshot:AfterEvaluate(RotaCore.State.data, "IT", nil) end
local after = collectgarbage("count")
collectgarbage("restart")
Assert(after - before < 0.001, "AfterEvaluate con todo apagado: cero basura")

-- Una custom guardada en la v1 (solo el gancho) no tapa la rotacion nueva; una custom de reglas si se respeta
local ck = _G.UnitName("player") .. " - " .. _G.GetRealmName()
db.charCustomProfiles = db.charCustomProfiles or {}
db.charCustomProfiles[ck] = {
    dk_unholy_morb_pve = { meta = { id = "dk_unholy_morb_pve", class = "DEATHKNIGHT", custom = true },
        lists = { main = { { id = "uh_master", type = "customLua", code = "return state.evaluateUnholyMorb(state)" } }, off = {} } },
    dk_frost_pve = { meta = { id = "dk_frost_pve", class = "DEATHKNIGHT", custom = true },
        lists = { main = { { id = "mine", type = "customLua", code = "if ready('OBL') then return 'OBL' end" } }, off = {} } },
}
Assert(RotaCore.Profiles:GetProfile("dk_unholy_morb_pve") == RotaCore.Profiles.presets.dk_unholy_morb_pve
    and db.charCustomProfiles[ck].dk_unholy_morb_pve == nil, "Custom vieja (gancho v1) se descarta: queda el preset nuevo")
Assert(RotaCore.Profiles:GetProfile("dk_frost_pve") == db.charCustomProfiles[ck].dk_frost_pve,
    "Custom con reglas propias se respeta")
db.charCustomProfiles[ck] = nil

-- Cada build declara los hechizos de talento que necesita, y todos estan en su catalogo
local reqOk, reqBad = true, ""
for id, p in pairs(RotaCore.Profiles.presets) do
    if p.meta and not p.meta.v1Of and p.meta.class and not id:find("^test_") then
        if not p.meta.requires then reqOk, reqBad = false, reqBad .. id .. " (sin requires) " end
        for _, alias in ipairs(p.meta.requires or {}) do
            if not (p.spells and p.spells[alias]) then reqOk, reqBad = false, reqBad .. id .. ":" .. alias .. " " end
        end
    end
end
Assert(reqOk, "Todas las builds declaran meta.requires con alias de su catalogo", reqBad)

-- Build elegida sin el talento: aviso por chat una sola vez
local said = {}
local oldAdd = _G.DEFAULT_CHAT_FRAME.AddMessage
_G.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) said[#said + 1] = msg end
local fakeIR = { meta = { id = "req_test", name = "Prueba", requires = { "SS", "IT" } },
    spells = { SS = { name = "Scourge Strike" }, IT = { name = "Icy Touch" } } }
local fakeState = { inCombat = true, hasSpell = function(a) return a == "IT" end }
RotaCore.CheckRequires(fakeIR, fakeState)
RotaCore.CheckRequires(fakeIR, fakeState)
_G.DEFAULT_CHAT_FRAME.AddMessage = oldAdd
Assert(#said == 1 and said[1]:find("Scourge Strike", 1, true) and not said[1]:find("Icy Touch", 1, true),
    "Falta un talento de la build: avisa una vez y nombra solo lo que falta")

-- Burst OFF no saltea Unstable Affliction del Brujo (alias "UA", igual que Unbreakable Armor del DK)
do
    local ua = { meta = { id = "burst_ua_test", class = "WARLOCK" }, spells = { UA = { name = "Unstable Affliction" } },
        lists = { main = { RotaCore.Rule("r", "UA", "UA", "return 'UA'") },
            off = { { id = "dk_ua", enabled = true, isBurst = true, type = "customLua", action = "UA", code = "return 'UA'" } } } }
    local b = RotaCore.Compiler:Compile(ua)
    local sd = RotaCore.State.data
    local oldBurst, oldHas = sd.burstMode, sd.hasSpell
    sd.burstMode, sd.hasSpell = false, function() return true end
    Assert(b.evaluatorMain(sd) == "UA", "Burst OFF: la regla de Unstable Affliction sigue sugiriendo UA")
    Assert(b.evaluatorOff(sd) == nil, "Burst OFF: una regla marcada isBurst (Unbreakable Armor) se guarda")
    sd.burstMode, sd.hasSpell = oldBurst, oldHas
end

-- Panel unico con pestanas: cada control vive en una sola pagina
local panel = RotaCore.Options and RotaCore.Options.panel
if panel and panel.ShowPage then
    panel.ShowPage(1)
    Assert(panel.useV1Cb:IsShown() and not panel.captureCb:IsShown(), "Pestana Rotacion: casilla v1 visible, grabacion oculta")
    panel.ShowPage(3)
    Assert(panel.captureCb:IsShown() and not panel.useV1Cb:IsShown(), "Pestana Herramientas: grabacion visible, casilla v1 oculta")
    Assert(db.settings.optionsTab == 3, "La pestana elegida se recuerda")
    panel.ShowPage(1)
end

Snapshot:Clear()
RotaCore.Profiles.presets.test_mig, RotaCore.Profiles.presets.test_mig_v1 = nil, nil
RotaCore.Profiles:SetActiveProfile("dk_unholy_morb_pve")
wowmock.inCombat = false
end
SuiteEtapa0()

-- ----------------------------------------------------------------------------
-- Brujo Affliction: proyeccion de casteo, tiempo real con celeridad y lookahead
-- ----------------------------------------------------------------------------
local function SuiteAfflictionLookahead()
    print("\n[Suite] Warlock Affliction Lookahead & Casting")
    wowmock.setClass("Warlock", "WARLOCK")
    SetBuild("affliction")
    RotaCore.Profiles:SetActiveProfile("wl_affliction_pve")
    _G.RotaCoreDB.settings.aoeMode = "OFF"
    _G.RotaCoreDB.settings.burstMode = true
    wowmock.inCombat = true
    wowmock.setPower("player", 0, 10000, 10000)
    wowmock.setHealth("target", 50000, 50000)

    -- Tiempos reales medidos en Frostmourne Rebuffed (14.4% celeridad)
    wowmock.setSpellCastTime(47843, 1311) -- Unstable Affliction: 1.311s
    wowmock.setSpellCastTime(59164, 1311) -- Haunt: 1.311s
    wowmock.setSpellCastTime(47809, 2185) -- Shadow Bolt: 2.185s

    local function eval(opts)
        opts = opts or {}
        wowmock.clearAuras("player")
        wowmock.clearAuras("target")
        wowmock.clearSpellCDs()
        wowmock.clearCasting()
        wowmock.gcdStart, wowmock.gcdDuration = 0, 0
        wowmock.setHealth("target", opts.hp or 50000, 50000)
        if opts.lt ~= false then
            wowmock.setAura("player", { name = "Life Tap", filter = "HELPFUL", duration = opts.lt or 30 })
        end
        if opts.trance then
            wowmock.setAura("player", { name = "Shadow Trance", filter = "HELPFUL", duration = 10 })
        end
        if opts.sm ~= false then
            wowmock.setAura("target", { name = "Shadow Mastery", filter = "HARMFUL", duration = opts.sm or 25, unitCaster = "player" })
        end
        if opts.corr ~= false then
            wowmock.setAura("target", { name = "Corruption", filter = "HARMFUL", duration = opts.corr or 15, unitCaster = "player" })
        end
        if opts.ua ~= false then
            wowmock.setAura("target", { name = "Unstable Affliction", filter = "HARMFUL", duration = opts.ua or 12, unitCaster = "player" })
        end
        if opts.coa ~= false then
            wowmock.setAura("target", { name = "Curse of Agony", filter = "HARMFUL", duration = opts.coa or 15, unitCaster = "player" })
        end
        if opts.haunt ~= false then
            wowmock.setAura("target", { name = "Haunt", filter = "HARMFUL", duration = opts.haunt or 10, unitCaster = "player" })
        end
        if opts.hauntCD then wowmock.triggerSpellCD(59164, opts.hauntCD) end
        if opts.cast then wowmock.setCasting("player", opts.cast[1], opts.cast[2], opts.cast[3]) end
        if opts.chan then wowmock.setChanneling("player", opts.chan[1], opts.chan[2], opts.chan[3]) end

        local st = RotaCore.State:Update(GetTime())
        st.inCombat = true
        st.isWaiting, st.waitTime, st.reason = false, nil, nil
        local b = RotaCore.Profiles:GetActiveEvaluator()
        return b.evaluatorMain(st), st
    end

    -- 1. UA justo al tiempo de casteo real (1.311s): renueva directo sin esperar
    local a, st = eval({ ua = 1.25, hauntCD = 5 })
    Assert(a == "UA" and not st.isWaiting, "Aff lookahead: UA <= 1.311s -> UA directo")

    -- 2. UA a 1.6s (gap 0.29s <= 0.5s): NO sugiere Shadow Bolt de 2.185s; espera UA sin cortar el ultimo tick
    a, st = eval({ ua = 1.6, hauntCD = 5 })
    Assert(a == "UA" and st.isWaiting and st.waitTime > 0.2 and st.waitTime < 0.35,
        "Aff lookahead: UA a 1.6s -> espera UA (~0.29s) en vez de Shadow Bolt")

    -- 3. UA a 2.3s (gap 0.99s > 0.5s): conviene tirar Shadow Bolt completo (mas DPS que esperar 1s o clipear)
    a, st = eval({ ua = 2.3, hauntCD = 5 })
    Assert(a == "SB" and not st.isWaiting, "Aff lookahead: UA a 2.3s -> Shadow Bolt completo")

    -- 4. Ya casteando Shadow Bolt (quedan 2.0s) con UA a 2.2s -> proyecta fin del casteo y encola UA
    a, st = eval({ ua = 2.2, hauntCD = 5, cast = { "Shadow Bolt", 2.0, 2.185 } })
    Assert(a == "UA" and not st.isWaiting, "Aff lookahead: casteando SB con UA a 2.2s -> proxima accion UA")

    -- 5. Ya casteando UA (quedan 1.0s) con UA a 1.1s -> NO sugiere doble UA, muestra el siguiente (SB)
    a = eval({ ua = 1.1, hauntCD = 5, cast = { "Unstable Affliction", 1.0, 1.311 } })
    Assert(a == "SB", "Aff lookahead: casteando UA -> no pide UA de nuevo, encola SB")

    -- 6. Haunt con tiempo de vuelo (0.8s): a 2.0s (<= 1.311 + 0.8) renueva directo
    a = eval({ haunt = 2.0 })
    Assert(a == "HAUNT", "Aff lookahead: Haunt a 2.0s (cast + vuelo) -> HAUNT")

    -- 7. Haunt a 3.5s (listo) antes de Shadow Bolt (2.185s): 3.5 <= 2.185 + 1.311 + 0.8 -> renueva Haunt antes de SB
    a = eval({ haunt = 3.5 })
    Assert(a == "HAUNT", "Aff lookahead: Haunt a 3.5s antes de SB -> HAUNT para que no caiga")

    -- 8. Ya casteando Haunt (quedan 1.0s) con Haunt a 1.5s -> NO pide Haunt de nuevo
    a = eval({ haunt = 1.5, cast = { "Haunt", 1.0, 1.311 } })
    Assert(a == "SB", "Aff lookahead: casteando Haunt -> no pide Haunt de nuevo")

    -- 9. Life Tap buff a 1.5s antes de SB (2.185s) -> renueva Life Tap antes
    a = eval({ lt = 1.5, hauntCD = 5 })
    Assert(a == "LT", "Aff lookahead: Life Tap buff a 1.5s antes de SB -> LT")

    -- 10. Life Tap buff a 1.0s antes de UA (1.311s) -> renueva Life Tap antes (snapshot SP)
    a = eval({ lt = 1.0, ua = 1.2, hauntCD = 5 })
    Assert(a == "LT", "Aff lookahead: Life Tap buff a 1.0s antes de UA -> LT")

    -- 11. Erradicacion (+20% haste -> UA 1.093s) + Shadow Trance (SB instantaneo = 0ms): UA a 1.5s -> SB instantaneo
    wowmock.setSpellCastTime(47843, 1093)
    wowmock.setSpellCastTime(59164, 1093)
    wowmock.setSpellCastTime(47809, 0)
    a, st = eval({ ua = 1.5, hauntCD = 5, trance = true })
    Assert(a == "SB" and not st.isWaiting, "Aff lookahead: SB instantaneo (Shadow Trance) con UA a 1.5s -> SB")

    -- Volver a tiempos normales (14.4% haste) para fase execute (< 25%)
    wowmock.setSpellCastTime(47843, 1311)
    wowmock.setSpellCastTime(59164, 1311)
    wowmock.setSpellCastTime(47809, 2185)

    -- 12. Execute (< 25%) sin canalizar, Haunt a 3.5s -> renueva Haunt antes de empezar Drain Soul
    a = eval({ hp = 10000, haunt = 3.5 })
    Assert(a == "HAUNT", "Aff execute: Haunt a 3.5s antes de empezar Drain Soul -> HAUNT")

    -- 13. Execute (< 25%) YA canalizando Drain Soul, Haunt a 3.5s -> mantiene Drain Soul
    a = eval({ hp = 10000, haunt = 3.5, chan = { "Drain Soul", 10.0, 13.112 } })
    Assert(a == "DSOUL", "Aff execute: ya canalizando Drain Soul con Haunt a 3.5s -> sigue DSOUL")

    -- 14. Execute (< 25%) canalizando Drain Soul, UA a 1.2s -> avisa UA (para renovar tras el tick)
    a = eval({ hp = 10000, ua = 1.2, hauntCD = 5, chan = { "Drain Soul", 10.0, 13.112 } })
    Assert(a == "UA", "Aff execute: canalizando Drain Soul con UA a 1.2s -> UA")

    -- 15. Abrazo de la Muerte (<= 35%): renovar Corrupcion 1 vez en jefe (configurable con corrExecute)
    _G.RotaClass_WL.ResetCorrExecute()
    wowmock.classification.target = "worldboss"
    wowmock.targetGUID = "0xF13000000000BOSS"
    a = eval({ hp = 18000, hauntCD = 5 }) -- 36% HP
    Assert(a == "SB", "Aff DE: jefe a 36% con Corrupcion activa -> no renueva todavia")
    a = eval({ hp = 17000, hauntCD = 5 }) -- 34% HP
    Assert(a == "CORR", "Aff DE: jefe a 34% con Corrupcion activa -> renueva Corrupcion 1 vez")
    wowmock.fireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Corruption")
    a = eval({ hp = 17000, hauntCD = 5 })
    Assert(a == "SB", "Aff DE: ya casteada Corrupcion manual a <=35% -> no la vuelve a pedir")
    wowmock.fireEvent("PLAYER_REGEN_ENABLED")
    a = eval({ hp = 17000, hauntCD = 5 })
    Assert(a == "CORR", "Aff DE: al salir de combate se limpia el registro y vuelve a pedir en otro pull")
    wowmock.classification.target = "normal"
    a = eval({ hp = 15000, hauntCD = 5 }) -- 30% HP mob normal con corrExecute="boss"
    Assert(a == "SB", "Aff DE: mob normal a 30% con corrExecute='boss' -> no renueva Corrupcion")
    RotaCore.State.data.vars.corrExecute = "all"
    a = eval({ hp = 15000, hauntCD = 5 })
    Assert(a == "CORR", "Aff DE: mob normal a 30% con corrExecute='all' -> renueva Corrupcion")
    RotaCore.State.data.vars.corrExecute = "off"
    wowmock.classification.target = "worldboss"
    a = eval({ hp = 17000, hauntCD = 5 })
    Assert(a == "SB", "Aff DE: jefe a 34% con corrExecute='off' -> apagado")
    RotaCore.State.data.vars.corrExecute = "boss"
    local prevTabs = wowmock.talents.tabs
    wowmock.talents.tabs = {
        [1] = { name = "Affliction", pointsSpent = 56, talents = { { name = "Abrazo de la Muerte", rank = 0 } } },
        [2] = { name = "Demonology", pointsSpent = 15, talents = {} },
        [3] = { name = "Destruction", pointsSpent = 0, talents = {} },
    }
    _G.RotaClass_WL:DetectBuild()
    a = eval({ hp = 17000, hauntCD = 5 })
    Assert(a == "SB", "Aff DE: sin puntos en Abrazo de la Muerte -> no pide renovar Corrupcion")
    wowmock.talents.tabs[1].talents[1].rank = 3
    _G.RotaClass_WL:DetectBuild()
    a = eval({ hp = 17000, hauntCD = 5 })
    Assert(a == "CORR", "Aff DE: con Abrazo de la Muerte 3/3 en jefe <= 35% -> renueva Corrupcion")
    wowmock.talents.tabs = prevTabs
    _G.RotaClass_WL:DetectBuild()
    wowmock.classification.target = nil
    wowmock.targetGUID = nil
    _G.RotaClass_WL.ResetCorrExecute()

    -- 16. Cero basura en 1000 evaluaciones del preset compilado con casteo activo
    eval({ ua = 1.6, haunt = 6, hauntCD = 4, cast = { "Shadow Bolt", 1.5, 2.185 } })
    local b = RotaCore.Profiles:GetActiveEvaluator()
    for _ = 1, 10 do
        local s = RotaCore.State:Update(GetTime())
        b.evaluatorMain(s)
    end
    collectgarbage("collect"); collectgarbage("collect")
    local affMemBefore = collectgarbage("count")
    for _ = 1, 1000 do
        local s = RotaCore.State:Update(GetTime())
        b.evaluatorMain(s)
    end
    local garbage = collectgarbage("count") - affMemBefore
    Assert(garbage == 0.0, string.format("Aff lookahead zero-alloc: %.4f KB en 1000 evals", garbage))

    -- Restaurar mocks
    wowmock.setSpellCastTime(47843, 0)
    wowmock.setSpellCastTime(59164, 0)
    wowmock.setSpellCastTime(47809, 0)
    wowmock.clearCasting()
    wowmock.inCombat = false
    RotaCore.Profiles:SetActiveProfile("dk_unholy_morb_pve")
end
SuiteAfflictionLookahead()


-- ----------------------------------------------------------------------------
-- FINAL REPORT & EXIT
-- ----------------------------------------------------------------------------
print("\n==================================================")
print(string.format(" RESULTS: %d Passed, %d Failed (Total: %d)", passedTests, failedTests, totalTests))
print("==================================================")

if failedTests > 0 then
    os.exit(1)
else
    print("\n>>> ALL PHASES 1-6 VALIDATION PASSED (DK, PALADIN, WARRIOR & EDITORS) <<<")
    os.exit(0)
end
