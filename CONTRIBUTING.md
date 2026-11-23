# Cómo contribuir

`main` está protegida: todo cambio entra por **pull request** y lo revisa el dueño. Se revisa línea por línea.
PRs grandes o que mezclan temas se piden partir.

## Feedback sin código

Abrí un issue con la plantilla **Rotación**. Lo más útil:
- clase, spec y build elegida en el addon;
- qué sugirió y qué tendría que haber sugerido;
- la situación (un objetivo / 2 enemigos / AoE, recursos, buffs y debuffs, cooldowns);
- la fuente (guía de Wowhead WotLK, o un cambio de Rebuffed con link).

## Cambios de rotación

1. Una rotación está en `RotaClass_<CLASE>/Presets.lua`, como lista de reglas (`RotaCore.Rule`).
   Funciones disponibles: `docs/FUNCIONES.md`.
2. Fuente: guías de **Wowhead WotLK** + `docs/REBUFFED.md`. No se toman rotaciones de otras fuentes sin acuerdo.
3. Si tu cambio hace que la build sugiera otra cosa, `lua5.1 tools/golden.lua check` lo va a marcar. Eso es lo
   esperado: regrabá **solo esa build** con `lua5.1 tools/golden.lua record <preset_id> --force` y explicá en el PR
   por qué cambia (con la fuente). Nunca edites `tools/golden/*.lua` a mano.
4. Agregá un test en `tools/test_runner.lua` con la situación que motivó el cambio.

## Reglas para todo PR

- Pasan `lua5.1 tools/test_runner.lua`, `lua5.1 tools/golden.lua check` y `luacheck .` (el CI lo corre solo).
- Lua 5.1 y API de WoW 3.3.5a. Sin dependencias nuevas.
- Nada que cree tablas, closures o strings en cada evaluación (corre 20 veces por segundo); `golden.lua check`
  lo mide.
- Textos visibles en castellano llano, sin jerga técnica.
- No tocar los presets `*_v1` ni los evaluadores viejos de los módulos (se borran en la 2.0.0).
- No cambiar el formato de `RotaCoreDB` (SavedVariables) sin una migración y su test.
- Nada de datos personales (nombres de cuenta, rutas de tu disco, nombres de personajes).
