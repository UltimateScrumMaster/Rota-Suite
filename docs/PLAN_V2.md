# Plan v2: rotaciones legibles por etapas

Objetivo: cada rotación es código legible en su preset (reglas que llaman funciones). El módulo de clase solo tiene datos (IDs, duraciones, detección de spec, estado) y funciones de ayuda. Cada spec se migra igual que en la v1.0.0, con todos sus ajustes.

## Reglas para todas las etapas

- Nada de la 2.x va a la carpeta AddOns del juego (no `deploy.sh`) hasta que el dueño lo pida. Se trabaja local: tests, luacheck y `dist/`.
- Migrar igual, error incluido. Si la v1 hace algo mal, se anota en "Errores de la v1" (abajo) y se arregla después en 2.0.x, no durante la migración.
- Las funciones de ayuda devuelven datos (número o sí/no), nunca el nombre de un hechizo. La decisión de qué tirar queda siempre en la regla.
- Una función de ayuda = una idea, que entre en una pantalla. Una función tipo `if dkMagia()` que decide todo es un fallo.
- El evaluador viejo de cada spec sigue en el código hasta la 2.0.0. Así se compara y se puede volver atrás.
- Los mocks y el simulador con que se graban las referencias quedan congelados. Si cambian, las referencias se regraban a propósito, nunca de pasada.
- Tests, luacheck y prueba de cero asignaciones a 20 Hz pasan en cada etapa.
- Todo se verifica offline con las referencias (`lua5.1 tools/golden.lua check`): el dueño no quiere probar en el juego. La grabación y el comparador en juego quedan como herramienta opcional.

## Etapa 0: herramientas (v1.1.0)

1. Grabador de referencias: corre el evaluador v1 de cada spec sobre ~200 estados simulados y guarda la sugerencia por preset.
2. Grabación de estados reales: con una opción en el panel, durante el combate guarda cada tanto (muestreado, no cada frame) el estado y la sugerencia en SavedVariables. Después se copian a `tools/` y se usan como casos de prueba. Así los casos no los inventa solo la IA.
3. Comparador en juego: con una opción en el panel, calcula v1 y regla nueva a la vez y anota cuándo difieren (muestreado, sin crear tablas ni textos por frame). El registro sale por SavedVariables.
4. Selector por spec: casilla "usar rotación nueva" para volver a la v1 en el momento, sin reinstalar.
5. Lista de diferencias permitidas: empates y arreglos a propósito, anotados.

Listo cuando: referencias grabadas para todos los presets, con situaciones de un objetivo, cleave (2) y AoE (3-6) en partes iguales.

Estado (2026-11-22): hecha. 26 presets × 200 situaciones (unas 67 de cada tipo), también Retri con su rotación actual.

Cómo se usa:
1. Opciones > Rota Suite > MIGRACIÓN v2: prender "Grabar situaciones reales" (y "Comparar" cuando la build ya esté migrada).
2. Jugar. Al salir o con `/reload` el juego escribe `WTF/Account/<cuenta>/SavedVariables/RotaCore.lua`.
3. `lua5.1 tools/golden.lua import "<ruta a ese archivo>"` y después `lua5.1 tools/golden.lua check`.
4. Si un caso real no da igual offline, el mock no imita bien al juego en algo: se arregla el mock o se anota en `tools/golden/allowed.lua`.

## Etapa 1: Retri (v1.2.0)

La Retri ya está en reglas. Su evaluador viejo se borró antes de la v1.0.0 y no quedó en git ni en el zip, así que no hay referencia v1. Su referencia es la rotación actual en reglas (grabada en la etapa 0): sirve para que los cambios de la migración no la muevan.

Listo cuando: sus funciones de ayuda pasan al formato nuevo y la referencia sigue sin diferencias.

## Etapa 2: DK, las 4 variantes (v1.3.0)

UH Morb, Morb+SS, UH 2H y Frost. Las funciones de ayuda salen de lo que necesita UH Morb (runas, enfermedades, gárgola, presencias). Las 4 deben coincidir con su referencia.

Listo cuando: las 4 coinciden con su referencia (sin diferencias sin explicar en `tools/golden/allowed.lua`).

## Etapa 3: resto de clases (v1.4.0 en adelante, una versión por clase)

Ordenadas por mecánica parecida, para reusar funciones:
1. Pícaro y Druida feral (energía, combos).
2. Guerrero y Chamán mejora.
3. Brujo, Sombras, Mago, Chamán elemental, Druida equilibrio (dots y procs).
4. Cazador.

Cada clase: coincide con su referencia.

Si las ganas se acaban a mitad de camino: las clases que falten pueden quedarse con el evaluador v1, que sigue funcionando.

## 2.0.0

Cuando todas las specs migradas pasan su referencia: borrar los evaluadores viejos (o no borrarlos nunca), quitar el selector por spec, tag `v2.0.0`. Después, arreglos de la lista "Errores de la v1" en 2.0.x.

## Errores de la v1

(se anotan acá durante la migración)
