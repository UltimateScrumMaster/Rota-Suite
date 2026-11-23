# Guía de Usuario — Addon Rota Suite (WoW 3.3.5a)

## 1. Instalación
1. Descarga el paquete release generado por `package.sh` (`dist/RotaSuite-v1.0.0-3.3.5a.zip`) o clona este repositorio.
2. Copia las siguientes carpetas a tu directorio `World of Warcraft/Interface/AddOns/`:
   - `RotaCore/` (Requerido: motor central, HUD, minimapa y panel de opciones)
   - `RotaEditor/` (Opcional, interfaz visual interactiva y tutorial bajo demanda)
   - `RotaClass_DK/` (Para jugar con Caballero de la Muerte)
   - `RotaClass_PAL/` (Para jugar con Paladín)
   - `RotaClass_WAR/` (Para jugar con Guerrero)
   - `RotaProbe/` (Opcional, para escanear y diagnosticar servidores custom)
3. Reinicia tu cliente WoW 3.3.5a o recarga la interfaz con `/reload`.

---

## 2. Métodos de Acceso y Tutoriales en el Juego

Rota Suite cuenta con 3 vías de acceso inmediato para no depender de recordar comandos de consola:

### A. Botón en el Minimapa
Un icono circular con borde estándar de rastreo de WoW en el minimapa:
- **Clic Izquierdo:** Abre / Cierra el **Editor Visual** (`RotaEditor`).
- **Clic Derecho:** Abre el **Panel de Opciones y Tutorial de Blizzard** (`ESC -> Interfaz -> AddOns -> Rota Suite`).
- **Shift + Clic:** Abre la ventana de diagnóstico **RotaProbe** (si está cargado).
- **Arrastrar:** Haz clic y arrastra con el ratón para rotar el icono alrededor del borde del minimapa (la posición se guarda automáticamente).

### B. Menú de Opciones de Blizzard (`ESC -> Interfaz -> AddOns -> Rota Suite`)
Integración nativa con la pestaña de AddOns del juego:
- **Estado de la Suite:** Versión, clase actual, spec y perfil activo.
- **Acciones Rápidas:** Botones para `[Abrir Editor Visual]`, `[Escanear Sonda]`, `[Ver Sonda]` y `[Resetear Posición HUD]`.
- **Casillas de Ajustes:**
  - *Bloquear posición del HUD:* Permite fijar o desbloquear los iconos en pantalla para reposicionarlos.
  - *Mostrar botón del minimapa:* Activa o desactiva la visibilidad del botón circular.
- **Guía Rápida & Tutorial:** Resumen completo con comandos, atajos y funcionamiento.

### C. Pestaña 5 del Editor: Tutorial Interactivo
Al abrir `/rc edit`, la **Pestaña 5 (Tutorial)** ofrece un manual interactivo navegable con 5 módulos:
1. **Inicio Rápido & HUD:** Qué hace cada icono (Main vs Off-GCD) y cómo configurar el HUD.
2. **RotaProbe (Servidores Custom):** Instrucciones paso a paso para escanear y reportar hechizos/talentos en servidores privados.
3. **Editor de Bloques & Código:** Cómo personalizar prioridades y escribir reglas de Ovale.
4. **Mecánicas de Clases:** Explicación técnica de runas/grace period (DK), sellos y Art of War (Paladín), y encolado On-Next-Swing / Ira (Guerrero).
5. **Comandos Slash:** Referencia completa de consola.

---

## 3. Comandos en el Chat (Slash Commands)
- `/rc` o `/rota` — Muestra el estado del addon y comandos disponibles.
- `/rc options` — Abre directamente el panel de opciones en la interfaz de Blizzard.
- `/rc edit` o `/rotaedit` — Abre el Editor Visual Interactivo (Bloques / Código / Overrides / Simulador / Tutorial).
- `/rc tutorial` o `/rc help` — Abre el Editor Visual directamente en la pestaña del Tutorial.
- `/rc lock` — Alterna el bloqueo/desbloqueo de los iconos del HUD para moverlos con el cursor.
- `/rc reset` — Restaura la posición de los iconos del HUD al centro de la pantalla.
- `/rotaprobe scan` — Ejecuta un escaneo profundo de talentos y spellbook en servidores custom.
- `/rotaprobe show` — Abre la ventana de visualización y exportación de datos de RotaProbe.

---

## 4. Funcionamiento de los Iconos HUD
El addon muestra dos marcos visuales optimizados (0 KB/s de memoria en combate):
1. **Icono Principal (`mainIcon`):**
   - Muestra la **siguiente habilidad a lanzar en Global Cooldown (GCD)**.
   - Evalúa opener sequences (si están activas) y luego la lista de prioridad principal de arriba hacia abajo.
2. **Icono Secundario (`offIcon`):**
   - Muestra habilidades que están **fuera del GCD** (cooldowns de daño, mitigación) o habilidades **On-Next-Swing** (como Heroic Strike o Cleave).
   - Incluye comprobación automática para no sugerir la habilidad si ya está en cola de ataque.

---

## 5. Uso del Editor Visual (`/rc edit`)

### Pestaña 1: Árbol de Bloques (Estilo TinkerCAD)
- Permite ver todas las reglas de la rotación activa en forma de bloques legibles.
- **Reordenar:** Usa los botones `^` (subir) y `v` (bajar) para cambiar la prioridad relativa de cada habilidad.
- **Activar / Desactivar:** Haz clic en `[ON]` / `[OFF]` para desactivar temporalmente una regla sin borrarla.
- **Agregar / Eliminar:** Añade nuevas reglas o elimina las obsoletas.

### Pestaña Código
- Todas las reglas de la rotación como texto (`if <condición> then return "ACCION" end`).
- **Guardar cambios:** aplica lo que escribiste. **Recargar:** descarta lo que no guardaste.
- Funciones disponibles: `docs/FUNCIONES.md` o la pestaña Ayuda.

### Pestaña IDs de hechizos
- Para servidores donde un hechizo tiene otro ID: escribí el ID correcto en esa fila.
- Lo que cargues ahí tiene prioridad sobre el libro de hechizos.

### Pestaña Ayuda
- Manual interactivo integrado con navegación por tópicos explicativos.

---

## 6. Soporte para Dual Spec
El addon detecta automáticamente el cambio de especialización de talentos (`ACTIVE_TALENT_GROUP_CHANGED`) y cambia de perfil sin requerir recargar la interfaz ni reiniciar el juego.
