# Especificaciones de Clase & Rotaciones — Rota Suite (WoW 3.3.5a)

## 1. Caballero de la Muerte (Death Knight — RotaClass_DK)

### Mecánicas Soportadas
- **6 Runes Engine:** Seguimiento individual de slots 1 a 6 (Blood, Frost, Unholy, Death).
- **Rune Grace Period:** Acumulación dinámica de hasta 2.5 segundos cuando una runa completa su recarga y espera sin usarse, reduciendo el siguiente cooldown hasta a 7.5s.
- **Reserva de Runas para Pestilence:** Bloqueo preventivo de Blood Strike cuando las enfermedades (`Frost Fever` y `Blood Plague`) expiran dentro de `pestMargin` (3.0s por defecto) para garantizar disponibilidad de runa para `Pestilence`.
- **Mantenimiento de Desolation:** Detección de caída de buff `Desolation` y sugerencia de `Blood Tap` off-GCD -> `Blood Strike` para renovarlo de inmediato.

### Presets Incluidos
1. **Unholy DK PvE (`dk_unholy_pve`):**
   - Opener: `IT` -> `PS` -> `BS` -> `SS` -> `BS` -> `DC`.
   - Prioridad: Mantener enfermedades (`IT`/`PS`) > `PEST` refresh > Mantenimiento `Desolation` > `SS` > `DC` dump (RP >= 80) > `HOW` filler.
   - Off-GCD: `GARG` (Summon Gargoyle en opener), `BT` (Blood Tap de emergencia).
2. **Frost DK PvE (`dk_frost_pve`):**
   - Prioridad: Mantener enfermedades > `Obliterate` (con Killing Machine o runas disponibles) > `Frost Strike` (Killing Machine o dump de RP) > `Howling Blast` (con proc Freezing Fog/Rime).
   - Off-GCD: `Unbreakable Armor`, `Blood Tap`.

---

## 2. Paladín (Paladin — RotaClass_PAL)

### Mecánicas Soportadas
- **Sistema FCFS (First Come First Served):** Cola de prioridad estricta para Retribution 3.3.5a.
- **Chequeo de Sellos:** Verificación automática de buff de sello activo (`Seal of Vengeance`, `Seal of Corruption`, `Seal of Command`, etc.). Si ningún sello está activo, se prioriza su lanzamiento inmediato.
- **Proc "The Art of War":** Detección de crítico melee para instant-cast. **Exorcism solo se sugiere cuando el buff "The Art of War" está presente** (prohibido hard-castear para no reiniciar swing timer).
- **Fase Execute (Hammer of Wrath):** Detección de vida del objetivo <= 20% para habilitar `Hammer of Wrath` como máxima prioridad de daño.
- **Tipo de Criatura (Holy Wrath):** Detección de objetivos No-muertos (`Undead`) y Demonios (`Demon`).
- **Mantenimiento de Buffs:** Seguimiento de `Sacred Shield`, `Avenging Wrath`, `Divine Plea` y `Judgements of the Wise`.

### Presets Incluidos
1. **Retribution Paladin PvE (`pal_retribution_pve`):**
   - Main (GCD):
     1. Seal Check (aplica `SOV`/`SOC` si falta sello).
     2. `Hammer of Wrath` (vida objetivo <= 20%).
     3. `Judgement of Light/Wisdom` (recuperación de maná y haste).
     4. `Crusader Strike` (4.0s CD).
     5. `Divine Storm` (10.0s CD).
     6. `Consecration` (si maná >= 20%).
     7. `Exorcism` (estrictamente con proc "The Art of War").
     8. `Holy Wrath` (filler si maná >= 25%).
     9. `Sacred Shield` (renovación si restante < 2.0s).
   - Off-GCD:
     1. `Avenging Wrath` (burst de daño off-GCD).
     2. `Divine Plea` (recuperación de maná cuando maná <= 60%).
2. **Retribution Paladin PvP (`pal_retribution_pvp`):**
   - Prioridad adaptada con `Seal of Command`, mantenimiento alto de `Sacred Shield`, y control con `Judgement of Justice`, `Hammer of Justice` y `Repentance`.

---

## 3. Guerrero (Warrior — RotaClass_WAR)

### Mecánicas Soportadas
- **Seguimiento de Actitudes (Stances):** Detección de Stance 1 (Battle), Stance 2 (Defensive), Stance 3 (Berserker) mediante `GetShapeshiftForm()`.
- **Separación de Listas GCD vs On-Next-Swing:**
  - Las habilidades que consumen GCD (`Bloodthirst`, `Whirlwind`, `Mortal Strike`, `Slam`, `Execute`, `Overpower`) se evalúan en `mainIcon`.
  - Las habilidades que se aplican en el siguiente golpe blanco (`Heroic Strike`, `Cleave`) se evalúan en `offIcon`.
- **Comprobación de Hechizo en Cola (`IsCurrentSpell`):** Si `Heroic Strike` o `Cleave` ya están encolados para el próximo golpe, **no se vuelven a sugerir**, evitando spam visual y bloqueos.
- **Umbral de Ira Inteligente (`hsRageThreshold`):** `Heroic Strike` solo se sugiere si la Ira es superior a 50 (o 65 en Arms) para **nunca privar de ira** a habilidades principales como `Bloodthirst` (30 ira), `Whirlwind` (25 ira) o `Mortal Strike` (30 ira).
- **Procs Especializados:**
  - `Bloodsurge`: Hace que `Slam` sea instantáneo. Solo se sugiere `Slam` si el proc está activo.
  - `Sudden Death`: Permite usar `Execute` independientemente del porcentaje de vida del objetivo.
  - `Taste for Blood`: Habilita `Overpower` en Battle Stance al tickear `Rend`.

### Presets Incluidos
1. **Fury Warrior PvE (`war_fury_pve`):**
   - Main (GCD):
     1. `Bloodthirst` (en CD con >= 30 de Ira).
     2. `Whirlwind` (en CD con >= 25 de Ira).
     3. `Slam` (estrictamente con proc instantáneo `Bloodsurge` y >= 15 de Ira).
     4. `Execute` (cuando vida objetivo <= 20% y principales en CD).
   - Off-GCD / On-Next-Swing:
     1. `Bloodrage` (generación de ira off-GCD si ira < 20).
     2. `Death Wish` (burst de daño 20% off-GCD).
     3. `Heroic Strike` (si NO está en cola y la Ira >= 50).
     4. `Cleave` (alternativa AoE si NO está en cola e Ira >= 50).
2. **Arms Warrior PvE/PvP (`war_arms_pve`):**
   - Main (GCD):
     1. `Rend` (mantenimiento en objetivo para procs de Taste for Blood).
     2. `Overpower` (con proc `Taste for Blood` en Battle Stance).
     3. `Mortal Strike` (en CD con >= 30 de Ira).
     4. `Execute` (con proc `Sudden Death` o vida objetivo <= 20%).
     5. `Bladestorm` (burst de daño).
     6. `Slam` (filler con alta ira).
   - Off-GCD:
     1. `Heroic Strike` (si NO está en cola y la Ira >= 65).
