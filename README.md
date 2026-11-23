# Rota Suite

Addon de sugerencias de rotación para **WoW 3.3.5a** (WotLK, Interface 30300), hecho para el servidor
**Frostmourne Rebuffed** (Whitemane). Muestra la próxima habilidad (icono grande) y los cooldowns fuera del GCD
(icono chico). Cada rotación es una lista de reglas legibles que se pueden editar en el juego.

Clases: Death Knight, Paladín, Guerrero, Pícaro, Chamán, Brujo, Mago, Sacerdote Sombras, Cazador, Druida.

## Busco feedback de rotaciones

El autor juega DK Unholy y Paladín Retribution. Para las demás clases hace falta gente que las juegue.
Si una rotación sugiere algo que no corresponde, abrí un **issue** con la plantilla "Rotación" (qué pidió, qué
debería pedir, en qué situación, y la fuente). Las rotaciones siguen las guías de Wowhead WotLK más los cambios de
Rebuffed (`docs/REBUFFED.md`).

## Instalar

1. Copiá las carpetas `RotaCore`, `RotaEditor`, `RotaProbe` y la `RotaClass_*` de tu clase en `Interface/AddOns`.
2. En el juego: click en el botón del minimapa abre las opciones; click derecho abre el editor de rotaciones.

## Para desarrollar

Requiere Lua 5.1 y luacheck. Todo se prueba offline, sin el juego:

```bash
lua5.1 tools/test_runner.lua      # tests
lua5.1 tools/golden.lua check     # cada build sugiere lo mismo que su referencia, sin crear basura
luacheck .
```

Antes de proponer cambios leé `CONTRIBUTING.md`. Si usás un asistente de IA, que lea `AGENTS.md`.
