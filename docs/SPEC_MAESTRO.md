# SPEC_MAESTRO.md — Sistema Multi-Agente: Addon de Rotación/CDs (WoW 3.3.5a Custom Server)

## 1. ROL DEL ORQUESTADOR Y REGLAS DE COORDINACIÓN
Sos el **Principal Systems Architect y Orquestador** de un proyecto de addon para World of Warcraft 3.3.5a (Interface 30300) en el servidor custom Whitemane ("Rebuffed").
Tu trabajo es coordinar subagentes especializados (A1–A11), hacer cumplir los contratos técnicos de la Sección 3, mantener actualizado el archivo `PROJECT_STATE.md` y bloquear el avance de cualquier fase si no supera su Gate de validación (tests offline en Lua 5.1 + validación en cliente cuando aplique).

### Reglas Operativas del Orquestador
1. **Contrato Primero:** Ningún agente escribe código funcional antes de que `CONTRATO_V1` y `API_MATRIX.md` (Fase 0) estén cerrados.
2. **Evidencia sobre Suposición:** Todo uso de la API de WoW debe estar respaldado por `API_MATRIX.md` o marcado explícitamente como `NO_VERIFICADO`.
3. **Verificación Offline Obligatoria:** Todo código entregado por A2–A9 debe pasar `lua5.1 tools/test_runner.lua` y `luacheck` sin errores antes de dar por completada la subtarea.
4. **Reporte por Subagente:** Al terminar su turno, cada subagente debe actualizar su sección o devolver: (a) Archivos creados/modificados, (b) Tests ejecutados y output, (c) Consumo de memoria/GC medido, (d) Asunciones o bloqueos.
5. **Decisiones por Defecto Pre-aprobadas (no bloquear salvo incompatibilidad técnica):**
   - **Specs iniciales:** DK (Frost PvE, Unholy PvE/PvP), Paladín (Retribution PvE/PvP), Guerrero (Fury PvE, Arms PvP).
   - **Conversión Lua <-> Bloques:** Aceptado el esquema de 3 niveles de fidelidad (A/B/C).
   - **Keybinds en icono:** Soportado y opcional (apagado por defecto).

---

## 2. OBJETIVO Y RESTRICCIONES DURAS DE INGENIERÍA (LUA 5.1 / 3.3.5a)

### Objetivo Funcional
Construir un ecosistema de addons modular y ultraliviano que sugiera la **próxima habilidad en GCD** (`mainIcon`) y la **próxima acción fuera de GCD / On-Next-Swing** (`offIcon`) para **Death Knight, Paladín y Guerrero**:
- Evalúa nivel, talentos activos (Dual Spec), glifos y hechizos aprendidos en el Spellbook.
- Resuelve hechizos por **Nombre -> ID de rango máximo en el libro de hechizos**, con una tabla de **Overrides manuales de SpellID** por si el servidor custom modifica IDs o nombres.
- Implementa una interfaz dual estilo **TinkerCAD (Código <-> Bloques)** cargada bajo demanda (`LoadOnDemand`):
  1. Importa/exporta un subconjunto del DSL de Ovale (listas de prioridad).
  2. Importa/exporta código Lua estructurado (`if <cond> then return "KEY" end`).
  3. Permite editar la rotación visualmente mediante un árbol de bloques interactivo y previsualizar el resultado con un simulador de estado integrado.

### Restricciones Duras (Inquebrantables)
1. **Entorno:** Lua 5.1 estricto, TOC `Interface: 30300`. Prohibido usar APIs de expansiones posteriores (`C_Timer`, `C_Spell`, `C_Aura`, `BackdropTemplate`, ni `UnitAura` por ID directo).
2. **Zero-Allocation en Combate (0 KB/s de basura en régimen):**
   - **PROHIBIDO** crear tablas (`{}`), concatenar strings variables (`..`) o instanciar closures (`function() ... end`) dentro de `OnUpdate`, `COMBAT_LOG_EVENT_UNFILTERED`, `UNIT_AURA` o dentro de `evaluator(state)`.
   - Usar tablas estáticas pre-alocadas al inicio y reutilizarlas con `wipe(t)`.
   - No empaquetar `...` en tablas `{...}` en eventos frecuentes; usar asignación local directa `local a, b, c = ...` o `select()`.
3. **Presupuesto de Performance:**
   - `RotaCore` en reposo: `< 300 KB` de RAM.
   - Tiempo de evaluación por pasada: `< 0.3 ms`.
   - Basura en régimen medida con `collectgarbage("count")` en 1000 pasadas del evaluador: `0.0 KB`.
4. **Cero Automatización Protegida:** El addon jamás llama a `CastSpellByName`, `CastSpellByID`, `UseAction` ni modifica frames seguros en combate. Solo sugiere visualmente.
5. **Sandbox de Usuario:** Todo código Lua pegado por el usuario se compila una única vez al cargar/guardar con `loadstring` + `setfenv(fn, sandboxWhitelist)`. En combate se ejecuta el closure pre-compilado dentro de `pcall`. Si una regla arroja error 3 veces, se desactiva esa regla (`disabled_by_error = true`), se avisa una vez en el chat y el resto de la rotación sigue funcionando.
6. **Código 100% Propio:** Prohibido copiar código de Ovale, WeakAuras o Ace3 (por licencias y peso). Cero librerías externas obligatorias.

### Arquitectura de Directorios
- `RotaProbe/`       -> Addon de reconocimiento para Fase 0 (genera datos para `API_MATRIX.md`).
- `RotaCore/`        -> Motor de estado, resolver de hechizos, compilador IR->Closures, sandbox, HUD de iconos, perfiles.
- `RotaClass_DK/`    -> Proveedor de estado de DK (runas, grace period, Desolation) + presets Frost/Unholy.
- `RotaClass_PAL/`   -> Proveedor de estado de Paladín (sellos, juicios, Art of War, FCFS) + presets Ret.
- `RotaClass_WAR/`   -> Proveedor de estado de Guerrero (stances, rage, next-swing queue) + presets Fury/Arms.
- `RotaEditor/`      -> Addon `LoadOnDemand`: Editor de bloques, editor de código, overrides de IDs y simulador.
- `tools/`           -> `wowmock.lua`, `test_runner.lua`, `luacheckrc`, scripts de empaquetado.

---

## 3. CONTRATOS COMPARTIDOS (IR + CATÁLOGO + API)

### 3.1 Representación Intermedia (`RotationIR`)
Toda fuente (Bloques, Lua, Ovale) compila hacia y desde esta estructura de datos pura:

```lua
RotationIR = {
  meta = {
    id = "dk_unholy_pve",
    name = "Unholy DK PvE",
    class = "DEATHKNIGHT", -- "DEATHKNIGHT" | "PALADIN" | "WARRIOR"
    spec = "Unholy",
    schema = 1,
    interface = 30300,
  },
  spells = {
    -- alias = { name = "Nombre Canónico", defaultId = 49909, overrideId = nil, matchById = false }
    IT   = { name = "Icy Touch",      defaultId = 49909, overrideId = nil, matchById = false },
    PS   = { name = "Plague Strike",  defaultId = 49921, overrideId = nil, matchById = false },
    BS   = { name = "Blood Strike",   defaultId = 49930, overrideId = nil, matchById = false },
    SS   = { name = "Scourge Strike", defaultId = 55271, overrideId = nil, matchById = false },
    BT   = { name = "Blood Tap",      defaultId = 45529, overrideId = nil, matchById = false },
    PEST = { name = "Pestilence",     defaultId = 50842, overrideId = nil, matchById = false },
  },
  vars = {
    pestMargin = 2.0,
    rpDumpMin  = 80,
    aoeTargets = 3,
  },
  sequences = {
    opener = { enabled = true, resetOnCombatEnd = true, timeout = 10, steps = { "IT", "PS", "BS", "SS" } }
  },
  lists = {
    main = { -- Lista de prioridad en GCD (primera regla verdadera gana)
      {
        id = "r1",
        enabled = true,
        type = "block", -- "block" (Niveles A/B) | "customLua" (Nivel C)
        action = "IT",
        note = "Mantener Frost Fever",
        when = {
          op = "cmp", cmp = "<",
          l = { op = "call", fn = "debuff.remaining", args = { "Frost Fever", "target", true } },
          r = { op = "var", name = "pestMargin" }
        }
      },
      {
        id = "r2_custom",
        enabled = true,
        type = "customLua",
        action = "BT",
        code = "if state.runes.bloodReady == 0 and state.debuffRemaining('Frost Fever') < 3.0 then return 'BT' end",
        note = "Regla Lua opaca (Nivel C)"
      }
    },
    off = { -- Lista fuera de GCD o On-Next-Swing (Blood Tap, Horn of Winter, Heroic Strike, Cleave, Interrupts)
    }
  }
}
