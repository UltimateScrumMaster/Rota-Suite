# Contexto para asistentes de IA

Leé esto antes de tocar código. Las reglas de `CONTRIBUTING.md` también aplican.

## Qué es

Addon de sugerencias de rotación para WoW 3.3.5a (Interface 30300, Lua 5.1), servidor privado Frostmourne Rebuffed.
Cada 0.05 s (20 Hz) se actualiza un estado y se evalúan dos listas de reglas: `main` (icono grande, habilidades en
GCD) y `off` (icono chico, cooldowns fuera de GCD).

## Mapa

| Ruta | Qué hay |
|---|---|
| `RotaCore/State.lua` | estado por tick (`stateData`, tabla única preasignada); providers de cada clase |
| `RotaCore/Sandbox.lua` | entorno de las reglas: funciones generales (`ready`, `mana`, `targetType`, ...) y `Sandbox:AddHelper` |
| `RotaCore/Compiler.lua` | compila un preset a evaluadores; `RotaCore.Rule`, `RotaCore.Flatten`, `RotaCore.V1Of` |
| `RotaCore/Profiles.lua` | presets registrados, rotaciones custom por personaje, selector v1 |
| `RotaCore/RotaCore.lua` | carga de clase/build, `UpdateAndEvaluate`, comandos `/rc`, `CheckRequires` |
| `RotaCore/UI.lua`, `Options.lua`, `Minimap.lua` | HUD, panel único de opciones, botón del minimapa |
| `RotaCore/Snapshot.lua` | captura de "situaciones" del juego (para tests) y comparador v1/nueva |
| `RotaClass_<X>/RotaClass_<X>.lua` | datos de la clase: IDs, provider de estado (`state.dk`, `state.rog`...), detección de build, funciones propias para reglas |
| `RotaClass_<X>/Presets.lua` | las builds: catálogo de hechizos, `vars`, `meta.requires`, listas de reglas |
| `RotaEditor/` | editor en el juego (reglas, código, IDs, ayuda); carga bajo demanda |
| `tools/wowmock.lua` | mock de la API de WoW para correr todo offline |
| `tools/test_runner.lua` | tests (un solo script) |
| `tools/golden.lua`, `tools/scenario.lua`, `tools/golden/` | referencias: 200 situaciones por build y lo que sugiere |
| `docs/FUNCIONES.md` | funciones para escribir reglas |
| `docs/REBUFFED.md` | cambios de clases del servidor respecto de WotLK original |
| `PROJECT_STATE.md` | qué hace hoy el addon y qué falta |

## Cómo es una regla

```lua
R("ret_cons", "CONS", "Consecration con mana >= 40%", [[
if ready("CONS") and mana() >= 40 then return "CONS" end
]]),
```

- La primera regla que devuelve un alias del catálogo gana. Sin `return` se pasa a la siguiente.
- `return false` corta la lista. `return wait("X", seg)` muestra la habilidad "esperando".
- Nombres sin definir caen al estado: `dru.rip`, `rog.cp`, `runes.bloodReady`, `power` (ojo: `power` es una
  función; usá `power()`).
- La lógica compleja de una clase va en una función del módulo registrada con `Sandbox:AddHelper` y documentada en
  `docs/FUNCIONES.md` (ej. predicción de runas del DK). Una función devuelve datos o el alias a mostrar; la
  prioridad tiene que quedar visible en las reglas.

## Restricciones duras

- **Lua 5.1 / WoW 3.3.5a**: sin `goto`, sin `//`, sin APIs de retail (`C_Spell`, `UnitAura` con filtros nuevos...).
  Si una API no está en `tools/wowmock.lua`, probablemente no existe en 3.3.5a: verificalo.
- **Cero asignaciones en el hot path**: nada de `{}`, closures ni concatenación de strings dentro de reglas,
  providers o evaluadores. Tablas reusables a nivel de módulo. `golden.lua check` falla si una build crea basura.
- **No editar** `tools/golden/*.lua` a mano ni regrabar referencias de builds que no cambiaste a propósito.
- **No tocar** presets `*_v1` ni los evaluadores viejos (`Evaluate*`) de los módulos.
- **Fuente de rotaciones**: guías de Wowhead WotLK + `docs/REBUFFED.md`.
- Textos de UI en castellano llano.
- Un local por variable: el archivo de tests ya está cerca del límite de 200 locales del chunk principal; meté
  suites nuevas dentro de una función.

## Verificar

```bash
lua5.1 tools/test_runner.lua
lua5.1 tools/golden.lua check
luacheck .
```

Las tres tienen que pasar. Si `golden.lua check` marca diferencias en una build que no tocaste, el cambio rompió
algo compartido (núcleo, sandbox, mocks): arreglalo, no regrabes.
