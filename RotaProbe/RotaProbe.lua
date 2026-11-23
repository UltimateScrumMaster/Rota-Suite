-- RotaProbe.lua — WoW 3.3.5a (Interface 30300) Diagnostic Probe
-- Escanea APIs, talentos, libro de hechizos y glifos del servidor (RotaProbeDB).

local ADDON_NAME = "RotaProbe"
local DB_VERSION = 1

local RotaProbe = {
    version = "1.0.0",
    db = nil,
    exportFrame = nil,
}
_G.RotaProbe = RotaProbe

local function PrintMsg(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaProbe]|r " .. tostring(msg))
    elseif print then
        print("[RotaProbe] " .. tostring(msg))
    end
end

-- 1. PROBE ROUTINES

local function ProbeAPIs()
    local apiList = {
        "GetSpellInfo",
        "GetSpellCooldown",
        "IsSpellInRange",
        "IsUsableSpell",
        "GetSpellTabInfo",
        "GetSpellBookItemInfo",
        "GetNumSpellTabs",
        "GetSpellName",
        "GetRuneCooldown",
        "GetRuneType",
        "UnitAura",
        "UnitBuff",
        "UnitDebuff",
        "UnitPower",
        "UnitPowerMax",
        "GetNumTalentTabs",
        "GetNumTalents",
        "GetTalentInfo",
        "GetActiveTalentGroup",
        "GetGlyphSocketInfo",
        "GetTime",
        "CreateFrame",
    }

    local results = {}
    for _, apiName in ipairs(apiList) do
        local fn = _G[apiName]
        results[apiName] = {
            exists = (type(fn) == "function"),
            type = type(fn),
        }
    end

    -- Check forbidden post-3.3.5 APIs
    results["C_Timer"] = { exists = (_G["C_Timer"] ~= nil), forbidden = true }
    results["C_Spell"] = { exists = (_G["C_Spell"] ~= nil), forbidden = true }
    results["C_Aura"]  = { exists = (_G["C_Aura"] ~= nil), forbidden = true }

    return results
end

local function ProbeSpellbook()
    local spells = {}
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0

    for tab = 1, numTabs do
        local tabName, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = 1, (numSpells or 0) do
            local slotIndex = offset + i
            local skillType, spellId = nil, nil
            if GetSpellBookItemInfo then
                skillType, spellId = GetSpellBookItemInfo(slotIndex, "spell")
            end

            local spellName, spellRank = nil, nil
            if GetSpellName then
                spellName, spellRank = GetSpellName(slotIndex, "spell")
            end

            local sName, sRank, sIcon, sCost, sPowerType
            if spellId and GetSpellInfo then
                sName, sRank, sIcon, sCost, _, sPowerType = GetSpellInfo(spellId)
            elseif spellName and GetSpellInfo then
                sName, sRank, sIcon, sCost, _, sPowerType = GetSpellInfo(spellName)
            end

            local finalName = sName or spellName or ("Slot" .. slotIndex)
            spells[finalName] = {
                slot = slotIndex,
                tab = tabName,
                skillType = skillType,
                spellId = spellId,
                rank = sRank or spellRank or "",
                icon = sIcon,
                cost = sCost,
                powerType = sPowerType,
            }
        end
    end

    return spells
end

local function ProbeTalents()
    local talents = {
        activeGroup = GetActiveTalentGroup and GetActiveTalentGroup() or 1,
        tabs = {},
    }

    local numTabs = GetNumTalentTabs and GetNumTalentTabs() or 0
    for tab = 1, numTabs do
        local numTalents = GetNumTalents and GetNumTalents(tab) or 0
        talents.tabs[tab] = {}
        for i = 1, numTalents do
            local name, icon, tier, col, currentRank, maxRank = GetTalentInfo(tab, i)
            if name then
                table.insert(talents.tabs[tab], {
                    index = i,
                    name = name,
                    icon = icon,
                    tier = tier,
                    column = col,
                    rank = currentRank or 0,
                    maxRank = maxRank or 0,
                })
            end
        end
    end

    return talents
end

local function ProbeGlyphs()
    local glyphs = {}
    local activeGroup = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    if GetGlyphSocketInfo then
        for i = 1, 6 do
            local enabled, glyphType, glyphSpellID, icon = GetGlyphSocketInfo(i, activeGroup)
            glyphs[i] = {
                enabled = enabled,
                glyphType = glyphType,
                glyphSpellID = glyphSpellID,
                icon = icon,
            }
        end
    end
    return glyphs
end

-- 2. SERIALIZATION FOR EXPORT

local function SerializeValue(val, depth)
    depth = depth or 0
    local t = type(val)
    if t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        if depth > 4 then return '"{depth_limit}"' end
        local indent = string.rep("  ", depth + 1)
        local closing = string.rep("  ", depth)
        local parts = {}
        local isArray = (#val > 0)
        if isArray then
            for i, v in ipairs(val) do
                table.insert(parts, indent .. SerializeValue(v, depth + 1))
            end
        else
            for k, v in pairs(val) do
                local keyRepr = (type(k) == "string" and k:match("^[%a_][%a%d_]*$")) and k or ("[" .. SerializeValue(k, 0) .. "]")
                table.insert(parts, indent .. keyRepr .. " = " .. SerializeValue(v, depth + 1))
            end
            table.sort(parts)
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. closing .. "}"
    else
        return '"<' .. t .. '>"'
    end
end

-- 3. SCAN EXECUTION

function RotaProbe:RunScan()
    local pClass, pClassFile = (UnitClass and UnitClass("player")) or "Unknown", "UNKNOWN"
    if UnitClass then
        local _, cFile = UnitClass("player")
        if cFile then pClassFile = cFile end
    end
    local pRace = (UnitRace and UnitRace("player")) or "Unknown"
    local pLevel = (UnitLevel and UnitLevel("player")) or 80

    local apis = ProbeAPIs()
    local spells = ProbeSpellbook()
    local talents = ProbeTalents()
    local glyphs = ProbeGlyphs()

    local spellCount = 0
    for _ in pairs(spells) do spellCount = spellCount + 1 end

    local scanData = {
        version = DB_VERSION,
        timestamp = GetTime and GetTime() or 0,
        player = {
            class = pClass,
            classFile = pClassFile,
            race = pRace,
            level = pLevel,
        },
        apis = apis,
        spellbook = spells,
        talents = talents,
        glyphs = glyphs,
    }

    if not _G.RotaProbeDB then _G.RotaProbeDB = {} end
    _G.RotaProbeDB.lastScan = scanData
    self.db = _G.RotaProbeDB

    PrintMsg(string.format("Escaneo completado exitosamente: %d hechizos, clase %s (%s, Nvl %d).",
        spellCount, tostring(pClass), tostring(pRace), tonumber(pLevel) or 0))
    PrintMsg("Datos guardados en SavedVariables (RotaProbeDB.lastScan). Usa '/rotaprobe show' para copiar.")

    return scanData
end

-- 4. IN-GAME EXPORT FRAME

function RotaProbe:ShowExportFrame()
    if not CreateFrame then
        PrintMsg("CreateFrame no disponible en este entorno.")
        return
    end

    if not self.exportFrame then
        local f = CreateFrame("Frame", "RotaProbeExportFrame", UIParent)
        f:SetSize(600, 420)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

        -- Background texture or backdrop if available
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 8, right = 8, top = 8, bottom = 8 }
            })
        end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if title then
            title:SetPoint("TOP", f, "TOP", 0, -12)
            title:SetText("RotaProbe — Exportación de Diagnóstico (WoW 3.3.5a)")
        end

        local scroll = CreateFrame("ScrollFrame", "RotaProbeExportScroll", f, "UIPanelScrollFrameTemplate")
        if scroll then
            scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
            scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36, 45)

            local editBox = CreateFrame("EditBox", "RotaProbeExportEditBox", scroll)
            editBox:SetMultiLine(true)
            editBox:SetMaxLetters(999999)
            editBox:EnableMouse(true)
            editBox:SetAutoFocus(false)
            if editBox.SetFontObject then
                editBox:SetFontObject("GameFontHighlightSmall")
            end
            editBox:SetWidth(530)
            editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus(); f:Hide() end)
            scroll:SetScrollChild(editBox)
            f.editBox = editBox
        end

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        if closeBtn then
            closeBtn:SetSize(100, 24)
            closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
            closeBtn:SetText("Cerrar")
            closeBtn:SetScript("OnClick", function() f:Hide() end)
        end

        self.exportFrame = f
    end

    local lastScan = (_G.RotaProbeDB and _G.RotaProbeDB.lastScan) or self:RunScan()
    local serialized = "RotaProbeScanResult = " .. SerializeValue(lastScan, 0)
    if self.exportFrame.editBox then
        self.exportFrame.editBox:SetText(serialized)
        self.exportFrame.editBox:HighlightText()
    end
    self.exportFrame:Show()
end

-- 5. INITIALIZATION & SLASH COMMANDS

local eventFrame = CreateFrame and CreateFrame("Frame", "RotaProbeEventFrame")
if eventFrame then
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
            if not _G.RotaProbeDB then
                _G.RotaProbeDB = { version = DB_VERSION }
            end
            RotaProbe.db = _G.RotaProbeDB
        elseif event == "PLAYER_LOGIN" then
            PrintMsg("Cargado. Escribe '/rotaprobe' para iniciar el escaneo de APIs y Spellbook.")
        end
    end)
end

local function HandleSlashCmd(msg)
    local cmd = (msg or ""):match("^%s*(%S+)") or ""
    cmd = string.lower(cmd)

    if cmd == "scan" or cmd == "" then
        RotaProbe:RunScan()
    elseif cmd == "show" or cmd == "dump" or cmd == "export" then
        RotaProbe:ShowExportFrame()
    else
        PrintMsg("Comandos disponibles:")
        PrintMsg("  /rotaprobe         - Ejecuta escaneo completo de APIs, talentos y spellbook.")
        PrintMsg("  /rotaprobe show    - Muestra ventana para copiar los datos escaneados.")
        PrintMsg("  /rotaprobe dump    - Alias de show.")
    end
end

if not _G.SlashCmdList then _G.SlashCmdList = {} end
_G.SlashCmdList["ROTAPROBE"] = HandleSlashCmd
_G.SLASH_ROTAPROBE1 = "/rotaprobe"
_G.SLASH_ROTAPROBE2 = "/rp"

return RotaProbe
