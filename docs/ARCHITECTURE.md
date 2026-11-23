# Arquitectura

## Flujo

```
OnUpdate (20 veces por segundo)
  └─ State:Update()            estado del tick en una tabla única (recursos, auras, CDs, runas, enemigos)
       └─ provider de la clase  completa state.dk / state.rog / state.dru ... (sin crear tablas)
  └─ lista main                 reglas en orden: la primera que devuelve una habilidad va al icono grande
  └─ lista off                  igual, para el icono chico (fuera del GCD)
  └─ UI:UpdateDisplay()         iconos, espiral de espera, motivo (modo aprendizaje)
```

## Piezas

| Archivo | Qué hace |
|---|---|
| `RotaCore/State.lua` | estado por tick, conteo de enemigos (placas y registro de combate), providers de clase |
| `RotaCore/Sandbox.lua` | entorno donde corren las reglas: funciones generales, funciones de clase (`AddHelper`), errores aislados (una regla que falla 3 veces se apaga) |
| `RotaCore/Compiler.lua` | convierte un preset en las funciones que evalúan sus listas |
| `RotaCore/Spells.lua` | catálogo alias -> hechizo, IDs del servidor y cambios manuales de ID |
| `RotaCore/Profiles.lua` | builds registradas, rotaciones custom por personaje, guardado en `RotaCoreDB` |
| `RotaCore/RotaCore.lua` | carga del módulo de clase, elección de build, ciclo de evaluación, comandos `/rc` |
| `RotaCore/UI.lua`, `Options.lua`, `Minimap.lua` | HUD, panel de opciones, botón del minimapa |
| `RotaCore/CodeGen.lua`, `ParserLua.lua` | pasan un preset a texto y de vuelta (pestaña Código del editor) |
| `RotaCore/Snapshot.lua` | graba situaciones reales del juego para usarlas como tests |
| `RotaClass_<CLASE>/` | provider de estado, detección de build, funciones propias y `Presets.lua` con las builds |
| `RotaEditor/` | editor en el juego (se carga al abrirlo) |
| `RotaProbe/` | escaneo de hechizos, talentos y APIs del servidor |

## Un preset

```lua
{
    meta = { id = "dru_feral_pve", class = "DRUID", requires = { "MANGLE", "BERSERK" }, ... },
    spells = { RIP = { name = "Rip", defaultId = 49800 }, ... },  -- alias -> hechizo
    vars = { maintainFF = 1, ... },                                -- ajustes que lee var("nombre")
    lists = { main = { regla, regla, ... }, off = { ... } },
}
```

Cada regla es `RotaCore.Rule(id, alias, descripción, código)`. El código corre en el sandbox y devuelve un alias,
nada (sigue la siguiente), `false` (corta la lista) o `wait(alias, segundos)`.

## Contratos

- **Cero basura en el hot path:** providers, reglas y evaluadores no crean tablas, closures ni strings por tick.
  `tools/golden.lua check` lo mide en todas las builds.
- **Solo API de 3.3.5a** (Lua 5.1). Las APIs propias de Rebuffed se usan con detección y `pcall`
  (`docs/REBUFFED_API.md`).
- **Rotaciones v1:** cada build conserva su versión anterior como `<id>_v1` (gancho al evaluador del módulo),
  usable con la casilla "Usar la rotación vieja". Se borran en la versión 2.0.0.

## Pruebas

`tools/wowmock.lua` imita la API del juego. `tools/test_runner.lua` corre los tests. `tools/golden.lua` reproduce
200 situaciones por build (`tools/scenario.lua` arma cada una en el mock) y compara con lo grabado en
`tools/golden/`.
