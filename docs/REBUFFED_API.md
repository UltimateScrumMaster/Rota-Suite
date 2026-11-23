# Rebuffed: API Lua extendida (referencia basada en pruebas)

Referencia para pasar a otra IA o a quien desarrolle addons con Rebuffed. Cada dato lleva una etiqueta: **\[MEDIDO\]** salió de pruebas en el cliente, **\[DOC\]** viene solo de la documentación oficial de Rebuffed, **\[NO CONCLUYENTE\]** tiene una prueba que no alcanza para afirmar nada.

## 1. Contexto

- Rebuffed extiende la API Lua del cliente de WoW con funciones, eventos y condicionales de macro nuevos.
- Cliente asumido: WotLK 3.3.5 con Lua 5.1. Es una inferencia a partir del addon donde se probó (un addon de rotaciones con DK, Paladín y Guerrero). Conviene confirmarlo con `/run print(GetBuildInfo())`.
- En un cliente sin Rebuffed estas APIs no existen. Toda llamada debe ir con feature detection y `pcall`.
- Las pruebas fueron pocas y casi todas con mobs de un mismo pack. Lo que no se probó está en la sección 11.

## 2. API según la documentación oficial \[DOC\]

**Funciones**

| Función | Descripción oficial |
| --- | --- |
| `C_NamePlate.GetNamePlates()` | Devuelve todas las nameplates visibles |
| `C_NamePlate.GetNamePlateForUnit(unit)` | Obtiene la nameplate de una unidad |
| `UnitIsControlled(unit)` | Verifica si la unidad está controlada |
| `UnitIsSilenced(unit)` | Verifica si la unidad está silenciada |
| `UnitIsDisarmed(unit)` | Verifica si la unidad está desarmada |
| `CopyToClipboard(text)` | Copia texto al portapapeles |
| `GetSpellBaseCooldown(spellId)` | Obtiene el cooldown base de un hechizo |
| `QueueInteract()` | Encola la interacción con un objeto cercano |

**Eventos:** `NAME_PLATE_CREATED` (se crea una nameplate), `NAME_PLATE_UNIT_ADDED` (una unidad obtiene nameplate), `NAME_PLATE_UNIT_REMOVED` (una unidad pierde su nameplate).

**Condicionales de macro:** `@cursor` (lanza un AoE en la posición del mouse) y `@playerlocation` / `@self` (lanza un AoE en la posición del jugador). Ejemplo oficial: `/cast [@cursor] Blizzard`.

La documentación no indica los argumentos de los eventos, los tipos de retorno ni la semántica exacta (por ejemplo, qué cuenta como "controlled").

## 3. Estado de cada API

| API | Existe | Probada | Resultado |
| --- | --- | --- | --- |
| `C_NamePlate.GetNamePlates()` | Sí | Sí | Tabla de frames. La cantidad coincidió con los tokens `nameplateN` existentes en la prueba de 3 mobs (ver sección 4) |
| `C_NamePlate.GetNamePlateForUnit(unit)` | Sí | No | Sin datos |
| `UnitIsControlled(unit)` | Sí | Parcial | `true` con un target silenciado, `false` sin efectos (sección 6) |
| `UnitIsSilenced(unit)` | Sí | Sí | `true` con target silenciado, `false` sin efectos |
| `UnitIsDisarmed(unit)` | Sí | Parcial | Siempre `false`. Nunca se probó con un desarme real |
| `CopyToClipboard(text)` | Sí | Sí | Funciona llamada desde un slash command |
| `GetSpellBaseCooldown(spellId)` | Sí | Sí | Milisegundos (30000 para el spell 49938) |
| `QueueInteract()` | Sí | No | Presente, sin probar |
| Eventos `NAME_PLATE_*` | - | No | Sin datos |
| `@cursor`, `@playerlocation`, `@self` | - | No | Sin datos |

## 4. Nameplates

### 4.1 Unit tokens

- **\[MEDIDO\]** `nameplateN` funciona como unit ID. Respondieron bien con esos tokens: `UnitExists`, `UnitName`, `UnitGUID`, `UnitCanAttack`, `UnitAffectingCombat`, `UnitIsDead` y `UnitIsUnit`. Los retornos son estilo Blizzard (`1` / `nil`), no booleanos. `UnitIsDead` solo se vio devolver `nil` (unidades vivas): no se probó con una muerta.
- **\[MEDIDO\]** Los tokens NO son estables. El mismo GUID apareció con distinto token en dos pasadas (por ejemplo `0xF13000596300004D` fue `nameplate14` y después `nameplate1`). Los índices llegaron a 14 con unas 8 plates visibles, y en otras corridas fueron 1, 2, 3 o 6. Consecuencias: no asumir `1..N`, no cachear el token entre ticks, y usar el GUID como identidad.
- **\[NO CONCLUYENTE\]** El nombre del campo que guarda el token dentro de cada frame de `GetNamePlates()`. El diagnóstico del addon mostró `'nameplate1'`, `'nameplate2'` y `'nameplate6'`, y una vez `'frame'`. No se sabe qué campo leyó ni por qué apareció `'frame'`. No dependas del frame: enumera por tokens (sección 10).
- **\[NO CONCLUYENTE\]** El orden de la lista. El primer elemento cambió entre corridas, pero las condiciones no eran comparables. No asumas orden.

### 4.2 Qué entra en la lista

- **\[MEDIDO\]** La lista trae todas las plates visibles, no solo las relevantes. En una pasada fuera de combate aparecieron 9 plates de mobs ociosos y lejos. En una corrida inicial sin target y fuera de combate el conteo fue 5.
- **\[MEDIDO\]** El conteo crudo no equivale a "enemigos en rango". Con 3 mobs, 2 pegando a distancia y 1 en melee, `GetNamePlates()` devolvió 3. Con 3 mobs enfrente dio 3, y sin mobs dio 0.
- **\[MEDIDO\]** `UnitAffectingCombat` separa los mobs ociosos del pack: en una pasada con mobs lejos, 1 de 8 estaba en combate. En otra con enemigos pegando, 4 de 8. Pero un mob puede estar en combate y lejos, así que el combate no reemplaza al rango.
- **No medido:** si la lista incluye unidades amistosas o neutrales, y cómo influye el CVar `nameplateShowEnemies` (tecla V). Hipótesis: sin nameplates enemigas activadas, no habrá plates enemigas. Verificar antes de depender de eso.

## 5. Rango sobre nameplates

| Función | Resultado con `nameplateN` | Notas |
| --- | --- | --- |
| `IsItemInRange(itemID, u)` | **\[MEDIDO\]** Funciona: `1` dentro, `0` fuera | Items probados: 37727 y 34368. Las yardas son de memoria (\~5 y \~8 yd) y NO están verificadas |
| `CheckInteractDistance(u, 3)` | **\[MEDIDO\]** Funciona: `1` o `nil` | Distancia de duelo, unas 10 yd según la tabla estándar de la API. Es binario |
| `IsSpellInRange("Plague Strike", u)` | **\[NO CONCLUYENTE\]** `nil` en 14 de 14 observaciones | Devuelve `nil` también si el personaje no conoce el hechizo, y no se hizo control con `"target"`. No se puede concluir que no funcione con plates |

Datos de la prueba de rango (columnas: IsSpellInRange, CheckInteractDistance, item 37727, item 34368):

- Fuera de combate, 9 plates ociosas y lejos: `nil nil 0 0` en todas.
- En combate, 5 plates: Dragon Turtle `nil 1 0 1`, y las otras cuatro `nil 1 1 1`.

Los resultados son coherentes entre sí (el item chico queda contenido en el grande), pero no hay verdad independiente: no se anotó qué mob estaba a qué distancia, así que la calibración contra yardas reales está pendiente.

Cadena recomendada: `IsItemInRange` (1 cuenta, 0 no cuenta) -> si da `nil`, `CheckInteractDistance(u, 3) == 1` -> si no hay dato, no contar la unidad. Deja el radio configurable.

## 6. UnitIsControlled / UnitIsSilenced / UnitIsDisarmed

| Situación | Controlled | Silenced | Disarmed |
| --- | --- | --- | --- |
| `player` sin efectos | false | false | false |
| `target` sin efectos | false | false | false |
| `target` silenciado | **true** | **true** | false |

- **\[MEDIDO\]** Devuelven booleanos `true` / `false` (no `1` / `nil`).
- **\[MEDIDO\]** `UnitIsControlled` también fue `true` con un silencio. No es un detector de crowd control puro (stun, fear, sheep). No lo uses solo para excluir un mob de un AoE: un mob silenciado sigue siendo un blanco válido.
- **No probado:** stun, root, fear, polymorph, un desarme positivo, qué silencio concreto se usó, y estas funciones con tokens `nameplateN` u otras unidades que no sean `player` y `target`.

## 7. GetSpellBaseCooldown

- **\[MEDIDO\]** `GetSpellBaseCooldown(49938)` (Death and Decay) devolvió `30000`: milisegundos. Normaliza con `/ 1000`.
- **\[DOC\]** Es el cooldown base. Por nombre y descripción no incluye talentos, glifos ni haste (no se midió). Para el cooldown real sigue siendo `GetSpellCooldown`.
- **No verificado:** si hay un segundo valor de retorno, y qué devuelve para hechizos sin cooldown o inexistentes. Trata `nil` o `0` como "sin dato".

## 8. CopyToClipboard

- **\[MEDIDO\]** Existe y se usó para copiar volcados de diagnóstico que después se pegaron en otro lado, llamada desde un slash command.
- **No probado:** tamaño máximo del texto, caracteres especiales o saltos de línea extremos, y si funciona fuera de un evento del usuario. Conserva un fallback a `print`.

## 9. Eventos y condicionales de macro \[DOC, sin probar\]

- No se sabe qué argumentos entregan los eventos `NAME_PLATE_*` (probablemente el unit token, sin verificar). Como los tokens son inestables, si se usan para mantener un caché, indexa por GUID resuelto en el momento del evento.
- `@cursor` y `@playerlocation` / `@self` apuntan a hechizos de suelo (AoE con click). Nunca se probaron en este cliente.

## 10. Patrón recomendado (Lua 5.1)

Ejemplo para contar enemigos hostiles, en combate y en rango. Adáptalo a tu caso.

```lua
local Compat = { hasPlates = (C_NamePlate and C_NamePlate.GetNamePlates) ~= nil }

-- tokens precalculados: sin crear strings en cada tick
local TOKENS = {}
for i = 1, 40 do TOKENS[i] = "nameplate" .. i end

local function PlateTotal()
  if not Compat.hasPlates then return nil end
  local ok, list = pcall(C_NamePlate.GetNamePlates)
  if not ok or type(list) ~= "table" then return nil end
  local n = #list
  if n == 0 then for _ in pairs(list) do n = n + 1 end end
  return n
end

-- rango: item -> interact -> no contar. 34368 ~8 yd (sin verificar), 37727 ~5 yd
local RANGE_ITEM = 34368
local function InRange(u)
  local r = IsItemInRange(RANGE_ITEM, u)
  if r == 1 then return true elseif r == 0 then return false end
  return CheckInteractDistance(u, 3) == 1
end

local function Evaluate(u, set)
  local guid = UnitGUID(u)
  if guid and UnitCanAttack("player", u) and not UnitIsDead(u)
     and UnitAffectingCombat(u) and InRange(u) then
    set[guid] = true   -- identidad = GUID, nunca el token
  end
end

-- reconstruir en cada tick (con wipe), NO cachear tokens entre ticks
function Compat.CollectPlates(set)
  wipe(set)
  local expected, found = PlateTotal(), 0
  if expected == 0 then return 0, 0 end
  for i = 1, 40 do
    local u = TOKENS[i]
    if UnitExists(u) then
      found = found + 1
      pcall(Evaluate, u, set)
      if expected and found >= expected then break end
    end
  end
  return found, expected   -- found < expected => scan incompleto
end
```

El cap de 40 tokens es arbitrario (el máximo observado fue 14). Cuenta el resultado con `pairs(set)`.

## 11. Pendientes por verificar

Comandos para probar en el juego (uno por vez, con mobs a la vista):

```
/run print(GetBuildInfo())
/run local s="HECHIZO_MELEE_QUE_CONOZCAS" print("target",(IsSpellInRange(s,"target"))) for i=1,40 do local u="nameplate"..i if UnitExists(u) then print(u,(IsSpellInRange(s,u))) end end
/run for k,v in pairs(C_NamePlate.GetNamePlates()[1]) do print(k,type(v),tostring(v)) end
/run local f=C_NamePlate.GetNamePlateForUnit("target") print(f, f and f:GetName())
/run local f=CreateFrame("Frame") f:RegisterEvent("NAME_PLATE_CREATED") f:RegisterEvent("NAME_PLATE_UNIT_ADDED") f:RegisterEvent("NAME_PLATE_UNIT_REMOVED") f:SetScript("OnEvent",function(_,e,...) print(e,...) end)
/run print(GetSpellBaseCooldown(49938))
/run print(UnitIsControlled("target"),UnitIsSilenced("target"),UnitIsDisarmed("target"))
```

- **Build:** confirma 3.3.5.
- **IsSpellInRange con plates:** si el control con `"target"` da `1` / `0` y las plates dan `nil`, entonces de verdad no funciona con plates. Si ambos responden, sirve y es mejor que los items.
- **Campos del frame:** imprime las claves del primer frame para saber dónde está el token.
- **GetNamePlateForUnit:** comprueba si devuelve el mismo frame que está en la lista.
- **Eventos:** mira los argumentos reales que imprimen.
- **Cooldown base:** mira si hay un segundo valor de retorno.
- **CC:** repite el último comando con cada efecto sobre el target (stun, root, fear, polymorph, desarme) y anota qué flag se activa con cuál.
- **Yardas de los items:** pon un mob a distancia conocida y compara `IsItemInRange` con esa distancia.

## 12. Reglas prácticas

- Feature detection y `pcall` en toda llamada a Rebuffed, centralizados en un solo módulo. Si la API no existe, el addon debe comportarse como antes.
- La identidad de una nameplate es su GUID. Los tokens `nameplateN` cambian.
- El conteo crudo de plates no es el conteo de enemigos en rango. Filtra por hostil, vivo, en combate y rango, y deduplica por GUID.
- No uses `UnitIsControlled` solo para decidir si un mob es CC: se activa con silencio.
- No uses `GetSpellBaseCooldown` donde importe el cooldown real.
- Evalúa las plates en un tick con throttle, no en cada frame, y reutiliza tablas con `wipe`.
- No modifiques CVars automáticamente.
