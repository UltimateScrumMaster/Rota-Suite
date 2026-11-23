# Funciones para escribir rotaciones

Cada rotación es una lista de reglas, de arriba hacia abajo. La primera regla que devuelve una habilidad gana.

```lua
-- Consecration solo con 40% de mana o más
if ready("CONS") and mana() >= 40 then return "CONS" end
```

- `return "ALIAS"`: sugiere esa habilidad. Los alias están en el catálogo del preset (`spells`).
- Sin `return`: la regla no aplica y se pasa a la siguiente.
- `return false`: corta la lista. No se mira ninguna regla más.
- `return wait("ALIAS", segundos)`: muestra la habilidad "esperando", con espiral y segundos en el icono.
- Para guardar un valor: `local m = mana()`. Lua no puede escribir en una variable que se pasa como parámetro, así que la función devuelve el valor.

## Generales (todas las clases)

| Función | Devuelve |
|---|---|
| `ready("X")` | conocida y fuera de cooldown al terminar el GCD |
| `known("X")` | la conocés |
| `cd("X")` | segundos de cooldown (0 = lista) |
| `gcd()` | segundos que faltan del GCD |
| `mana()` | % de mana (0 en clases sin mana) |
| `rage()`, `energy()`, `runic()` | valor de ira, energía, poder rúnico |
| `power()`, `powerPct()` | recurso principal: valor y % |
| `combo()` | combo points en el objetivo |
| `hp()` | % de vida propia |
| `targetHP()` | % de vida del objetivo |
| `targetType()` | `"Undead"`, `"Demon"`, `"Beast"`, `"Humanoid"`, `"Elemental"`, `"Dragonkin"`, `"Giant"`, `"Mechanical"`, `"Critter"` (también con el cliente en español) |
| `targetBoss()` | el objetivo es un jefe |
| `buff("Nombre")` | segundos que le quedan a un buff tuyo |
| `buffStacks("Nombre")` | stacks de un buff |
| `debuff("Nombre")` | segundos de un debuff tuyo en el objetivo |
| `debuffStacks("Nombre")` | stacks de un debuff tuyo |
| `debuffAny("Nombre")` | segundos de un debuff de cualquiera (ej. Faerie Fire de otro druida) |
| `aoe()` | modo AoE activo |
| `enemies()` | enemigos contados para el AoE |
| `combat()` | en combate |
| `moving()` | te estás moviendo |
| `burst()` | Burst activado |
| `gloves()` | guantes de ingeniero listos |
| `glyph("Nombre")` | tenés el glifo |
| `talent("Nombre")` | tenés al menos 1 punto en el talento |
| `var("nombre", defecto)` | variable del preset (se ajusta en el editor) |
| `say("texto")` | motivo que se ve en modo aprendizaje |
| `soonest("A", "B")` | de esas habilidades, la que sale antes de cooldown |

Además, cada clase deja sus datos en una tabla: `pal`, `dk`, `war`, `rog`, `dru`, `sha`, `wl`, `mag`, `pri`, `hun`. Ejemplos: `dru.rip` (segundos de tu Rip), `rog.cp`, `war.rage`, `runes.bloodReady`. El comentario arriba de cada preset lista los campos.

## Por clase

| Clase | Funciones |
|---|---|
| Paladín | `judgement()` (Judgement listo, con anti-traba), `reckoning()` |
| DK | `unholy()` y `frost()` (contexto de la evaluación), `canCast(b, f, u)`, `runeDeficit(b, f, u)`, `runeWait("blood"/"unholy"/"frost")`, `keepsRune(tipo, segundos)`, `canWithRunes(segundos, b, f, u, guardarBlood)`, `grace(tipo)`, `bloodTapFor("X")`, `bloodTapReady()`, `healthOK()`, `longFight()`, `lastPestilence()` |
| Guerrero | `opWeaving()` (build Fury con Overpower), `shatteringReady()`, `spellReady("X")` |
| Pícaro | `show("X")` (marca "esperando" si falta energía), `canAfford("X")`, `needExpose()` |
| Druida | `catCost("X")`, `poolFor("X")`, `shredLeavesFor(segundos, "X")` |
| Brujo | `curse(defecto)`, `lifeTapNeeded()`, `shadowMasteryNeeded()` |

Las rotaciones v1 (antes de las reglas) quedan guardadas como `<preset>_v1`. En Opciones, la casilla "Usar la rotación vieja" las activa.
