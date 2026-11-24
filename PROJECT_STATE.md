# Estado del proyecto

Rota Suite: addon de sugerencias de rotación para WoW 3.3.5a (Interface 30300), servidor Frostmourne Rebuffed
(Whitemane). Este archivo describe qué hace hoy el addon y qué falta. Se actualiza con cada cambio.

## Qué hace

- **HUD:** icono grande con la próxima habilidad en GCD, icono chico con cooldowns y habilidades fuera de GCD.
  Si la habilidad todavía no se puede usar (runas, energía, cooldown), el icono muestra una espiral y los segundos.
- **Mini-barra:** build activa, modo AoE (automático / siempre / nunca), Burst (usar o guardar cooldowns largos) y
  botón de opciones.
- **Opciones:** un solo panel, el mismo desde el botón del minimapa y desde Interfaz > AddOns > Rota Suite, con
  tres pestañas: Rotación, Pantalla y Avanzado.
- **Editor de rotaciones** (click derecho en el minimapa): pestañas Reglas, Código, IDs de hechizos y Ayuda. Lo que
  se cambia queda como rotación custom del personaje; "Restaurar" vuelve a la original.
- **Modo aprendizaje:** muestra debajo del icono por qué sugiere cada habilidad.
- **Aviso de talentos:** si la build elegida necesita un hechizo de talento que el personaje no tiene, avisa una
  vez por chat al entrar en combate.
- **Botón Pre-Pull** (movible por separado): todas las builds tienen lista de pre-pull (poción más lo propio de cada
  una). Muestra una vez esa rotación, con la etiqueta PRE, hasta el pull. Se oculta en combate y vuelve al salir.
  También con `/rc prepull` (para macros). Opcional y apagado por defecto: lo arma el temporizador de pull de DBM.
- **Glifos que cambian la rotación:** toggles en Opciones > Rotación, detectados solos; si se apaga uno, queda
  apagado (para todas las builds del personaje, por talento dual) hasta cambiar de talentos. Se detectan con el
  cliente en inglés o en español. Hoy: Army of the Dead (DK), Shattering Throw (Guerrero), Omen of Clarity
  (Druida Feral), Life Tap (Brujo).

## Cómo funcionan las rotaciones

Cada build es una lista de reglas legibles en `RotaClass_<CLASE>/Presets.lua`. Se leen de arriba hacia abajo y la
primera que sugiere algo gana. Las reglas usan funciones generales (`ready`, `mana`, `targetType`, `buff`...) y
funciones propias de cada clase (por ejemplo, la predicción de runas del DK). La lista completa está en
`docs/FUNCIONES.md`.

Fuente de las rotaciones: guías de Wowhead WotLK más los cambios del servidor (`docs/REBUFFED.md`).

## Clases y builds

| Clase | Builds |
|---|---|
| Death Knight | Frost, UH Morb (DW), UH Morb+SS (DW+SS), UH (2H) |
| Paladín | Retribution |
| Guerrero | Fury, Fury con Overpower, Arms |
| Pícaro | Assassination, Combat, Subtlety, Subtlety (daga) |
| Chamán | Elemental, Enhancement |
| Brujo | Affliction, Demonology, Destruction |
| Mago | Arcane, Fire, Frost |
| Sacerdote | Shadow |
| Cazador | Beast Mastery, Marksmanship, Survival |
| Druida | Balance, Feral |

La build se elige en Opciones o con AUTO, que la detecta por talentos. Se guarda por personaje.

DK y Paladín se juegan en el servidor. El resto de las clases sigue las guías y pasa las pruebas offline, pero
**falta feedback de gente que las juegue**: ver README.

## Módulos

| Carpeta | Qué hace | Carga |
|---|---|---|
| `RotaCore` | estado, reglas, HUD, opciones, perfiles | siempre |
| `RotaClass_<CLASE>` | datos de la clase y sus builds | siempre (se usa solo la de tu clase) |
| `RotaEditor` | editor de rotaciones | cuando se abre |
| `RotaProbe` | escaneo de hechizos, talentos y APIs del servidor | cuando se usa |

## Pruebas

Todo se verifica offline, sin el juego (el CI de GitHub lo corre en cada PR):

- `lua5.1 tools/test_runner.lua`: 973 tests.
- `lua5.1 tools/golden.lua check`: cada build se compara con su referencia (200 situaciones: un tercio de un
  objetivo, un tercio con 2 enemigos y un tercio AoE) y se mide que no cree basura en memoria a 20 evaluaciones por
  segundo.
- `luacheck .`: sin advertencias.

Cuando un cambio modifica a propósito lo que sugiere una build, se actualiza solo esa referencia con
`lua5.1 tools/golden.lua update <preset>`: conserva las situaciones y lista los casos que cambiaron.

## Pendiente

1. Feedback de las clases que el autor no juega.
2. Versión 2.0.0: borrar las rotaciones viejas (presets `*_v1` y evaluadores `Evaluate*` de los módulos), que hoy
   quedan como respaldo con la casilla "Usar la rotación vieja".
3. Ver el panel de opciones y el editor nuevos en el cliente y ajustar lo que haga falta.
4. Verificar en el juego el formato del aviso de pull de DBM (prefijo "D4", "PT\t<segundos>"): se tomó del formato
   conocido de DBM para WotLK y no se probó en el servidor.
5. Glyph of Quick Pain (Sacerdote Sombras): falta saber qué parte de la rotación cambia con el glifo para hacerlo
   toggle.
6. Ajustar los pre-pull de las clases que el autor no juega con el feedback de quienes las juegan.
7. Partes avanzadas de las guías que todavía no están: bearweaving del Druida Feral, renovar Savage Roar antes de
   tiempo, Lock and Load "434" del Cazador Survival, Shadowflame del Brujo, Corruption en movimiento (Destruction),
   openers por clase.
