-- RotaCore/Options.lua — Blizzard Interface Options Panel & Integrated Tutorial (WoW 3.3.5a)
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Options = {
    panel = nil,
}
RotaCore.Options = Options

--- Creates and registers the Interface Options panel (ESC -> Interfaz -> AddOns -> Rota Suite).
function Options:Init()
    if self.panel or not _G.CreateFrame then return end

    local panel = _G.CreateFrame("Frame", "RotaCoreOptionsPanel", _G.UIParent)
    panel.name = "Rota Suite"

    -- Boton de texto simple (mismo estilo que los de arriba)
    local function MakeButton(name, text, width, point, rel, relPoint, x, y, onClick)
        local b = _G.CreateFrame("Button", name, panel)
        b:SetSize(width, 24)
        b:SetPoint(point, rel, relPoint, x, y)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetFontObject(GameFontNormal)
        t:SetPoint("CENTER", b, "CENTER", 0, 0)
        t:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end

    -- Desplegable con etiqueta. options = { {text, value}, ... }; getCur() -> value; apply(value)
    local function MakeDropDown(name, labelText, point, rel, relPoint, x, y, options, getCur, apply)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetFontObject(GameFontNormal)
        label:SetPoint(point, rel, relPoint, x, y)
        label:SetText(labelText)
        local dd = _G.CreateFrame("Frame", name, panel, "UIDropDownMenuTemplate")
        dd:SetPoint("LEFT", label, "RIGHT", 4, -2)
        if _G.UIDropDownMenu_SetWidth then _G.UIDropDownMenu_SetWidth(dd, 150) end
        local function Show(val)
            for _, opt in ipairs(options) do
                if opt.value == val then
                    if _G.UIDropDownMenu_SetSelectedValue then _G.UIDropDownMenu_SetSelectedValue(dd, val) end
                    if _G.UIDropDownMenu_SetText then _G.UIDropDownMenu_SetText(dd, opt.text) end
                    if dd.text and dd.text.SetText then dd.text:SetText(opt.text) end
                end
            end
        end
        local function Select(val)
            apply(val)
            Show(val)
        end
        if _G.UIDropDownMenu_Initialize then
            _G.UIDropDownMenu_Initialize(dd, function(_, level)
                for _, opt in ipairs(options) do
                    local info = _G.UIDropDownMenu_CreateInfo and _G.UIDropDownMenu_CreateInfo() or {}
                    info.text = opt.text
                    info.value = opt.value
                    info.func = function() Select(opt.value) end
                    info.checked = (opt.value == getCur())
                    if _G.UIDropDownMenu_AddButton then _G.UIDropDownMenu_AddButton(info, level) end
                end
            end)
        end
        Show(getCur())
        dd.Select = Select
        return label, dd
    end

    local function Settings()
        if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
        if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
        return _G.RotaCoreDB.settings
    end

    -- 1. Header & Version
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetFontObject(GameFontNormal)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("|cFFFFFF00Rota Suite|r — v" .. (RotaCore.version or "1.0.0"))

    local subTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    subTitle:SetFontObject(GameFontNormal)
    subTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subTitle:SetText("|cFF888888Rotación con reglas editables. Minimapa: click abre este panel, click derecho el editor.|r")

    -- 2. Status Label (Active Profile & Class)
    local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusText:SetFontObject(GameFontNormal)
    statusText:SetPoint("TOPLEFT", subTitle, "BOTTOMLEFT", 0, -12)
    panel.statusText = statusText

    local function RefreshStatus()
        local p = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
        local pName = (p and p.meta and p.meta.name) or "Ninguno"
        local burstState = (_G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.burstMode ~= false) and "ON" or "OFF"
        local st = _G.RotaCoreDB and _G.RotaCoreDB.settings or {}
        local aoeState = "AUTO"
        if st.aoeMode == "ON" or (st.aoeMode == true and st.autoAoE == false) then aoeState = "ON"
        elseif st.aoeMode == "OFF" or st.aoeMode == false then aoeState = "OFF" end
        statusText:SetFontObject(GameFontNormal)
        statusText:SetText(string.format("Rotación activa: |cFF00FF00%s|r   ·   Burst: |cFFFFFFFF%s|r   ·   AoE: |cFFFFFFFF%s|r",
            pName, burstState, aoeState))
    end
    RefreshStatus()

    -- 3. Action Buttons Bar
    -- Button: Open Editor
    local editBtn = _G.CreateFrame("Button", "RotaOptionsEditBtn", panel)
    editBtn:SetSize(140, 24)
    editBtn:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -12)
    local editBtnText = editBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editBtnText:SetFontObject(GameFontNormal)
    editBtnText:SetPoint("CENTER", editBtn, "CENTER", 0, 0)
    editBtnText:SetText("Editar rotación")
    editBtn:SetScript("OnClick", function()
        if not _G.RotaEditor and _G.LoadAddOn then
            _G.LoadAddOn("RotaEditor")
        end
        if _G.RotaEditor and _G.RotaEditor.Toggle then
            _G.RotaEditor:Toggle()
        end
    end)

    -- Button: Run Probe Scan
    local scanBtn = _G.CreateFrame("Button", "RotaOptionsScanBtn", panel)
    scanBtn:SetSize(140, 24)
    scanBtn:SetPoint("LEFT", editBtn, "RIGHT", 10, 0)
    local scanBtnText = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scanBtnText:SetFontObject(GameFontNormal)
    scanBtnText:SetPoint("CENTER", scanBtn, "CENTER", 0, 0)
    scanBtnText:SetText("Escanear hechizos")
    scanBtn:SetScript("OnClick", function()
        if not _G.RotaProbe and _G.LoadAddOn then
            _G.LoadAddOn("RotaProbe")
        end
        if _G.RotaProbe and _G.RotaProbe.RunScan then
            _G.RotaProbe:RunScan()
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaProbe]|r Escaneo de talentos y hechizos completado.")
            end
        end
    end)

    -- Button: Open Probe Window
    local probeBtn = _G.CreateFrame("Button", "RotaOptionsProbeBtn", panel)
    probeBtn:SetSize(140, 24)
    probeBtn:SetPoint("LEFT", scanBtn, "RIGHT", 10, 0)
    local probeBtnText = probeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    probeBtnText:SetFontObject(GameFontNormal)
    probeBtnText:SetPoint("CENTER", probeBtn, "CENTER", 0, 0)
    probeBtnText:SetText("Datos del servidor")
    probeBtn:SetScript("OnClick", function()
        if not _G.RotaProbe and _G.LoadAddOn then
            _G.LoadAddOn("RotaProbe")
        end
        if _G.RotaProbe and _G.RotaProbe.Show then
            _G.RotaProbe:Show()
        end
    end)

    -- Button: Reset HUD
    local resetBtn = _G.CreateFrame("Button", "RotaOptionsResetBtn", panel)
    resetBtn:SetSize(100, 24)
    resetBtn:SetPoint("LEFT", probeBtn, "RIGHT", 10, 0)
    local resetBtnText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetBtnText:SetFontObject(GameFontNormal)
    resetBtnText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetBtnText:SetText("Volver al centro")
    resetBtn:SetScript("OnClick", function()
        if RotaCore.UI and RotaCore.UI.ResetPosition then
            RotaCore.UI:ResetPosition()
        elseif RotaCore.UI and RotaCore.UI.hudFrame then
            RotaCore.UI.hudFrame:ClearAllPoints()
            RotaCore.UI.hudFrame:SetPoint("CENTER", _G.UIParent or RotaCore.UI.hudFrame, "CENTER", 0, -120)
            if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Posición del HUD restablecida.")
            end
        end
    end)

    -- Fila de herramientas: los mismos comandos de /rc
    local function Cmd(text) return function() if RotaCore.HandleSlashCmd then RotaCore.HandleSlashCmd(text) end end end
    local traceBtn = MakeButton("RotaOptionsTraceBtn", "Ver enemigos (10 s)", 110, "TOPLEFT", editBtn, "BOTTOMLEFT", 0, -6,
        Cmd("aoetrace 10"))
    local debugBtn = MakeButton("RotaOptionsDebugBtn", "Modo debug", 70, "LEFT", traceBtn, "RIGHT", 10, 0, Cmd("debug"))
    local apiBtn = MakeButton("RotaOptionsApiBtn", "Probar API", 80, "LEFT", debugBtn, "RIGHT", 10, 0, Cmd("apitest"))
    local platesBtn = MakeButton("RotaOptionsPlatesBtn", "Probar placas", 120, "LEFT", apiBtn, "RIGHT", 10, 0,
        Cmd("apitest plates"))

    -- 4. Checkbox Settings
    -- Minimap Checkbox
    local minimapCb = _G.CreateFrame("CheckButton", "RotaOptionsMinimapCb", panel)
    minimapCb:SetSize(20, 20)
    minimapCb:SetPoint("TOPLEFT", traceBtn, "BOTTOMLEFT", 0, -10)
    local minimapCbLabel = minimapCb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    minimapCbLabel:SetFontObject(GameFontNormal)
    minimapCbLabel:SetPoint("LEFT", minimapCb, "RIGHT", 6, 0)
    minimapCbLabel:SetText("Botón en el minimapa")

    local showMini = true
    if _G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.showMinimap ~= nil then
        showMini = _G.RotaCoreDB.settings.showMinimap
    end
    minimapCb:SetChecked(showMini)
    minimapCb:SetScript("OnClick", function(cb)
        local val = cb:GetChecked() and true or false
        if RotaCore.Minimap and RotaCore.Minimap.SetShown then
            RotaCore.Minimap:SetShown(val)
        end
    end)

    -- Lock HUD Checkbox
    local lockCb = _G.CreateFrame("CheckButton", "RotaOptionsLockCb", panel)
    lockCb:SetSize(20, 20)
    lockCb:SetPoint("TOPLEFT", minimapCb, "BOTTOMLEFT", 0, -6)
    local lockCbLabel = lockCb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lockCbLabel:SetFontObject(GameFontNormal)
    lockCbLabel:SetPoint("LEFT", lockCb, "RIGHT", 6, 0)
    lockCbLabel:SetText("Bloquear los iconos (destildar para moverlos con el mouse)")

    local locked = true
    if _G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.locked ~= nil then
        locked = _G.RotaCoreDB.settings.locked
    end
    lockCb:SetChecked(locked)
    lockCb:SetScript("OnClick", function(cb)
        local val = cb:GetChecked() and true or false
        if _G.RotaCoreDB and _G.RotaCoreDB.settings then
            _G.RotaCoreDB.settings.locked = val
        end
        if RotaCore.UI and RotaCore.UI.SetLocked then
            RotaCore.UI:SetLocked(val)
        elseif RotaCore.UI and RotaCore.UI.hudFrame then
            RotaCore.UI.hudFrame:EnableMouse(not val)
        end
    end)

    -- 5. Build Selector & AoE / Burst Controls
    local buildLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    buildLabel:SetFontObject(GameFontNormal)
    buildLabel:SetPoint("TOPLEFT", lockCb, "BOTTOMLEFT", 0, -10)
    buildLabel:SetText("Build:")

    local function GetBuildOptions()
        local playerClass = "DEATHKNIGHT"
        if _G.UnitClass then
            local _, cls = _G.UnitClass("player")
            if cls then playerClass = cls end
        end
        local mod = RotaCore.GetClassModule and RotaCore:GetClassModule(playerClass)
        local builds = (mod and mod.builds) or (RotaCore.GetClassBuilds and RotaCore:GetClassBuilds(playerClass))
        if builds and #builds > 0 then
            local opts = {}
            for _, b in ipairs(builds) do
                local label = (b.key == "auto") and (b.name .. " (Talentos)") or b.name
                table.insert(opts, { text = label, value = b.key })
            end
            return opts
        end
        return {
            { text = "Autodetectar", value = "auto" },
        }
    end

    local buildDropDown = _G.CreateFrame("Frame", "RotaOptionsBuildDropDown", panel, "UIDropDownMenuTemplate")
    buildDropDown:SetPoint("LEFT", buildLabel, "RIGHT", 4, -2)
    if _G.UIDropDownMenu_SetWidth then
        _G.UIDropDownMenu_SetWidth(buildDropDown, 160)
    end

    local function ApplyBuildSelection(val)
        if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
        if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end

        local playerClass = "DEATHKNIGHT"
        if _G.UnitClass then
            local _, cls = _G.UnitClass("player")
            if cls then playerClass = cls end
        end

        local charName = (_G.UnitName and _G.UnitName("player")) or "Unknown"
        local realmName = (_G.GetRealmName and _G.GetRealmName()) or "Unknown"
        local charKey = charName .. " - " .. realmName

        _G.RotaCoreDB.charBuilds = _G.RotaCoreDB.charBuilds or {}
        _G.RotaCoreDB.classBuilds = _G.RotaCoreDB.classBuilds or {}
        _G.RotaCoreDB.charBuilds[charKey] = val
        _G.RotaCoreDB.classBuilds[playerClass] = val
        _G.RotaCoreDB.settings.selectedBuild = val

        if _G.UIDropDownMenu_SetSelectedValue then
            _G.UIDropDownMenu_SetSelectedValue(buildDropDown, val)
        end
        local currentOptions = GetBuildOptions()
        for _, opt in ipairs(currentOptions) do
            if opt.value == val then
                if _G.UIDropDownMenu_SetText then
                    _G.UIDropDownMenu_SetText(buildDropDown, opt.text)
                end
                if buildDropDown.text and buildDropDown.text.SetText then
                    buildDropDown.text:SetText(opt.text)
                end
                break
            end
        end

        local mod = RotaCore.GetClassModule and RotaCore:GetClassModule(playerClass)
        if val == "auto" then
            if mod and mod.detectBuild then
                pcall(mod.detectBuild)
            elseif playerClass == "DEATHKNIGHT" and _G.RotaClass_DK and _G.RotaClass_DK.DetectBuild then
                pcall(function() _G.RotaClass_DK:DetectBuild() end)
            elseif playerClass == "WARRIOR" and _G.RotaClass_WAR and _G.RotaClass_WAR.DetectSpec then
                pcall(function() _G.RotaClass_WAR:DetectSpec() end)
            elseif playerClass == "PALADIN" and RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
                RotaCore.Profiles:SetActiveProfile("pal_retribution_pve")
            end
        else
            local foundPreset = nil
            local builds = (mod and mod.builds) or (RotaCore.GetClassBuilds and RotaCore:GetClassBuilds(playerClass))
            if builds then
                for _, b in ipairs(builds) do
                    if b.key == val and b.preset then
                        foundPreset = b.preset
                        break
                    end
                end
            end
            if foundPreset and RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
                RotaCore.Profiles:SetActiveProfile(foundPreset)
            elseif mod and mod.detectBuild then
                pcall(mod.detectBuild)
            elseif playerClass == "DEATHKNIGHT" and _G.RotaClass_DK and _G.RotaClass_DK.DetectBuild then
                _G.RotaClass_DK:DetectBuild()
            elseif playerClass == "WARRIOR" and _G.RotaClass_WAR and _G.RotaClass_WAR.DetectSpec then
                _G.RotaClass_WAR:DetectSpec()
            elseif playerClass == "PALADIN" and RotaCore.Profiles and RotaCore.Profiles.SetActiveProfile then
                RotaCore.Profiles:SetActiveProfile("pal_retribution_pve")
            end
        end
        if RotaCore.UI and RotaCore.UI.UpdateButtonStates then
            RotaCore.UI:UpdateButtonStates()
        end
        RefreshStatus()
    end
    buildDropDown.ApplyBuildSelection = ApplyBuildSelection

    local function InitBuildDropDown(_, level)
        local currentOptions = GetBuildOptions()
        for _, opt in ipairs(currentOptions) do
            local info = _G.UIDropDownMenu_CreateInfo and _G.UIDropDownMenu_CreateInfo() or {}
            info.text = opt.text
            info.value = opt.value
            info.func = function()
                ApplyBuildSelection(opt.value)
            end
            local current = RotaCore:GetSelectedBuild()
            info.checked = (opt.value == current)
            if _G.UIDropDownMenu_AddButton then
                _G.UIDropDownMenu_AddButton(info, level)
            end
        end
    end
    if _G.UIDropDownMenu_Initialize then
        _G.UIDropDownMenu_Initialize(buildDropDown, InitBuildDropDown)
    end
    panel.buildDropDown = buildDropDown

    -- Texto del desplegable con la build actual
    for _, opt in ipairs(GetBuildOptions()) do
        if opt.value == RotaCore:GetSelectedBuild() and _G.UIDropDownMenu_SetText then
            _G.UIDropDownMenu_SetText(buildDropDown, opt.text)
        end
    end

    -- Modo AoE: AUTO (detecta enemigos) / ON (forzado) / OFF  (= /rc aoe)
    local function CurAoE()
        local st = Settings()
        if st.aoeMode == "ON" or (st.aoeMode == true and st.autoAoE == false) then return "ON" end
        if st.aoeMode == "OFF" or st.aoeMode == false then return "OFF" end
        return "AUTO"
    end
    local aoeLabel, aoeModeDropDown = MakeDropDown("RotaOptionsAoEModeDropDown", "Modo AoE:", "TOPLEFT", buildLabel,
        "BOTTOMLEFT", 0, -14, {
            { text = "AUTO (detecta enemigos)", value = "AUTO" },
            { text = "ON (forzado)", value = "ON" },
            { text = "OFF", value = "OFF" },
        }, CurAoE, function(val)
            local st = Settings()
            st.aoeMode = val
            st.autoAoE = (val == "AUTO")
            if RotaCore.State and RotaCore.State.data and val == "OFF" then RotaCore.State.data.aoeMode = false end
            if RotaCore.UI and RotaCore.UI.UpdateButtonStates then RotaCore.UI:UpdateButtonStates() end
            RefreshStatus()
        end)
    panel.aoeModeDropDown = aoeModeDropDown

    -- Burst Mode Checkbox
    local burstCb = _G.CreateFrame("CheckButton", "RotaOptionsBurstCb", panel)
    burstCb:SetSize(20, 20)
    burstCb:SetPoint("TOPLEFT", aoeLabel, "BOTTOMLEFT", 0, -12)
    local burstCbLabel = burstCb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    burstCbLabel:SetFontObject(GameFontNormal)
    burstCbLabel:SetPoint("LEFT", burstCb, "RIGHT", 6, 0)
    burstCbLabel:SetText("Usar cooldowns largos (Gárgola, Unbreakable Armor, pociones, racial)")

    local burstVal = true
    if _G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.burstMode ~= nil then
        burstVal = _G.RotaCoreDB.settings.burstMode
    end
    burstCb:SetChecked(burstVal)
    burstCb:SetScript("OnClick", function(cb)
        local val = cb:GetChecked() and true or false
        if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
        if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
        _G.RotaCoreDB.settings.burstMode = val
        if RotaCore.State and RotaCore.State.data then
            RotaCore.State.data.burstMode = val
        end
        if RotaCore.UI and RotaCore.UI.UpdateButtonStates then
            RotaCore.UI:UpdateButtonStates()
        end
        RefreshStatus()
    end)
    panel.burstCb = burstCb

    -- Modo aprendizaje: muestra el motivo de cada sugerencia debajo del icono
    local learningCb = _G.CreateFrame("CheckButton", "RotaOptionsLearningCb", panel)
    learningCb:SetSize(20, 20)
    learningCb:SetPoint("TOPLEFT", burstCb, "BOTTOMLEFT", 0, -6)
    local learningCbLabel = learningCb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    learningCbLabel:SetFontObject(GameFontNormal)
    learningCbLabel:SetPoint("LEFT", learningCb, "RIGHT", 6, 0)
    learningCbLabel:SetText("Mostrar por qué sugiere cada habilidad")
    learningCb:SetChecked(_G.RotaCoreDB and _G.RotaCoreDB.settings and _G.RotaCoreDB.settings.learningMode == true)
    learningCb:SetScript("OnClick", function(cb)
        if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
        if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
        _G.RotaCoreDB.settings.learningMode = cb:GetChecked() and true or false
    end)
    panel.learningCb = learningCb

    -- Burst Display Mode Dropdown (SIDE, INLINE, CORNER)
    local burstModeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    burstModeLabel:SetFontObject(GameFontNormal)
    burstModeLabel:SetPoint("TOPLEFT", learningCb, "BOTTOMLEFT", 0, -10)
    burstModeLabel:SetText("Icono de cooldowns:")

    local BURST_MODE_OPTIONS = {
        { text = "Al costado", value = "SIDE" },
        { text = "Dentro del icono grande", value = "INLINE" },
        { text = "Esquina chica", value = "CORNER" },
    }

    local burstModeDropDown = _G.CreateFrame("Frame", "RotaOptionsBurstModeDropDown", panel, "UIDropDownMenuTemplate")
    burstModeDropDown:SetPoint("LEFT", burstModeLabel, "RIGHT", 4, -2)
    if _G.UIDropDownMenu_SetWidth then
        _G.UIDropDownMenu_SetWidth(burstModeDropDown, 180)
    end

    local function ApplyBurstModeSelection(val)
        if RotaCore.UI and RotaCore.UI.SetBurstDisplayMode then
            RotaCore.UI:SetBurstDisplayMode(val)
        else
            if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
            if not _G.RotaCoreDB.settings then _G.RotaCoreDB.settings = {} end
            _G.RotaCoreDB.burstDisplayMode = val
            _G.RotaCoreDB.settings.burstDisplayMode = val
        end
        if _G.UIDropDownMenu_SetSelectedValue then
            _G.UIDropDownMenu_SetSelectedValue(burstModeDropDown, val)
        end
        for _, opt in ipairs(BURST_MODE_OPTIONS) do
            if opt.value == val then
                if _G.UIDropDownMenu_SetText then
                    _G.UIDropDownMenu_SetText(burstModeDropDown, opt.text)
                end
                if burstModeDropDown.text and burstModeDropDown.text.SetText then
                    burstModeDropDown.text:SetText(opt.text)
                end
                break
            end
        end
        RefreshStatus()
    end

    local function InitBurstModeDropDown(_, level)
        for _, opt in ipairs(BURST_MODE_OPTIONS) do
            local info = _G.UIDropDownMenu_CreateInfo and _G.UIDropDownMenu_CreateInfo() or {}
            info.text = opt.text
            info.value = opt.value
            info.func = function() ApplyBurstModeSelection(opt.value) end
            local db = _G.RotaCoreDB
            local cur = (db and (db.burstDisplayMode or (db.settings and db.settings.burstDisplayMode))) or "SIDE"
            info.checked = (opt.value == cur)
            if _G.UIDropDownMenu_AddButton then
                _G.UIDropDownMenu_AddButton(info, level)
            end
        end
    end
    if _G.UIDropDownMenu_Initialize then
        _G.UIDropDownMenu_Initialize(burstModeDropDown, InitBurstModeDropDown)
    end
    do
        local db = _G.RotaCoreDB
        local cur = (db and (db.burstDisplayMode or (db.settings and db.settings.burstDisplayMode))) or "SIDE"
        for _, opt in ipairs(BURST_MODE_OPTIONS) do
            if opt.value == cur and _G.UIDropDownMenu_SetText then _G.UIDropDownMenu_SetText(burstModeDropDown, opt.text) end
        end
    end
    panel.burstModeDropDown = burstModeDropDown

    -- Corner Scale Selector (10% to 50%)
    local scaleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetFontObject(GameFontNormal)
    scaleLabel:SetPoint("LEFT", burstModeDropDown, "RIGHT", 10, 2)
    local db = _G.RotaCoreDB
    local dbScale = (db and (db.cornerScale or (db.settings and db.settings.cornerScale))) or 0.45
    scaleLabel:SetText(string.format("Tamaño de la esquina: %d%%", math.floor(dbScale * 100 + 0.5)))
    panel.scaleLabel = scaleLabel

    local scaleBtnMinus = _G.CreateFrame("Button", "RotaOptionsScaleMinusBtn", panel)
    scaleBtnMinus:SetSize(22, 20)
    scaleBtnMinus:SetPoint("LEFT", scaleLabel, "RIGHT", 6, 0)
    local minusTxt = scaleBtnMinus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minusTxt:SetFontObject(GameFontNormal)
    minusTxt:SetPoint("CENTER", scaleBtnMinus, "CENTER", 0, 0)
    minusTxt:SetText("[-]")
    scaleBtnMinus:SetScript("OnClick", function()
        local curDb = _G.RotaCoreDB
        local curScale = (curDb and (curDb.cornerScale or (curDb.settings and curDb.settings.cornerScale))) or 0.45
        local nextScale = math.max(0.10, curScale - 0.05)
        if RotaCore.UI and RotaCore.UI.SetCornerScale then
            RotaCore.UI:SetCornerScale(nextScale)
        end
        scaleLabel:SetText(string.format("Tamaño de la esquina: %d%%", math.floor(nextScale * 100 + 0.5)))
    end)

    local scaleBtnPlus = _G.CreateFrame("Button", "RotaOptionsScalePlusBtn", panel)
    scaleBtnPlus:SetSize(22, 20)
    scaleBtnPlus:SetPoint("LEFT", scaleBtnMinus, "RIGHT", 4, 0)
    local plusTxt = scaleBtnPlus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plusTxt:SetFontObject(GameFontNormal)
    plusTxt:SetPoint("CENTER", scaleBtnPlus, "CENTER", 0, 0)
    plusTxt:SetText("[+]")
    scaleBtnPlus:SetScript("OnClick", function()
        local curDb = _G.RotaCoreDB
        local curScale = (curDb and (curDb.cornerScale or (curDb.settings and curDb.settings.cornerScale))) or 0.45
        local nextScale = math.min(0.50, curScale + 0.05)
        if RotaCore.UI and RotaCore.UI.SetCornerScale then
            RotaCore.UI:SetCornerScale(nextScale)
        end
        scaleLabel:SetText(string.format("Tamaño de la esquina: %d%%", math.floor(nextScale * 100 + 0.5)))
    end)

    -- Fusion AoE (= /rc aoefusion)
    local fusionLabel, fusionDropDown = MakeDropDown("RotaOptionsAoEFusionDropDown", "Contar enemigos con:", "TOPLEFT", burstModeLabel,
        "BOTTOMLEFT", 0, -18, {
            { text = "Placas o combate (recomendado)", value = "union" },
            { text = "Placas y combate", value = "confirm" },
            { text = "Solo placas de nombre", value = "plates" },
            { text = "Solo registro de combate", value = "classic" },
        }, function() return (_G.RotaCoreDB and _G.RotaCoreDB.aoeFusion) or "union" end, function(val)
            if not _G.RotaCoreDB then _G.RotaCoreDB = {} end
            _G.RotaCoreDB.aoeFusion = val
        end)

    -- Migracion a rotaciones legibles (docs/PLAN_V2.md): grabar situaciones reales y comparar con la v1
    local function MakeCheck(name, text, rel, y, getCur, apply)
        local cb = _G.CreateFrame("CheckButton", name, panel)
        cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", rel, "BOTTOMLEFT", 0, y)
        local label = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetFontObject(GameFontNormal)
        label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        label:SetText(text)
        cb.label = label
        cb:SetChecked(getCur())
        cb:SetScript("OnClick", function(b) apply(b:GetChecked() and true or false) end)
        return cb
    end

    local v2Header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    v2Header:SetFontObject(GameFontNormal)
    v2Header:SetPoint("TOPLEFT", fusionLabel, "BOTTOMLEFT", 0, -18)
    v2Header:SetText("|cFFFFFF00GRABAR PARA LOS TESTS|r")

    local captureCb = MakeCheck("RotaOptionsCaptureCb", "Grabar situaciones reales en combate",
        v2Header, -6, function() return Settings().captureReal == true end,
        function(val) Settings().captureReal = val end)
    local compareCb = MakeCheck("RotaOptionsCompareCb", "Comparar con la rotación vieja",
        captureCb, -4, function() return Settings().compareV1 == true end,
        function(val) Settings().compareV1 = val end)

    -- Id del preset activo como build (la version v1 de un preset migrado cuenta como el preset nuevo)
    local function ActiveMigratedId()
        local ir = RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile()
        local id = ir and ir.meta and (ir.meta.v1Of or ir.meta.id)
        local p = id and RotaCore.Profiles.presets[id]
        return (p and p.meta and p.meta.v1) and id or nil
    end
    local useV1Cb = MakeCheck("RotaOptionsUseV1Cb", "Usar la rotación vieja en esta build", compareCb, -4,
        function()
            local id = ActiveMigratedId()
            return id ~= nil and Settings().useV1 ~= nil and Settings().useV1[id] == true
        end,
        function(val)
            local id = ActiveMigratedId()
            if not id then return end
            Settings().useV1 = Settings().useV1 or {}
            Settings().useV1[id] = val or nil
            RotaCore.Profiles:SetActiveProfile(id)
        end)

    local v2Status = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    v2Status:SetFontObject(GameFontNormal)
    v2Status:SetPoint("TOPLEFT", useV1Cb, "BOTTOMLEFT", 0, -6)
    local function RefreshV2()
        local id = ActiveMigratedId()
        useV1Cb:SetChecked(id ~= nil and Settings().useV1 ~= nil and Settings().useV1[id] == true)
        if useV1Cb.label then
            useV1Cb.label:SetText(id and "Usar la rotación vieja (v1) en esta build"
                or "|cFF888888Usar la rotación vieja (esta build no tiene)|r")
        end
        local c, d = 0, 0
        if RotaCore.Snapshot then c, d = RotaCore.Snapshot:Counts() end
        v2Status:SetText(string.format("Guardado: %d situaciones, %d diferencias", c, d))
    end
    local clearBtn = MakeButton("RotaOptionsClearCaptureBtn", "Borrar", 70, "LEFT", v2Status, "RIGHT", 8, 0, function()
        if RotaCore.Snapshot then RotaCore.Snapshot:Clear() end
        RefreshV2()
    end)
    panel.captureCb, panel.compareCb, panel.useV1Cb, panel.v2Status, panel.RefreshV2 = captureCb, compareCb, useV1Cb,
        v2Status, RefreshV2
    RefreshV2()

    -- Guia rapida
    local tutorialHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tutorialHeader:SetFontObject(GameFontNormal)
    tutorialHeader:SetPoint("TOPLEFT", v2Status, "BOTTOMLEFT", 0, -18)
    tutorialHeader:SetText("|cFFFFFF00GUÍA RÁPIDA|r")

    local tutorialContent = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tutorialContent:SetFontObject(GameFontNormal)
    tutorialContent:SetPoint("TOPLEFT", tutorialHeader, "BOTTOMLEFT", 0, -8)
    tutorialContent:SetJustifyH("LEFT")
    tutorialContent:SetText([[• Icono grande: próxima habilidad en GCD. Icono chico: cooldowns y fuera de GCD.
• Espiral + segundos sobre el icono: todavía no, ya viene (runas / cooldown).
• Mini-barra: Build, AoE y Burst. Click derecho en Burst cambia SIDE / INLINE / CORNER.
• Editor (/rc edit): tus cambios quedan como rotación custom de este PJ; "Restaurar" vuelve al preset.
• Todo lo de este panel también está en /rc (escribí /rc para la lista).]])

    -- Pestanas: todo en este panel (el minimapa y Interfaz > AddOns abren el mismo). Cada pagina es una lista de
    -- controles que se muestran u ocultan; la primera fila de cada pagina se ancla debajo de las pestanas.
    local pagesTop = _G.CreateFrame("Frame", nil, panel)
    pagesTop:SetSize(1, 1)
    pagesTop:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -44)
    local function Anchor(ctrl, rel, y)
        ctrl:ClearAllPoints()
        ctrl:SetPoint("TOPLEFT", rel, rel == pagesTop and "TOPLEFT" or "BOTTOMLEFT", 0, y)
    end
    -- Estilo: casillas con el cuadradito del juego y botones con borde (antes eran texto suelto)
    local function StyleCheck(cb)
        cb:SetSize(24, 24)
        if cb.SetNormalTexture then
            cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
            cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
            cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
            cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        end
    end
    local function StyleButton(b, width)
        if width then b:SetWidth(width) end
        if b.SetBackdrop then
            b:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 8, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            b:SetBackdropColor(0.15, 0.15, 0.18, 0.95)
            b:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)
            b:SetScript("OnEnter", function(f) f:SetBackdropBorderColor(1, 0.82, 0, 1) end)
            b:SetScript("OnLeave", function(f) f:SetBackdropBorderColor(0.5, 0.5, 0.55, 1) end)
        end
    end
    for _, cb in ipairs({ lockCb, minimapCb, burstCb, learningCb, captureCb, compareCb, useV1Cb }) do StyleCheck(cb) end
    for b, w in pairs({ [editBtn] = 150, [scanBtn] = 150, [probeBtn] = 150, [resetBtn] = 150, [traceBtn] = 150,
        [debugBtn] = 110, [apiBtn] = 110, [platesBtn] = 120, [clearBtn] = 80, [scaleBtnMinus] = 26, [scaleBtnPlus] = 26 }) do
        StyleButton(b, w)
    end

    -- Una linea de ayuda por pagina (gris, chica)
    local function Help(text)
        local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWidth(560)
        fs:SetText("|cFFAAAAAA" .. text .. "|r")
        return fs
    end
    local rotHelp = Help("Build: la rotación que usás (AUTO la elige por tus talentos). AoE AUTO cuenta los enemigos solo. "
        .. "Las reglas de la rotación se cambian en Editar rotación.")
    local screenHelp = Help("Para mover los iconos: destildá Bloquear y arrastralos. \"Icono de cooldowns\" elige dónde "
        .. "aparecen Gárgola, guantes, racial y demás.")
    local advHelp = Help("Para diagnosticar problemas. Para jugar no hace falta tocar nada de acá.")

    -- Rotacion
    Anchor(buildLabel, pagesTop, 0)
    Anchor(editBtn, learningCb, -14)
    Anchor(useV1Cb, editBtn, -8)
    Anchor(rotHelp, useV1Cb, -14)
    -- Pantalla
    Anchor(lockCb, pagesTop, 0)
    Anchor(minimapCb, lockCb, -6)
    Anchor(burstModeLabel, minimapCb, -14)
    Anchor(resetBtn, burstModeLabel, -20)
    Anchor(screenHelp, resetBtn, -14)
    -- Herramientas
    Anchor(advHelp, pagesTop, 0)
    Anchor(traceBtn, advHelp, -10)
    Anchor(scanBtn, traceBtn, -6)
    Anchor(fusionLabel, scanBtn, -16)
    Anchor(v2Status, compareCb, -6)

    local PAGES = {
        { title = "Rotación", items = { buildLabel, buildDropDown, aoeLabel, aoeModeDropDown, burstCb, learningCb,
            editBtn, useV1Cb, rotHelp } },
        { title = "Pantalla", items = { lockCb, minimapCb, burstModeLabel, burstModeDropDown, scaleLabel,
            scaleBtnMinus, scaleBtnPlus, resetBtn, screenHelp } },
        { title = "Avanzado", items = { advHelp, traceBtn, debugBtn, apiBtn, platesBtn, scanBtn, probeBtn, fusionLabel,
            fusionDropDown, v2Header, captureCb, compareCb, v2Status, clearBtn, tutorialHeader, tutorialContent } },
    }
    local tabButtons = {}
    local function ShowPage(index)
        for i, page in ipairs(PAGES) do
            for _, ctrl in ipairs(page.items) do
                if i == index then ctrl:Show() else ctrl:Hide() end
            end
            local t = tabButtons[i].label
            if t then t:SetText(i == index and ("|cFFFFD100[ " .. page.title .. " ]|r") or ("|cFFAAAAAA" .. page.title .. "|r")) end
        end
        Settings().optionsTab = index
        panel.currentPage = index
    end
    local prevTab
    for i, page in ipairs(PAGES) do
        local b = _G.CreateFrame("Button", "RotaOptionsTab" .. i, panel)
        b:SetSize(130, 24)
        if prevTab then b:SetPoint("LEFT", prevTab, "RIGHT", 6, 0)
        else b:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -12) end
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetFontObject(GameFontNormal)
        t:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.label = t
        StyleButton(b)
        b:SetScript("OnClick", function() ShowPage(i) end)
        tabButtons[i] = b
        prevTab = b
    end
    panel.ShowPage, panel.tabButtons = ShowPage, tabButtons
    ShowPage(Settings().optionsTab or 1)

    panel:SetScript("OnShow", function() RefreshStatus(); RefreshV2() end)

    self.panel = panel
    self.RefreshStatus = RefreshStatus
    RotaCore.optionsPanel = panel

    if _G.InterfaceOptions_AddCategory then
        _G.InterfaceOptions_AddCategory(panel)
    end
end

--- Abre este panel (lo usan el minimapa y /rc). En 3.3.5 hay que llamarlo dos veces la primera vez.
function Options:Open()
    if not self.panel then return end
    if _G.InterfaceOptionsFrame_OpenToCategory then
        _G.InterfaceOptionsFrame_OpenToCategory(self.panel)
        _G.InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
end

return Options
