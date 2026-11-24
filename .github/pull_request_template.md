## Qué cambia

<!-- Clase / build y qué sugiere distinto. Si no es una rotación, qué arregla o agrega. -->

## Por qué

<!-- Fuente: link a la guía de Wowhead WotLK o al cambio de Rebuffed. -->

## Checklist

- [ ] `lua5.1 tools/test_runner.lua`, `lua5.1 tools/golden.lua check` y `luacheck .` pasan
- [ ] Si cambió lo que sugiere una build: `lua5.1 tools/golden.lua update <preset>` solo de esa build, con la lista de casos que cambiaron pegada arriba
- [ ] Agregué un test con la situación que motivó el cambio
- [ ] Sin dependencias nuevas, sin datos personales, textos en castellano llano
