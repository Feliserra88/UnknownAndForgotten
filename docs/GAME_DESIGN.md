# Diseño de juego — U&F (Unknown & Forgotten)

Documento de referencia obligatorio para mecánicas, sistemas de juego y contenido jugable.
Complementa `docs/ARCHITECTURE.md` (código) con las reglas de **qué** debe hacer el juego.

---

## 1. Visión general

- **Género**: RPG 2,5D con vista isométrica, movimiento en rejilla **x/y/z** (cada celda puede tener distinta altura).
- **Mundo**: generación procedural como norma; zonas y estructuras clave definidas a mano.
- **Entidades**: NPCs organizados por arquetipos jerárquicos y capas de facción independientes.
- **Herramientas de artista**: módulos de alto reuso + fine-tuning manual → editor dedicado (§11).
- **Identificadores en código**: siempre en **inglés** (ver reglas de coding style).

---

## 2. Navegación y cámara

### 2.1 Stack Godot: vista isométrica 2,5D

Godot trata el isométrico como **tilemap 2D con forma diamante**, no como cámara 3D inclinada. Referencias oficiales: [Using TileSets](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html), [Using TileMaps](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html), demo **2D Isometric Demo**.

| Componente Godot | Uso en U&F |
|------------------|------------|
| `TileMapLayer` | Capas de mapa (suelo, decoración, colisiones). **No** usar el nodo `TileMap` legacy. |
| `TileSet` con `tile_shape = TILE_SHAPE_ISOMETRIC` | Proyección isométrica y tamaño de celda (`tile_size`). |
| `y_sort_enabled = true` | Orden de dibujado por profundidad en capas y padres `Node2D` (requerido en isométrico). |
| `Camera2D` | Pan sobre el plano 2D; **vista fija** (sin rotación libre; alineada al editor y `DIAMOND_DOWN`). |
| `map_to_local()` / `local_to_map()` | Conversión celda ↔ posición en mundo (`TileMapLayer`). |

La **inclinación isométrica** queda definida por el `TileSet` y el arte de tiles, no por inclinar una cámara 3D.

**Layout de celda (`tile_layout`):** el proyecto usa **`TILE_LAYOUT_DIAMOND_DOWN`** (vértice del rombo arriba/abajo). Cambiar a **`DIAMOND_RIGHT`** es posible en Godot pero **arriesgado** en U&F sin un sprint dedicado:

| Área afectada | Riesgo |
|---------------|--------|
| Placeholder y arte Pixelorama | Redibujar o reexportar todos los atlas isométricos |
| `map_to_local` / `local_to_map` / `AStarGrid2D.cell_shape` | Convenciones de eje x/y cambian de orientación |
| `uf_map_editor` overlay de altura | Geometría del rombo en `height_overlay.gd` asume `DIAMOND_DOWN` |
| Mapas guardados en escenas | Requiere re-pintar o migrar si el layout no coincide |
| NPC orientación 8 vías | Convención N/S/E/O respecto a la rejilla puede desalinearse |

**Recomendación:** mantener `DIAMOND_DOWN` hasta que haya motivo artístico fuerte; si se cambia, hacerlo como **migración de proyecto** (TileSet + arte + docs + editor + pruebas de movimiento), no como toggle aislado.

### 2.2 Cámara: pan y rotación (inclinación/zoom fijos)

Implementar un **rig de cámara** (`Node2D` padre + `Camera2D` hijo):

| Requisito de diseño | API / propiedad Godot |
|---------------------|------------------------|
| Traslación (pan) | Mover el rig (`Node2D.position`) o `Camera2D.offset` (botón central del ratón) |
| Rotación de vista | **Fija a 0°** — misma orientación que el viewport del editor y el pintado en `TileMapLayer`. Sin Q/E en runtime. |
| Inclinación fija | No variable: proyección fijada por `TileSet` isométrico |
| Zoom fijo | `Camera2D.zoom` constante (p. ej. `Vector2(1, 1)`); sin zoom libre salvo cambio documentado |
| Suavizado opcional | `position_smoothing_enabled` (rotación desactivada) |
| Límites de mapa | `Camera2D.limit_*` acordes al `region` del mapa generado |

**Prohibido** reinventar proyección isométrica manual si el `TileSet` ya la proporciona. Para lógica de juego usar coordenadas **`Vector3i(x, y, z)`** (§3.1); la presentación proyecta `(x, y)` con `map_to_local()` y aplica offset visual por `z`.

### 2.3 Capas de mapa

Varias `TileMapLayer` compartiendo el mismo `TileSet` (recurso externo `.tres`):

| Capa sugerida | Contenido |
|---------------|-----------|
| `ground` | Suelo / bioma base |
| `terrain` | Autotiling de terreno y transiciones |
| `objects` | Obstáculos, decoración interactiva |
| `structures` | Prefabs pintados o estampados (`TileMapPattern`, scene tiles) |

---

## 3. Rejilla, altura y movimiento

### 3.1 Coordenadas del mapa (`x`, `y`, `z`)

Todo mapa/escenario usa coordenadas lógicas **`Vector3i(x, y, z)`**:

| Eje | Significado | Godot |
|-----|-------------|-------|
| **x**, **y** | Celda en el plano del mapa (columna/fila de rejilla) | `TileMapLayer` — `Vector2i`, `set_cell()`, `local_to_map()` |
| **z** | **Altura** de la superficie jugable en esa celda (entero; distintas celdas → distinto `z`) | No nativo en `TileMapLayer`; módulo `world` → `MapHeightField` |

- Cada **tile** en `(x, y)` tiene un **`z` de superficie** (altura del suelo transitable en esa columna).
- Variaciones de relieve, plataformas y desniveles se expresan cambiando `z` entre celdas adyacentes.
- Convención: **`z` entero**; un paso de altura = `height_step` unidades visuales (config en `venv.ini` / Resource de mundo).
- Alias de diseño: **`GridCell`** = `Vector3i` o Resource fino con `cell: Vector3i`.

**Almacenamiento (no duplicar el tilemap):**

| Dato | Dónde |
|------|--------|
| Tipo de tile, terrain, colisión | `TileMapLayer` en `(x, y)` |
| Altura `z` por celda | **`MapHeightField`** (`Resource` o buffer en módulo `world`) indexado por `Vector2i` |
| Metadatos de tile (daño, destructible…) | Custom data layers del `TileSet` ([Using TileSets](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html)) |

Sincronizar altura visual con Godot:

- Offset de posición: `map_to_local(Vector2i(x, y))` + **`z * height_step`** en Y (o eje acordado al isométrico).
- **`y_sort_enabled`** + `y_sort_origin` del tile / capa ([TileMapLayer.y_sort_origin](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)) para separar niveles en profundidad.
- **Orden isométrico (misma `z`):** todos los `TileDef` de celda (ground, terrain, objects, structures) se pintan en la capa **`Ground`** para que el y-sort sea **por coordenada de rejilla**, no por orden de pintado ni por orden de capas en el árbol. Ancla de sort en el **pie del rombo** (`y_sort_origin = tile_size.y / 2`): a igual altura lógica, la celda con **mayor `y` de mapa** se dibuja delante (más cerca de la cámara en `DIAMOND_DOWN`).
- Opcional: `TileMapLayer._tile_data_runtime_update()` para ajustar `TileData` por celda al pintar.

**Editor (`uf_map_editor`):** en modo *Edit height*, overlay sobre el viewport 2D: tinte por celda (azul = `z>0`, rojo = `z<0`, etiqueta con el valor `z`, borde amarillo en la celda bajo el cursor). Implementación en `addons/uf_map_editor/height_overlay.gd`; datos siguen en `MapHeightField`.

### 3.2 Estructura del mapa (`TileMapLayer`)

- Plano **x/y**: rejilla `Vector2i` gestionada por una o más `TileMapLayer`.
- Plano **z**: campo de alturas **`MapHeightField`** paralelo, misma región que el mapa.
- Movimientos válidos por defecto: **up**, **down**, **left**, **right** en **x/y** (4 direcciones).
- Transiciones en **z**: subir/bajar escalones solo si la regla de movimiento lo permite (p. ej. `|Δz| ≤ max_climb` hacia celda vecina).
- No asumir movimiento diagonal en x/y salvo mecánica o rasgo que lo habilite.

### 3.3 Pathfinding y colisión en rejilla

Usar APIs nativas alineadas con el isométrico:

| Sistema | API Godot | Configuración U&F |
|---------|-----------|-------------------|
| Pathfinding base | `AStarGrid2D` | Plano **x/y**; `diagonal_mode = DIAGONAL_MODE_NEVER`, `HEURISTIC_MANHATTAN` |
| Altura en rutas | Módulo `grid` | Tras `get_id_path()`, filtrar/ponderar vecinos según `MapHeightField` y `max_climb` |
| Forma de celda | `AStarGrid2D.cell_shape` | `CELL_SHAPE_ISOMETRIC_*` alineado al `TileSet` |
| Tamaño / offset | `cell_size`, `offset` | Igual que `TileSet.tile_size` |
| Celdas bloqueadas | `set_point_solid()` | Según tiles + celdas sin superficie / `z` intransitable |
| Colisión | Physics layers del `TileSet` | Por capa `(x, y)`; validar `z` en lógica de movimiento |

`AStarGrid2D` no modela **z** nativamente: el grafo es 2D; la **altura** se resuelve en `grid`/`movement` al evaluar aristas entre celdas `(x,y)` usando el `z` de cada una.

Tras modificar `region` o `cell_size`: llamar `AStarGrid2D.update()`.

Tutorial: [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html).

### 3.4 Posicionamiento visual (x, y, z)

```gdscript
## Convierte celda lógica 3D a posición 2D en el mundo isométrico.
func grid_to_world(cell: Vector3i) -> Vector2:
	var base := tile_map.map_to_local(Vector2i(cell.x, cell.y))
	return base + Vector2(0, -cell.z * height_step)  # convención; fijar al implementar
```

NPCs, props y efectos usan **`Vector3i`**; nunca asumir `z = 0` salvo mapa explícitamente plano.

### 3.5 Dirección y orientación del personaje

Los personajes tienen **orientación** independiente de la posición en celda:

| Orientación | Descripción |
|-------------|-------------|
| `front` | Hacia la cámara / sur lógico de la rejilla |
| `front_right` | Diagonal SE (sur + este) |
| `side_right` | Perfil derecho (este) |
| `back_right` | Diagonal NE (norte + este) |
| `back` | Espalda al observador (norte) |
| `back_left` | Diagonal NW (norte + oeste) |
| `side_left` | Perfil izquierdo (oeste) |
| `front_left` | Diagonal SW (sur + oeste) |

Hoja idle 8 vías (export Pixelorama): columnas 0–7 = S, SE, E, NE, N, NW, W, SW.

- Animaciones walk por orientación cuando exista hoja dedicada; si no, idle de esa orientación.
- Al cambiar de celda, la orientación sigue la dirección del paso (8 vías en demo del personaje principal).
- **Movimiento del jugador (`DIAMOND_DOWN`):** WASD es pantalla (arriba/abajo/izq/der); el paso en rejilla usa `Direction.to_isometric_step()` (p. ej. W → celda `(-1,-1)` visualmente arriba). Pathfinding y reglas de tile siguen brújula de mapa (`Direction.to_vector()`).
- Posicionar con `grid_to_world(grid_cell)` (§3.4), no solo `map_to_local(Vector2i)`.

---

## 4. Generación de mundo

### 4.1 Principio general: procedural con APIs de `TileMapLayer`

El mapa se **genera proceduralmente** en runtime (o en editor vía tool script) escribiendo celdas en `TileMapLayer`. Salvo excepciones (§4.3, §4.4).

**No** duplicar el almacenamiento de tiles del `TileMapLayer`; **sí** mantener **`MapHeightField`** para `z` (Godot no guarda altura por celda en el mapa 2D).

Componentes:

| Capa de diseño | API / recurso Godot |
|----------------|---------------------|
| Biomas | `FastNoiseLite` / `Noise` + reglas → terrains del `TileSet` |
| **Relieve / altura `z`** | Ruido 2D/3D (`get_noise_2d`, `get_noise_3d`) o máscaras → **`MapHeightField`** |
| Encaje de tiles | **Terrains** (autotiling) del `TileSet` |
| Ruido / distribución | `FastNoiseLite` con `seed` reproducible |
| Escritura masiva | `set_cells_terrain_connect()`, `set_cell()`, `set_pattern()` + **`MapHeightField.set_height(x, y, z)`** |
| Estructuras manuales | `TileMapPattern`, scene tiles del `TileSet` |

Referencias: [Using TileSets — terrains](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html), [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html), [FastNoiseLite](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html).

### 4.2 Biomas y terrains (autotiling)

Cada bioma define:

- Identificador (`forest`, `desert`, `swamp`, …).
- Restricciones de colocación (umbrales sobre ruido, máscaras manuales, etc.).
- **Terrain ID** dentro de un `terrain_set` del `TileSet` (no tiles sueltos sin terrain).
- Reglas de transición entre biomas/terrenos (terrains adyacentes con peering bits configurados en el atlas).
- Cualidades particulares (spawn tables, peligros, recursos) como datos en `Resource`.

**Encaje automático de tiles** — flujo Godot recomendado:

1. Configurar **terrain sets** y **terrains** en el `TileSet` (modos `Match Corners`, `Match Sides`, etc.).
2. Asignar peering bits a cada atlas tile.
3. En generación, acumular celdas por terrain y llamar:

```gdscript
## Rellena celdas con autotiling de transiciones.
tile_map_layer.set_cells_terrain_connect(cells, terrain_set_id, terrain_id)
```

Para trazados lineales (caminos, ríos): `set_cells_terrain_path(path, terrain_set_id, terrain_id)`.

Distribución procedural típica (x/y + z):

```gdscript
var noise := FastNoiseLite.new()
noise.seed = generation_seed
for x in region.size.x:
	for y in region.size.y:
		var z := int(noise.get_noise_2d(x, y) * max_height)
		height_field.set_height(Vector2i(x, y), z)
		if biome_noise.get_noise_2d(x, y) > biome_threshold:
			forest_cells.append(Vector2i(x, y))
ground_layer.set_cells_terrain_connect(forest_cells, 0, TerrainId.FOREST)
```

### 4.3 Directrices y zonas a mano

- Existen **directrices de alto nivel** o **máscaras/zonas** diseñadas a mano que determinan dónde empieza y termina un bioma.
- Estas zonas **acotan** el generador (p. ej. umbral de ruido forzado, `Image` de máscara leída celda a celda) sin sustituir terrains ni `set_cells_terrain_connect`.
- Formato recomendado: recursos editables (`BiomeZone`, imagen en `assets/world/masks/`) versionados en repositorio.

### 4.4 Estructuras a mano

| Tipo | API Godot | Uso |
|------|-----------|-----|
| Fragmentos de mapa repetibles | `TileMapPattern` + `get_pattern()` / `set_pattern()` | Dungeons, cuevas, bloques de ciudad |
| Construcciones con nodos | **Scene tiles** (Scenes Collection en `TileSet`) | Ciudades, edificios con lógica (`Area2D`, NPCs spawners) |
| Prefabs completos | Escena instanciada + anclaje a celda vía `map_to_local()` | Estructuras grandes fuera del tilemap |

- Scene tiles: mayor coste por instancia; reservar para estructuras interactivas ([Using TileSets — scenes collection](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html)).
- Patrones: reutilizables entre mapas porque se guardan en el `TileSet` externo.

### 4.5 Motor de generación de escenario (`world_gen`)

Debe ser **suficientemente flexible** para describir un mapa mediante:

```
Bioma X + área/forma
  + 0..N tipos de estructura fija
    cada tipo con apariciones 1..M (p. ej. 3× cave, 1× city)
```

El motor (módulo `world_gen`) orquesta la API de `TileMapLayer`; no duplica su almacenamiento de celdas.

Parámetros mínimos por solicitud de generación:

| Parámetro | Descripción |
|-----------|-------------|
| `biome_id` | Bioma dominante → `terrain_id` / reglas de ruido |
| `area` | `Rect2i region` (x/y) + rango `z_min`/`z_max` opcional |
| `structures[]` | `{ structure_id, min_count, max_count, placement_rules }` |
| `seed` | Semilla para `FastNoiseLite` y RNG de colocación |
| `hand_zones` | Máscaras/zonas manuales opcionales |

Pipeline:

1. Resolver límites de bioma (ruido + máscaras manuales).
2. Generar **`MapHeightField`** (`z` por celda x/y).
3. Rellenar terrains en `TileMapLayer` según bioma y, si aplica, bandas de altura.
4. Colocar estructuras con `set_pattern()` y/o scene tiles (con `z` de anclaje).
5. Sincronizar `AStarGrid2D` y reglas de escalado (`max_climb`).
6. Validar mapa jugable (conectividad 3D en x/y/z, spawn points).
7. Opcional: `notify_runtime_tile_data_update()` / `_tile_data_runtime_update()` si se ajusta `TileData` por celda.

**WFC u otros algoritmos** solo si terrains de Godot no cubren el caso; deben escribir resultado final en `TileMapLayer`.

### 4.6 Modelo de tile (`TileDef`)

El tile es un `Resource` reutilizable (`class_name TileDef`, `.tres` en `res://assets/world/tiles/`). Propiedades:

| Propiedad | Tipo | Función |
|-----------|------|---------|
| `id`, `display_name_key` | `StringName`, clave i18n | Identidad y nombre localizado |
| `tags` | `@export_flags` (bitmask) | Tipos **no exclusivos**: `Ground, Walkable, Wall, Water, Hazard, Interactable, Cover, VisionBlocker` (ver `TileTags`). Un tile combina varios |
| `side_rules` | `TileSideRules` | Reglas **por lado** (índice N/E/S/W): `passable[]`, `blocks_vision[]`, `provides_cover[]`. Ej.: puerta abierta transitable N/S pero no E/O; muro que tapa visión solo por un lado |
| `placement_rule` | `TilePlacementRule` | Restricciones para generación procedural (§4.6.1) |
| `allowed_modifiers` | `Array[TileModifierDef]` | Modificadores aplicables (§4.6.2) |
| `art_texture` | `Texture2D` | Sprite isométrico opcional (suelo plano o prop) |
| `y_sort_origin_offset` | `int` | Ancla Y-sort en el pie del sprite (`objects`) |
| `placeholder_color` | `Color` | Diamante placeholder; sustituible por arte |
| `source_id`, `atlas_coords` | int, `Vector2i` | Mapeo al `TileSet` (asignado al construir el atlas) |

Consultas de comportamiento (fachada `world`): `is_walkable_from(dir)`, `blocks_vision_from(dir)`, `provides_cover_to(dir)` combinan `tags` y `side_rules` (las reglas por lado prevalecen cuando existen). `world.can_move(from, dir)` valida además `|Δz| ≤ max_climb` contra `MapHeightField`.

#### 4.6.1 Restricciones de colocación (`TilePlacementRule`)

| Campo | Uso |
|-------|-----|
| `forbid_isolated` | Rechaza tiles sueltos (p. ej. agua) |
| `min_cluster_size`, `max_cluster_size` | Tamaño del cuerpo (p. ej. agua entre 6 y 24) |
| `roundness_min` (0..1) | Compacidad mínima → cuerpos **redondeados** |
| `is_linear`, `min_collinear_neighbors` | Trazados lineales (camino = 2 vecinos: delante/detrás) |
| `allowed_neighbors`, `forbidden_neighbors` | Adyacencias permitidas/prohibidas |

El generador (`world_gen`) **coloca** respetando estas reglas (blobs redondeados para agua, polilíneas conectadas para caminos) y luego **valida**, emitiendo `Log.warn` si un cuerpo queda fuera de rango/forma o un camino tiene celdas mal conectadas.

#### 4.6.2 Modificadores de tile (`TileModifierDef`)

Estados opcionales sobre un tile (`mojado`, `nevado`, `ardiendo`): **dato + overlay visual**.

- Dato: `adds_tags` (p. ej. ardiendo añade `Hazard`), `movement_cost_mult`, `permanent`.
- Visual: `overlay_texture` (sprite PixelLab con alpha) o `overlay_color` (diamante tintado placeholder) en la capa `modifiers` (`TileMapLayer` propia). El suelo de la celda **no** se sustituye.
- Aplicación runtime vía `world.add_modifier(cell, def)` / `clear_modifiers(cell)`; el dato y el overlay van juntos.

**Terreno vs modificador:** agua de estanque / muro / arbusto = `TileDef` (celda completa). Charco, nieve, quemado o guijarros dispersos = `TileModifierDef` (overlay sobre hierba u otro suelo).

#### 4.6.3 Capas de arte (qué va en cada `TileMapLayer`)

| Capa | Contenido permitido | Prohibido |
|------|---------------------|-----------|
| `ground` | Suelo base **plano y seamless** (hierba, tierra) — solo la cara superior del diamante isométrico | Objetos centrados, bloques 3D con paredes laterales, decoración que rompe el tileado |
| `terrain` | Features de terreno pintadas celda a celda (agua plana provisional, caminos) o **Wang autotile** (§4.6.4) | Muros altos, arbustos |
| `objects` | Props **altos** con `y_sort_origin_offset` en el pie (muros, arbustos, puertas) | Suelo repetible, overlays de estado |
| `Props` (`Node2D`) | Sprites libres altos (árboles, rocas) con offset aleatorio y `y_sort` | Tiles de suelo |
| `Decor` (`Node2D`) | Sprites decorativos sin gameplay (guijarros, flores) con offset/escala aleatorios | Modificadores con efecto |
| `modifiers` | Overlays de gameplay (`wet` en bordes de agua, `burning`) | Sustituir el tile de suelo |

**Generación (`world_gen`):**

- `BiomeDef.scatter_props` → capa `Props` (`world.add_prop()`).
- `BiomeDef.scatter_decor` → capa `Decor` (`world.add_decor()` con offset aleatorio).
- `BiomeDef.scatter_tiles` → capa `objects` (legacy: tiles con tags de gameplay).
- `BiomeDef.terrain_regions` → Wang en `terrain` (`world.paint_terrain()`).
- Bordes de agua → modificador `wet` (gameplay + overlay opcional).

Arte archivado / descartado (bloques 3D, props mal tileables) → `res://local/art/` (gitignored); el usuario puede extraer sprites sueltos.

#### 4.6.4 Wang autotile (cuerpos de agua y transiciones)

**Wang tiling** (también *corner autotiling*): cada variante de tile depende de qué vecinos (N/E/S/W o esquinas) comparten el mismo terreno. Godot lo modela con **Terrain sets** en el `TileSet`: peering bits + `set_cells_terrain_connect()`.

**Cuándo usarlo en U&F:**

| Caso | Herramienta arte | Runtime Godot |
|------|------------------|---------------|
| Suelo uniforme (hierba, tierra) | PixelLab `create_isometric_tile` — cara plana `thin tile` | `set_cell()` en `ground` |
| Charcos, nieve, guijarros | `create_map_object` o tinte placeholder | `modifiers` + `add_modifier()` |
| Props altos (árbol, roca) | `create_map_object` (`low top-down`, lineless) | `Props` + `MapPropDef` |
| Decor sin efecto (flor, guijarro) | `create_map_object` pequeño | `Decor` + `MapDecorDef` |
| **Agua, caminos, suelos interiores, cuevas** | PixelLab **`create_topdown_tileset`** encadenado | `terrain` + `TerrainRegionDef` + `paint_terrain()` |
| **Paredes / bordes de estructura** | Wang `grass→stone_floor`, `stone_floor→wall` | Mismo pipeline; varias regiones en `BiomeDef` |

**Por qué no bloques isométricos para agua:** un tile tipo *block* con paredes laterales deja costuras visibles al repetir celdas; el agua debe ser superficie plana con transiciones Wang hacia hierba/tierra.

**Flujo recomendado (PixelLab → Godot):**

1. Generar tile base seamless (`grass.png`, seed `42001`, `lineless`).
2. `create_topdown_tileset` con `transition_description` (p. ej. *shallow pond water meeting grass*) y `lower_base_tile_id` apuntando al set de hierba.
3. Descargar `metadata` + `image` → `tools/pixellab_wang_converter.gd` → `assets/world/terrains/field_combined.tres`.
4. Asignar en `TerrainSetDef` (`field_terrain_set.tres`) y mapear `terrain_ids` (`grass`, `water`, `dirt_path`, `stone_floor`, `cave_floor`, `wall`).
5. `BiomeDef.terrain_regions` declara cada feature (`water`, `path`, futuras `cave`, `house_interior`) con `TerrainRegionDef`.
6. Generador: blobs o paths → `world.paint_terrain()`; si falta tileset Wang, fallback a `set_tile()` legacy.

**Casos extendidos (misma API):** estanques (`water`), caminos (`dirt_path`), plataformas de piedra (`stone_floor`), suelos de cueva (`cave_floor`), perímetros de muro (`wall` como terreno alto o capa `objects`).

#### 4.6.5 Sprites de mapa (`MapPropDef`, `MapDecorDef`)

| Recurso | Capa | Offset | Gameplay |
|---------|------|--------|----------|
| `MapPropDef` | `Props` | `offset_spread` aleatorio | Opcional: `tags`, `blocks_cell` |
| `MapDecorDef` | `Decor` | `offset_spread` + `scale_range` | Ninguno (solo visual) |

Catálogo: `field_sprite_catalog.tres`. API: `world.add_prop()`, `world.add_decor()`.

#### 4.6.6 Kits modulares (`StructurePieceDef`, `StructureCatalog`)

Piezas verticales de edificio (pared, puerta, teja…) colocadas a mano en el editor como puzzle. **Suelos** del kit siguen siendo `TileDef` en `ground`; **piezas** son sprites en `Props` con meta `uf_kind=structure`.

**Layout de carpetas y PNG:** regla Cursor `world-assets-layout.mdc` (`structures/<kit>/floors/` + `pieces/`, cada uno con `art/`).

| Recurso | Capa | Placement | Gameplay |
|---------|------|-----------|----------|
| `StructurePieceDef` | `Props` | ancla en celda + `footprint` + `y_sort_origin` | Opcional: `blocks_cell`, `connect_hints` (solo editor) |
| `StructureCatalog` | — | lista de piezas por `kit_id` | — |

Catálogo ejemplo: `assets/world/structures/dark_medieval_wood/dark_medieval_wood_catalog.tres`. API: `world.add_structure_piece()`, `world.remove_structure_piece_at()`. Editor: `uf_map_editor` modo *Place structure piece* (clic izq. coloca, der. borra).

Arte PixelLab: suelos → `create_isometric_tile`; piezas verticales → `create_map_object` (ver `pixellab-art.mdc`).

#### 4.6.7 Regiones Wang (`TerrainSetDef`, `TerrainRegionDef`)

- `TerrainSetDef`: `tileset` + `terrain_ids` (nombre lógico → índice Godot).
- `TerrainRegionDef`: `terrain_set_id`, `terrain_name`, `placement_kind` (`BLOB` | `PATH`), `placement_rule`, contadores.

Assets: tiles en `res://assets/world/tiles/` + `tiles/art/`; props `props/` + `props/art/`; decors `decors/art/`; kits de edificio `structures/<kit>/` con `floors/` (`TileDef` + `art/`) y `pieces/` (`StructurePieceDef` + `art/`); Wang `terrains/wang/`; catálogos raíz `field_catalog.tres`, `field_sprite_catalog.tres`; terreno `terrains/field_terrain_set.tres`.

**Arte PixelLab (campo *field*):** seed **`42001`**, outline **`lineless`**. Reglas: `world-assets-layout.mdc`, `pixellab-art.mdc`, `world-map.mdc`; MCP https://api.pixellab.ai/mcp/docs .

---

## 5. NPCs — arquitectura Godot

Godot **no incluye** un sistema de NPC/RPG (arquetipos, facciones, stats). El enfoque oficial equivalente a *ScriptableObjects* es: **`Resource` custom + escenas `PackedScene` + composición**, con escenas autocontenidas y señales para comunicación ([Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)).

### 5.1 Objetivo

Sistema **flexible y escalable** para añadir personajes sin reescribir la base. El **jugador** es un NPC con la misma escena base, otro `NpcArchetype` y el grupo `"player"` (módulo `player` añade input y reglas propias).

### 5.2 Tres capas (definición / instancia / nodo)

| Capa | Tipo Godot | Persistencia | Mutabilidad | Contiene |
|------|------------|--------------|-------------|----------|
| **Definición** | `Resource` (`.tres`) | Disco, compartido | Solo diseño/balance | Arquetipo, facción, item, efecto, stats base |
| **Instancia runtime** | `RefCounted` o `Resource.duplicate(true)` | Memoria | Por NPC | Vitals, inventario, cooldowns, IDs |
| **Presentación** | Escena (`Node2D`…) | `.tscn` | Transform, animación | Sprites, `AnimationTree`, colisión, audio |

**Regla crítica:** los `.tres` cargados con `load()`/`preload()` son **compartidos**. Nunca mutar un `.tres` de definición en runtime. Al spawn: clonar plantillas con `.duplicate(true)` o construir un `NpcInstanceData` (`RefCounted`).

### 5.3 Taxonomía de arquetipos (datos, no herencia profunda de scripts)

La jerarquía conceptual se modela como **árbol de Resources**, no como cadena larga de `extends` en GDScript:

```
NpcArchetype (Resource)
├── humanoid.tres
│   ├── archer.tres
│   └── warrior.tres
├── beast.tres
└── animal.tres
    ├── quadruped.tres
    │   ├── dog.tres
    │   └── wolf.tres
    └── bipedal.tres
```

Cada `NpcArchetype` (`class_name NpcArchetype extends Resource`):

- `id: StringName`
- `parent: NpcArchetype` — herencia de datos (stats, slots, escena por defecto)
- `display_name_key: String`
- `scene: PackedScene` — escena visual/comportamiento (override del padre si vacío)
- `base_attributes: AttributeSet`
- `base_vitals: VitalsTemplate`
- `body_part_map: BodyPartMap` — slots **anatómicos** del rig (cabeza, brazos…)
- `equipment_slot_map: EquipmentSlotMap` — slots de **objeto** equipable (§7.1); distinto de `body_part_map`
- `inspection_layout: InspectionLayoutDef` — silueta + posiciones de slots para `UfInspectionPanel` (§5.5.5)
- `tags: Array[StringName]` — p. ej. `humanoid`; compatibilidad de items y agrupación
- `default_factions: Array[StringName]` — ids de facción por defecto (resueltos vía `FactionModule`)
- `default_traits: Array[StringName]` — ids de rasgo (legacy; preferir `default_modifiers` con `kind = TRAIT`)
- `default_modifiers: Array[StringName]` — ids de `ModifierDef` aplicados al spawn (traits, scalers…)

Resolver valores efectivos en el módulo `npc`: recorrer `parent` hasta la raíz (`resolve_*`). Facciones y modificadores se referencian **por id**; las fachadas `FactionModule` / `ModifierModule` / `EquipmentModule` se inyectan en `NpcModule.set_facades()` (desacoplamiento; `spawn()` funciona sin ellas).

### 5.4 Escena base de NPC (rig modular)

Escena recomendada `res://scenes/npc/npc_base.tscn`. El NPC debe ser **modular**: partes del cuerpo, equipo y lesiones se **equipan/desequipan** en runtime sin cambiar de escena.

**Patrón Godot recomendado:** [Cutout animation](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html) — piezas independientes (`Sprite2D` / `AnimatedSprite2D`) por **slot anatómico**, opcionalmente bajo `Skeleton2D`/`Bone2D` si el arquetipo lo necesita ([2D skeletons](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html)). Usar **`RemoteTransform2D`** cuando el orden de dibujado (casco delante/detras) no coincida con la jerarquía de huesos.

```
NpcRoot (Node2D)                         # y_sort_enabled = true
├── NpcAppearanceController (Node)       # API visual: equip, unequip, injury
├── Skeleton2D                           # opcional; cutout / cuadrúpedos
│   └── Bone2D… → sprites por parte
├── VisualRig (Node2D)                   # si no hay skeleton: anclas por slot
│   ├── Slot_head (Node2D)
│   │   ├── BaseLayer (Sprite2D)         # cabeza desnuda
│   │   ├── EquipmentLayer (Sprite2D)    # casco / sombrero
│   │   └── InjuryLayer (Sprite2D)       # cicatriz, ojo morado, etc.
│   ├── Slot_body / Slot_arm_left / …
│   └── Slot_leg_fl …                    # lobo: piernas independientes
├── AnimationPlayer                      # anima huesos o slots (orientación)
├── AnimationTree
└── Area2D + CollisionShape2D
```

| Decisión | Godot | Uso U&F |
|----------|-------|---------|
| Piezas modulares | `Sprite2D` / `AnimatedSprite2D` por **slot** | Equipo y lesiones intercambian texturas/escenas en la capa del slot |
| Orden de capas | `z_index`, `y_sort_enabled`, `show_behind_parent` ([Node2D](https://docs.godotengine.org/en/stable/classes/class_node2d.html)) | Casco tapa parte de la cabeza; capa base puede ocultarse parcialmente |
| Rig animado | `Skeleton2D` + `Bone2D` | Humanoides articulados, cuadrúpedos (pierna herida = swap en slot del hueso) |
| Desacople de orden | `RemoteTransform2D` | Brazo delante del torso pero colgando del hueso de espalda |
| Orientación | `AnimationTree` / animaciones por dirección | Cada `PartVisualDef` define 4 vistas: `front`, `back`, `side_left`, `side_right` |
| Lógica vs visual | Nodo **`NpcAppearanceController`** | Módulo `equipment`/`status` notifica; el controller actualiza capas |

Referencias: [AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html), [Cutout animation](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html).

### 5.5 Apariencia modular — equipo y lesiones

Separar **tres capas** (misma idea que datos vs presentación):

| Capa | Responsabilidad | Tipo |
|------|-----------------|------|
| Juego | Qué está equipado, stats, reglas | `EquipmentState`, `ItemDef`, `InjuryState` en `NpcInstanceData` |
| Definición visual | Qué dibujar al equipar/lesionar | `PartVisualDef`, `EquipmentVisualDef`, `InjuryVisualDef` (`.tres`) |
| Presentación | Mostrar/ocultar capas en el rig | `NpcAppearanceController` en escena |

#### 5.5.1 Slots anatómicos (`BodyPartSlot`)

Catálogo por arquetipo (`BodyPartMap` Resource), independiente de slots de **objeto** equipable:

| Ejemplo humanoide | Ejemplo lobo (`quadruped`) |
|-------------------|----------------------------|
| `head`, `body`, `arm_left`, `arm_right`, … | `leg_front_left`, `leg_front_right`, `leg_back_left`, `leg_back_right`, `tail`, `head` |

Cada **parte anatómica** tiene en escena un nodo **`Slot_<id>`** con capas:

| Capa | Contenido |
|------|-----------|
| `BaseLayer` | Apariencia por defecto (cabeza desnuda, pierna sana) |
| `EquipmentLayer` | Item equipado visible (casco, bróquer de brazo) |
| `InjuryLayer` | Sustituto o overlay de lesión (pierna herida, vendaje) |

#### 5.5.2 Equipar / desequipar (visual)

Flujo (módulo `equipment` → apariencia):

1. Cambio en `EquipmentState` (equip / unequip).
2. `NpcAppearanceController.apply_equipment(slot, item_def)`.
3. Resolver `EquipmentVisualDef` del item (texturas/escena por orientación).
4. Aplicar reglas de **cobertura** sobre la base:

| `base_coverage` | Efecto en `BaseLayer` |
|-----------------|------------------------|
| `none` | Base visible completa (anillo, amuleto) |
| `partial` | Base visible con regiones tapadas (casco deja ver parte del rostro/cabello) |
| `full` | Ocultar base (`visible = false` o sprite vacío) |

5. `EquipmentLayer`: mostrar sprite del item; al **desequipar**, ocultar capa y restaurar base.

```gdscript
## Actualiza capas visuales de un slot tras equipar.
func apply_equipment(slot: StringName, visual: EquipmentVisualDef, orientation: StringName) -> void:
	var slot_node := _get_slot(slot)
	slot_node.base_layer.visible = visual.base_coverage != &"full"
	slot_node.equipment_layer.texture = visual.get_texture(orientation)
	slot_node.equipment_layer.visible = visual != null
```

Items sin representación visual (`EquipmentVisualDef` nulo) solo afectan stats.

#### 5.5.3 Lesiones e variantes corporales

Las **lesiones** no pasan por slots de inventario: usan **`InjuryVisualDef`** + estado en `NpcInstanceData` (`injuries: Array[InjuryState]`).

| Modo | Uso | Ejemplo |
|------|-----|---------|
| `replace` | Sustituye la base del slot | Pierna sana → pierna herida (lobo) |
| `overlay` | Superpone sobre base/equipo | Vendaje, sangre |
| `hide_part` | Oculta slot completo | Cola arrancada |

Prioridad de resolución por slot (de mayor a menor): **injury `replace`** → **equipment** → **base**.

Al curar: `remove_injury(part_id)` restaura base y re-aplica equipo visible.

#### 5.5.4 Resources visuales

| Resource | Campos clave |
|----------|--------------|
| `PartVisualDef` | `part_id`, texturas/animaciones por `orientation`, `scene` opcional |
| `EquipmentVisualDef` | `slot`, `base_coverage`, texturas por orientación, `z_offset` |
| `InjuryVisualDef` | `part_id`, `mode` (`replace`/`overlay`/`hide_part`), visual por orientación |
| `BodyPartMap` | Lista de `part_id` válidos por arquetipo (humano vs lobo) |

Ubicación: `res://assets/visuals/parts/`, `res://assets/visuals/equipment/`, `res://assets/visuals/injuries/`.

#### 5.5.5 Panel de inspección (`InspectionLayoutDef` + `UfInspectionPanel`)

Para inspeccionar o equipar un NPC (en juego o en `uf_npc_editor`), el arquetipo define un layout de inspección **independiente del rig 3D/2D**:

| Pieza | Tipo | Rol |
|-------|------|-----|
| `InspectionLayoutDef` | `Resource` (`.tres`) | `background_texture`, `background_size`, `slots[]` con `{ slot_id, rect }` donde `rect` es **normalizado** 0..1 sobre el fondo |
| `UfInspectionPanel` | `UfInfoPanel` (módulo `gui`) | Construye fondo + una `UfEquipmentSlot` por entrada del layout; **solo presentación** (señales `item_dropped`, `item_removed`, `slot_activated`) |
| `UfEquipmentSlot` | `Panel` (widget `gui`) | Celda cuadrada con icono; drag-and-drop con payload opaco (`uf_equipment_item`); sin tipos de dominio |

Flujo editor / runtime:

1. `archetype.resolve_inspection_layout()` → `InspectionLayoutDef`.
2. `GuiModule.create_inspection_panel(layout)` → `UfInspectionPanel.build_from_layout()`.
3. Al soltar un item, el **consumidor** (editor o módulo `equipment`) actualiza `EquipmentState` y llama `NpcAppearanceController.set_equipment_texture(part_id, tex)`.

Assets de ejemplo: `assets/visuals/parts/humanoid_inspection_layout.tres`. El módulo `gui` **no** importa `ItemDef` ni `FactionDef`.

#### 5.5.5 Reglas de diseño

- Un NPC **misma escena base** (`npc_base.tscn` o variante por `BodyPartMap`); variación por **datos + capas**, no por escena distinta por cada combinación casco/armadura.
- Combinaciones N×M (items × lesiones) deben resolverse por **composición de capas**, no por sprites pre-renderizados de every combination.
- Sincronizar orientación: al cambiar `orientation` en `NpcInstanceData`, el controller refresca **todas** las capas activas.
- Cel animation opcional ([Cutout animation — cel alongside cutout](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html)) para manos/patas en ataques, sin romper modularidad.

### 5.6 Creación e instanciación

Pipeline obligatorio (módulo `npc`):

1. Cargar `NpcArchetype` (`.tres`) por `id`.
2. `var body = archetype.resolve_scene().instantiate()` — `PackedScene.instantiate()`.
3. `var instance = NpcInstanceData.new()` — runtime `RefCounted` con `uid`, vitals, inventario vacío.
4. `instance.apply_archetype(archetype)` — copia stats base (`duplicate`), aplica facciones/traits por defecto.
5. `body.initialize(instance)` — inyección de dependencias; **`NpcAppearanceController.sync_from_instance(instance)`** aplica base, equipo y lesiones.
6. Posicionar: `body.global_position = grid_to_world(instance.grid_cell)`.
7. `body.add_to_group("npc")`; facciones → `add_to_group("faction_%s" % id)`.

**Spawner / world:** el contenedor de mundo instancia; el NPC no busca nodos globales por path hardcodeado.

### 5.7 Datos mínimos de instancia (`NpcInstanceData`)

Identificadores y estado **runtime** (no `.tres` compartido):

- `uid: int` o `StringName` — ID único de instancia
- `archetype_id: StringName`
- `display_name_key: String` — puede override del arquetipo
- `grid_cell: Vector3i` — posición **x, y, z** en el mapa
- `orientation` — `front` | `front_right` | `side_right` | `back_right` | `back` | `back_left` | `side_left` | `front_left`
- `vitals: NpcVitals` — copia mutable (`duplicate`)
- `attributes: AttributeSet` — base + modificadores runtime
- `equipment: EquipmentState` — mapa runtime slot → `item_id`
- `modifier_ids: Array[StringName]` — ids activos (`ModifierDef`); incluye defaults del arquetipo, grants de facción y runtime
- `injuries: Array[InjuryState]` — partes lesionadas (visual + mecánicas)
- `faction_ids: Array[StringName]`
- `active_effects: Array[ActiveEffect]` — buffs, debuffs, maladies (futuro módulo `status`)
- `traits: Array[StringName]` — legacy; preferir `modifier_ids` con `ModifierDef.kind = TRAIT`

Atributos efectivos: `NpcInstanceData.effective_attributes(ModifierModule, EquipmentModule)` — base → modificadores de instancia/facción/equipo vía `ModifierModule.apply()`.

Señales en el nodo presentación (hacia `EventBus` o padre): `died`, `cell_changed`, `health_changed`.

---

## 6. Facciones

### 6.1 Concepto

Capa **transversal** a la jerarquía de arquetipos. Un NPC puede ser, por ejemplo:

- Arquetipo: `Humanoid` → `Archer`
- Facción: `bandits` (propiedades y comportamientos propios de la facción)

O bien:

- Arquetipo: `Beast` → `BipedalBeast`
- Facción: `undead` (ejemplo ilustrativo; no implica contenido implementado)

### 6.2 Modelo (`FactionDef` Resource)

- `class_name FactionDef extends Resource` — `.tres` en `res://assets/data/factions/`.
- Fachada: `FactionModule` (`modules/faction/`, log `FAC`).
- Campos implementados: `id`, `display_name_key`, `granted_modifier_ids` (ids de `ModifierDef` otorgados a miembros), `hostile_to`, `ally_to`, `tags`.
- Campos previstos (futuro): modificadores de IA, loot tables, reglas de aggro, plantillas de equipo.
- Runtime: `faction_ids` en `NpcInstanceData` + **`add_to_group("faction_%s" % id)`** para consultas (`get_tree().get_nodes_in_group(...)`).
- `NpcModule.assemble(instance)` fusiona `granted_modifier_ids` de las facciones activas en `instance.modifier_ids`.
- Un NPC tiene **0..N** facciones; la facción aporta hoy **modificadores por id** y relaciones; comportamiento de combate/IA queda para fases posteriores.

### 6.4 Tres conceptos separados (arquetipo / facción / modificador)

| Concepto | Pregunta | Resource / módulo |
|----------|----------|-------------------|
| **Arquetipo** | ¿Qué **es**? (forma, stats base, rig, slots) | `NpcArchetype` → `npc` |
| **Facción** | ¿A qué **grupo** pertenece? (alianzas, grants) | `FactionDef` → `faction` |
| **Modificador** | ¿Qué **delta** aplica? (trait, malady, status, scaler) | `ModifierDef` → `modifier` |

No mezclar facción con arquetipo en un solo `.tres`. Los tres se componen en `NpcInstanceData` y se resuelven vía fachadas inyectadas.

### 6.3 Separación arquetipo vs facción

| Capa | Responde a |
|------|------------|
| Arquetipo | Qué **es** (forma, capacidades base, animaciones) |
| Facción | A qué **grupo** pertenece (alianzas, conducta, loot temático) |

---

## 7. Equipo e inventario

Definiciones como **`ItemDef extends Resource`** (`.tres`); estado equipado en **`EquipmentState`** (runtime, `RefCounted` o `duplicate`).

Cada NPC (incluido el jugador) tiene tres conjuntos en `EquipmentState`:

| Conjunto | Descripción |
|----------|-------------|
| `equipped` | Items actualmente equipados |
| `inventory` | Items portables no equipados |
| `death_loot` | Items que suelta al morir (puede derivar de equipped + inventory según reglas) |

### 7.1 Slots de humanoide

Para arquetipos humanoides (`Humanoid` y derivados):

| Slot | Código |
|------|--------|
| Cabeza | `head` |
| Cuerpo | `body` |
| Brazo izquierdo | `arm_left` |
| Brazo derecho | `arm_right` |
| Cinturón | `belt` |
| Amuleto (cuello) | `neck` |
| Anillo 1 | `ring_1` |
| Anillo 2 | `ring_2` |
| Botas | `feet` |
| Espalda | `back` |

- Otros arquetipos definen **`BodyPartMap`** propio (p. ej. cuadrúpedo: `leg_*`, sin `arm_left`).
- Validar compatibilidad item ↔ slot ↔ arquetipo en módulo `equipment`.
- Cada `ItemDef` referencia opcionalmente **`EquipmentVisualDef`** (§5.5); equipar actualiza stats **y** capas visuales vía `NpcAppearanceController`.

### 7.2 Equipo visual modular

Ver §5.5. Resumen:

- **Equipar** → `EquipmentLayer` visible + reglas `base_coverage` sobre `BaseLayer`.
- **Desequipar** → ocultar `EquipmentLayer`, restaurar `BaseLayer` (salvo injury `replace` activa).
- **Lesión** → `InjuryVisualDef` en slot anatómico (p. ej. `leg_back_left` herida en lobo).
- Lógica de inventario **no** manipula nodos del rig directamente; solo llama API pública de `NpcAppearanceController` o emite señal consumida por él.
- Items en datos: `ItemDef` por `id` o referencia Resource; nunca stats sueltos hardcodeados.

---

## 8. Estado, atributos y efectos

### 8.0 Modificadores unificados (`ModifierDef` + `ModifierModule`)

Implementación actual: un solo Resource **`ModifierDef`** (`modules/modifier/`, log `MOD`) cubre traits, maladies, status y scalers mediante `kind`:

| `ModifierDef.Kind` | Uso típico | Ejemplo asset |
|--------------------|------------|---------------|
| `TRAIT` | Rasgo permanente del individuo | `undead` (vía facción) |
| `MALADY` | Enfermedad / condición duradera | (futuro) |
| `STATUS` | Buff/debuff temporal | (futuro módulo `status`) |
| `SCALER` | Multiplicador de balance (élite, jefe) | `elite` (+20% strength/vitality) |

Campos: `id`, `display_name_key`, `additive` / `multiplicative` (Dictionary por nombre de atributo), `tags`.

`ModifierModule.apply(base: AttributeSet, defs)` — primero todos los aditivos, luego todos los multiplicativos. Los `.tres` viven en `res://assets/data/modifiers/`.

Los tipos `StatusEffectDef`, `MaladyDef`, `TraitDef` de diseño (§8.3–8.5) pueden migrar a `ModifierDef` con `kind` distinto; el runtime unificado usa ids en `NpcInstanceData.modifier_ids`.

### 8.1 Resources de definición vs estado runtime

| Concepto | Definición (`.tres`) | Runtime (instancia) |
|----------|----------------------|---------------------|
| Atributos base | `AttributeSet` | Copia en `NpcInstanceData` + modificadores |
| Vitals máximos / iniciales | `VitalsTemplate` | `NpcVitals` (`duplicate` al spawn) |
| Buff / debuff | `StatusEffectDef` | `ActiveEffect` (duración, stacks) |
| Malady | `MaladyDef` | `ActiveMalady` |
| Trait | `TraitDef` | `Array[StringName]` en instancia |

Usar `@export` tipado y `class_name` en cada Resource para edición en Inspector ([Resources — custom](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)).

### 8.2 Variables vitales (`NpcVitals`)

| Variable | Código | Notas |
|----------|--------|-------|
| Salud | `health` | |
| Energía | `energy` | |
| Maná | `mana` | |
| Cordura | `sanity` | |
| Moral | `morale` | |
| Hambre | `hunger` | |
| Sed | `thirst` | |
| Cansancio | `fatigue` | |
| Carga | `encumbrance` | Relacionado con peso/volumen transportado |
| Temperatura | `temperature` | Body / exposición ambiental |

### 8.3 Modificadores temporales (`StatusEffectDef`)

- **Beneficios** (`buff`) y **perjudiciales** (`debuff`): duración limitada, apilables según reglas.
- Afectan vitales, atributos efectivos o acciones permitidas.

### 8.4 Maladies (`MaladyDef`)

- Modificadores de **carácter más duradero** (p. ej. `flu`, `rabies`, enfermedades crónicas).
- Distintas de buffs/debuffs por persistencia, curación y efectos narrativos.
- Identificador en inglés; nombre visible vía localización.

### 8.5 Rasgos (`TraitDef`)

- Modificadores **permanentes** y distintivos del individuo (p. ej. `bold`, `fearless`).
- Definidos en creación del NPC o eventos irreversibles; no confundir con maladies curables.

### 8.6 Orden de aplicación (atributos efectivos)

```
base attributes (AttributeSet en instancia)
  → modifier_ids (arquetipo default_modifiers + facción granted_modifier_ids + runtime)
  → equipment item attribute_modifier_id (opcional por item equipado)
  → ModifierModule.apply() → effective values (combat, checks, UI, editor)
```

Efectos temporales con duración/stacks (`ActiveEffect`) y maladies con curación propia quedan en el futuro módulo `status`; hoy los deltas estáticos pasan por `ModifierDef`.

Emitir `changed` en Resources de runtime solo si un sistema `@tool` de editor lo requiere; en juego preferir señales del nodo NPC o `EventBus`.

### 8.7 Atributos (`AttributeSet`)

Atributos base (Resource o sub-resource dentro de `NpcArchetype`):

| Atributo | Código |
|----------|--------|
| Fuerza | `strength` |
| Agilidad | `agility` |
| Voluntad | `willpower` |
| Vitalidad | `vitality` |
| Percepción | `perception` |
| Carisma | `charisma` |

- Valores numéricos; escalado en `.tres` bajo `res://assets/data/attributes/`.
- Los modificadores de §8.3–8.5 alteran valores **efectivos**; la base en `AttributeSet` solo cambia por progresión explícita.

### 8.8 Estados de animación vs estado de juego

| Tipo | Mecanismo Godot | Ejemplos |
|------|-----------------|----------|
| Animación (presentación) | `AnimationTree` / `AnimationNodeStateMachine` | `idle`, `walk`, `attack` |
| Juego (mecánicas) | `NpcInstanceData`, módulo `status` | vitals, efectos, turno, IA |

No mezclar vitals/efectos dentro del `AnimationTree`; el árbol reacciona a señales/cambios del estado de juego.

---

## 9. Localización (i18n)

Todo texto que el jugador pueda ver (nombres, descripciones, propiedades, diálogos, UI, tooltips, mensajes de error jugables, etc.) debe estar **desacoplado del código**. El código solo guarda **claves estables**; el texto traducido vive en ficheros de idioma.

### 9.1 Enfoque: sistema nativo de Godot

Usar el pipeline oficial de Godot 4 ([Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html)):

- Ficheros de traducción registrados en **Project Settings → Localization**.
- Resolución en runtime vía **`TranslationServer`** y **`tr()`** en GDScript.
- Formatos recomendados: **CSV** (múltiples idiomas en un archivo) o **PO** (gettext, un archivo por idioma).

Estructura prevista:

```
res://locale/
├── translations.csv      # claves + columnas por idioma (en, es, …)
└── translations/         # opcional: dominios separados (ui.csv, items.csv, …)
```

Ejemplo CSV:

```csv
keys,en,es
item.iron_sword.name,Iron Sword,Espada de hierro
item.iron_sword.desc,A basic blade.,Una hoja básica.
trait.bold.name,Bold,Atrevido
```

### 9.2 Claves de traducción

- Identificadores **estables**, en inglés, con notación jerárquica: `<dominio>.<entidad>.<campo>`.
- Ejemplos: `npc.merchant.greeting`, `malady.flu.desc`, `ui.inventory.title`.
- **Prohibido** usar el texto visible como clave (p. ej. `"Espada de hierro"`).
- **Prohibido** literales de UI en código o recursos de datos jugables.

### 9.3 Uso en código y recursos

**GDScript** — solo claves + `tr()`:

```gdscript
label.text = tr("ui.inventory.title")

## En recursos: guardar la clave, no el texto.
@export var name_key: String = "item.iron_sword.name"

func get_display_name() -> String:
	return tr(name_key)
```

**Escenas (`.tscn`)** — texto traducible en el editor con claves, o asignación vía script con `tr()`. Activar traducción automática en nodos de UI cuando aplique.

**Datos** (`Resource`, JSON, CSV de juego) — campos `*_key` (`name_key`, `description_key`), nunca `name: "Espada..."`.

**Placeholders** — textos con variables usando formato de Godot:

```gdscript
tr("combat.damage_taken").format({"amount": amount, "source": tr(source_name_key)})
```

### 9.4 Idiomas y cambio en runtime

- Idiomas soportados inicialmente: **`en`**, **`es`** (extensible añadiendo columnas/ficheros).
- Locale por defecto: configuración del proyecto; cambio en runtime con `TranslationServer.set_locale(locale)` (p. ej. desde menú de opciones o clave en `venv.ini` cuando se implemente).
- Al añadir contenido nuevo: **siempre** añadir entradas para todos los idiomas activos en el CSV/PO.

### 9.5 Qué no localizar aquí

| Tipo | Dónde va |
|------|----------|
| Identificadores de código (`bandits`, `apply_damage`) | Código (inglés) |
| Claves de config (`LOG_NPC_LEVEL`) | `venv.ini` |
| Trazas de desarrollo | Módulo `Log` |
| Texto visible al jugador | `res://locale/` + `tr()` |

### 9.6 Checklist de localización

- [ ] ¿Hay literal visible hardcodeado? → sustituir por clave + `tr()`.
- [ ] ¿La clave sigue `<dominio>.<entidad>.<campo>`?
- [ ] ¿Entradas añadidas en todos los idiomas del CSV/PO?
- [ ] ¿Recursos usan `*_key` en lugar de texto embebido?

---

## 10. Interfaz gráfica (GUI)

La UI del juego se organiza en **paneles movibles** y **widgets reutilizables**, sobre el sistema de controles nativo de Godot ([Using Containers](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html), [Control](https://docs.godotengine.org/en/stable/classes/class_control.html)).

### 10.1 Principios

| Principio | Descripción |
|-----------|-------------|
| Paneles movibles | Toda ventana/panel de juego puede **reposicionarse** por el jugador (p. ej. arrastrar desde asa en esquina o barra de título). |
| Jerarquía de clases | Funcionalidad común en **`UfPanel`** (clase/script padre); especializaciones en hijos. |
| Widgets desacoplados | Botones, listas, rejillas, etc. como componentes independientes, sin lógica de inventario/estado embebida. |
| Paneles de dominio | Inventario, estado, habilidades, hechizos, etc. **extienden/componen** `UfPanel`, no reinventan drag ni chrome. |
| Localización | Texto visible vía claves + `tr()` (§9). |

### 10.2 Stack Godot

| Necesidad | API Godot |
|-----------|-----------|
| Layout | `VBoxContainer`, `HBoxContainer`, `GridContainer`, `MarginContainer`, `ScrollContainer` |
| Panel con fondo | `PanelContainer` + `Theme` / StyleBox |
| Pestañas | `TabContainer` (hijo de panel especializado) |
| Listas | `ItemList`, `Tree` o widget custom sobre `ScrollContainer` |
| Botones | `Button`, `TextureButton` |
| Entrada drag | `_gui_input()` / `GuiInput` en asa de arrastre; mover `position` del panel |
| Tema global | `Theme` resource en `res://ui/theme/` |

Contenedores anidados para layouts complejos (patrón recomendado por Godot para RPG/tool UIs).

### 10.3 Jerarquía del módulo `gui`

```
res://ui/
├── theme/                    # Theme global
├── widgets/                  # Elementos atómicos reutilizables
│   ├── uf_button.tscn
│   ├── uf_grid_container.tscn
│   ├── uf_list.tscn
│   └── …
├── panels/                   # Escenas base de panel
│   ├── uf_panel.tscn         # Padre: movible + chrome mínimo
│   ├── uf_tabbed_panel.tscn
│   ├── uf_dialog_panel.tscn  # Aceptar / Cancelar
│   └── uf_info_panel.tscn    # Informativo + cerrar
└── domain/                   # Paneles de juego (componen panels + widgets)
    ├── inventory_panel.tscn
    ├── status_panel.tscn
    ├── skills_panel.tscn
    └── spells_panel.tscn
```

Scripts de módulo en `res://modules/gui/` (fachada pública) con implementación en `_private/` según arquitectura.

**Implementación actual:** los tipos base son scripts con `class_name` en `res://modules/gui/` (paneles) y `res://modules/gui/widgets/` (widgets); construyen su estructura (Header/ContentSlot) por código de forma idempotente. En `res://ui/` viven el `theme/` y los paneles de dominio generados (`domain/`). El plugin `uf_gui_tools` compone `UfPanel` + widgets y los guarda como `PackedScene` en `ui/domain/`, reutilizables como assets.

### 10.4 Clase base `UfPanel`

`class_name UfPanel extends PanelContainer` (o `Control` raíz con `PanelContainer` hijo).

Responsabilidades **solo** del padre:

- **Asa de arrastre** (`DragHandle`): `TextureButton` o zona en esquina; `gui_input` con botón pulsado → actualizar `position` del panel.
- Contenedor de **contenido** (`ContentSlot`) donde hijos especializados insertan UI.
- Título opcional (`title_key` → `tr()`).
- Señales: `panel_closed`, `panel_moved`, `panel_focused`.
- API pública: `set_title_key()`, `get_content_slot()`, `enable_drag()`, `reset_position()`.

Opcional: persistir posición en `venv.ini` / perfil de usuario por `panel_id`.

```gdscript
## Panel base movible; el contenido va en ContentSlot.
class_name UfPanel
extends PanelContainer

@onready var _drag_handle: Control = $Header/DragHandle

func _ready() -> void:
	_drag_handle.gui_input.connect(_on_drag_handle_input)

## Procesa arrastre del panel mientras el asa recibe input del ratón.
func _on_drag_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		position += event.relative
```

### 10.5 Paneles especializados (hijos)

| Clase / escena | Extiende | Añade |
|----------------|----------|-------|
| `UfTabbedPanel` | `UfPanel` | `TabContainer`; pestañas con `title_key` por tab |
| `UfInfoPanel` | `UfPanel` | Botón **cerrar**; emite `panel_closed` |
| `UfInspectionPanel` | `UfInfoPanel` | Silueta + slots de equipo desde `InspectionLayoutDef`; señales drag-drop (§5.5.5) |
| `UfDialogPanel` | `UfPanel` | Botones **accept** / **cancel** + señales `confirmed`, `cancelled` |
| `UfInventoryPanel` | `UfPanel` o `UfTabbedPanel` | Componer `UfGridContainer` + lógica vía módulo `equipment` |
| `UfStatusPanel` | `UfPanel` | Vitals, efectos; datos desde módulo `status` |
| `UfSkillsPanel` / `UfSpellsPanel` | `UfPanel` | Dominio combate/magia (futuro) |

Reglas:

- Especializaciones **no** reimplementan arrastre ni chrome común.
- Lógica de dominio vive en **módulos** (`equipment`, `status`…); el panel solo enlaza señales y refresca widgets.

### 10.6 Widgets modulares (`res://ui/widgets/`)

Elementos recurrentes, **sin** acoplamiento a un panel concreto:

| Widget | Base Godot | Uso |
|--------|------------|-----|
| `UfButton` | `Button` | Acciones; texto vía `label_key` |
| `UfGridContainer` | `GridContainer` + celdas custom | Inventario, tiles de habilidad |
| `UfList` | `ItemList` o `VBoxContainer` en `ScrollContainer` | Listas de items, hechizos, log |
| `UfLabel` | `Label` | Texto localizado |
| `UfSeparator` | `HSeparator` / `VSeparator` | Divisores |
| `UfLayoutRegion` | `Control` | Zona de layout libre (anclas) dentro de un `ContentSlot` en flujo |
| `UfEquipmentSlot` | `Panel` | Celda de slot de equipo (icono + drag-drop); usada por `UfInspectionPanel` |

Cada widget: escena `.tscn` + script mínimo; expone API pequeña (`set_items()`, `set_label_key()`, etc.).

#### `UfLayoutRegion` — flujo + posición libre

`ContentSlot` sigue siendo `VBoxContainer`: los hijos directos se apilan en vertical. Cuando hace falta colocar widgets con el ratón (anclas, tamaño en viewport 2D), se inserta un **`UfLayoutRegion`** como hijo del slot:

```
ContentSlot (VBoxContainer)
├── UfLayoutRegion          # altura mínima region_min_size; ancho = ancho del panel
│   ├── UfButton            # anchors / offsets relativos a la región
│   └── UfGridContainer
└── UfList                  # resto del panel en flujo vertical
```

- Los hijos **dentro** de la región usan `layout_mode` por anclas; el editor 2D permite moverlos y redimensionarlos.
- Al mover la región en el árbol o arrastrar el **panel** entero, los hijos conservan su posición **relativa** a la región (transform del padre).
- La región no sustituye contenedores de dominio (`UfGridContainer`, `UfList`); convive con ellos en el mismo `ContentSlot`.

### 10.7 Composición de paneles de dominio

Ejemplo **inventario**:

```
UfInventoryPanel (extends UfPanel)
├── Header (título + DragHandle heredado)
├── ContentSlot
│   ├── UfGridContainer      # slots equipamiento
│   └── UfList               # inventario
└── (sin lógica de items en nodos UI; escucha EquipmentState)
```

El panel se suscribe a datos del módulo `equipment` / `NpcInstanceData` vía API o señales; **no** lee inventario con paths globales.

### 10.8 Reglas de diseño GUI

- Toda ventana de juego es un **`UfPanel`** o subclase.
- Arrastre solo desde **asa/barra** definida, no desde todo el panel (evita conflictos con clics en contenido).
- Nuevos paneles (mapa, diálogo NPC, crafteo…) → extender base o componer widgets existentes.
- Estilos centralizados en **`Theme`**; evitar StyleBox duplicados por escena.
- Identificadores en **inglés**; textos en `res://locale/`.

### 10.9 Herramientas de editor para GUI

Norma general de herramientas para artistas: **§11**. Esta sección aplica esa norma al módulo **`gui`**.

**Sí** — Godot permite extender el editor para facilitar el trabajo de arte/UI sin recompilar el motor ([Making plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html), [Running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html)).

Los artistas pueden montar paneles concretos (inventario, hechizos, etc.) **a mano en el editor** apoyándose en las escenas base del módulo `gui`. Las herramientas custom **aceleran** ese flujo; no sustituyen la jerarquía `UfPanel` + widgets.

#### Flujo sin plugin (mínimo viable)

| Mecanismo Godot | Uso para artistas |
|-----------------|-------------------|
| **Escena instanciada / heredada** | Duplicar `uf_panel.tscn` o `uf_tabbed_panel.tscn` → guardar en `ui/domain/` como `inventory_panel.tscn` |
| **`class_name` + `@icon`** en `UfPanel`, widgets | Nodos aparecen en el diálogo “Añadir nodo” con icono |
| **`@tool`** en scripts base | Previsualización en editor (layout, asa de arrastre) |
| **`Theme`** en `ui/theme/` | Estilo unificado; artista retoca una vez, aplica a todos los widgets |

Flujo típico del artista:

1. Instanciar `uf_panel.tscn` (o `uf_tabbed_panel.tscn`).
2. Dentro de `ContentSlot`, instanciar `UfGridContainer`, `UfList`, `UfButton`, etc.
3. Ajustar layout con contenedores Godot (arrastrar en el editor 2D).
4. Guardar en `res://ui/domain/inventory_panel.tscn`.
5. El programador enlaza el panel al módulo de dominio (`equipment`, etc.) — **sin** mover nodos a mano en código.

#### Plugins de editor (`addons/`)

Ubicación: `res://addons/uf_gui_tools/` (plugin del proyecto, activable en *Project → Project Settings → Plugins*).

| Herramienta | API Godot | Propósito |
|-------------|-----------|-----------|
| **Plantillas de panel** | `EditorPlugin` + menú contextual | “Crear panel → Inventario / Hechizos / Estado” instanciando escena base en `ui/domain/` |
| **Dock de biblioteca UI** | `EditorPlugin.add_dock()` | Paleta con widgets `Uf*` para arrastrar o instanciar |
| **Nodos registrados** | `@tool` + `class_name` + `@icon` | `UfPanel`, `UfGridContainer` en el árbol de nodos |
| **Inspector custom** | `EditorInspectorPlugin` | Editar `title_key`, `label_key` con selector de claves de locale |
| **Validación al guardar** | `@tool` en raíz del panel | Avisar si falta `ContentSlot` o hay literal sin localizar |

Esqueleto de plugin:

```gdscript
@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_tool_menu_item("Create UF Inventory Panel", _create_inventory_panel)

func _create_inventory_panel() -> void:
	var panel := preload("res://ui/panels/uf_panel.tscn").instantiate()
	# Abrir como escena nueva o insertar en escena activa (EditorInterface)
```

#### Reglas para herramientas de artista

- Las herramientas **solo generan/componen escenas** con nodos ya definidos en `ui/panels/` y `ui/widgets/`; no duplican lógica del módulo `gui`.
- Paneles creados por artistas → **`res://ui/domain/`**; bases reutilizables → **`ui/panels/`**, **`ui/widgets/`**.
- Scripts `@tool` del editor **no** van en builds de juego salvo que sean también runtime; preferir carpeta `addons/` separada.
- Toda cadena visible que el artista escriba en inspector → **`title_key` / `label_key`**, nunca texto final en español en la escena.

#### Roadmap sugerido

1. **Fase 1:** escenas base + `class_name` + `@icon` (artista trabaja solo con instancias).
2. **Fase 2:** `@tool` en `UfPanel` para preview de chrome en editor.
3. **Fase 3:** plugin `uf_gui_tools` con menú de plantillas y dock de widgets.

---

## 11. Herramientas de editor para artistas (norma general)

### 11.1 Regla obligatoria

Cuando un módulo sea candidato a **utilizarse muchas veces** y requiera **fine-tuning manual** por un artista o diseñador de contenido, hay que **crear la herramienta de editor** necesaria para que el artista:

1. Se apoye en la **API pública** del módulo (no en `_private/` ni en hacks).
2. **Cree assets a mano** en el editor (escenas, Resources, máscaras, arquetipos…).
3. Produzca datos en el **mismo formato** que consume el juego en runtime.

La herramienta no sustituye al módulo: lo **expone** de forma visual y guiada.

Referencias Godot: [Making plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html), [Running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html).

### 11.2 Criterios para exigir herramienta

| Criterio | Pregunta |
|----------|----------|
| **Reuso alto** | ¿Se crearán muchos assets distintos con este módulo (mapas, NPCs, paneles, items…)? |
| **Fine-tuning** | ¿El artista debe ajustar detalle visual o de datos que el inspector genérico no cubre bien? |
| **Complejidad** | ¿Hay relaciones entre datos (x/y/z, slots, biomas, capas de apariencia) difíciles de editar a mano en JSON/código? |

Si se cumplen **reuso + fine-tuning**, la herramienta pasa de “deseable” a **obligatoria** antes de escalar contenido.

### 11.3 Principios de implementación

- Plugin en `res://addons/uf_<dominio>_editor/` (`EditorPlugin`, scripts `@tool`).
- La herramienta **solo llama** métodos públicos del módulo (`world`, `world_gen`, `npc`, `gui`…).
- **Una fuente de verdad**: lo guardado por la herramienta es lo que carga el runtime (`.tres`, `.tscn`, máscaras en `assets/`).
- Lógica de dominio **no** duplicada en el plugin; si falta API, **extender el módulo** primero.
- Identificadores en inglés; textos de UI del plugin localizables si son visibles al artista (claves o inglés técnico en editor).

### 11.4 Herramientas identificadas en el proyecto

| Herramienta | Addon | Módulos | Qué hace el artista |
|-------------|-------|---------|---------------------|
| **Editor de mapas** | `uf_map_editor` | `world`, `world_gen`, `grid` | Pintar rejilla **x/y/z**, overlay de altura en viewport, biomas, zonas manuales, colocar estructuras prefab (`TileMapPattern`, scene tiles), máscaras de bioma; exportar escenas/recursos en `assets/world/` |
| **Editor de NPCs** | `uf_npc_editor` | `npc`, `appearance`, `attributes`, `equipment`, `faction`, `modifier`, `gui` | **En progreso (esqueleto):** pantalla principal 3 columnas (detalles / preview rig / panel de inspección con drag-drop); carga arquetipos reales; edición en memoria. Pendiente: guardar `.tres`, lesiones, IA de facción |
| **Herramientas GUI** | `uf_gui_tools` | `gui` | Componer paneles de dominio (inventario, hechizos, estado…) desde `UfPanel` y widgets (§10.9) |

Otras candidatas futuras (misma norma): editor de items (`ItemDef` + `EquipmentVisualDef`), editor de facciones, editor de biomas/terrains.

### 11.5 Flujo de trabajo artista ↔ módulo

```
Módulo runtime (API pública)
        ↑ lee
Assets en res://assets/…  ←  guarda  ←  EditorPlugin (@tool)
        ↑                              ↑
   Juego en runtime              Artista fine-tunea a mano
```

### 11.6 Checklist al añadir un módulo con contenido artístico

- [ ] ¿Alto reuso + fine-tuning? → planificar addon en `addons/`.
- [ ] ¿API pública suficiente para la herramienta? Si no, ampliar módulo antes del plugin.
- [ ] ¿Formato de asset documentado en `GAME_DESIGN.md` / `ARCHITECTURE.md`?
- [ ] ¿Herramienta registrada en tabla §12 (módulos previstos)?

---

## 12. Módulos previstos (diseño ↔ código)

| Dominio | Módulo sugerido | API Godot base | Código log |
|---------|-----------------|----------------|------------|
| Rejilla / mapa | `world` | `TileMapLayer`, `TileSet`, **`MapHeightField`** | WLD |
| Pathfinding | `grid` | `AStarGrid2D` + reglas de **z** / `max_climb` | GRD |
| Generación | `world_gen` | `FastNoiseLite`, `set_cells_terrain_connect()`, `TileMapPattern` | WGN |
| Cámara isométrica | `camera` | `Camera2D` + rig `Node2D` | CAM |
| NPC / spawn | `npc` | `PackedScene`, `NpcAppearanceController`, `BodyPartMap` | NPC |
| Facciones | `faction` | `FactionDef` Resource | FAC |
| Modificadores | `modifier` | `ModifierDef` Resource | MOD |
| Equipo | `equipment` | `ItemDef`, `EquipmentVisualDef`, `EquipmentState` | EQP |
| Apariencia / lesiones | `appearance` | `PartVisualDef`, `InjuryVisualDef`, capas por slot | APP |
| Estado / efectos | `status` | `StatusEffectDef`, `MaladyDef`, `TraitDef` | STS |
| Atributos | `attributes` | `AttributeSet` Resource | ATR |
| Jugador | `player` | Misma escena NPC + grupo `"player"` | PLR |
| GUI / paneles | `gui` | `UfPanel`, `TabContainer`, widgets `Control` | GUI |
| Editor de mapas | `addons/uf_map_editor` | `EditorPlugin` + API `world` / `world_gen` | — |
| Editor de NPCs | `addons/uf_npc_editor` | `EditorPlugin` (main screen) + API `npc` / `appearance` / `equipment` / `faction` / `modifier` / `gui` | — |
| Herramientas GUI | `addons/uf_gui_tools` | `EditorPlugin`, plantillas `UfPanel` | — |
| Localización | — | `TranslationServer` + `res://locale/` | — |

Registrar en `docs/ARCHITECTURE.md` al implementar.

---

## 13. Checklist al diseñar o implementar una mecánica

- [ ] ¿Encaja con vista isométrica, rejilla **x/y/z** y movimiento 4-dir en x/y?
- [ ] ¿Cada celda (x,y) tiene `z` en `MapHeightField` y posicionamiento vía `grid_to_world`?
- [ ] ¿Mapa/cámara/generación usan `TileMapLayer`, `Camera2D`, terrains, `MapHeightField` y `AStarGrid2D` (§2–4)?
- [ ] ¿NPCs usan rig modular (slots + capas base/equipment/injury) y `NpcAppearanceController` (§5.5)?
- [ ] ¿Sin mutar `.tres` compartidos en runtime?
- [ ] ¿Respeta separación arquetipo / facción?
- [ ] ¿Identificadores de código en inglés?
- [ ] ¿Texto visible al jugador desacoplado (claves + `tr()`, §9)?
- [ ] ¿Arte de mapa en `assets/world/` respeta `world-assets-layout.mdc` (`.tres` + `art/` por categoría)?
- [ ] ¿Estado usa vitales + buff/debuff + malady + trait según corresponda?
- [ ] ¿UI usa `UfPanel` movible, widgets desacoplados y localización (§9–10)?
- [ ] ¿Paneles de dominio extienden la base sin reimplementar arrastre?
- [ ] ¿Módulo con alto reuso + fine-tuning artístico tiene herramienta de editor planificada o implementada (§11)?
- [ ] ¿Actualizado este documento si cambian reglas de diseño?

---

## 14. Referencias

- Arquitectura de código: `docs/ARCHITECTURE.md`
- Reglas Cursor diseño: `.cursor/rules/game-design.mdc`
- Reglas Cursor herramientas artista: `.cursor/rules/editor-artist-tools.mdc`
- Reglas Cursor GUI: `.cursor/rules/gui-panels.mdc`
- Reglas Cursor mapas: `.cursor/rules/world-map.mdc`
- Reglas Cursor NPCs: `.cursor/rules/npc-entities.mdc`
- Reglas Cursor localización: `.cursor/rules/localization.mdc`
- Reglas Cursor código: `.cursor/rules/`
- Godot i18n: https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html
- Godot Resources: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html
- Godot Scene organization: https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
- Godot Editor plugins: https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html
- Godot Running code in editor (@tool): https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html
- Godot 2D skeletons: https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html
- Godot TileMaps / isométrico: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html
- Godot TileSets / terrains: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html
- Godot Camera2D: https://docs.godotengine.org/en/stable/classes/class_camera2d.html
- Godot AStarGrid2D: https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html
- Godot FastNoiseLite: https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html
