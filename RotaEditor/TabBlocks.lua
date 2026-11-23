-- RotaEditor/TabBlocks.lua — Interactive Visual Block Tree with Guided Rule Editor (WoW 3.3.5a)
local RotaEditor = _G.RotaEditor or {}
_G.RotaEditor = RotaEditor
local RotaCore = _G.RotaCore

local TabBlocks = {
    currentList = "main", -- "main" or "off"
    pool = nil,
    container = nil,
    editModal = nil,
    editingRule = nil,
    editingIndex = nil,
    editingList = nil,
}
RotaEditor.TabBlocks = TabBlocks

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function GetCreateStyledButton(parent, width, height, text)
    if RotaEditor.CreateStyledButton then
        return RotaEditor.CreateStyledButton(parent, width, height, text)
    end
    local btn = _G.CreateFrame("Button", nil, parent)
    if width and height then btn:SetSize(width, height) end
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetFontObject(GameFontNormal)
    txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
    txt:SetText(text or "")
    btn.text = txt
    return btn
end

local function GetCreateStyledEditBox(parent, width, height, defaultText)
    if RotaEditor.CreateStyledEditBox then
        return RotaEditor.CreateStyledEditBox(parent, width, height, defaultText)
    end
    local eb = _G.CreateFrame("EditBox", nil, parent)
    if width and height then eb:SetSize(width, height) end
    eb:SetAutoFocus(false)
    if defaultText then eb:SetText(tostring(defaultText)) end
    return eb
end

local function RecompileCurrentProfile()
    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if profile and RotaCore.Compiler then
        local eval = RotaCore.Compiler:Compile(profile)
        if RotaCore.Profiles and RotaCore.Profiles.activeEvaluator ~= nil then
            RotaCore.Profiles.activeEvaluator = eval
        end
        if RotaCore.Profiles and RotaCore.Profiles.SaveProfile then
            RotaCore.Profiles:SaveProfile(profile)
        end
    end
end

--- Translates rule condition AST into a concise, human-readable description
local function FormatConditionReadable(rule)
    if not rule then return "Siempre" end
    if rule.note and rule.note ~= "" and rule.note ~= "Nueva regla" then
        return rule.note
    end
    if rule.type == "customLua" then
        local code = rule.code or ""
        if #code > 32 then code = code:sub(1, 29) .. "..." end
        return "|cFF00FFFF[Lua]|r " .. code
    end

    local when = rule.when
    if not when then return "Siempre" end

    local function NodeToStr(node)
        if not node then return "true" end
        local op = node.op
        if op == "val" then
            return tostring(node.val)
        elseif op == "not" then
            return "Sin " .. NodeToStr(node.expr)
        elseif op == "and" then
            return NodeToStr(node.left) .. " Y " .. NodeToStr(node.right)
        elseif op == "or" then
            return NodeToStr(node.left) .. " O " .. NodeToStr(node.right)
        elseif op == "compare" then
            local left = node.left
            local opSym = node.operator or "=="
            local right = tostring(node.right)

            if left == "state.runes.frostReady" or left == "state.runes.effectiveFrost" then
                return string.format("[Runas Frost %s %s]", opSym, right)
            elseif left == "state.runes.bloodReady" or left == "state.runes.effectiveBlood" then
                return string.format("[Runas Sangre %s %s]", opSym, right)
            elseif left == "state.runes.unholyReady" or left == "state.runes.effectiveUnholy" then
                return string.format("[Runas Profanas %s %s]", opSym, right)
            elseif left == "state.power" then
                return string.format("[Poder %s %s]", opSym, right)
            elseif left == "state.targetHealthPct" then
                return string.format("[HP Target %s %s%%]", opSym, right)
            elseif type(left) == "string" and left:match("state%.debuffRemaining%([\"']([^\"']+)[\"']%)") then
                local debuff = left:match("state%.debuffRemaining%([\"']([^\"']+)[\"']%)")
                return string.format("[%s %s %ss]", debuff, opSym, right)
            elseif type(left) == "string" and left:match("state%.buffRemaining%([\"']([^\"']+)[\"']%)") then
                local buff = left:match("state%.buffRemaining%([\"']([^\"']+)[\"']%)")
                return string.format("[%s %s %ss]", buff, opSym, right)
            elseif type(left) == "string" and left:match("state%.spellReady%([\"']([^\"']+)[\"']%)") then
                local sp = left:match("state%.spellReady%([\"']([^\"']+)[\"']%)")
                return string.format("[%s Listo]", sp)
            else
                return string.format("[%s %s %s]", tostring(left), opSym, right)
            end
        elseif op == "fn" then
            local fnName = node.fn
            local arg = node.args and node.args[1]
            if fnName == "spellReady" then
                return string.format("[%s Listo]", tostring(arg))
            elseif fnName == "debuffRemaining" then
                return string.format("[%s Activo]", tostring(arg))
            elseif fnName == "buffRemaining" then
                return string.format("[%s Activo]", tostring(arg))
            else
                return string.format("[%s(%s)]", tostring(fnName), tostring(arg or ""))
            end
        end
        return tostring(op)
    end

    local text = NodeToStr(when)
    if #text > 42 then
        text = text:sub(1, 39) .. "..."
    end
    return text
end

local function InitBlockFrame(f)
    f:SetSize(620, 42)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if f.SetBackdropColor then f:SetBackdropColor(0.1, 0.1, 0.14, 0.9) end
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.8) end
    end

    -- Rule sequence number badge
    f.badgeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.badgeText:SetFontObject(GameFontNormal)
    f.badgeText:SetPoint("LEFT", f, "LEFT", 8, 0)

    -- Toggle ON/OFF button
    f.toggleBtn = GetCreateStyledButton(f, 40, 24, "ON")
    f.toggleBtn:SetPoint("LEFT", f, "LEFT", 30, 0)

    -- Real 24x24 spell icon
    f.iconFrame = _G.CreateFrame("Frame", nil, f)
    f.iconFrame:SetSize(24, 24)
    f.iconFrame:SetPoint("LEFT", f.toggleBtn, "RIGHT", 8, 0)
    if f.iconFrame.SetBackdrop then
        f.iconFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 4, edgeSize = 4,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
    end
    f.iconTexture = f.iconFrame:CreateTexture(nil, "BACKGROUND")
    f.iconTexture:SetPoint("TOPLEFT", f.iconFrame, "TOPLEFT", 1, -1)
    f.iconTexture:SetPoint("BOTTOMRIGHT", f.iconFrame, "BOTTOMRIGHT", -1, 1)
    f.iconTexture:SetTexture(DEFAULT_ICON)

    -- Spell alias & display name
    f.actionText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.actionText:SetFontObject(GameFontNormal)
    f.actionText:SetPoint("LEFT", f.iconFrame, "RIGHT", 6, 0)
    f.actionText:SetWidth(150)
    f.actionText:SetJustifyH("LEFT")

    -- Condition block readable text: entre el nombre y los botones (se corta con "..." si no entra)
    f.condText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.condText:SetFontObject(GameFontNormal)
    f.condText:SetJustifyH("LEFT")

    -- Edit modal button
    f.editBtn = GetCreateStyledButton(f, 38, 22, "Edit")
    f.editBtn:SetPoint("RIGHT", f, "RIGHT", -78, 0)

    -- Reorder Up button
    f.upBtn = GetCreateStyledButton(f, 22, 22, "^")
    f.upBtn:SetPoint("RIGHT", f, "RIGHT", -52, 0)

    -- Reorder Down button
    f.downBtn = GetCreateStyledButton(f, 22, 22, "v")
    f.downBtn:SetPoint("RIGHT", f, "RIGHT", -28, 0)

    -- Delete button
    f.delBtn = GetCreateStyledButton(f, 22, 22, "X")
    f.delBtn:SetPoint("RIGHT", f, "RIGHT", -4, 0)

    f.condText:SetPoint("LEFT", f.actionText, "RIGHT", 8, 0)
    f.condText:SetPoint("RIGHT", f.editBtn, "LEFT", -6, 0)
    f.condText:SetHeight(20)
end

--- Initializes the UI components for Tab 1 (Blocks)
function TabBlocks:Init(parent)
    local container = _G.CreateFrame("Frame", "RotaEditorTabBlocksFrame", parent)
    container:SetAllPoints(parent)
    self.container = container

    -- 1. Header controls: List selector toggle
    local listToggleBtn = GetCreateStyledButton(container, 130, 24, "Lista: principal")
    listToggleBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 10, -6)
    listToggleBtn:SetScript("OnClick", function()
        if self.currentList == "main" then
            self.currentList = "off"
            listToggleBtn:SetButtonText("Lista: fuera del GCD")
        else
            self.currentList = "main"
            listToggleBtn:SetButtonText("Lista: principal")
        end
        self:Refresh()
    end)
    self.listToggleBtn = listToggleBtn

    -- Add Rule button
    local addRuleBtn = GetCreateStyledButton(container, 110, 24, "+ Agregar Regla")
    addRuleBtn:SetPoint("LEFT", listToggleBtn, "RIGHT", 8, 0)
    addRuleBtn:SetScript("OnClick", function()
        self:AddRule()
    end)

    -- Preset selector button
    local presetBtn = GetCreateStyledButton(container, 140, 24, "Preset: Cargar...")
    presetBtn:SetPoint("LEFT", addRuleBtn, "RIGHT", 6, 0)
    presetBtn:SetScript("OnClick", function()
        self:CyclePreset()
    end)
    self.presetBtn = presetBtn

    -- Restaurar: borra la rotacion custom de este PJ y vuelve al preset
    local resetBtn = GetCreateStyledButton(container, 90, 24, "Restaurar")
    resetBtn:SetPoint("LEFT", presetBtn, "RIGHT", 6, 0)
    resetBtn:SetScript("OnClick", function()
        self:ResetToPreset()
    end)
    self.resetBtn = resetBtn

    -- Burst toggle button
    local burstBtn = GetCreateStyledButton(container, 64, 24, "Burst: ON")
    burstBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)
    burstBtn:SetScript("OnClick", function()
        if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
        if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
        local cur = (_G.RotaCoreDB.settings.burstMode ~= false)
        _G.RotaCoreDB.settings.burstMode = not cur
        self:Refresh()
    end)
    self.burstBtn = burstBtn

    -- AoE toggle button
    local aoeBtn = GetCreateStyledButton(container, 64, 24, "AoE: Auto")
    aoeBtn:SetPoint("LEFT", burstBtn, "RIGHT", 6, 0)
    aoeBtn:SetScript("OnClick", function()
        if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
        if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
        local cur = (_G.RotaCoreDB.settings.aoeMode == true)
        _G.RotaCoreDB.settings.aoeMode = not cur
        self:Refresh()
    end)
    self.aoeBtn = aoeBtn

    -- 2. Scroll area / Child
    local scrollFrame = _G.CreateFrame("ScrollFrame", "RotaEditorBlocksScrollFrame", container)
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 10, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -10, 10)
    if scrollFrame.EnableMouseWheel then
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
            local cur = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
            local nextVal = math.max(0, cur - (delta * 36))
            if sf.SetVerticalScroll then
                sf:SetVerticalScroll(nextVal)
            end
        end)
    end

    local scrollChild = _G.CreateFrame("Frame", "RotaEditorBlocksScrollChild", scrollFrame)
    scrollChild:SetSize(620, 400)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild
    self.scrollFrame = scrollFrame

    -- Instantiate FramePool
    self.pool = RotaEditor.FramePool.New("Frame", scrollChild, nil, InitBlockFrame)

    -- 3. Create the Block Edit Modal Sub-panel
    self:CreateEditModal(RotaEditor.mainFrame or container)
end

--- Cycles through available presets in RotaCore.Profiles
function TabBlocks:CyclePreset()
    if not RotaCore or not RotaCore.Profiles or not RotaCore.Profiles.presets then return end
    local presets = RotaCore.Profiles.presets
    local playerClass = _G.UnitClass and select(2, _G.UnitClass("player"))
    local presetList = {}
    local seen = {}
    for id, p in pairs(presets) do
        -- solo los de tu clase, sin repetir alias que apuntan al mismo preset
        local realId = p.meta and p.meta.id
        if realId == id and not seen[realId] and not p.meta.v1Of and (not playerClass or p.meta.class == playerClass) then
            seen[realId] = true
            table.insert(presetList, id)
        end
    end
    table.sort(presetList)
    if #presetList == 0 then return end

    local active = RotaCore.Profiles:GetActiveProfile()
    local currentId = active and active.meta and active.meta.id
    local nextIdx = 1
    for i, id in ipairs(presetList) do
        if id == currentId then
            nextIdx = (i % #presetList) + 1
            break
        end
    end

    local targetId = presetList[nextIdx]
    if RotaCore.Profiles.SetActiveProfile then
        -- SetActiveProfile ya compila; usa tu custom de ese preset si existe
        RotaCore.Profiles:SetActiveProfile(targetId)
        self:Refresh()
    end
end

--- Borra la rotacion custom de este PJ para el perfil activo y vuelve al preset
function TabBlocks:ResetToPreset()
    local active = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    local id = active and active.meta and active.meta.id
    if not id or not RotaCore.Profiles.ResetProfile then return end
    RotaCore.Profiles:ResetProfile(id)
    if _G.DEFAULT_CHAT_FRAME then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Rotacion custom borrada: vuelve el preset " .. id)
    end
    self:Refresh()
end

--- Builds the Block Editor Modal
function TabBlocks:CreateEditModal(parent)
    local modal = _G.CreateFrame("Frame", "RotaEditorRuleEditModal", parent)
    modal:SetSize(520, 420)
    modal:SetPoint("CENTER", parent, "CENTER", 0, 0)
    if modal.SetFrameStrata then
        modal:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    if modal.EnableMouse then modal:EnableMouse(true) end
    if modal.SetBackdrop then
        modal:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 24, edgeSize = 16,
            insets = { left = 6, right = 6, top = 6, bottom = 6 }
        })
        if modal.SetBackdropColor then
            modal:SetBackdropColor(0.06, 0.06, 0.1, 0.98)
        end
        if modal.SetBackdropBorderColor then
            modal:SetBackdropBorderColor(0.6, 0.6, 0.7, 1)
        end
    end

    -- Title
    local modalTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modalTitle:SetFontObject(GameFontNormal)
    modalTitle:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -14)
    modalTitle:SetText("|cFFFFFF00Editor de Regla de Rotación|r")
    modal.title = modalTitle

    -- Close 'X' button
    local closeBtn = GetCreateStyledButton(modal, 24, 22, "X")
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -12, -12)
    closeBtn:SetScript("OnClick", function()
        modal:Hide()
    end)

    -- Section 1: List selection
    local listLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetFontObject(GameFontNormal)
    listLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -45)
    listLabel:SetText("Lista Destino:")

    local listMainBtn = GetCreateStyledButton(modal, 110, 22, "Main (GCD)")
    listMainBtn:SetPoint("LEFT", listLabel, "RIGHT", 10, 0)
    local listOffBtn = GetCreateStyledButton(modal, 120, 22, "Off (Fuera GCD)")
    listOffBtn:SetPoint("LEFT", listMainBtn, "RIGHT", 6, 0)

    listMainBtn:SetScript("OnClick", function()
        self.editingList = "main"
        if listMainBtn.SetBackdropBorderColor then listMainBtn:SetBackdropBorderColor(0, 1, 0, 1) end
        if listOffBtn.SetBackdropBorderColor then listOffBtn:SetBackdropBorderColor(0.5, 0.5, 0.55, 1) end
    end)
    listOffBtn:SetScript("OnClick", function()
        self.editingList = "off"
        if listOffBtn.SetBackdropBorderColor then listOffBtn:SetBackdropBorderColor(0, 1, 0, 1) end
        if listMainBtn.SetBackdropBorderColor then listMainBtn:SetBackdropBorderColor(0.5, 0.5, 0.55, 1) end
    end)
    modal.listMainBtn = listMainBtn
    modal.listOffBtn = listOffBtn

    -- Section 2: Action / Spell Alias
    local actLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actLabel:SetFontObject(GameFontNormal)
    actLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -80)
    actLabel:SetText("Hechizo / Acción:")

    local actEdit = GetCreateStyledEditBox(modal, 90, 22, "WAIT")
    actEdit:SetPoint("LEFT", actLabel, "RIGHT", 10, 0)
    modal.actEdit = actEdit

    -- Spell Icon preview
    local actIconFrame = _G.CreateFrame("Frame", nil, modal)
    actIconFrame:SetSize(24, 24)
    actIconFrame:SetPoint("LEFT", actEdit, "RIGHT", 8, 0)
    local actIconTex = actIconFrame:CreateTexture(nil, "BACKGROUND")
    actIconTex:SetPoint("TOPLEFT", actIconFrame, "TOPLEFT", 1, -1)
    actIconTex:SetPoint("BOTTOMRIGHT", actIconFrame, "BOTTOMRIGHT", -1, 1)
    actIconTex:SetTexture(DEFAULT_ICON)
    modal.actIconTex = actIconTex

    local actNameLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actNameLabel:SetFontObject(GameFontNormal)
    actNameLabel:SetPoint("LEFT", actIconFrame, "RIGHT", 6, 0)
    actNameLabel:SetText("")
    modal.actNameLabel = actNameLabel

    actEdit:SetScript("OnTextChanged", function()
        local alias = actEdit:GetText() or ""
        local name, icon = alias, DEFAULT_ICON
        if RotaCore and RotaCore.Spells then
            local sName, _, sIcon = RotaCore.Spells:GetInfo(alias)
            if sName then name = sName end
            if sIcon then icon = sIcon end
        end
        actIconTex:SetTexture(icon)
        actNameLabel:SetText(name)
    end)

    -- Section 3: Guided Condition Template
    local condLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    condLabel:SetFontObject(GameFontNormal)
    condLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -120)
    condLabel:SetText("Constructor de Condición Guiada:")

    -- Condition Preset Buttons
    local templates = {
        { label = "Debuff <= (s)", code = "state.debuffRemaining('Frost Fever') <= 3.0" },
        { label = "Buff <= (s)", code = "state.buffRemaining('Desolation') <= 3.0" },
        { label = "Runa Frost >= 1", code = "state.runes.frostReady >= 1" },
        { label = "Runa Sangre >= 1", code = "state.runes.bloodReady >= 1" },
        { label = "Poder >= 40", code = "state.power >= 40" },
        { label = "HP Target <= 20%", code = "state.targetHealthPct <= 20" },
    }
    local startX = 20
    local startY = -145
    for i, t in ipairs(templates) do
        local tBtn = GetCreateStyledButton(modal, 150, 22, t.label)
        tBtn:SetPoint("TOPLEFT", modal, "TOPLEFT", startX, startY)
        tBtn:SetScript("OnClick", function()
            if modal.condLuaEdit then
                modal.condLuaEdit:SetText(t.code)
            end
        end)
        if i % 3 == 0 then
            startX = 20
            startY = startY - 26
        else
            startX = startX + 158
        end
    end

    -- Condition Lua Expression input
    local luaLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    luaLabel:SetFontObject(GameFontNormal)
    luaLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -210)
    luaLabel:SetText("Expresión Lua de Condición:")

    local condLuaEdit = GetCreateStyledEditBox(modal, 470, 24, "true")
    condLuaEdit:SetPoint("TOPLEFT", luaLabel, "BOTTOMLEFT", 0, -6)
    modal.condLuaEdit = condLuaEdit

    -- Note input
    local noteLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetFontObject(GameFontNormal)
    noteLabel:SetPoint("TOPLEFT", condLuaEdit, "BOTTOMLEFT", 0, -12)
    noteLabel:SetText("Descripción / Nota de la Regla:")

    local noteEdit = GetCreateStyledEditBox(modal, 470, 24, "")
    noteEdit:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 0, -6)
    modal.noteEdit = noteEdit

    -- Action Buttons (Save / Cancel)
    local saveBtn = GetCreateStyledButton(modal, 130, 26, "Guardar Regla")
    saveBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOMLEFT", 20, 18)
    saveBtn:SetScript("OnClick", function()
        self:SaveModalRule()
    end)

    local cancelBtn = GetCreateStyledButton(modal, 100, 26, "Cancelar")
    cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 12, 0)
    cancelBtn:SetScript("OnClick", function()
        modal:Hide()
    end)

    modal:Hide()
    self.editModal = modal
end

--- Opens the Block Editor Modal for a specific rule
function TabBlocks:OpenEditModal(index, rule)
    if not self.editModal then return end
    self.editingIndex = index
    self.editingRule = rule
    self.editingList = self.currentList

    local modal = self.editModal
    modal.title:SetText(string.format("|cFFFFFF00Editar Regla #%d — [%s]|r", index, tostring(rule.action or "WAIT")))

    -- Set active list
    if self.editingList == "main" then
        if modal.listMainBtn.SetBackdropBorderColor then modal.listMainBtn:SetBackdropBorderColor(0, 1, 0, 1) end
        if modal.listOffBtn.SetBackdropBorderColor then modal.listOffBtn:SetBackdropBorderColor(0.5, 0.5, 0.55, 1) end
    else
        if modal.listOffBtn.SetBackdropBorderColor then modal.listOffBtn:SetBackdropBorderColor(0, 1, 0, 1) end
        if modal.listMainBtn.SetBackdropBorderColor then modal.listMainBtn:SetBackdropBorderColor(0.5, 0.5, 0.55, 1) end
    end

    -- Set action
    modal.actEdit:SetText(rule.action or "WAIT")

    -- Set condition Lua
    local condCode = "true"
    if rule.type == "customLua" then
        condCode = rule.code or "true"
    elseif rule.when and RotaCore and RotaCore.CodeGen and RotaCore.CodeGen.ASTToLua then
        condCode = RotaCore.CodeGen.ASTToLua(rule.when)
    end
    modal.condLuaEdit:SetText(condCode)

    -- Set note
    modal.noteEdit:SetText(rule.note or "")

    modal:Show()
end

--- Saves changes made in the modal back into the profile
function TabBlocks:SaveModalRule()
    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if not profile or not profile.lists then
        if self.editModal then self.editModal:Hide() end
        return
    end

    local origList = profile.lists[self.currentList]
    local targetList = profile.lists[self.editingList]
    if not targetList then
        targetList = {}
        profile.lists[self.editingList] = targetList
    end

    local modal = self.editModal
    local newAction = modal.actEdit:GetText()
    if not newAction or newAction == "" then newAction = "WAIT" end
    local newCode = modal.condLuaEdit:GetText() or "true"
    local newNote = modal.noteEdit:GetText() or ""

    local rule = self.editingRule or {}
    rule.action = newAction
    rule.note = newNote
    rule.type = "customLua"
    rule.code = newCode

    -- If moved to a different list, remove from old and insert in new
    if self.editingList ~= self.currentList and origList and self.editingIndex then
        table.remove(origList, self.editingIndex)
        table.insert(targetList, rule)
    elseif origList and self.editingIndex then
        origList[self.editingIndex] = rule
    end

    modal:Hide()
    RecompileCurrentProfile()
    self:Refresh()
end

--- Adds a default block rule to the current list
function TabBlocks:AddRule()
    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if not profile or not profile.lists then return end

    local list = profile.lists[self.currentList]
    if not list then
        list = {}
        profile.lists[self.currentList] = list
    end

    local newRule = {
        id = string.format("%s_%d", self.currentList, #list + 1),
        enabled = true,
        type = "block",
        action = "WAIT",
        note = "Nueva regla",
        when = { op = "val", val = true }
    }
    table.insert(list, newRule)
    RecompileCurrentProfile()
    self:Refresh()
end

--- Moves a rule at index up or down
function TabBlocks:MoveRule(index, direction)
    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if not profile or not profile.lists then return end

    local list = profile.lists[self.currentList]
    if not list then return end

    local targetIndex = index + direction
    if targetIndex >= 1 and targetIndex <= #list then
        local temp = list[index]
        list[index] = list[targetIndex]
        list[targetIndex] = temp
        RecompileCurrentProfile()
        self:Refresh()
    end
end

--- Deletes a rule at index
function TabBlocks:DeleteRule(index)
    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if not profile or not profile.lists then return end

    local list = profile.lists[self.currentList]
    if not list or not list[index] then return end

    table.remove(list, index)
    RecompileCurrentProfile()
    self:Refresh()
end

--- Toggles enabled status of rule at index
function TabBlocks:ToggleRule(index)
    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if not profile or not profile.lists then return end

    local list = profile.lists[self.currentList]
    if not list or not list[index] then return end

    list[index].enabled = (list[index].enabled == false)
    RecompileCurrentProfile()
    self:Refresh()
end

--- Refreshes the display of blocks using the recycled pool
function TabBlocks:Refresh()
    if not self.pool or not self.scrollChild then return end

    self.pool:ReleaseAll()

    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    local list = profile and profile.lists and profile.lists[self.currentList] or {}

    -- Update active preset button label
    if self.presetBtn then
        local pName = (profile and profile.meta and profile.meta.name) or "Ninguno"
        local isCustom = profile and profile.meta and profile.meta.custom
        if #pName > 14 then pName = pName:sub(1, 12) .. ".." end
        self.presetBtn:SetButtonText(isCustom and ("|cFF00FF00Custom:|r " .. pName) or ("Preset: " .. pName))
    end

    if self.burstBtn then
        local bOn = (_G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.burstMode ~= false)
        self.burstBtn:SetButtonText(bOn and "|cFFFF8800Burst: ON|r" or "|c55888888Burst: OFF|r")
    end

    if self.aoeBtn then
        local aOn = (_G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.aoeMode == true)
        local auto = (_G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.autoAoE ~= false)
        self.aoeBtn:SetButtonText(auto and "|cFFFF2222AoE: Auto|r" or (aOn and "|cFFFF2222AoE: ON|r" or "|c55888888AoE: OFF|r"))
    end

    local Spells = RotaCore and RotaCore.Spells

    for i = 1, #list do
        local rule = list[i]
        local frame = self.pool:Acquire()
        frame:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, - (i - 1) * 44)

        -- Badge: #1
        frame.badgeText:SetFontObject(GameFontNormal)
        frame.badgeText:SetText(string.format("#%d", i))

        -- Toggle Button: ON / OFF with visual color
        frame.toggleBtn.text:SetFontObject(GameFontNormal)
        if rule.enabled ~= false then
            frame.toggleBtn:SetButtonText("|cFF00FF00ON|r")
            if frame.toggleBtn.SetBackdropBorderColor then
                frame.toggleBtn:SetBackdropBorderColor(0, 0.8, 0, 0.9)
            end
        else
            frame.toggleBtn:SetButtonText("|cFFFF4444OFF|r")
            if frame.toggleBtn.SetBackdropBorderColor then
                frame.toggleBtn:SetBackdropBorderColor(0.8, 0, 0, 0.9)
            end
        end
        frame.toggleBtn:SetScript("OnClick", function()
            self:ToggleRule(i)
        end)

        -- Spell Icon & Name
        local alias = rule.action or "WAIT"
        local spellName, spellIcon = alias, DEFAULT_ICON
        if Spells and Spells.GetInfo then
            local n, _, ic = Spells:GetInfo(alias)
            if n then spellName = n end
            if ic then spellIcon = ic end
        end
        if frame.iconTexture and frame.iconTexture.SetTexture then
            frame.iconTexture:SetTexture(spellIcon)
        end

        frame.actionText:SetFontObject(GameFontNormal)
        local shortName = spellName
        if #shortName > 14 then shortName = shortName:sub(1, 12) .. ".." end
        frame.actionText:SetText(string.format("|cFFFFFF00[%s]|r %s", alias, shortName))

        -- Human-readable condition description
        local condReadable = FormatConditionReadable(rule)
        frame.condText:SetFontObject(GameFontNormal)
        frame.condText:SetText(condReadable)

        -- Edit Button
        frame.editBtn:SetScript("OnClick", function()
            self:OpenEditModal(i, rule)
        end)

        -- Move Up / Down / Del
        frame.upBtn:SetScript("OnClick", function()
            self:MoveRule(i, -1)
        end)

        frame.downBtn:SetScript("OnClick", function()
            self:MoveRule(i, 1)
        end)

        frame.delBtn:SetScript("OnClick", function()
            self:DeleteRule(i)
        end)
    end

    self.scrollChild:SetHeight(math.max(400, #list * 44 + 20))
end

return TabBlocks