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
   esperado: actualizá **solo esa build** con `lua5.1 tools/golden.lua update <preset_id>`. Conserva las 200
   situaciones y lista los casos que cambiaron: pegá esa lista en el PR y explicá por qué cambian (con la fuente).
   `record --force` genera situaciones nuevas y no deja ver qué cambió: solo para builds nuevas.
   Nunca edites `tools/golden/*.lua` a mano.
4. Agregá un test en `tools/test_runner.lua` con la situación que motivó el cambio.
5. Glifos: si un glifo cambia un poco la rotación, declaralo en `preset.glyphs` (con `ids` si los tenés, medidos en
   el servidor) y usá `glyphOn("clave")`, con un test
   con el glifo puesto y otro sin él (las referencias se graban sin glifos). Si cambia mucho, proponé otra build.
6. Pre-pull: cada build tiene su lista `prepull`, solo para antes del pull (termina al entrar en combate). Para la
   poción usá `RotaCore.PrepullPotion("melee")` o `("caster")`.

## Reglas para todo PR

- Pasan `lua5.1 tools/test_runner.lua`, `lua5.1 tools/golden.lua check` y `luacheck .` (el CI lo corre solo).
- Lua 5.1 y API de WoW 3.3.5a. Sin dependencias nuevas.
- Nada que cree tablas, closures o strings en cada evaluación (corre 20 veces por segundo); `golden.lua check`
  lo mide.
- Textos visibles en castellano llano, sin jerga técnica.
- No tocar los presets `*_v1` ni los evaluadores viejos de los módulos (se borran en la 2.0.0).
- No cambiar el formato de `RotaCoreDB` (SavedVariables) sin una migración y su test.
- Nada de datos personales (nombres de cuenta, rutas de tu disco, nombres de personajes).
