-- RotaClass_ROG/RotaClass_ROG.lua — Rogue State Provider, Build Detection & Evaluators (WoW 3.3.5a)
-- Specs: Assassination (Mutilate / Hybrid AoE), Combat, Subtlety (Hemo / Dagger-Dance).
-- Fuentes: Icy Veins / Wowhead WotLK Classic (Sellin + Simonize). Costos de energia aproximados: la afordabilidad inmediata
-- se consulta con IsUsableSpell; la tabla COST solo se usa para anticipar (lookahead).
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local RotaClass_ROG = {
    detectedBuild = "assassination_mutilate",
    detectedPresetId = "rog_assassination_pve",
    detectedSpecName = "Assassination (Mutilate)",
    detectedBadge = "[A]",
    mainHandType = "",
}
_G.RotaClass_ROG = RotaClass_ROG

-- Helpers
local function SN(id, fallback)
    return (_G.GetSpellInfo and _G.GetSpellInfo(id)) or fallback
end

-- Nombres localizados de auras (buffs propios / debuffs en el target)
local NAME = {
    SND = SN(6774, "Slice and Dice"),       ENVENOM = SN(57993, "Envenom"),
    HFB = SN(51662, "Hunger for Blood"),    BF = SN(13877, "Blade Flurry"),
    AR = SN(13750, "Adrenaline Rush"),      KS = SN(51690, "Killing Spree"),
    SD = SN(51713, "Shadow Dance"),         CB = SN(14177, "Cold Blood"),
    STEALTH = SN(1784, "Stealth"),          VANISH = SN(26889, "Vanish"),
    RUPTURE = SN(48672, "Rupture"),         GARROTE = SN(48676, "Garrote"),
    HEMO = SN(48660, "Hemorrhage"),         EXPOSE = SN(26866, "Expose Armor"),
    SUNDER = SN(47467, "Sunder Armor"),
}

-- Cualquier sangrado en el target habilita Hunger for Blood
local BLEED = {}
do
    -- Rupture, Garrote, Rend, Rip, Lacerate, Deep Wounds, Pounce, Rake
    local ids = { 48672, 48676, 47465, 49800, 48568, 12721, 49804, 48574 }
    local fb = { "Rupture", "Garrote", "Rend", "Rip", "Lacerate", "Deep Wounds", "Pounce Bleed", "Rake" }
    for i = 1, #ids do BLEED[SN(ids[i], fb[i])] = true end
end

local DEADLY = {}
do
    local ids = { 2823, 2824, 11355, 11356, 25349, 26968, 27187, 57969, 57970 }
    for i = 1, #ids do
        local n = SN(ids[i], "Deadly Poison")
        if n then DEADLY[n] = true end
    end
    DEADLY["Deadly Poison"] = true
    DEADLY["Veneno mortal"] = true
end

-- Hechizos: alias -> { nombre ingles, ID } (nombre localizado via GetSpellInfo)
local SPELLS = {
    MUT = { "Mutilate", 48666 },        ENV = { "Envenom", 57993 },          SND = { "Slice and Dice", 6774 },
    RUP = { "Rupture", 48672 },         EVIS = { "Eviscerate", 48668 },      SS = { "Sinister Strike", 48638 },
    HEMO = { "Hemorrhage", 48660 },     BACKSTAB = { "Backstab", 48657 },    AMBUSH = { "Ambush", 48691 },
    GARROTE = { "Garrote", 48676 },     HFB = { "Hunger for Blood", 51662 }, FOK = { "Fan of Knives", 51723 },
    EXPOSE = { "Expose Armor", 26866 }, COLDBLOOD = { "Cold Blood", 14177 }, VANISH = { "Vanish", 26889 },
    KS = { "Killing Spree", 51690 },    AR = { "Adrenaline Rush", 13750 },   BF = { "Blade Flurry", 13877 },
    SDANCE = { "Shadow Dance", 51713 }, SHADOWSTEP = { "Shadowstep", 36554 }, PREMED = { "Premeditation", 14183 },
    PREP = { "Preparation", 14185 },    GHOSTLY = { "Ghostly Strike", 14278 }, TRICKS = { "Tricks of the Trade", 57934 },
}

-- Costo de energia aproximado (con talentos puede variar; solo para anticipar)
local COST = {
    MUT = 60, ENV = 35, SND = 25, RUP = 25, EVIS = 35, SS = 45, HEMO = 35, BACKSTAB = 60, AMBUSH = 60,
    GARROTE = 50, HFB = 15, FOK = 50, EXPOSE = 25, GHOSTLY = 40, SHADOWSTEP = 10, TRICKS = 15,
}

local function RogHas(state, alias)
    if state and state.hasSpell then
        local s = state.hasSpell(alias)
        if s ~= nil then return s and true or false end
    end
    local info = SPELLS[alias]
    if info and _G.GetSpellCooldown then
        local name = SN(info[2], info[1])
        return _G.GetSpellCooldown(name) ~= nil
    end
    return false
end

-- Cooldown real: nil = no conocido | 0 = listo | n = segundos. Siempre por NOMBRE primero y luego por ID.
local function ApiCooldown(name, id, now)
    if not _G.GetSpellCooldown then return nil end
    local s, d = _G.GetSpellCooldown(name)
    if s == nil and id then s, d = _G.GetSpellCooldown(id) end
    if s == nil then return nil end
    if s == 0 or not d or d <= 1.5 then return 0 end
    local rem = (s + d) - now
    if rem < 0 then rem = 0 end
    return rem
end

local function Now(state)
    return (state and state.now) or (_G.GetTime and _G.GetTime()) or 0
end

-- Segundos de cooldown restantes de un alias (nil = desconocido)
local function Cd(state, alias)
    local info = SPELLS[alias]
    if not info then return nil end
    return ApiCooldown(SN(info[2], info[1]), info[2], Now(state))
end

-- Listo = cooldown termina antes del fin del GCD actual
local function Ready(state, alias)
    local cd = Cd(state, alias)
    if cd ~= nil then
        return cd <= (((state and state.gcdRemains) or 0) + 0.1)
    end
    return (state and state.spellReady and state.spellReady(alias)) and true or false
end

-- Talentos (cache por evento)
local talentCache = {}      -- nombre -> puntos
local tabPoints = { 0, 0, 0 }

local function ScanTalents()
    for k in pairs(talentCache) do talentCache[k] = nil end
    tabPoints[1], tabPoints[2], tabPoints[3] = 0, 0, 0
    if not (_G.GetNumTalentTabs and _G.GetTalentInfo) then return end
    for tab = 1, (_G.GetNumTalentTabs() or 3) do
        local n = (_G.GetNumTalents and _G.GetNumTalents(tab)) or 0
        local tabSum = 0
        for idx = 1, n do
            local name, _, _, _, rank = _G.GetTalentInfo(tab, idx)
            if name then
                talentCache[name] = rank or 0
                tabSum = tabSum + (rank or 0)
            end
        end
        if _G.GetTalentTabInfo then
            local _, _, pointsSpent = _G.GetTalentTabInfo(tab)
            if type(pointsSpent) == "number" and pointsSpent > tabSum then
                tabSum = pointsSpent
            end
        end
        if tab <= 3 then tabPoints[tab] = tabSum end
    end
end

local function HasTalent(name)
    return (talentCache[name] or 0) > 0
end
RotaClass_ROG.HasTalent = HasTalent

local function ScanWeapon()
    if _G.GetInventoryItemLink and _G.GetItemInfo then
        local link = _G.GetInventoryItemLink("player", 16)
        local t = ""
        if link then
            local _, _, _, _, _, _, subType = _G.GetItemInfo(link)
            t = string.lower(subType or "")
        end
        RotaClass_ROG.mainHandType = t
        RotaClass_ROG.isDagger = (string.find(t, "dagger", 1, true) or string.find(t, "daga", 1, true)) and true or false
    end
end

local function MainHandIsDagger()
    if RotaClass_ROG.isDagger ~= nil then return RotaClass_ROG.isDagger end
    local t = RotaClass_ROG.mainHandType or ""
    return (string.find(t, "dagger", 1, true) or string.find(t, "daga", 1, true)) and true or false
end

-- Provider de estado (cada frame; sin crear tablas: state.rog se aloca una sola vez)
local function UpdateRogueState(state, _)
    local rog = state.rog
    if not rog then
        rog = {}
        state.rog = rog
    end
    local now = (state.now) or (_G.GetTime and _G.GetTime()) or 0

    rog.energy = (_G.UnitPower and _G.UnitPower("player", 3)) or 0
    rog.energyMax = (_G.UnitPowerMax and _G.UnitPowerMax("player", 3)) or 100
    rog.cp = (_G.GetComboPoints and _G.GetComboPoints("player", "target")) or 0

    -- buffs propios
    local snd, env, hfb, bf, ar, ks, sd, cb, stealth = 0, 0, 0, 0, 0, 0, 0, 0, false
    if _G.UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, expT = _G.UnitBuff("player", i)
            if not name then break end
            local rem = (expT and expT > 0) and (expT - now) or 999
            if rem < 0 then rem = 0 end
            if name == NAME.SND then snd = rem
            elseif name == NAME.ENVENOM then env = rem
            elseif name == NAME.HFB then hfb = rem
            elseif name == NAME.BF then bf = rem
            elseif name == NAME.AR then ar = rem
            elseif name == NAME.KS then ks = rem
            elseif name == NAME.SD then sd = rem
            elseif name == NAME.CB then cb = rem
            elseif name == NAME.STEALTH or name == NAME.VANISH then stealth = true end
        end
    end
    rog.sndRemaining, rog.envenomRemaining, rog.hfbRemaining = snd, env, hfb
    rog.bladeFlurryRemaining, rog.arRemaining, rog.ksRemaining = bf, ar, ks
    rog.shadowDanceRemaining, rog.coldBloodRemaining = sd, cb
    rog.stealthed = stealth or (sd > 0)
    rog.energyRegen = (ar > 0) and 20 or 10

    -- debuffs en el target
    local rupt, garr, hemo, armor, bleed, dp = 0, 0, 0, 0, 0, 0
    if _G.UnitDebuff and state.hasTarget ~= false then
        for i = 1, 40 do
            local name, _, _, count, _, _, expT, caster = _G.UnitDebuff("target", i)
            if not name then break end
            local rem = (expT and expT > 0) and (expT - now) or 0
            if rem < 0 then rem = 0 end
            if BLEED[name] and rem > bleed then bleed = rem end
            if name == NAME.EXPOSE or name == NAME.SUNDER then
                if rem > armor then armor = rem end
            end
            if caster == "player" then
                if name == NAME.RUPTURE then rupt = rem
                elseif name == NAME.GARROTE then garr = rem
                elseif name == NAME.HEMO then hemo = rem
                elseif (DEADLY[name] or (name and string.find(name, "Deadly Poison", 1, true))) then
                    dp = count or 0
                end
            end
        end
    end
    rog.ruptureRemaining, rog.garroteRemaining, rog.hemoRemaining = rupt, garr, hemo
    rog.armorDebuffRemaining = armor
    rog.bleedRemaining = bleed
    rog.hasBleed = bleed > 0
    rog.deadlyStacks = dp

    rog.cutToTheChase = HasTalent("Cut to the Chase")
    rog.dagger = MainHandIsDagger()
end

-- Energia: afordabilidad con anticipacion
local function CanAfford(state, alias, lead)
    local rog = state.rog
    local cost = COST[alias] or 0
    lead = lead or 0
    if lead <= 0.05 and _G.IsUsableSpell and SPELLS[alias] then
        local u, noMana = _G.IsUsableSpell(SN(SPELLS[alias][2], SPELLS[alias][1]))
        if noMana then return false end
        if u then return true end
    end
    return (rog.energy + lead * rog.energyRegen) >= cost
end

local function Var(state, name, default)
    local v = state.vars and state.vars[name]
    if v == nil then return default end
    return v
end

-- Marca "esperando" si no alcanza la energia ahora, y devuelve el alias
local function Show(state, alias, lead)
    if not CanAfford(state, alias, lead or 0) then
        state.isWaiting = true
    end
    return alias
end

-- Quien aplica Expose Armor (cuando no hay Warrior): var exposeArmor = 1
local function NeedExpose(state, rog)
    return Var(state, "exposeArmor", 0) == 1 and RogHas(state, "EXPOSE") and rog.armorDebuffRemaining <= 3
end

-- Funciones del Picaro para las reglas del preset (ver RotaClass_ROG/Presets.lua)
if RotaCore.Sandbox and RotaCore.Sandbox.AddHelper then
    local Sandbox = RotaCore.Sandbox
    --- mostrar la habilidad; si no alcanza la energia, "esperando"
    Sandbox:AddHelper("show", function(alias, lead) return Show(Sandbox.current, alias, lead) end)
    --- alcanza la energia (o llega en `lead` segundos)
    Sandbox:AddHelper("canAfford", function(alias, lead) return CanAfford(Sandbox.current, alias, lead or 0) end)
    --- hay que poner Expose Armor (var exposeArmor = 1 y el debuff de armadura se cae)
    Sandbox:AddHelper("needExpose", function()
        local st = Sandbox.current
        return NeedExpose(st, st.rog)
    end)
end

-- ASSASSINATION (Mutilate / Hunger for Blood / Envenom)
-- Envenom con 4-5 CP, Mutilate con 1-3. Hunger for Blood siempre activo (necesita sangrado). SnD solo si cayo (Cut to the Chase).
function RotaClass_ROG.EvaluateAssassination(state)
    local rog = state.rog
    local cp = rog.cp
    local envMin = Var(state, "envenomMinCP", 4)
    local sndMargin = Var(state, "sndMargin", 1.5)
    local hfbMargin = Var(state, "hfbMargin", 4)

    -- AoE (masivo, 6+ objetivos por defecto): Fan of Knives; SnD siempre arriba
    if state.aoeMode and RogHas(state, "FOK") then
        if rog.sndRemaining <= sndMargin and cp >= 1 then return Show(state, "SND") end
        return Show(state, "FOK")
    end

    -- Hunger for Blood: mantenerlo; si no hay sangrado, Rupture lo habilita (una vez por minuto)
    if RogHas(state, "HFB") and rog.hfbRemaining <= hfbMargin then
        if rog.hasBleed then
            return Show(state, "HFB")
        elseif cp >= 1 then
            return Show(state, "RUP")
        end
        return Show(state, "MUT")
    end

    -- Slice and Dice: con Cut to the Chase lo refresca Envenom; solo se lanza si se cayo
    if cp >= 1 and rog.sndRemaining <= sndMargin then
        if (not rog.cutToTheChase) or rog.sndRemaining <= 0 then
            return Show(state, "SND")
        end
    end

    -- Expose Armor si no hay Warrior
    if cp >= 4 and NeedExpose(state, rog) then return Show(state, "EXPOSE") end

    -- Envenom con 4-5 CP, Mutilate con 0-3
    if cp >= envMin then
        return Show(state, "ENV")
    end
    return Show(state, "MUT")
end

function RotaClass_ROG.EvaluateAssassinationOff(state)
    local rog = state.rog
    if state.inCombat ~= true then return nil end
    local envMin = Var(state, "envenomMinCP", 4)
    -- Cold Blood se usa en el Envenom
    if rog.cp >= envMin and RogHas(state, "COLDBLOOD") and Ready(state, "COLDBLOOD") and rog.coldBloodRemaining <= 0 then
        return "COLDBLOOD"
    end
    if state.burstMode ~= false then
        if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
        if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
        if Var(state, "usePotion", 0) == 1 and state.spellReady and state.spellReady("SPEED_POT") then return "SPEED_POT" end
    end
    if Var(state, "tricks", 0) == 1 and RogHas(state, "TRICKS") and Ready(state, "TRICKS") then return "TRICKS" end
    return nil
end

-- COMBAT (Sinister Strike / Slice and Dice / Rupture, ventana BF -> KS -> AR)
function RotaClass_ROG.EvaluateCombat(state)
    local rog = state.rog
    local cp = rog.cp
    local sndMargin = Var(state, "sndMargin", 1.2)
    local rupMargin = Var(state, "ruptureMargin", 1.5)

    -- AoE (3+ objetivos): Fan of Knives con casi toda la energia; SnD con cualquier CP
    if state.aoeMode and RogHas(state, "FOK") then
        if cp >= 1 and rog.sndRemaining <= sndMargin then return Show(state, "SND") end
        return Show(state, "FOK")
    end

    local cleave = rog.bladeFlurryRemaining > 0

    if cp >= 4 and NeedExpose(state, rog) then return Show(state, "EXPOSE") end

    -- Slice and Dice: si esta por caer, con los CP que haya; si no, refrescar con 5 CP
    if cp >= 1 and rog.sndRemaining <= sndMargin then return Show(state, "SND") end
    if cp >= 5 and rog.sndRemaining <= 5 then return Show(state, "SND") end

    -- Rupture (con Blade Flurry activo se prioriza Eviscerate)
    if cp >= 5 and rog.ruptureRemaining <= rupMargin and (not cleave) and RogHas(state, "RUP") then
        return Show(state, "RUP")
    end
    if cp >= 4 and rog.ruptureRemaining <= 0 and (not cleave) and RogHas(state, "RUP") and rog.energy < 45 then
        return Show(state, "RUP")
    end

    -- Eviscerate: solo con CP sobrantes (o en ventana de Blade Flurry)
    if cp >= 5 then
        if cleave or (rog.sndRemaining > 6 and rog.ruptureRemaining > 6) then
            return Show(state, "EVIS")
        end
    end

    -- Generador
    return Show(state, "SS")
end

function RotaClass_ROG.EvaluateCombatOff(state)
    local rog = state.rog
    if state.inCombat ~= true then return nil end
    if state.burstMode == false then return nil end

    local hasBF, hasKS, hasAR = RogHas(state, "BF"), RogHas(state, "KS"), RogHas(state, "AR")
    -- Secuencia de cooldowns: Blade Flurry -> Killing Spree -> Adrenaline Rush
    if hasBF and Ready(state, "BF") and rog.bladeFlurryRemaining <= 0 and (state.aoeMode or Var(state, "bladeFlurryST", 1) == 1) then
        return "BF"
    end
    if hasKS and Ready(state, "KS") and rog.arRemaining <= 0 and rog.energy <= 50 then
        return "KS"
    end
    if hasAR and Ready(state, "AR") and rog.arRemaining <= 0 then
        local ksCD = hasKS and Cd(state, "KS") or 999
        if (not hasKS) or (ksCD ~= nil and ksCD >= 100) or rog.ksRemaining > 0 or rog.energy <= 40 then
            return "AR"
        end
    end
    if rog.arRemaining > 0 or rog.bladeFlurryRemaining > 0 then
        if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
        if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
        if Var(state, "usePotion", 0) == 1 and state.spellReady and state.spellReady("SPEED_POT") then return "SPEED_POT" end
    end
    return nil
end

-- SUBTLETY (Hemorrhage / Honor Among Thieves / Shadow Dance)
function RotaClass_ROG.EvaluateSubtlety(state)
    local rog = state.rog
    local cp = rog.cp
    local sndMargin = Var(state, "sndMargin", 1.5)
    local rupMargin = Var(state, "ruptureMargin", 2.0)
    local useDagger = (Var(state, "dagger", 0) == 1) or rog.dagger

    -- AoE masivo (6+): Fan of Knives
    if state.aoeMode and RogHas(state, "FOK") then
        if cp >= 1 and rog.sndRemaining <= sndMargin then return Show(state, "SND") end
        return Show(state, "FOK")
    end

    -- Ventana de Shadow Dance: Garrote -> Ambush -> refrescar debuffs -> Eviscerate con 4-5 CP
    if rog.shadowDanceRemaining > 0 then
        if RogHas(state, "GARROTE") and rog.garroteRemaining <= 0 and (not rog.hasBleed) then
            return Show(state, "GARROTE")
        end
        if cp >= 1 and rog.sndRemaining <= sndMargin then return Show(state, "SND") end
        if cp >= 4 and rog.ruptureRemaining <= rupMargin then return Show(state, "RUP") end
        if cp >= 4 then return Show(state, "EVIS") end
        if useDagger and RogHas(state, "AMBUSH") then return Show(state, "AMBUSH") end
        return Show(state, "HEMO")
    end

    -- Prioridad fuera de la ventana: Expose Armor > SnD > Rupture > Eviscerate (CP extra) > Ghostly Strike > Hemorrhage
    if cp >= 4 and NeedExpose(state, rog) then return Show(state, "EXPOSE") end
    if cp >= 1 and rog.sndRemaining <= sndMargin then return Show(state, "SND") end
    if cp >= 4 and rog.ruptureRemaining <= rupMargin and RogHas(state, "RUP") then return Show(state, "RUP") end
    if cp >= 4 then return Show(state, "EVIS") end
    if RogHas(state, "GHOSTLY") and Ready(state, "GHOSTLY") then return Show(state, "GHOSTLY") end
    if useDagger and (Var(state, "backstab", 0) == 1) and RogHas(state, "BACKSTAB") then
        return Show(state, "BACKSTAB")
    end
    return Show(state, "HEMO")
end

function RotaClass_ROG.EvaluateSubtletyOff(state)
    local rog = state.rog
    if state.inCombat ~= true then return nil end
    local sdActive = rog.shadowDanceRemaining > 0

    -- Shadowstep antes de cada Rupture (+20% dano)
    if rog.cp >= 4 and rog.ruptureRemaining <= (Var(state, "ruptureMargin", 2.0) + 1.5)
       and RogHas(state, "SHADOWSTEP") and Ready(state, "SHADOWSTEP") then
        return "SHADOWSTEP"
    end
    -- Dentro de Shadow Dance: Premeditation, y trinkets/racial/guantes
    if sdActive then
        if RogHas(state, "PREMED") and Ready(state, "PREMED") and rog.cp <= 3 then return "PREMED" end
        if state.burstMode ~= false then
            if state.areGlovesReady and state.areGlovesReady(state.now) then return "GLOVES" end
            if state.spellReady and state.spellReady("RACIAL") then return "RACIAL" end
        end
        return nil
    end
    if state.burstMode ~= false then
        -- Shadow Dance con energia suficiente (se prepara antes: Preparation resetea cooldowns)
        if RogHas(state, "SDANCE") and Ready(state, "SDANCE") and rog.energy >= Var(state, "sdMinEnergy", 60) then
            return "SDANCE"
        end
        local sdCD = RogHas(state, "SDANCE") and Cd(state, "SDANCE") or 0
        if RogHas(state, "PREP") and Ready(state, "PREP") and sdCD and sdCD >= 15 then
            return "PREP"
        end
    end
    return nil
end

-- Evaluadores publicos: nunca devuelven nil (un perfil guardado viejo no puede disparar reglas de respaldo)
local function Wrap(fn, spec)
    return function(state)
        state.isWaiting = false
        local a = fn(state)
        if a then return a end
        state.isWaiting = true
        return (spec == "combat") and "SS" or ((spec == "subtlety") and "HEMO" or "MUT")
    end
end

RotaClass_ROG.Evaluate = {
    assassination = Wrap(RotaClass_ROG.EvaluateAssassination, "assassination"),
    combat = Wrap(RotaClass_ROG.EvaluateCombat, "combat"),
    subtlety = Wrap(RotaClass_ROG.EvaluateSubtlety, "subtlety"),
}

if RotaCore.State and RotaCore.State.data then
    local sd = RotaCore.State.data
    sd.evaluateRogAssassination = RotaClass_ROG.Evaluate.assassination
    sd.evaluateRogAssassinationOff = RotaClass_ROG.EvaluateAssassinationOff
    sd.evaluateRogCombat = RotaClass_ROG.Evaluate.combat
    sd.evaluateRogCombatOff = RotaClass_ROG.EvaluateCombatOff
    sd.evaluateRogSubtlety = RotaClass_ROG.Evaluate.subtlety
    sd.evaluateRogSubtletyOff = RotaClass_ROG.EvaluateSubtletyOff
end

-- Deteccion automatica de build (arbol con mas puntos + arma) y override desde Settings
function RotaClass_ROG:DetectBuild()
    ScanTalents()
    ScanWeapon()
    local a, c, s = tabPoints[1], tabPoints[2], tabPoints[3]
    local key, presetId, specName, badge

    if s > a and s > c then
        if MainHandIsDagger() then
            key, presetId, specName, badge = "subtlety_dagger", "rog_subtlety_dagger_pve", "Subtlety (Dagger / Dance)", "[SD]"
        else
            key, presetId, specName, badge = "subtlety", "rog_subtlety_pve", "Subtlety (Hemorrhage)", "[S]"
        end
    elseif c > a and c >= s then
        key, presetId, specName, badge = "combat", "rog_combat_pve", "Combat", "[C]"
    else
        key, presetId, specName, badge = "assassination", "rog_assassination_pve", "Assassination (Mutilate)", "[A]"
    end

    RotaClass_ROG.detectedBuild = key
    RotaClass_ROG.detectedPresetId = presetId
    RotaClass_ROG.detectedSpecName = specName
    RotaClass_ROG.detectedBadge = badge

    -- override manual: build elegida por este PJ
    local sel = RotaCore.GetSelectedBuild and RotaCore:GetSelectedBuild() or "auto"
    local active = presetId
    if sel == "assassination" or sel == "assassination_mutilate" or sel == "mutilate" then
        active = "rog_assassination_pve"
    elseif sel == "combat" then
        active = "rog_combat_pve"
    elseif sel == "subtlety" or sel == "subtlety_hemo" then
        active = "rog_subtlety_pve"
    elseif sel == "subtlety_dagger" or sel == "dance" then
        active = "rog_subtlety_dagger_pve"
    end

    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(active)
    end
    return key, active, specName
end

-- Registro del modulo de clase y eventos
RotaClass_ROG.UpdateState = UpdateRogueState

if RotaCore.RegisterClassModule then
    RotaCore:RegisterClassModule({
        class = "ROGUE",
        addonName = "RotaClass_ROG",
        classColor = { r = 1.0, g = 0.96, b = 0.41 },
        builds = {
            { key = "auto", name = "AUTO", color = {1.0, 0.9, 0.0} },
            { key = "assassination", name = "Assassination", color = {0.8, 1.0, 0.2}, preset = "rog_assassination_pve" },
            { key = "combat", name = "Combat", color = {1.0, 0.5, 0.2}, preset = "rog_combat_pve" },
            { key = "subtlety", name = "Subtlety", color = {0.6, 0.3, 0.9}, preset = "rog_subtlety_pve" },
            { key = "subtlety_dagger", name = "Subtlety (Dagger)", color = {0.8, 0.4, 1.0}, preset = "rog_subtlety_dagger_pve" },
        },
        detectBuild = function() return RotaClass_ROG:DetectBuild() end,
        getIdlePreviewAction = function(buildKey)
            if buildKey == "combat" then return "SS"
            elseif buildKey == "subtlety" or buildKey == "subtlety_dagger" then return "HEMO"
            else return "MUT" end
        end,
        stateProvider = RotaClass_ROG.UpdateState,
    })
elseif RotaCore.State and RotaCore.State.RegisterProvider then
    RotaCore.State:RegisterProvider("ROGUE", UpdateRogueState)
end

if _G.CreateFrame and not RotaClass_ROG.eventFrame then
    local f = _G.CreateFrame("Frame", "RotaClass_ROG_EventFrame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_EQUIPMENT_CHANGED" and arg1 ~= 16 then return end
        RotaClass_ROG:DetectBuild()
    end)
    RotaClass_ROG.eventFrame = f
end

return RotaClass_ROG
