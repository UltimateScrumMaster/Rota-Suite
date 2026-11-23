-- RotaEditor/RotaEditor.lua — Main Editor Frame & Navigation Shell (WoW 3.3.5a)
local RotaEditor = _G.RotaEditor or {}
_G.RotaEditor = RotaEditor

RotaEditor.version = "1.0.0"
RotaEditor.currentTab = 1
RotaEditor.mainFrame = nil
RotaEditor.tabs = {}

local TAB_NAMES = {
    "Reglas",
    "Código",
    "IDs de hechizos",
    "Ayuda",
}

--- Creates a stylized button with solid dark backdrop, hover border glow, and text label.
-- @param parent table
-- @param width number
-- @param height number
-- @param text string
-- @return table button frame
function RotaEditor.CreateStyledButton(parent, width, height, text)
    local btn = _G.CreateFrame("Button", nil, parent)
    if width and height then
        btn:SetSize(width, height)
    end
    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if btn.SetBackdropColor then
            btn:SetBackdropColor(0.18, 0.18, 0.22, 1)
        end
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)
        end
    end

    btn:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor and not self.isSelected then
            self:SetBackdropBorderColor(1, 0.82, 0, 1) -- Hover dorado
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor and not self.isSelected then
            self:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)
        end
    end)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btnText:SetFontObject(GameFontNormal)
    btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnText:SetText(text or "")
    btn.text = btnText

    function btn:SetButtonText(t)
        self.text:SetFontObject(GameFontNormal)
        self.text:SetText(t)
    end

    return btn
end

--- Creates a stylized EditBox with solid dark backdrop, visible border, and focus safety.
-- @param parent table
-- @param width number
-- @param height number
-- @param defaultText string|number|nil
-- @return table editbox frame
function RotaEditor.CreateStyledEditBox(parent, width, height, defaultText)
    local eb = _G.CreateFrame("EditBox", nil, parent)
    if width and height then
        eb:SetSize(width, height)
    end
    eb:SetAutoFocus(false)
    if eb.SetFontObject and _G.GameFontHighlightSmall then
        eb:SetFontObject(_G.GameFontHighlightSmall)
    end
    if eb.SetTextInsets then
        eb:SetTextInsets(6, 6, 2, 2)
    end
    if eb.SetBackdrop then
        eb:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if eb.SetBackdropColor then
            eb:SetBackdropColor(0, 0, 0, 0.9)
        end
        if eb.SetBackdropBorderColor then
            eb:SetBackdropBorderColor(0.6, 0.6, 0.65, 1)
        end
    end

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    if defaultText ~= nil then
        eb:SetText(tostring(defaultText))
    end
    return eb
end

function RotaEditor:Init()
    if self.mainFrame then return end

    -- 1. Main Window Frame (Draggable, DIALOG strata, Opaque dark backdrop)
    local f = _G.CreateFrame("Frame", "RotaEditorMainFrame", _G.UIParent)
    f:SetSize(660, 510)
    f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    if f.SetFrameStrata then
        f:SetFrameStrata("DIALOG")
    end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.SetMovable then f:SetMovable(true) end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end

    f:SetScript("OnDragStart", function(frame)
        if frame.StartMoving then frame:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(frame)
        if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
    end)

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        if f.SetBackdropColor then
            f:SetBackdropColor(0.05, 0.05, 0.08, 0.96)
        end
        if f.SetBackdropBorderColor then
            f:SetBackdropBorderColor(0.5, 0.5, 0.6, 1)
        end
    end

    -- Title Bar & Drag handle
    local titleBar = _G.CreateFrame("Frame", "RotaEditorTitleBar", f)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -8)
    titleBar:SetHeight(28)
    if titleBar.EnableMouse then titleBar:EnableMouse(true) end
    if titleBar.RegisterForDrag then titleBar:RegisterForDrag("LeftButton") end
    titleBar:SetScript("OnDragStart", function()
        if f.StartMoving then f:StartMoving() end
    end)
    titleBar:SetScript("OnDragStop", function()
        if f.StopMovingOrSizing then f:StopMovingOrSizing() end
    end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFontObject(GameFontNormal)
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText("|cFFFFFF00RotaCore Editor|r — v" .. self.version .. " |cFF888888(Arrastra para mover)|r")

    -- Close Button
    local closeBtn = RotaEditor.CreateStyledButton(f, 26, 22, "X")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10)
    closeBtn:SetScript("OnClick", function()
        self:Hide()
    end)

    -- Content Area Container
    local contentArea = _G.CreateFrame("Frame", "RotaEditorContentArea", f)
    contentArea:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -70)
    contentArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
    self.contentArea = contentArea

    -- 2. Initialize the 5 Sub-Tabs
    if self.TabBlocks then
        self.TabBlocks:Init(contentArea)
        self.tabs[1] = { name = "Bloques", module = self.TabBlocks, frame = self.TabBlocks.container }
    end
    if self.TabCode then
        self.TabCode:Init(contentArea)
        self.tabs[2] = { name = "Código", module = self.TabCode, frame = self.TabCode.container }
    end
    if self.TabOverrides then
        self.TabOverrides:Init(contentArea)
        self.tabs[3] = { name = "Overrides", module = self.TabOverrides, frame = self.TabOverrides.container }
    end
    if self.TabTutorial then
        self.TabTutorial:Init(contentArea)
        self.tabs[4] = { name = "Ayuda", module = self.TabTutorial, frame = self.TabTutorial.container }
    end

    -- 3. Tab Buttons Bar using CreateStyledButton
    self.tabButtons = {}
    for i, tabName in ipairs(TAB_NAMES) do
        local btn = RotaEditor.CreateStyledButton(f, 126, 26, tabName)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 18 + (i - 1) * 132, -38)

        btn:SetScript("OnClick", function()
            self:SelectTab(i)
        end)
        self.tabButtons[i] = btn
    end

    self.mainFrame = f
    self:SelectTab(1)
end

--- Selects and shows the specified tab (1 to 5)
-- @param tabIndex number
function RotaEditor:SelectTab(tabIndex)
    if not self.tabs then return end
    self.currentTab = tabIndex

    for i, t in ipairs(self.tabs) do
        local btn = self.tabButtons and self.tabButtons[i]
        if i == tabIndex then
            if t.frame and t.frame.Show then t.frame:Show() end
            if btn then
                btn.isSelected = true
                if btn.text then btn.text:SetText("|cFFFFFF00[" .. t.name .. "]|r") end
                if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(1, 0.82, 0, 1) end
            end
            if t.module and t.module.Refresh then
                t.module:Refresh()
            end
        else
            if t.frame and t.frame.Hide then t.frame:Hide() end
            if btn then
                btn.isSelected = false
                if btn.text then btn.text:SetText(t.name) end
                if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(0.5, 0.5, 0.55, 1) end
            end
        end
    end
end

function RotaEditor:Show()
    if not self.mainFrame then
        self:Init()
    end
    if self.mainFrame and self.mainFrame.Show then
        self.mainFrame:Show()
        self:SelectTab(self.currentTab or 1)
    end
end

function RotaEditor:Hide()
    if self.mainFrame and self.mainFrame.Hide then
        self.mainFrame:Hide()
    end
end

function RotaEditor:Toggle()
    if not self.mainFrame then
        self:Init()
    end
    if self.mainFrame and self.mainFrame.IsShown and self.mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Slash command registration
if _G.SlashCmdList then
    _G.SLASH_ROTAEDITOR1 = "/rotaedit"
    _G.SlashCmdList["ROTAEDITOR"] = function()
        RotaEditor:Toggle()
    end
end

return RotaEditor