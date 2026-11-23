-- RotaEditor/TabCode.lua — Code Editor with Bidirectional Sync & Scrollable View (WoW 3.3.5a)
local RotaEditor = _G.RotaEditor or {}
_G.RotaEditor = RotaEditor
local RotaCore = _G.RotaCore

local TabCode = {
    container = nil,
    editBox = nil,
    scrollFrame = nil,
    statusText = nil,
}
RotaEditor.TabCode = TabCode

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

function TabCode:Init(parent)
    local container = _G.CreateFrame("Frame", "RotaEditorTabCodeFrame", parent)
    container:SetAllPoints(parent)
    self.container = container

    -- Top Control Bar with Styled Buttons
    local syncFromBtn = GetCreateStyledButton(container, 120, 24, "Recargar")
    syncFromBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 16, -10)
    syncFromBtn:SetScript("OnClick", function()
        self:SyncFromIR()
    end)

    local applyToBtn = GetCreateStyledButton(container, 130, 24, "Guardar cambios")
    applyToBtn:SetPoint("TOPLEFT", syncFromBtn, "TOPRIGHT", 10, 0)
    applyToBtn:SetScript("OnClick", function()
        self:ApplyToIR()
    end)

    -- Status message text
    local statusText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetFontObject(GameFontNormal)
    statusText:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 16, 12)
    statusText:SetText("|cFF888888Edita las reglas y toca Guardar cambios. Recargar descarta lo que no guardaste.|r")
    self.statusText = statusText

    -- ScrollFrame with solid backdrop
    local scrollFrame = _G.CreateFrame("ScrollFrame", "RotaEditorCodeScrollFrame", container)
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 16, -42)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -48, 36)
    if scrollFrame.SetBackdrop then
        scrollFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        if scrollFrame.SetBackdropColor then
            scrollFrame:SetBackdropColor(0.02, 0.02, 0.04, 0.95)
        end
        if scrollFrame.SetBackdropBorderColor then
            scrollFrame:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)
        end
    end

    -- Mouse wheel scroll support
    if scrollFrame.EnableMouseWheel then
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
            local cur = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
            local nextVal = math.max(0, cur - (delta * 40))
            if sf.SetVerticalScroll then
                sf:SetVerticalScroll(nextVal)
            end
        end)
    end
    self.scrollFrame = scrollFrame

    -- Scroll Up / Down Buttons
    local scrollUpBtn = GetCreateStyledButton(container, 26, 26, "^")
    scrollUpBtn:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, 0)
    scrollUpBtn:SetScript("OnClick", function()
        local cur = (scrollFrame.GetVerticalScroll and scrollFrame:GetVerticalScroll()) or 0
        local nextVal = math.max(0, cur - 80)
        if scrollFrame.SetVerticalScroll then
            scrollFrame:SetVerticalScroll(nextVal)
        end
    end)

    local scrollDownBtn = GetCreateStyledButton(container, 26, 26, "v")
    scrollDownBtn:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 0)
    scrollDownBtn:SetScript("OnClick", function()
        local cur = (scrollFrame.GetVerticalScroll and scrollFrame:GetVerticalScroll()) or 0
        local nextVal = cur + 80
        if scrollFrame.SetVerticalScroll then
            scrollFrame:SetVerticalScroll(nextVal)
        end
    end)

    -- Multiline EditBox inside ScrollFrame
    local editBox = _G.CreateFrame("EditBox", "RotaEditorCodeEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(99999)
    if editBox.EnableMouse then editBox:EnableMouse(true) end
    editBox:SetAutoFocus(false)
    editBox:SetWidth(560)
    if editBox.SetTextInsets then
        editBox:SetTextInsets(6, 6, 6, 6)
    end
    if editBox.SetFontObject and _G.GameFontHighlightSmall then
        editBox:SetFontObject(_G.GameFontHighlightSmall)
    end

    editBox:SetScript("OnEscapePressed", function(eb)
        if eb.ClearFocus then eb:ClearFocus() end
    end)

    scrollFrame:SetScrollChild(editBox)
    self.editBox = editBox
end

--- Syncs code editor contents from active RotationIR
function TabCode:SyncFromIR()
    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if not profile then
        self.statusText:SetFontObject(GameFontNormal)
        self.statusText:SetText("|cFFFF0000[Error] No hay perfil activo.|r")
        return
    end

    if RotaCore.CodeGen and RotaCore.CodeGen.ProfileToLua then
        local luaCode = RotaCore.CodeGen:ProfileToLua(profile)
        if self.editBox and self.editBox.SetText then
            self.editBox:SetText(luaCode)
        end
        self.statusText:SetFontObject(GameFontNormal)
        self.statusText:SetText("|cFF00FF00Codigo cargado desde la rotacion activa.|r")
    end
end

--- Parses editbox contents and applies to active RotationIR
function TabCode:ApplyToIR()
    if not self.editBox or not self.editBox.GetText then return end
    local code = self.editBox:GetText() or ""

    if code:match("^%s*$") then
        self.statusText:SetFontObject(GameFontNormal)
        self.statusText:SetText("|cFFFF0000[Error] El código está vacío.|r")
        return
    end

    local activeProfile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    if not RotaCore.ParserLua then
        self.statusText:SetFontObject(GameFontNormal)
        self.statusText:SetText("|cFFFF0000No se pudo leer el codigo.|r")
        return
    end

    local parsedIR = RotaCore.ParserLua:Parse(code, activeProfile)
    if not parsedIR or not parsedIR.lists then
        self.statusText:SetFontObject(GameFontNormal)
        self.statusText:SetText("|cFFFF0000El codigo tiene un error: revisa la ultima regla que cambiaste.|r")
        return
    end

    -- Update active profile and recompile
    if RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
        RotaCore.Profiles:SetActiveProfile(parsedIR)
    elseif activeProfile then
        for k, v in pairs(parsedIR) do
            activeProfile[k] = v
        end
        if RotaCore.Compiler then
            local eval = RotaCore.Compiler:Compile(activeProfile)
            if RotaCore.Profiles then
                RotaCore.Profiles.activeEvaluator = eval
            end
        end
        if RotaCore.Profiles and RotaCore.Profiles.SaveProfile then
            RotaCore.Profiles:SaveProfile(activeProfile)
        end
    end

    if RotaEditor.TabBlocks and RotaEditor.TabBlocks.Refresh then
        RotaEditor.TabBlocks:Refresh()
    end

    local mainCount = (parsedIR.lists.main and #parsedIR.lists.main) or 0
    local offCount = (parsedIR.lists.off and #parsedIR.lists.off) or 0
    self.statusText:SetFontObject(GameFontNormal)
    self.statusText:SetText(string.format("|cFF00FF00Guardado: %d reglas principales, %d fuera del GCD.|r",
        mainCount, offCount))
end


--- Refreshes the TabCode UI (loads current IR code if editbox is empty)
function TabCode:Refresh()
    if self.editBox and self.editBox.GetText then
        local currentText = self.editBox:GetText()
        if not currentText or currentText == "" then
            self:SyncFromIR()
        end
    end
end

return TabCode