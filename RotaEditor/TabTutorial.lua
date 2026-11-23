-- RotaEditor/TabTutorial.lua — Pestana Ayuda del editor: temas en castellano llano
local RotaEditor = _G.RotaEditor or {}
_G.RotaEditor = RotaEditor

local TabTutorial = {
    container = nil,
    currentTopic = 1,
    contentFontString = nil,
    scrollFrame = nil,
    topicButtons = {},
}
RotaEditor.TabTutorial = TabTutorial

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

local TOPICS = {
    {
        title = "Qué hace",
        text = [[|cFFFFFF00QUÉ HACE ROTA SUITE|r

• |cFFFFFFFFIcono grande:|r la próxima habilidad que conviene usar (las que pasan por el GCD).
• |cFFFFFFFFIcono chico:|r cooldowns y habilidades fuera del GCD (Tiger's Fury, Gárgola, guantes...).
• |cFFFFFFFFEspiral y segundos sobre el icono:|r esa habilidad todavía no, pero viene (runas, energía, cooldown).
• |cFFFFFFFFMini-barra debajo:|r Build (qué rotación usás), AoE (automático / siempre / nunca) y Burst
  (usar o guardar los cooldowns largos). El botón de la derecha abre las opciones.

La rotación de cada build es una lista de |cFFFFFFFFreglas|r. Se leen de arriba hacia abajo y la primera
que sugiere algo gana. Las podés ver, ordenar, apagar y editar en este editor.]],
    },
    {
        title = "Reglas",
        text = [[|cFFFFFF00CÓMO SE ESCRIBE UNA REGLA|r

Cada regla es un pedacito de código. Ejemplo: Consecration solo con 40% de mana o más:

|cFF88CCFF    if ready("CONS") and mana() >= 40 then return "CONS" end|r

• |cFFFFFFFFreturn "CONS"|r: sugiere esa habilidad ("CONS" es el nombre corto del catálogo de la build).
• Si la regla no devuelve nada, se pasa a la siguiente.
• |cFFFFFFFFreturn false|r: corta la lista acá (no se mira ninguna regla más).
• |cFFFFFFFFreturn wait("CONS", 2)|r: la muestra "esperando" con la espiral.
• Para guardar un valor: |cFF88CCFFlocal m = mana()|r

|cFFFFFFFFPestaña Reglas:|r ON/OFF apaga una regla sin borrarla; ^ y v cambian el orden; Edit la abre.
|cFFFFFFFFPestaña Código:|r todas las reglas juntas como texto. "Guardar cambios" las aplica.
Lo que cambies queda como rotación |cFFFFFFFFCustom|r de este personaje; "Restaurar" vuelve a la original.]],
    },
    {
        title = "Funciones",
        text = [[|cFFFFFF00FUNCIONES PARA LAS REGLAS|r

|cFFFFFFFFHabilidades:|r ready("X") lista · known("X") la conocés · cd("X") segundos de cooldown · gcd()
|cFFFFFFFFRecursos:|r mana() en % · rage() · energy() · runic() · combo() · power() · powerPct()
|cFFFFFFFFVida:|r hp() tu vida en % · targetHP() la del objetivo en %
|cFFFFFFFFObjetivo:|r targetType() da "Undead", "Demon", "Beast", "Humanoid"... · targetBoss()
|cFFFFFFFFAuras:|r buff("Nombre") y debuff("Nombre") segundos que quedan · buffStacks / debuffStacks
           debuffAny("Nombre") debuff de cualquiera (ej. Faerie Fire de otro druida)
|cFFFFFFFFSituación:|r aoe() · enemies() · combat() · moving() · burst() · gloves()
|cFFFFFFFFOtros:|r glyph("Nombre") · talent("Nombre") · var("nombre", defecto) · say("motivo")

Cada clase suma las suyas (DK: predicción de runas como canCast(b, f, u) y runeWait("frost");
Pícaro: show("X") marca esperar energía; Druida: poolFor("X")...). El comentario arriba de cada
build en la pestaña Código dice qué datos tiene tu clase (ej. dru.rip, rog.cp, runes.bloodReady).]],
    },
    {
        title = "IDs de hechizos",
        text = [[|cFFFFFF00PESTAÑA IDs DE HECHIZOS|r

Cada habilidad del catálogo tiene un ID. Si en este servidor un hechizo tiene otro ID (el icono sale
gris o con otro nombre), escribí el ID correcto en esa fila y queda guardado para todos tus personajes.

Para buscar el ID: en Opciones > Avanzado, "Escanear hechizos" revisa tu libro de hechizos y guarda
los IDs reales del servidor.]],
    },
}

function TabTutorial:SelectTopic(idx)
    self.currentTopic = idx
    local data = TOPICS[idx]
    if not data then return end

    if self.contentFontString then
        self.contentFontString:SetFontObject(GameFontNormal)
        self.contentFontString:SetText(data.text)
    end

    if self.scrollFrame and self.scrollFrame.SetVerticalScroll then
        self.scrollFrame:SetVerticalScroll(0)
    end

    for i, btn in ipairs(self.topicButtons) do
        if btn then
            if i == idx then
                btn.isSelected = true
                if btn.text then btn.text:SetText("|cFFFFFF00" .. TOPICS[i].title .. "|r") end
                if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(1, 0.82, 0, 1) end
            else
                btn.isSelected = false
                if btn.text then btn.text:SetText(TOPICS[i].title) end
                if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(0.5, 0.5, 0.55, 1) end
            end
        end
    end
end

function TabTutorial:Init(parent)
    local container = _G.CreateFrame("Frame", "RotaEditorTabTutorialFrame", parent)
    container:SetAllPoints(parent)
    self.container = container

    -- Header Title
    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFontObject(GameFontNormal)
    title:SetPoint("TOPLEFT", container, "TOPLEFT", 16, -10)
    title:SetText("|cFFFFFF00Ayuda|r")

    -- Navigation Bar (Topic Buttons: 118px each + 8px gap)
    self.topicButtons = {}
    local startX = 16
    for i, tData in ipairs(TOPICS) do
        local btn = GetCreateStyledButton(container, 118, 24, tData.title)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", startX, -34)

        local topicIdx = i
        btn:SetScript("OnClick", function()
            self:SelectTopic(topicIdx)
        end)

        self.topicButtons[i] = btn
        startX = startX + 126
    end

    -- Scrollable Content Box
    local scrollFrame = _G.CreateFrame("ScrollFrame", "RotaEditorTutScrollFrame", container)
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 16, -66)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -16, 14)

    if scrollFrame.SetBackdrop then
        scrollFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        if scrollFrame.SetBackdropColor then scrollFrame:SetBackdropColor(0.04, 0.04, 0.06, 0.95) end
        if scrollFrame.SetBackdropBorderColor then scrollFrame:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9) end
    end

    if scrollFrame.EnableMouseWheel then
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
            local cur = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
            local nextVal = math.max(0, cur - (delta * 30))
            if sf.SetVerticalScroll then
                sf:SetVerticalScroll(nextVal)
            end
        end)
    end
    self.scrollFrame = scrollFrame

    local scrollChild = _G.CreateFrame("Frame", "RotaEditorTutScrollChild", scrollFrame)
    scrollChild:SetSize(610, 600)
    scrollFrame:SetScrollChild(scrollChild)

    local text = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFontObject(GameFontNormal)
    text:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 12, -12)
    text:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -12, -12)
    if text.SetJustifyH then text:SetJustifyH("LEFT") end
    if text.SetJustifyV then text:SetJustifyV("TOP") end
    self.contentFontString = text

    self:SelectTopic(1)
end

return TabTutorial