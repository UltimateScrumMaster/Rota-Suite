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

## Botón Pre-Pull

Aparece fuera de combate. Todas las builds tienen pre-pull: poción (Speed para cuerpo a cuerpo, Wild Magic o Speed
para casters; solo si la tenés en las bolsas y fuera de cooldown) más lo propio de cada una, por ejemplo Army of the
Dead (DK Frost con el glifo), Pyroblast (Mago Fuego), Vampiric Touch (Sombras), Divine Plea (Paladín), Shadow Bolt
(Brujo) o Feral Spirit (Mejora).

1. Tocalo unos segundos antes del pull. El tooltip dice cuántos y qué se tira.
2. El icono grande muestra la rotación de pre-pull, con la etiqueta **PRE** arriba. Pasa una sola vez.
3. Termina solo al entrar en combate, cuando no queda nada por tirar, o si el pull no llega a tiempo. Funciona aunque
   Burst esté apagado. Si no hay nada para tirar (por ejemplo, no tenés poción), avisa por chat.
4. El botón desaparece en combate y vuelve cuando salís de combate. Si tiraste todo y el pull no llegó, vuelve solo
   a los pocos segundos.

**DBM (opcional, apagado por defecto):** con "Armar el pre-pull solo con el temporizador de pull de DBM" tildado
(Opciones > Pantalla), cuando alguien larga un pull de DBM el addon arma el pre-pull solo, a los segundos de
anticipación de tu build. Sin tildar, solo funciona el botón.

Se mueve arrastrándolo, por separado del resto. "Volver al centro" (Opciones > Pantalla) también lo centra, y ahí
mismo, con "Mostrar el botón Pre-Pull", se puede ocultar.

## Glifos que cambian la rotación

En Opciones > Rotación aparecen los glifos que cambian un poco la rotación de tu build: Army of the Dead (DK),
Shattering Throw (Guerrero), Omen of Clarity (Druida Feral) y Life Tap (Brujo). El addon los detecta solo, con el
cliente en inglés o en español (también un glifo nuevo que quedó sin traducir). Si destildás uno, queda apagado para todas las builds de ese
personaje hasta que cambies de talentos; ahí vuelve a activarse y avisa por chat. Cada talento dual guarda lo suyo.
Un glifo que no tenés puesto aparece en gris.

## Opciones

Se abren con click en el botón del minimapa, con el botón de la mini-barra o desde Interfaz > AddOns > Rota Suite.
Es el mismo panel en los tres casos.

| Pestaña | Qué tiene |
|---|---|
| Rotación | build, modo AoE, usar cooldowns largos, mostrar el motivo de cada sugerencia, editar rotación, usar la rotación vieja, glifos de la build |
| Pantalla | bloquear iconos, botón del minimapa, botón Pre-Pull, dónde va el icono de cooldowns, tamaño, volver al centro |
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
| `/rc prepull` | arma o cancela el pre-pull (sirve en una macro) |
| `/rotaprobe scan` | escanea hechizos, talentos y APIs del servidor |

## Doble talento

La build se guarda por personaje. Con AUTO, al cambiar de talentos el addon detecta la build nueva.
