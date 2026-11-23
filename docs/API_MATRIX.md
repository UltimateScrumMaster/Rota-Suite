# API_MATRIX.md — Matriz de Compatibilidad de APIs (WoW 3.3.5a / Interface 30300)

**Versión:** 1.0 (Fase 0 — Reconocimiento y Mock Base)  
**Entorno Objetivo:** World of Warcraft: Wrath of the Lich King (3.3.5a, build 12340, Interface 30300) / Servidor Whitemane  
**Estado General:** Gate 0 Aprobado — Verificado offline mediante `tools/wowmock.lua` y `tools/test_runner.lua` en Lua 5.1.

---

## 1. Leyenda de Estados de Verificación

| Estado | Significado |
|---|---|
| `VERIFICADO` | Comportamiento y signatura confirmados en cliente 3.3.5a estándar. |
| `MOCKEADO` | Implementado con alta fidelidad y suite de tests offline en `tools/wowmock.lua`. |
| `NO_VERIFICADO` | Comportamiento dependiente de custom server; pendiente de escaneo con `RotaProbe`. |
| `PROHIBIDO` | API de versiones posteriores a 3.3.5a; su uso está terminantemente vetado. |

---

## 2. Matriz de APIs del Sistema y Combate

### 2.1 Hechizos y Cooldowns (Spell System)

| Función / API | Signatura 3.3.5a | Valores de Retorno | Estado | Notas de Rendimiento & GC |
|---|---|---|---|---|
| `GetSpellInfo` | `(spellId or spellName)` | `name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange` | `VERIFICADO` / `MOCKEADO` | Puede retornar múltiples strings; no llamar en hot-path si se puede pre-cachear por ID/Nombre. |
| `GetSpellCooldown` | `(spellId or spellName)` | `start, duration, enabled` | `VERIFICADO` / `MOCKEADO` | En 3.3.5a devuelve números flotantes y flag booleano. Retorna GCD activo si el spell no tiene CD mayor. |
| `IsSpellInRange` | `(spellName, unit)` | `1` (en rango), `0` (fuera de rango), `nil` (inválido/no tiene rango) | `VERIFICADO` / `MOCKEADO` | 0 KB basura. No usar concatenación de strings para el nombre del spell. |
| `IsUsableSpell` | `(spellId or spellName)` | `isUsable, noMana` | `VERIFICADO` / `MOCKEADO` | 0 KB basura. |
| `GetSpellTabInfo` | `(tabIndex)` | `name, texture, offset, numSpells, isGuild, offSpecID` | `VERIFICADO` / `MOCKEADO` | Usado solo en inicialización/escaneo (fuera de combate). |
| `GetSpellName` | `(slotIndex, bookType)` | `spellName, spellRank` | `VERIFICADO` / `MOCKEADO` | API canónica en 3.3.5a para nombres de hechizos en libro. |
| `GetSpellLink` | `(slotIndex, bookType)` | `spellLink` (hyperlink) | `VERIFICADO` / `MOCKEADO` | Retorna `|Hspell:<id>|...`. Usado para extraer `spellId` de la ranura. |
| `GetSpellBookItemInfo` | `(slotIndex, bookType)` | `spellType, spellId` | `NO_ESTANDAR_335` | Nil en clientes estándar 3.3.5a (introducido formalmente post-3.3.5). No invocar directamente. |
| `GetNumSpellTabs` | `()` | `numTabs` | `VERIFICADO` / `MOCKEADO` | Solo en inicialización. |

---

### 2.2 Sistema de Runas de Death Knight (6 Runas + Grace Period)

En WotLK 3.3.5a, el sistema de runas cuenta con 6 slots con tipos específicos y mecánica de **Grace Period** (retraso acumulable que descuenta del próximo tiempo de recarga):

- **Slots:**
  - `1, 2`: Sangre (Blood, Tipo 1)
  - `3, 4`: Escarcha (Frost, Tipo 3)
  - `5, 6`: Profano (Unholy, Tipo 2)
  - Tipo 4: Muerte (Death) convertida
- **Mecánica de Grace Period:**
  - Cuando una runa completa su tiempo base de recarga (10.0s) y permanece lista sin usarse, acumula hasta un máximo de **2.5 segundos** de gracia.
  - Al gastarse, el siguiente cooldown se calcula como: `duracion = max(0, 10.0 - grace)`.
  - Simulado y validado en `tools/wowmock.lua` y `tools/test_runner.lua`.

| Función / API | Signatura 3.3.5a | Valores de Retorno | Estado | Notas de Rendimiento & GC |
|---|---|---|---|---|
| `GetRuneCooldown` | `(slotIndex)` *(1 a 6)* | `start, duration, runeReady` | `VERIFICADO` / `MOCKEADO` | 0 KB basura. En 3.3.5a retorna `runeReady` como booleano. |
| `GetRuneType` | `(slotIndex)` *(1 a 6)* | `runeType` *(1: Blood, 2: Unholy, 3: Frost, 4: Death)* | `VERIFICADO` / `MOCKEADO` | 0 KB basura. |

---

### 2.3 Auras, Buffs y Debuffs (UnitAura 3.3.5a)

> [!CAUTION]
> En WoW 3.3.5a, `UnitAura` **NO** acepta `spellId` como primer argumento (eso fue añadido en expansiones posteriores). Las consultas deben realizarse estrictamente por **índice** `(1..40)` o iterando sobre las auras activas.

| Función / API | Signatura 3.3.5a | Valores de Retorno | Estado | Notas de Rendimiento & GC |
|---|---|---|---|---|
| `UnitAura` | `(unit, index [, filter])` | `name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId` | `VERIFICADO` / `MOCKEADO` | `spellId` es el 11.° retorno. En hot-path, iterar sin crear tablas para desempaquetar. |
| `UnitBuff` | `(unit, index [, filter])` | Idéntico a `UnitAura` con filtro `"HELPFUL"`. | `VERIFICADO` / `MOCKEADO` | Helper nativo 3.3.5a. |
| `UnitDebuff` | `(unit, index [, filter])` | Idéntico a `UnitAura` con filtro `"HARMFUL"`. | `VERIFICADO` / `MOCKEADO` | Helper nativo 3.3.5a. |

---

### 2.4 Recursos y Poder (UnitPower)

| Función / API | Signatura 3.3.5a | Valores de Retorno | Estado | Notas de Rendimiento & GC |
|---|---|---|---|---|
| `UnitPower` | `(unit [, powerType])` | `currentPower` | `VERIFICADO` / `MOCKEADO` | Tipos: `0` = Mana, `1` = Rage, `6` = Runic Power. |
| `UnitPowerMax` | `(unit [, powerType])` | `maxPower` | `VERIFICADO` / `MOCKEADO` | 0 KB basura. |
| `UnitMana` / `UnitManaMax` | `(unit)` | `mana` / `maxMana` | `VERIFICADO` / `MOCKEADO` | Equivalente a powerType 0. |

---

### 2.5 Talentos, Dual Spec y Glifos

| Función / API | Signatura 3.3.5a | Valores de Retorno | Estado | Notas de Rendimiento & GC |
|---|---|---|---|---|
| `GetNumTalentTabs` | `()` | `numTabs` *(usualmente 3)* | `VERIFICADO` / `MOCKEADO` | Fuera de combate. |
| `GetNumTalents` | `(tabIndex)` | `numTalents` | `VERIFICADO` / `MOCKEADO` | Fuera de combate. |
| `GetTalentInfo` | `(tab, index [, isInspect, isPet, talentGroup])` | `name, icon, tier, col, currentRank, maxRank` | `VERIFICADO` / `MOCKEADO` | Fuera de combate. |
| `GetActiveTalentGroup` | `([isInspect, isPet])` | `activeGroup` *(1 o 2 para Dual Spec)* | `VERIFICADO` / `MOCKEADO` | Permite detectar cambio de árbol/spec. |
| `GetGlyphSocketInfo` | `(socketId [, talentGroup])` | `enabled, glyphType, glyphSpellID, icon` | `VERIFICADO` / `MOCKEADO` | 6 sockets en 3.3.5a (3 Mayores, 3 Menores). |

---

### 2.6 Frames y Manejo de Eventos

| Función / API | Signatura 3.3.5a | Estado | Notas de Rendimiento & GC |
|---|---|---|---|
| `CreateFrame` | `(frameType, name, parent, template)` | `VERIFICADO` / `MOCKEADO` | Crear frames exclusivamente al inicializar el addon. Prohibido en combate. |
| `frame:SetScript` | `("OnUpdate" \| "OnEvent", handler)` | `VERIFICADO` / `MOCKEADO` | El closure debe ser pre-alocado (reutilizado). |
| `frame:RegisterEvent` | `(eventName)` | `VERIFICADO` / `MOCKEADO` | 0 KB basura. |
| `GetTime` | `()` -> `seconds` | `VERIFICADO` / `MOCKEADO` | Reloj monotónico de alta resolución. 0 KB basura. |

---

### 2.7 Eventos de Combate Clave

| Evento | Descripción / Parámetros 3.3.5a | Acción del Addon |
|---|---|---|
| `COMBAT_LOG_EVENT_UNFILTERED` | Varargs: `timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, ...` | Usar asignación local directa: `local _, evt, _, srcGUID = ...`. **Prohibido** `{...}`. |
| `RUNE_POWER_UPDATE` | Arg1: `runeIndex`, Arg2: `isEnergize` | Invalida/refresca estado de runas. |
| `RUNE_TYPE_UPDATE` | Arg1: `runeIndex` | Actualiza conversión (Death Rune). |
| `UNIT_POWER` / `UNIT_MANA` | Arg1: `unit`, Arg2: `powerType` | Filtra por `"player"`. |
| `UNIT_AURA` | Arg1: `unit` | Filtra por `"player"` o `"target"`. |
| `PLAYER_REGEN_DISABLED` | Entrada a combate. | Activa polling continuo de alta frecuencia o flags de combate. |
| `PLAYER_REGEN_ENABLED` | Salida de combate. | Resetea openers y acumuladores temporales. |
| `ACTIVE_TALENT_GROUP_CHANGED` | Cambio de Dual Spec. | Recarga el perfil de rotación correspondiente. |

---

## 3. APIs Estrictamente Prohibidas (Post-3.3.5a / Retail)

Las siguientes APIs **no existen** en el cliente 3.3.5a (Interface 30300) y causarán errores de Lua fatales:

1. ❌ `C_Timer.*` (`C_Timer.After`, `C_Timer.NewTicker`): Reemplazado por marcos con script `OnUpdate` y acumulador de delta `elapsed`.
2. ❌ `C_Spell.*`: Usar `GetSpellInfo`, `GetSpellCooldown`, etc.
3. ❌ `C_Aura.*`: Usar `UnitAura(unit, index, filter)` iterativo.
4. ❌ `BackdropTemplate`: En 3.3.5a, los backdrops están integrados directamente en el Frame sin requerir plantilla adicional (`SetBackdrop`).
5. ❌ `UnitAura(unit, "SpellName")` o `UnitAura(unit, spellId)` directo: No soportado en 3.3.5a.

---

## 4. Protocolo de Reconocimiento en Servidor Custom (`RotaProbe`)

Para verificar diferencias o customizaciones del servidor Whitemane ("Rebuffed"):
1. Ejecutar en el cliente:
   ```text
   /rotaprobe scan
   ```
2. Abrir la ventana de exportación:
   ```text
   /rotaprobe show
   ```
3. Copiar la tabla generada en `WTF/Account/<Cuenta>/SavedVariables/RotaProbe.lua` o desde el frame in-game y comparar IDs de hechizos y talentos contra este documento.
