-- RotaEditor/TabOverrides.lua — SpellID Overrides Manager Table with Styled Inputs (WoW 3.3.5a)
local RotaEditor = _G.RotaEditor or {}
_G.RotaEditor = RotaEditor
local RotaCore = _G.RotaCore

local TabOverrides = {
    container = nil,
    pool = nil,
    scrollChild = nil,
    scrollFrame = nil,
}
RotaEditor.TabOverrides = TabOverrides

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
    if defaultText ~= nil then eb:SetText(tostring(defaultText)) end
    return eb
end

local function InitRowFrame(f)
    f:SetSize(620, 38)
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

    f.aliasText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.aliasText:SetFontObject(GameFontNormal)
    f.aliasText:SetPoint("LEFT", f, "LEFT", 10, 0)

    f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.nameText:SetFontObject(GameFontNormal)
    f.nameText:SetPoint("LEFT", f, "LEFT", 70, 0)

    f.defaultText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.defaultText:SetFontObject(GameFontNormal)
    f.defaultText:SetPoint("LEFT", f, "LEFT", 220, 0)

    f.resolvedText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.resolvedText:SetFontObject(GameFontNormal)
    f.resolvedText:SetPoint("LEFT", f, "LEFT", 305, 0)

    -- Styled visible EditBox with backdrop for Manual Override
    f.overrideEdit = GetCreateStyledEditBox(f, 75, 22, "")
    f.overrideEdit:SetPoint("LEFT", f, "LEFT", 390, 0)
    if f.overrideEdit.SetNumeric then
        f.overrideEdit:SetNumeric(true)
    end
    if f.overrideEdit.SetMaxLetters then
        f.overrideEdit:SetMaxLetters(7)
    end

    -- Set button
    f.setBtn = GetCreateStyledButton(f, 40, 22, "Set")
    f.setBtn:SetPoint("LEFT", f.overrideEdit, "RIGHT", 6, 0)

    -- Clear button
    f.clearBtn = GetCreateStyledButton(f, 48, 22, "Clear")
    f.clearBtn:SetPoint("LEFT", f.setBtn, "RIGHT", 6, 0)
end

function TabOverrides:Init(parent)
    local container = _G.CreateFrame("Frame", "RotaEditorTabOverridesFrame", parent)
    container:SetAllPoints(parent)
    self.container = container

    -- Column Headers
    local headerFrame = _G.CreateFrame("Frame", nil, container)
    headerFrame:SetSize(620, 24)
    headerFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 16, -10)

    local hAlias = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hAlias:SetFontObject(GameFontNormal)
    hAlias:SetPoint("LEFT", headerFrame, "LEFT", 10, 0)
    hAlias:SetText("|cFFFFFF00Alias|r")

    local hName = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hName:SetFontObject(GameFontNormal)
    hName:SetPoint("LEFT", headerFrame, "LEFT", 70, 0)
    hName:SetText("|cFFFFFF00Hechizo / Habilidad|r")

    local hDef = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hDef:SetFontObject(GameFontNormal)
    hDef:SetPoint("LEFT", headerFrame, "LEFT", 220, 0)
    hDef:SetText("|cFFFFFF00Def ID|r")

    local hRes = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hRes:SetFontObject(GameFontNormal)
    hRes:SetPoint("LEFT", headerFrame, "LEFT", 305, 0)
    hRes:SetText("|cFFFFFF00Resuelto|r")

    local hOvr = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hOvr:SetFontObject(GameFontNormal)
    hOvr:SetPoint("LEFT", headerFrame, "LEFT", 390, 0)
    hOvr:SetText("|cFFFFFF00Manual Override|r")

    -- ScrollFrame & Child with mouse wheel support
    local scrollFrame = _G.CreateFrame("ScrollFrame", "RotaEditorOverridesScrollFrame", container)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -16, 12)
    if scrollFrame.EnableMouseWheel then
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
            local cur = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
            local nextVal = math.max(0, cur - (delta * 38))
            if sf.SetVerticalScroll then
                sf:SetVerticalScroll(nextVal)
            end
        end)
    end
    self.scrollFrame = scrollFrame

    local scrollChild = _G.CreateFrame("Frame", "RotaEditorOverridesScrollChild", scrollFrame)
    scrollChild:SetSize(620, 400)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    self.pool = RotaEditor.FramePool.New("Frame", scrollChild, nil, InitRowFrame)
end

function TabOverrides:Refresh()
    if not self.pool or not self.scrollChild then return end

    self.pool:ReleaseAll()

    local profile = RotaCore and RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
    local spells = profile and profile.spells or {}

    -- Deterministic sorting
    local sorted = {}
    for alias in pairs(spells) do
        table.insert(sorted, alias)
    end
    table.sort(sorted)

    local SpellsEngine = RotaCore and RotaCore.Spells

    for i, alias in ipairs(sorted) do
        local s = spells[alias]
        local row = self.pool:Acquire()
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, - (i - 1) * 40)

        row.aliasText:SetFontObject(GameFontNormal)
        row.aliasText:SetText(string.format("|cFF00FFFF%s|r", alias))
        row.nameText:SetFontObject(GameFontNormal)
        local shortName = s.name or alias
        if #shortName > 18 then shortName = shortName:sub(1, 16) .. ".." end
        row.nameText:SetText(shortName)
        row.defaultText:SetFontObject(GameFontNormal)
        row.defaultText:SetText(tostring(s.defaultId or 0))

        local resolvedId
        if SpellsEngine and SpellsEngine.ResolveID then
            resolvedId = SpellsEngine:ResolveID(alias)
        else
            resolvedId = s.overrideId or s.defaultId or 0
        end
        row.resolvedText:SetFontObject(GameFontNormal)
        row.resolvedText:SetText(string.format("|cFF00FF00%d|r", resolvedId))

        if s.overrideId then
            row.overrideEdit:SetText(tostring(s.overrideId))
        else
            row.overrideEdit:SetText(tostring(s.defaultId or ""))
        end

        local function SaveOverride()
            local text = row.overrideEdit:GetText()
            local newId = tonumber(text)
            if newId and newId > 0 then
                s.overrideId = newId
                if SpellsEngine and SpellsEngine.SetOverride then
                    SpellsEngine:SetOverride(alias, newId)
                end
                self:Refresh()
            end
        end

        row.setBtn:SetScript("OnClick", SaveOverride)
        row.overrideEdit:SetScript("OnEnterPressed", function(eb)
            if eb.ClearFocus then eb:ClearFocus() end
            SaveOverride()
        end)

        row.clearBtn:SetScript("OnClick", function()
            s.overrideId = nil
            if SpellsEngine and SpellsEngine.SetOverride then
                SpellsEngine:SetOverride(alias, nil)
            end
            self:Refresh()
        end)
    end

    self.scrollChild:SetHeight(math.max(400, #sorted * 40 + 20))
end

return TabOverrides