-- RotaCore/Glyphs.lua — Glifos que cambian un poco la rotacion de una build (toggles por personaje)
--
-- Una build declara sus glifos en el preset:
--   glyphs = { army = { name = "Glyph of Army of the Dead", desc = "Que cambia en la rotacion" } }
-- y las reglas preguntan glyphOn("army"): el glifo esta puesto (deteccion automatica) y el jugador no lo apago.
-- El "apagado" se guarda con una huella de los talentos: vale hasta que el personaje cambia de talentos (otra
-- distribucion de puntos o el otro talento dual). No se borra con el evento de talentos porque ese evento tambien
-- salta al loguear. Glifos que cambian mucho la rotacion no van aca: son otra build.
local RotaCore = _G.RotaCore or {}
_G.RotaCore = RotaCore

local Glyphs = {}
RotaCore.Glyphs = Glyphs

local function DB()
    local db = _G.RotaCoreDB
    if not db then return nil end
    db.charGlyphOff = db.charGlyphOff or {}
    return db
end

-- Tabla de "apagados" de este personaje: [talento dual][clave del glifo] = puntos de talentos con los que se apago.
-- Es por personaje y no por build (el glifo esta en el personaje) y por talento dual: cambiar de spec no lo borra.
local function CharTable(create)
    local db = DB()
    local key = RotaCore.GetCharKey and RotaCore:GetCharKey()
    if not db or not key then return nil end
    local t = db.charGlyphOff[key]
    if not t and create then
        t = {}
        db.charGlyphOff[key] = t
    end
    return t
end

--- Talento dual activo y puntos por arbol ("0/19/52")
function Glyphs:TalentPoints()
    local group = (_G.GetActiveTalentGroup and _G.GetActiveTalentGroup()) or 1
    local a, b, c = 0, 0, 0
    if _G.GetTalentTabInfo then
        a = select(3, _G.GetTalentTabInfo(1)) or 0
        b = select(3, _G.GetTalentTabInfo(2)) or 0
        c = select(3, _G.GetTalentTabInfo(3)) or 0
    end
    return group, string.format("%d/%d/%d", a, b, c), a + b + c
end

--- Llamado al escanear talentos y glifos (eventos, nunca por tick). Guarda la huella y borra los apagados de
--- otra distribucion de talentos de este mismo talento dual, avisando una vez por chat.
function Glyphs:Refresh()
    self:RefreshDetected()
    local group, points, total = self:TalentPoints()
    -- Al loguear los talentos pueden no estar cargados todavia (0 puntos): no vencer nada con esa huella
    if total == 0 then return end
    self.group, self.hash = group, points
    local t = CharTable(false)
    self.charOff = t and t[group]
    if not self.charOff then return end
    for gkey, savedHash in pairs(self.charOff) do
        if type(savedHash) ~= "string" then
            self.charOff[gkey] = nil -- formato viejo: se descarta
        elseif savedHash ~= points then
            self.charOff[gkey] = nil
            local def = self:FindDef(gkey)
            if def and _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
                _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RotaCore]|r Cambiaste de talentos: " .. def.name
                    .. " vuelve a estar activo en la rotación (si lo tenés puesto).")
            end
        end
    end
end

--- Definicion de un glifo en cualquier build registrada (para el aviso de vencimiento)
function Glyphs:FindDef(gkey)
    for _, p in pairs((RotaCore.Profiles and RotaCore.Profiles.presets) or {}) do
        if p.glyphs and p.glyphs[gkey] then return p.glyphs[gkey] end
    end
    return nil
end

-- Prefijo de los glifos en cada idioma del cliente. Un cliente en espanol puede tener glifos nuevos sin traducir
-- ("Glyph of ..."), asi que se prueban los dos siempre.
local PREFIXES = { "glyph of ", "glifo de ", "glifo del ", "glifo de la " }

--- El glifo esta puesto. Se reconoce por:
---   1. ID del hechizo del glifo (def.ids), sirve en cualquier idioma;
---   2. nombre en ingles (def.name);
---   3. prefijo de glifo en ingles o espanol + nombre del hechizo (def.spell) traducido por el propio cliente,
---      ej. "Glifo de Ejército de los muertos" o "Glyph of Army of the Dead".
--- Crea strings: se usa al escanear (eventos) y en Opciones, nunca por tick (las reglas leen self.detected).
function Glyphs:Detected(def)
    local g = RotaCore.State and RotaCore.State.data and RotaCore.State.data.glyphs
    if not g or not def then return false end
    if g[def.name] then return true end
    for _, id in ipairs(def.ids or {}) do
        if g[id] then return true end
    end
    local spellName = def.spell and _G.GetSpellInfo and _G.GetSpellInfo(def.spell)
    if not spellName then return false end
    local wanted = string.lower(spellName)
    for name in pairs(g) do
        if type(name) == "string" then
            local lower = string.lower(name)
            for _, prefix in ipairs(PREFIXES) do
                if lower == prefix .. wanted then return true end
            end
        end
    end
    return false
end

--- Recalcula que glifos de las builds registradas estan puestos (al escanear glifos, nunca por tick)
function Glyphs:RefreshDetected()
    local d = self.detected or {}
    for k in pairs(d) do d[k] = nil end
    for _, p in pairs((RotaCore.Profiles and RotaCore.Profiles.presets) or {}) do
        for gkey, def in pairs(p.glyphs or {}) do
            if d[gkey] == nil or d[gkey] == false then d[gkey] = self:Detected(def) end
        end
    end
    self.detected = d
end

--- El jugador lo apago (vale para este personaje y estos talentos)
function Glyphs:IsOff(_, gkey)
    local t = self.charOff
    return (t and self.hash and t[gkey] == self.hash) and true or false
end

--- Para las reglas (por tick, sin crear nada): la build declara el glifo, esta puesto y no lo apagaron
function Glyphs:On(ir, gkey)
    if not (ir and ir.glyphs and ir.glyphs[gkey]) then return false end
    return (self.detected and self.detected[gkey]) and not self:IsOff(ir, gkey) or false
end

--- Prender / apagar un glifo (desde Opciones); vale para todas las builds del personaje en este talento dual
function Glyphs:SetOff(_, gkey, off)
    if not self.hash then
        local group, points = self:TalentPoints()
        self.group, self.hash = group, points
    end
    local t = CharTable(true)
    if not t then return end
    t[self.group] = t[self.group] or {}
    self.charOff = t[self.group]
    self.charOff[gkey] = off and self.hash or nil
end

if RotaCore.Sandbox and RotaCore.Sandbox.AddHelper then
    --- el glifo de la build (clave de preset.glyphs) esta puesto y el jugador no lo apago en Opciones
    RotaCore.Sandbox:AddHelper("glyphOn", function(gkey)
        return Glyphs:On(RotaCore.Profiles and RotaCore.Profiles:GetActiveProfile(), gkey)
    end)
end

return Glyphs
