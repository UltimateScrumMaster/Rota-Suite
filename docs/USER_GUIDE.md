# Guía de uso

## Instalar

Copiá en `Interface/AddOns` del juego las carpetas `RotaCore`, `RotaEditor`, `RotaProbe` y la `RotaClass_*` de tu
clase (podés copiar todas: solo se usa la de tu clase). Entrá al juego o hacé `/reload`.

## Qué ves en pantalla

- **Icono grande:** la próxima habilidad que conviene usar (las que pasan por el GCD).
- **Icono chico:** cooldowns y habilidades fuera del GCD (Gárgola, Tiger's Fury, guantes, racial...).
- **Espiral y segundos sobre el icono:** esa habilidad todavía no, pero viene (runas, energía, cooldown).
- **Mini-barra debajo:**
  - **Build:** la rotación que estás usando.
  - **AoE:** AUTO cuenta los enemigos solo; ON lo fuerza; OFF lo apaga.
  - **Burst:** si está en OFF, guarda los cooldowns largos.
  - **Botón de la derecha:** abre las opciones.

Para mover los iconos: en Opciones > Pantalla, destildá "Bloquear los iconos" y arrastralos.

## Opciones

Se abren con click en el botón del minimapa, con el botón de la mini-barra o desde Interfaz > AddOns > Rota Suite.
Es el mismo panel en los tres casos.

| Pestaña | Qué tiene |
|---|---|
| Rotación | build, modo AoE, usar cooldowns largos, mostrar el motivo de cada sugerencia, editar rotación, usar la rotación vieja |
| Pantalla | bloquear iconos, botón del minimapa, dónde va el icono de cooldowns, tamaño, volver al centro |
| Avanzado | herramientas de diagnóstico, cómo se cuentan los enemigos, grabación para los tests |

Si la build elegida necesita un hechizo de talento que no tenés (por ejemplo UH Morb+SS sin Scourge Strike), el
addon avisa una vez por chat al entrar en combate.

## Editor de rotaciones

Se abre con click derecho en el botón del minimapa o con `/rc edit`.

- **Reglas:** la lista de la build. ON/OFF apaga una regla sin borrarla; ^ y v cambian el orden; Edit la abre.
  El botón "Lista" cambia entre la lista principal y la de fuera del GCD.
- **Código:** todas las reglas como texto. "Guardar cambios" las aplica; "Recargar" descarta lo no guardado.
- **IDs de hechizos:** si en el servidor un hechizo tiene otro ID (icono gris o con otro nombre), escribí el ID
  correcto en su fila.
- **Ayuda:** cómo se escribe una regla y qué funciones hay (lista completa en `docs/FUNCIONES.md`).

Lo que cambies queda como rotación **Custom** de ese personaje. "Restaurar" vuelve a la rotación original.

## Comandos

| Comando | Qué hace |
|---|---|
| `/rc` | lista de comandos |
| `/rc edit` | abre el editor |
| `/rc options` | abre las opciones |
| `/rc burst` | prende o apaga los cooldowns largos |
| `/rc aoe` | cambia el modo AoE (AUTO / OFF / ON) |
| `/rc build <build>` | elige la build (DK: auto, frost, morb, ums, unholy) |
| `/rc lock` | bloquea o desbloquea los iconos |
| `/rc reset` | vuelve a centrar los iconos |
| `/rc aprender` | muestra el motivo de cada sugerencia |
| `/rc status` | rotación activa y estado |
| `/rotaprobe scan` | escanea hechizos, talentos y APIs del servidor |

## Doble talento

La build se guarda por personaje. Con AUTO, al cambiar de talentos el addon detecta la build nueva.
