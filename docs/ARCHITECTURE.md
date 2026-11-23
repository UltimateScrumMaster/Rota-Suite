# Arquitectura del Sistema — Addon Rota Suite (WoW 3.3.5a)

## 1. Visión General
El ecosistema **Rota Suite** es un sistema modular de rotaciones y cooldowns diseñado específicamente para **World of Warcraft: Wrath of the Lich King (3.3.5a, build 12340, Interface 30300)**. Proporciona sugerencias visuales en tiempo real para la próxima habilidad en **Global Cooldown (GCD)** y la próxima acción **fuera de GCD u On-Next-Swing**, con cero impacto en la tasa de refresco (FPS) y cero generación de basura en memoria durante combate (**0 KB/s garbage**).

```
 +-----------------------------------------------------------------------+
 |                              RotaCore                                 |
 |  +--------------------+  +------------------+  +-------------------+  |
 |  |    State Engine    |  |  Spell Catalog   |  |   IR Compiler     |  |
 |  |  (Static Snapshot) |  |   & Overrides    |  |  (Native Closures)|  |
 |  +--------------------+  +------------------+  +-------------------+  |
 |  +--------------------+  +------------------+  +-------------------+  |
 |  |  Dual HUD (GCD/Off)|  | Profile Manager  |  |  Sandbox (pcall)  |  |
 |  +--------------------+  +------------------+  +-------------------+  |
 +-----------------------------------------------------------------------+
        ^                         ^                          ^
        |                         |                          |
 +---------------+       +------------------+       +------------------+
 | RotaClass_DK  |       |  RotaClass_PAL   |       |  RotaClass_WAR   |
 | 6 Runes/Grace |       |   FCFS Engine    |       | GCD / Next-Swing |
 | Presets IR    |       |   Presets IR     |       |   Presets IR     |
 +---------------+       +------------------+       +------------------+
                                  |
                                  v (LoadOnDemand: /rc edit)
                         +------------------+
                         |    RotaEditor    |
                         | FramePool (Recyc)|
                         | Tab 1: Bloques   |
                         | Tab 2: Código    |
                         | Tab 3: Overrides |
                         | Tab 4: Ayuda     |
                         +------------------+
```

---

## 2. Componentes y Módulos

### 2.1 RotaCore
El núcleo del addon. Contiene:
- **`State.lua`**: Snapshot estático de recursos, auras y tiempo. Se ejecuta una única tabla pre-alocada en memoria `stateData`, actualizada a 20 Hz sin instanciar tablas ni closures.
- **`Spells.lua`**: Catálogo de hechizos con resolución de 6 niveles (Manual Override > IR Override > MatchByID > Highest Learned Spellbook Rank > Default ID > Passthrough).
- **`Compiler.lua`**: Compilador de `RotationIR` a closures nativos de Lua 5.1.
- **`Sandbox.lua`**: Aislamiento seguro de código de usuario mediante `setfenv` y `pcall`. Desactiva automáticamente cualquier regla que falle 3 veces en combate.
- **`CodeGen.lua`**: Serializador canónico bidireccional desde `RotationIR` a código Lua estructurado.
- **`ParserLua.lua`**: Parser recursivo descendente con soporte para expresiones booleanas (Niveles A y B) y bloques opacos (`customLua` Nivel C).
- **`UI.lua`**: Marcos HUD visuales de alta respuesta (`mainIcon` y `offIcon`) con throttling a 20 Hz.
- **`Profiles.lua`**: Gestor de perfiles y persistencia con compatibilidad nativa para Dual Spec (`ACTIVE_TALENT_GROUP_CHANGED`).

### 2.2 Módulos de Clase (`RotaClass_*`)
Cada clase cuenta con su propio módulo desacoplado que registra proveedores de estado y presets IR:
- **`RotaClass_DK`**: Seguimiento de 6 runas con cálculo dinámico de hasta 2.5s de Grace Period, reserva de runas Blood para Pestilence y mantenimiento de Desolation.
- **`RotaClass_PAL`**: Motor de prioridad FCFS (First Come First Served), detección de sellos activos, chequeo de "The Art of War" para Exorcism instantáneo y umbral execute (<= 20% HP) para Hammer of Wrath.
- **`RotaClass_WAR`**: Separación estricta de lista principal en GCD y lista secundaria On-Next-Swing con verificación de `IsCurrentSpell` (Heroic Strike / Cleave) y umbrales de Rage.

### 2.3 RotaEditor (LoadOnDemand)
Módulo visual interactivo con directiva `LoadOnDemand: 1` para no ocupar memoria en combate hasta que el usuario lo solicite con `/rc edit`:
- **`FramePool.lua`**: Sistema de reciclaje de frames con cero fugas de memoria.
- **Pestaña 1 (Bloques)**: Reordenamiento visual (^/v), toggling de reglas y edición jerárquica.
- **Pestaña 2 (Código)**: las reglas como texto Lua; Guardar cambios / Recargar.
- **Pestaña 3 (Overrides)**: Tabla editable de sobreescritura manual de SpellIDs para servidores custom.
- **Pestaña 4 (Ayuda)**: cómo funciona, cómo escribir reglas y funciones disponibles.

### 2.4 RotaProbe
Herramienta de diagnóstico de Fase 0 que extrae el árbol de talentos, spellbook e información de APIs del servidor para generar `API_MATRIX.md`.

---

## 3. Contratos Técnicos

### 3.1 Zero-Allocation en Hot-Path
En régimen de combate, las funciones invocadas en `OnUpdate` o durante la evaluación de rotación tienen prohibido:
- Crear nuevas tablas `{}`.
- Concatenar strings variables `a .. b`.
- Crear closures anónimos `function() ... end`.
- Empaquetar varargs `{ ... }`.

### 3.2 Representación Intermedia (`RotationIR`)
Toda rotación se almacena en una estructura pura de datos:
```lua
RotationIR = {
  meta = { id = "spec_id", name = "Display Name", class = "CLASS", spec = "Spec", schema = 1, interface = 30300 },
  spells = { ALIAS = { name = "Spell Name", defaultId = 1234, overrideId = nil, matchById = false } },
  vars = { varName = 50 },
  sequences = { opener = { enabled = true, resetOnCombatEnd = true, timeout = 10, steps = { "A", "B" } } },
  lists = {
    main = { { id = "r1", enabled = true, type = "block", action = "A", when = AST_NODE } },
    off  = { { id = "r2", enabled = true, type = "block", action = "B", when = AST_NODE } },
  }
}
```
