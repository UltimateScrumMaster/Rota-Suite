# Estado del proyecto

Addon de rotaciones para WoW 3.3.5a (Frostmourne Rebuffed, Whitemane).
Actualizar este archivo cada vez que se cambia algo.

## Versión

Actual: **1.0.0** (tag git `v1.0.0`). Desde acá todo va a 2.x: `2.0.0` cuando las rotaciones legibles estén migradas, después `2.0.x` para arreglos y `2.x.0` para cambios grandes. La versión vive en `RotaCore.version` y en el `## Version` de cada `.toc`.

Copia de los SavedVariables de la v1.0.0 en `backups/savedvariables-v1.0.0/` (fuera de git: tiene datos de personajes).

Volver a la v1.0.0 si algo de la 2.x sale mal:
1. `git checkout v1.0.0` (para ver/probar esa versión; `git checkout master` vuelve a la última).
2. `bash deploy.sh` para instalarla en el WoW.
3. Si hace falta, copiar `backups/savedvariables-v1.0.0/<cuenta>/RotaCore.lua` a `WTF/Account/<cuenta>/SavedVariables/` con el juego cerrado.

## Módulos

| Carpeta | Qué hace | Carga |
|---|---|---|
| `RotaCore` | Motor, estado, compilador de reglas, HUD, perfiles, opciones | siempre |
| `RotaClass_DK` / `_PAL` / `_WAR` / `_ROG` / `_SHA` / `_WL` / `_MAG` / `_PRI` / `_HUN` / `_DRU` | Lógica y presets por clase | siempre (solo se usa la de tu clase) |
| `RotaEditor` | Editor de bloques, código, overrides, simulador | bajo demanda (`/rc edit`) |
| `RotaProbe` | Diagnóstico de APIs y talentos | manual |

Para usar solo una clase, instalar `RotaCore` + el `RotaClass_*` de esa clase.

## Variantes de DK

| Key interna | Nombre | Badge | Preset |
|---|---|---|---|
| `frost` | Frost | `[F]` | `dk_frost_pve` |
| `unholy_morb` | UH Morb (DW) | `[UM]` | `dk_unholy_morb_pve` |
| `unholy_dw_ss` | UH Morb+SS (DW+SS) | `[UMS]` | `dk_unholy_dw_ss_pve` |
| `unholy_2h` | UH (Warcraft Tavern) | `[U]` | `dk_unholy_2h_pve` |

Las keys no se renombran para no romper `RotaCoreDB.charBuilds`.

Detección AUTO (`RotaClass_DK:DetectBuild`), por talentos:
- Howling Blast -> Frost
- sin Scourge Strike y (Nerves of Cold Steel o UH >= 40) -> UH Morb (DW)
- Scourge Strike + Nerves of Cold Steel -> UH Morb+SS (DW+SS)
- resto -> UH

## Tests

`lua5.1 tools/test_runner.lua`: 907/907 (se borraron los tests de Ovale, Simulador y menú rápido). `luacheck .`: limpio.

Referencias de la v1 (`docs/PLAN_V2.md`): `lua5.1 tools/golden.lua check` reproduce 26 presets × 200 situaciones (5200 casos, 0 diferencias). `package.sh` corre las dos cosas.
- `record [preset] [--force]`: graba `tools/golden/<preset>.lua`. No pisa una referencia existente sin `--force` (las referencias quedan congeladas).
- `import <WTF/Account/<cuenta>/SavedVariables/RotaCore.lua>`: suma lo grabado en el juego a `tools/golden/real/`.
- `tools/golden/allowed.lua`: diferencias aceptadas a propósito, con motivo.

## Historial

### 2026-11-18
- Icono oscuro: la textura del icono pasó de `BACKGROUND` a `ARTWORK` (el backdrop negro 0.7 la tapaba).
- DK: restaurado `RegisterClassModule` (sin él el botón Build no ciclaba).
- DK AUTO: decide por talentos; `GetSpellCooldown(id)` daba falsos positivos de Howling Blast.
- DK: nombres unificados de las 4 variantes; `/rc build ums` para Morb+SS.
- Quitados emojis de la UI (3.3.5 no los dibuja) y comentarios de relleno.
- Borrados prompts de otra IA, `docs/BENCHMARKS.md` y `Zone.Identifier`.
- Build por PJ: se lee solo de `RotaCoreDB.charBuilds[PJ]` (`RotaCore:GetSelectedBuild()`). `settings.selectedBuild` es de cuenta y ya no se usa para leer. PJ sin build guardada arranca en AUTO (no hereda de `classBuilds`).
- Revisión contra Warcraft Tavern WotLK (Wowhead WotLK redirige a retail, Icy Veins da 403):
  - Fury ST: Whirlwind antes que Bloodthirst.
  - Arms ST: Mortal Strike antes que Bladestorm.
  - Pícaro (Assa/Combat): coincide, sin cambios. Sutileza: Warcraft Tavern no tiene guía PvE.
- Cambios de Rebuffed relevados en `docs/REBUFFED.md` (noticia inicial + changelog).
- Paladín Retri (Warcraft Tavern + Rebuffed):
  - ST: Divine Storm > Judgement > Hammer of Wrath > Crusader Strike > Consecration (mana >= 40%) > Exorcism (Art of War) > Holy Wrath.
  - AoE: Divine Storm > Consecration (mana >= 40%) > Holy Wrath > Crusader Strike > Hammer of Wrath > Judgement > Exorcism.
  - Hand of Reckoning ya no se sugiere (va en macro); queda `state.isReckoningReady` para reglas custom.
- Arms: Mortal Strike antes que Overpower (Improved Mortal Strike +35% en Rebuffed).
- DK Unholy: sin snapshot de Gárgola en Unholy Presence ni vuelta a Blood Presence (Rebuffed recalcula la haste en cada golpe). Quitada la var `gargBackToBP`.
- Chamán nuevo (`RotaClass_SHA`), Warcraft Tavern:
  - Elemental ST: Flame Shock (caído) > Lava Burst (si FS dura el casteo) > Chain Lightning > Thunderstorm (mana < 60%) > Totem of Wrath (sin totem de fuego) > Lightning Bolt.
  - Elemental AoE: Chain Lightning > Fire Nova (con totem de fuego) > Magma Totem > Lava Burst > Lightning Bolt.
  - Elemental off: Water Shield, Flametongue fuera de combate, Elemental Mastery, Fire Elemental (Burst).
  - Enhancement: Lightning Shield > Maelstrom 5 (LB, CL en AoE) > Stormstrike > Flame Shock (caído) / Earth Shock > Magma Totem > Fire Nova > Lava Lash.
  - Enhancement off: Windfury / Flametongue fuera de combate, Shamanistic Rage (mana < 30%), Feral Spirit y Fire Elemental (Burst).
  - Restauración se trata como Elemental (no hay rotación de daño de heal).
  - AoE automático cuenta enemigos a 8 yardas del jugador: para Elemental conviene el AoE manual.

### 2026-11-19
- Brujo nuevo (`RotaClass_WL`), Warcraft Tavern:
  - Affliction: Haunt > Unstable Affliction > Corruption > Curse of Agony > Life Tap > Drain Soul (< 25%) > Shadow Bolt. AoE: Seed of Corruption.
  - Demonology: maldición > Corruption > Immolate > Soul Fire (Decimation) > Incinerate (Molten Core) > Life Tap > Shadow Bolt. AoE: Immolation Aura (en Metamorphosis) > Seed. Off: Demonic Empowerment, Metamorphosis (Burst).
  - Destruction: maldición > Immolate > Conflagrate > Chaos Bolt > Life Tap > Incinerate. AoE: Shadowfury > Seed.
  - Var `curse`: `auto` (Doom en bosses `worldboss`, Agony en el resto), `doom`, `agony`, `elements`. Affliction usa `agony` por defecto (la guía dice que Doom no conviene).
  - Life Tap: mantiene el buff de Glyph of Life Tap en combate (`glyphLifeTap = 1`) y recupera mana debajo de 15%.
  - Mascota, Infernal y Doomguard no se sugieren.
- Mago nuevo (`RotaClass_MAG`), Warcraft Tavern:
  - Arcane: Arcane Missiles con Missile Barrage a 4 stacks de Arcane Blast (3 con mana < 35%, aunque no haya proc) > Evocation (mana < 15%) > Arcane Blast. Off: Arcane Power > Presence of Mind (3+ stacks) > Icy Veins > Mirror Image.
  - Fire: Pyroblast (Hot Streak) > Living Bomb > Scorch (sin debuff de crítico propio o de brujo) > Fireball / Frostfire Bolt (var `filler`). Off: Combustion con Living Bomb recién puesta, Mirror Image.
  - Frost: Water Elemental (sin mascota) > Deep Freeze (Fingers of Frost) > Frostfire Bolt (Brain Freeze) > Frostbolt. Off: Icy Veins, Mirror Image.
  - AoE: Arcane usa var `aoeSpell` (Blizzard por defecto), Fire Flamestrike después de Hot Streak y Living Bomb, Frost Blizzard.
  - Time Warp y Mana Gem no se sugieren. La guía no cubre Ice Lance; no se sugiere.
- Sacerdote Sombras nuevo (`RotaClass_PRI`), Wowhead WotLK + Warcraft Tavern (coinciden):
  - Shadowform > SW:P (una vez, con 5 stacks de Shadow Weaving; Mind Flay lo renueva) > Vampiric Touch (si se cae antes del casteo) > Devouring Plague > Mind Blast > Mind Flay.
  - En movimiento (`GetUnitSpeed`): Shadow Word: Death > Devouring Plague. AoE: Mind Sear en lugar de Mind Flay.
  - Off: Inner Fire y Vampiric Embrace fuera de combate, Dispersion (mana < 10%), Shadowfiend (Burst o mana < 40%), Inner Focus antes de Mind Blast (Burst).
  - Disciplina y Sagrado no tienen rotación: siempre carga Shadow.
- Fuentes de guías: Wowhead WotLK (`/wotlk/guide/classes/<clase>/<spec>/dps-rotation-cooldowns-abilities-pve`) renderiza con JS: se baja con curl y se lee el texto de `WH.markup.printHtml`. Warcraft Tavern se lee directo. Icy Veins bloquea (403).

- Revisión de todas las clases contra Wowhead WotLK (además de Warcraft Tavern). Cuando difieren, manda Wowhead salvo que Rebuffed justifique otra cosa:
  - DK Unholy: corregido. La Gárgola toma la haste en cada golpe, así que va UP -> racial -> Gárgola, se queda en UP mientras vive y vuelve a BP al desaparecer (`gargBackToBP` restaurada). El cambio anterior que sacaba UP estaba mal.
  - Paladín: ST Divine Storm (reset de Rebuffed) > Crusader Strike > Judgement > Hammer of Wrath > Consecration (mana >= 40%) > Exorcism > Holy Wrath. AoE: DS > Consecration > Judgement > Holy Wrath > CS > HoW > Exorcism.
  - Paladín: el anti-traba de Judgement se reiniciaba mal tras un hueco (lo ocultaba 4 s al volver a sugerirlo). Arreglado.
  - Fury: vuelve a Bloodthirst > Whirlwind (Wowhead).
  - Arms: queda Mortal Strike antes que Overpower por el +35% de Rebuffed (Wowhead lo pone como relleno, pero es anterior al buff).
  - Pícaro Combat: AoE desde 2 objetivos (Fan of Knives + Blade Flurry). Assa y Sutileza coinciden.
  - Chamán Elemental: Chain Lightning en ST apagado por defecto (`chainLightningST = 0`, Wowhead: mucho mana). AoE: Magma > Fire Nova > Chain Lightning.
  - Chamán Mejora: Flame Shock > Magma Totem > Lightning Shield > Earth Shock (Magma antes que Earth Shock). Shamanistic Rage a CD (`shamanisticRageMana = 100`).
  - Brujo: Life Tap primero; Shadow Bolt si falta Shadow Mastery en Aflicción y Demo (`shadowMastery`). Aflicción: Corruption > UA > maldición > Haunt.
  - Mago Escarcha: Deep Freeze con la última carga de Fingers of Frost. Arcano y Fuego coinciden.
  - DK Frost y Sombras: coinciden.
- Tests: un test viejo de Frost AoE pisaba `state.spellCooldown` para siempre; ahora lo restaura.
- Cazador nuevo (`RotaClass_HUN`), Wowhead WotLK + Warcraft Tavern:
  - Beast Mastery: Kill Shot (< 20%) > Multi-Shot (mana >= 40%) > Serpent Sting > Arcane Shot > Steady Shot. Off: Bestial Wrath (Burst).
  - Marksmanship: Kill Shot > Serpent Sting > Chimera Shot (con Serpent Sting puesto) > Aimed Shot > Trap Launcher: Explosive Trap > Arcane Shot > Steady Shot. Off: Silencing Shot, Readiness (con Rapid Fire y Chimera gastados).
  - Survival: Kill Shot > Explosive Shot > Serpent Sting (solo caído) > Trap Launcher: Explosive Trap > Black Arrow > Aimed Shot > Steady Shot. Nunca Arcane Shot (comparte CD con Explosive Shot).
  - AoE: Trap Launcher: Explosive Trap > Multi-Shot > Volley.
  - Off común: Aspect of the Dragonhawk, Viper con mana < 10% y vuelta a Dragonhawk con >= 70%, Kill Command a CD, Rapid Fire, guantes y racial (Burst).
  - Var `arcaneShot = 0` cuando sobre Armor Penetration; `explosiveTrap = 0` si el boss se mueve.
  - No se sugiere: Hunter's Mark, mascota, Call of the Wild, Misdirection, el patrón de rangos 4-3-4 de Explosive Shot con Lock and Load.
- Druida nuevo (`RotaClass_DRU`), Wowhead WotLK + Warcraft Tavern (coinciden):
  - Balance: Moonkin Form > Faerie Fire (de cualquiera) > Insect Swarm (dejarlo caer; no en los últimos 5 s de Lunar) > Force of Nature y Starfall (fuera de Eclipse, Burst) > Starfire en Lunar / Wrath en Solar. Sin Eclipse, el hechizo del último Eclipse (arranca con Wrath). En movimiento: Insect Swarm / Moonfire. AoE: Starfall > Hurricane.
  - Los dos Eclipse se llaman "Eclipse" en 3.3.5: se distinguen por ID (48517 Solar, 48518 Lunar).
  - Feral (gato): Cat Form > Savage Roar (1+ CP) > Shred con Clearcasting > Faerie Fire (Feral) (energía < 80, sin Berserk) > Rip (5 CP) > Rake > Mangle (de cualquiera, o Trauma) > Shred. Junta energía si Savage Roar / Rip / Rake se caen en 2 s. AoE: Savage Roar > Rake (sin CP) > Swipe (Cat).
  - Feral off: Tiger's Fury con energía < 40, Berserk con Tiger's Fury a 15+ s de CD, guantes y racial.
  - Restauración se trata como Balance. No hay bearweaving ni rotación de oso (en forma de oso sugiere volver a gato).

- UH Morb arreglado:
  - AoE: Death and Decay antes que las enfermedades (Wowhead).
  - Sin basura en memoria: `can`/`safe` eran funciones creadas en cada evaluación; ahora se llama directo a `UHCanCast` y los pares seguros (`safeB`/`safeU`/`safeF`) se calculan una vez por evaluación.
  - Ghoul Frenzy: hasta 3 s después del casteo (`UNIT_SPELLCAST_SUCCEEDED`) asume 30 s aunque el buff de la mascota todavía no aparezca.
  - Test de Blood Boil en AoE: simula el Pestilence por el combat log, que es lo que lee el evaluador.

- Rotación custom por PJ (`Profiles.lua`):
  - Antes, activar un preset por tabla (login) o desde el editor lo guardaba entero en SavedVariables y lo congelaba en ese PJ: no le llegaban los cambios nuevos. También se guardaba en `customProfiles` de cuenta y se filtraba a los otros PJ.
  - Ahora los presets nunca se guardan. Activar un preset da una copia de trabajo; lo que se edita y guarda queda en `charCustomProfiles[PJ][id]` con `meta.custom = true` y tapa al preset solo en ese PJ (también tras `/reload` y al cambiar de spec).
  - `Profiles:ResetProfile(id)` borra la custom; en el editor, botón "Restaurar". El botón de preset muestra "Custom:" si la activa es tuya y solo cicla presets de tu clase (ya no guarda al elegir).
  - `InitDB` borra las copias viejas sin `meta.custom` y `customProfiles`. Se borraron las purgas por clase de DK, PAL y ROG (la de DK habría borrado una Morb custom sin la regla `uh_master`) y `presetVersion`.
- Editor:
  - Tests de `ProfileToLua` / `TabCode` buscaban el ID viejo `dk_unholy_pve` (ahora `dk_unholy_2h_pve`).
  - Simulador: su estado de prueba no tenía los evaluadores de los módulos, así que los presets "gancho" nunca corrían. Ahora toma del estado real lo que no define, usa sus propias runas para `canCastRunes`/`canWithRunes` y los contadores de auras sincronizan `dk.*` (`TabSimulator:SetAura`).

- Build que volvía a AUTO en cada `/reload`: RotaCore carga antes que el módulo de clase, y en su `ADDON_LOADED` `LoadClassPreset` veía solo el build "auto", tomaba la build guardada como inválida y la pisaba con "auto". Ahora sale sin tocar nada si el módulo no está registrado; `PLAYER_LOGIN` la vuelve a llamar. Test que reproduce el orden de carga real.

- Builds = presets (test que lo garantiza por clase):
  - Paladín: una sola Retri. Borrado el preset PvP y las 15 reglas de respaldo; el preset es solo el gancho al evaluador. Orden Wowhead: ST Crusader Strike > Judgement > Hammer of Wrath (<= 20%, posición de Warcraft Tavern) > Divine Storm > Consecration (mana >= 40%) > Exorcism (AoW) > Holy Wrath. AoE: Consecration > DS > Judgement > Holy Wrath > CS > HoW > Exorcism.
  - Paladín y Sombras: una sola build en el botón (sin AUTO aparte); el botón muestra esa build.
  - DK: borrados los 5 aliases de presets (`dk_frost`, `dk_uh_morb`, `dk_uh_dw_ss`, `dk_uh_2h`, `dk_unholy_pve`) y las reglas de respaldo que nunca corrían (13 de Frost, 11 de UH 2H, `uh_dnd_lock` de Morb).
  - Pícaro: borrado `rog_assassination_hybrid_pve` (no estaba en el botón; solo cambiaba el umbral de AoE, que es la var `aoeTargets`).

- DK Unholy contra Wowhead WotLK (Icy Veins da 403): Morb coincide (DnD siempre, enfermedades primero, Desolation con BS, Ghoul Frenzy antes que PS, UP durante la Gárgola y BT para volver a BP). Agregado Army of the Dead: con la Gárgola viva y después de ERW, solo contra jefes (sus ghouls tauntean adds); var `armyOfTheDead` en Morb, Morb+SS y UH.

- HUD: cuando la sugerencia es esperar (`state.isWaiting`), el icono grande muestra la espiral de cooldown y los segundos que faltan (`state.waitTime` que pone la rotación; si no lo pone, el cooldown del hechizo o el GCD). Textos del contador precalculados (sin strings por frame). Se sacó el icono de espera y `/rc espera`.
- Modo aprendizaje (`settings.learningMode`, casilla en Opciones y `/rc aprender`): muestra el motivo de cada sugerencia debajo del icono (`state.reason`, strings constantes). Apagado por defecto. `UpdateAndEvaluate` resetea `isWaiting` y `reason` antes de cada evaluación.
- DK Unholy AoE: Pestilence se pedía casi siempre (re-esparcir cada 20 s con un registro de casteo que podía fallar) y tapaba a Blood Boil. Ahora con nameplates esparce solo si algún enemigo en rango no tiene plagas (`aoePlateCount` vs `dk.aoeDiseasedCount`); sin nameplates, cada 20 s con el último casteo del combat log o de `UNIT_SPELLCAST_SUCCEEDED`. Refrescar con Pestilence solo con Glyph of Disease.
- DK Unholy: motivos en enfermedades, Desolation, Death and Decay (listo / Blood Tap / esperando runas), Ghoul Frenzy, Death Coil, Horn of Winter y espera ("Guardando RP para la Gargola", "Death and Decay en menos de 1 GCD", "Esperando runas").
- DK Unholy: Death Coil ya no queda bloqueado guardando 60 RP cuando la Gárgola está lista pero la lista off no la pide (plagas < 4.5 s, sin UP, pelea corta); el anti-cap a 80 RP también aplica en ese caso.

- Panel de Opciones (ESC > Interfaz > AddOns > Rota Suite): cada comando `/rc` tiene su control. Nuevos: fila de herramientas (Trace AoE 10s, Debug, Test API, Test nameplates), desplegable Modo AoE AUTO/ON/OFF (reemplaza la casilla que solo cubría AUTO/OFF), Fusión AoE. Se borró `/rc macro`. Los botones llaman a `RotaCore.HandleSlashCmd`, el mismo código que `/rc`. La guía rápida se achicó para que entre todo.

- Rotaciones legibles (en curso): los presets eran un solo "gancho" a una función escondida del módulo y en el editor no se entendía nada. Ahora el sandbox tiene funciones comunes a todas las clases (`ready`, `cd`, `known`, `buff`, `debuff`, `mana`, `power`, `aoe`, `burst`, `combat`, `targetHP`, `gloves`, `wait`, `soonest`, `say`) y los nombres sin definir caen al estado (`pal`, `dk`, `runes`...). Los módulos agregan las suyas con `Sandbox:AddHelper` (Paladín: `judgement()`, `reckoning()`).
  - Paladín Retri convertido: 13 reglas main + 5 off, una por paso, con descripción. Se borró el evaluador escondido del módulo.
  - Modo aprendizaje general: la descripción de la regla que dispara es el motivo (si la regla no puso uno con `say()`).
  - Avenging Wrath, guantes y racial ahora piden estar en combate.

### 2026-11-22

- Plan v2, etapa 0 (herramientas), código listo:
  - `RotaCore/Snapshot.lua`: captura la "situación" del juego solo por API (auras de jugador/objetivo/mascota, CDs de los hechizos del preset, recursos, combo, vida, runas, tótems, imbues, forma, talentos, AoE). Con "Grabar situaciones reales" guarda una cada 2 s en combate con lo que sugirió (`RotaCoreDB.capture`, hasta 500). Con "Comparar con la rotación vieja" evalúa también la v1 del preset activo (`meta.v1`) y anota las diferencias con su situación (`RotaCoreDB.parityLog`, hasta 200, sin repetir la misma seguida). Apagado no crea basura.
  - Selector: un preset migrado lleva `meta.v1 = "<id>_v1"`; la v1 queda registrada con `meta.v1Of` (no aparece como build ni en el editor). Con la casilla "Usar la rotación vieja" en esa build, `SetActiveProfile` carga la v1 y la guarda con el id del preset nuevo.
  - Panel de opciones: sección MIGRACIÓN v2 (dos casillas, selector, contador de lo guardado, botón Borrar).
  - `tools/scenario.lua` reproduce una situación en los mocks; `tools/golden.lua` genera situaciones "a mitad de pelea" (cumple las primeras sugerencias antes de grabar, para no caer siempre en la primera regla), graba y verifica referencias. Se grabaron los 26 presets, Retri incluido (su referencia es la rotación actual en reglas, no hay v1).
  - Reparto fijo de situaciones por preset: 1/3 AoE (3-6 enemigos), 1/3 cleave (2), 1/3 un objetivo. Antes era al azar y Mago Fuego había quedado con 1 solo caso de AoE. Referencias regrabadas.
  - Límites conocidos: el opener se apaga al reproducir (depende del tiempo en combate); lo que los módulos recuerdan por eventos (último Pestilence, juicios, etc.) no viaja en la situación; glifos no se capturan; el mock siempre tiene objetivo.

- Druida Feral rehecho según la guía de Wowhead (no Warcraft Tavern). Bug: pedía Faerie Fire (Feral) cada 6 s con energía < 80, antes que Rip/Rake/Mangle, por el Glyph of Omen of Clarity de Rebuffed, sin chequear que el glifo estuviera puesto. Ahora: Savage Roar > Shred con Clearcasting > Rip (5 CP) > Rake > Mangle > Faerie Fire solo si el objetivo no tiene (var `maintainFF`) > Shred si después alcanza la energía para renovar lo que se cae (cuenta con 10 de energía por segundo y Berserk a mitad de costo); si no, espera mostrando lo que se cae, con los segundos en el icono. Con el glifo puesto, Faerie Fire (Feral) reemplaza la espera. Se sacó la var `poolWindow`. Referencia `dru_feral_pve` regrabada a propósito.
- Revisión de todas las clases contra las guías de Wowhead WotLK (ya no se usa Warcraft Tavern):
  - Sin cambios (ya coincidían): Guerrero Fury y Arms (MS antes que Overpower queda por Improved Mortal Strike de Rebuffed), DK Unholy Morb y Frost, Chamán Mejora, Sombras, Cazador BM y MM, Brujo (las tres).
  - Chamán Elemental: se sacó Chain Lightning en ST (var `chainLightningST`, venía de Warcraft Tavern); en movimiento Flame Shock si está caído, si no Frost Shock; en AoE mantiene Flame Shock.
  - Cazador Supervivencia: Explosive Trap antes de reponer Serpent Sting.
  - Mago Arcano: "Better Rotation" de Wowhead (Arcane Missiles con Missile Barrage después del 4.o Arcane Blast, o del siguiente si el proc salió en el 4.o o más tarde; sin proc, después del 6.o; cuenta los Arcane Blast por `UNIT_SPELLCAST_SUCCEEDED`). Se sacaron las vars `arcaneBlastStacks` y `conserveMana`. Arcane Barrage en movimiento.
  - Mago Fuego: Scorch apagado por defecto (`scorch = 0`, Wowhead no lo usa); AoE Living Bomb > Flamestrike con Firestarter > Blast Wave > Dragon's Breath > Flamestrike; Fire Blast en movimiento (también Escarcha).
  - DK "UH (2H)": Wowhead sacó esa build (rinde menos que Morb); queda porque la eligió el dueño.
  - Referencias regrabadas a propósito: `sha_elemental_pve`, `hun_survival_pve`, `mag_arcane_pve`, `mag_fire_pve`, `mag_frost_pve`.

- Migración v2 completa: las 26 builds de las 10 clases son reglas legibles en su `Presets.lua`, idénticas a la v1 en las 5200 situaciones de referencia, y sin basura en el hot path (`golden.lua check` lo verifica). La v1 de cada build queda como `<id>_v1` (`RotaCore.V1Of`).
  - Funciones generales nuevas en el sandbox: `mana()` (ahora % de mana real), `rage`, `energy`, `runic`, `combo`, `hp`, `powerPct`, `targetType` (normaliza el cliente en español), `targetBoss`, `enemies`, `moving`, `gcd`, `buffStacks`, `debuffStacks`, `debuffAny`, `var`, `glyph`, `talent`. Lista completa en `docs/FUNCIONES.md`.
  - `return false` en una regla corta la lista. `RotaCore.Rule` arma una regla; `RotaCore.Flatten` aplana grupos de reglas.
  - Funciones por clase registradas con `Sandbox:AddHelper` (DK: contextos `unholy()`/`frost()` y predicción de runas; Guerrero, Pícaro, Druida, Brujo: ver `docs/FUNCIONES.md`).
  - Paladín: Holy Wrath usa `targetType()`.
- Rotaciones custom viejas: una custom guardada en la v1 (solo el gancho al evaluador) tapaba la rotación nueva del preset (DK Frost y UH Morb mostraban un solo bloque). `Profiles:GetCustom` ahora la descarta la primera vez y avisa por chat; las custom con reglas propias se respetan.
- DK: el alias GF usaba el ID 49213, que en el servidor es otro hechizo ("Defending Wyrmrest..."); ahora 63560 (Ghoul Frenzy).
- Editor (pestaña Bloques): el nombre de la habilidad tiene ancho fijo y la descripción va entre el nombre y los botones, cortada si no entra (antes se pisaban).
- DK Morb+SS: revisado. Con Scourge Strike aprendido lo pide en las situaciones típicas. El escaneo de RotaProbe del DK del dueño confirma talentos Morb sin Scourge Strike: con esa build corresponde UH Morb (DW).
- Todas las builds declaran `meta.requires` (hechizos de talento sin los que no funcionan, ej. Morb+SS: Scourge Strike; Feral: Mangle, Berserk). Al entrar en combate, `RotaCore.CheckRequires` avisa una vez por build y sesión si falta alguno (antes la rotación simplemente nunca lo pedía).
- IDs del catálogo del DK comparados con el libro de hechizos escaneado: todos en su rango máximo. Para las otras clases no hay escaneo del servidor.
- Interfaz, segunda pasada (pedido del dueño: "poco legible"):
  - Panel: casillas con el cuadradito del juego, botones con borde, desplegables de Build e Icono de cooldowns con su texto (antes vacíos y con un click que ciclaba en vez de abrir), textos en castellano llano y una línea de ayuda por pestaña. "Herramientas" pasó a "Avanzado".
  - Se borró el menú rápido del HUD: el botón de la mini-barra abre el panel.
  - Editor: pestañas Reglas / Código / IDs de hechizos / Ayuda. Se borraron el importador de Ovale (`ParserOvale.lua`) y el Simulador (las referencias offline cubren esa prueba). "Leer/Aplicar a IR" pasó a "Recargar / Guardar cambios". La Ayuda se reescribió (qué hace, reglas, funciones, IDs).
- Interfaz unificada: el panel de Interfaz > AddOns > Rota Suite es la única ventana de opciones, con 3 pestañas (Rotación: build, AoE, Burst, aprendizaje, editor, usar v1 / Pantalla: bloquear HUD, minimapa, modo y escala de Burst, reset / Herramientas: trace, debug, sondas, fusión AoE, grabación y comparador, guía). La pestaña elegida se recuerda (`settings.optionsTab`). El botón del minimapa abre ese mismo panel (`Options:Open()`); click derecho abre el editor. Se sacó el Shift+click a RotaProbe (está en Herramientas).

- Preparado para GitHub: README, CONTRIBUTING (reglas de PR), AGENTS.md (contexto para asistentes de IA; CLAUDE.md apunta ahí), plantillas de PR e issue "Rotación", CI (`.github/workflows/tests.yml`: tests, referencias y luacheck en cada PR). Sin datos personales en los archivos: `deploy.sh` toma la ruta de `WOW_ADDONS_DIR` o de `.wow-addons-path` (fuera de git). Documentos sueltos movidos a `docs/`.

## Pendiente

Plan por etapas en `docs/PLAN_V2.md`:
Todo se verifica offline con las referencias; no se prueba en el juego.
0. Herramientas: hecha. Referencias con un tercio de situaciones de un objetivo, cleave (2 enemigos) y AoE (3-6).
1-3. Hechas: todas las clases en reglas.
4. 2.0.0: borrar los evaluadores v1 de los módulos y los presets `_v1` (cuando el dueño decida que ya no hacen falta).
5. Interfaz: hecha la primera versión (panel único con pestañas). Falta verla en el cliente.
