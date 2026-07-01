---
name: Map and NPC engines
overview: "Construir la base de código del proyecto siguiendo ARCHITECTURE.md y GAME_DESIGN.md: autoloads Config/Log, motor de mapas (tiles con flags no exclusivos, reglas por lado, modificadores dato+overlay, altura z) con bioma \"campo\" en placeholders y su editor completo, y motor de NPC hasta \"humano\" con un asset aleatorio como personaje principal. Todo persistible como assets (.tres/.tscn)."
todos:
  - id: foundations
    content: Crear autoloads Config y Log, core/direction.gd, registrar en project.godot, añadir claves LOG_* a venv.ini y crear locale/translations.csv
    status: completed
  - id: world-module
    content: "Implementar módulo world: TileDef, TileSideRules, TileModifierDef, TilePlacementRule, TileCatalog, MapHeightField, fachada world.gd y generador de TileSet placeholder isométrico"
    status: completed
  - id: worldgen-module
    content: "Implementar módulo world_gen: BiomeDef, WorldGenRequest, generador con solver de restricciones (agua en blobs redondeados, caminos conectados) y bioma campo con tiles placeholder"
    status: completed
  - id: world-scene-camera
    content: Crear módulo camera (rig Camera2D) y escena world_root.tscn que genera un mapa de campo de prueba
    status: completed
  - id: map-editor-addon
    content: "Crear addon uf_map_editor: dock de generación/presets, pintado manual de tiles y edición de altura z, guardado de mapa y presets como assets"
    status: completed
  - id: npc-modules
    content: "Implementar attributes, appearance y npc: Resources, npc_base.tscn, NpcAppearanceController, cadena de arquetipos npc_root->humanoid->human"
    status: completed
  - id: random-character
    content: Generar asset aleatorio de humano (main_character.tres + visuals placeholder) y escena de prueba que lo instancia
    status: completed
  - id: docs-update
    content: Actualizar ARCHITECTURE.md (§12 registro de módulos) y GAME_DESIGN.md (formato TileDef, modificadores, reglas de colocación)
    status: completed
isProject: false
---

# Motor de mapas + editor y motor de NPC (humano)

Greenfield: solo existen docs, reglas, `project.godot`, `venv.ini`, `icon.svg`. Se respeta el flujo de capas `scenes/ui -> modules -> core -> autoload` y la regla "motor primero" (APIs nativas de Godot 4.7).

## Decisiones de diseño (confirmadas)
- Tipos de tile **no exclusivos** via `@export_flags` (bitmask): `Ground, Walkable, Wall, Water, Hazard, Interactable, Cover, VisionBlocker`.
- **Reglas por lado** (N/E/S/W del plano x/y): paso + propiedades direccionales (bloquea visión, da cobertura). Ej.: puerta abierta = paso N/S sí, E/O no.
- **Modificadores** = dato + overlay visual: `TileModifierDef` con efectos de juego y sprite opcional en capa `modifiers`.
- **Editor completo**: generar/guardar presets + pintado manual de tiles + edición de `z`.
- Todo guardable como **Resource `.tres`** o **`PackedScene`**.

## 1. Fundaciones (autoload + core + config + locale)
- `res://autoload/config.gd` (`class_name`/autoload `Config`, log `CFG`): parsea `venv.ini`, API `get_int/get_bool/get_string/get_float` con defaults; recarga opcional.
- `res://autoload/log.gd` (autoload `Log`, log `LOG`): `info/detail/warn/err(code, type, msg)`, formato `YYYY/MM/DD hh:mm:ss [COD] tipo msg`, gates por módulo leídos de `Config` (`LOG_<MOD>_LEVEL`).
- `res://core/direction.gd`: enum `Direction {N,E,S,W}` + helpers (opuesto, vector, índice). Base compartida sin dependencias.
- Registrar autoloads en [project.godot](project.godot) `[autoload]` y la localización (`internationalization/locale/translation_*`).
- Añadir a [venv.ini](venv.ini): `LOG_WLD/WGN/NPC/APP/ATR/CAM_LEVEL`.
- `res://locale/translations.csv` (`keys,en,es`) con nombres de tiles, biomas, modificadores, arquetipos.

## 2. Módulo `world` (WLD) — definición de tile y mapa
Carpeta `res://modules/world/` (fachada `world.gd` + `_private/`). Resources guardables:
- `tile_def.gd` (`class_name TileDef extends Resource`): `id`, `display_name_key`, `tags:int` (flags), `source_id/atlas_coords` (placeholder en TileSet), `side_rules: TileSideRules`, `placement_rule: TilePlacementRule`, `allowed_modifiers: Array[TileModifierDef]`, helpers `has_tag()`, `is_walkable_from(dir)`.
- `tile_side_rules.gd` (`TileSideRules extends Resource`): por dirección `passable[4]`, `blocks_vision[4]`, `provides_cover[4]`.
- `tile_modifier_def.gd` (`TileModifierDef extends Resource`): `id`, `display_name_key`, `overlay_texture`, `adds_tags:int`, `movement_cost_mult`, semántica de duración.
- `tile_placement_rule.gd` (`TilePlacementRule extends Resource`): `forbid_isolated`, `min_cluster_size`, `max_cluster_size`, `roundness_min` (compacidad 0..1), `is_linear`, `min_collinear_neighbors` (camino=2), `allowed_neighbors/forbidden_neighbors: Array[StringName]`.
- `tile_catalog.gd` (`TileCatalog extends Resource`): `tiles: Array[TileDef]` + lookup por `id`.
- `map_height_field.gd` (`MapHeightField extends Resource`): `z` por `Vector2i` (PackedInt buffer + `region`), `get/set_height`, `height_step`.
- Fachada `world.gd`: `grid_to_world(cell)`, `local_to_cell()`, consulta de paso/visión/cobertura por celda+dirección usando `TileDef` + `MapHeightField`, capas estándar (`ground/terrain/objects/structures/modifiers`).
- Placeholders: `_private/placeholder_tileset.gd` (`@tool`) genera `TileSet` isométrico (`TILE_SHAPE_ISOMETRIC`) con atlas de diamantes de color por tile y custom data layer `tile_def_id`. Guardado en `res://assets/tilesets/uf_placeholder.tres`.

## 3. Módulo `world_gen` (WGN) — bioma "campo" + restricciones
Carpeta `res://modules/world_gen/` (fachada `world_gen.gd` + `_private/`):
- `biome_def.gd` (`BiomeDef extends Resource`): `id`, `display_name_key`, `ground_tile`, `tile_weights`, `allowed_tiles`, `z_min/z_max`, `noise params`, `structures`.
- `world_gen_request.gd` (`WorldGenRequest extends Resource`, **preset guardable**): `biome_id`, `area: Rect2i`, `seed`, `water_*`, `path_*`, `hand_zones`.
- Pipeline en `_private/generator.gd`: (1) `MapHeightField` via `FastNoiseLite`; (2) suelo base con `set_cells_terrain_connect()`; (3) **solver de restricciones**: agua en blobs con tamaño en `[min,max]` y compacidad `>= roundness_min`, descartar sueltos; caminos como polilínea con `set_cells_terrain_path()` garantizando `>=2` vecinos colineales; validación de adyacencias; (4) escribir capas + overlay de modificadores; (5) validar conectividad.
- Bioma `campo` con placeholders: `grass`, `dirt_path` (lineal), `pond_water` (cluster redondeado), `rock_wall` (muro, bloquea visión), `bush` (cobertura + bloquea visión, transitable). Assets en `res://assets/world/biomes/field.tres` y `res://assets/world/tiles/*.tres`.
- API pública: `generate(request, world) -> result`, `save_generated(path)`.

## 4. Escena de mundo + cámara (CAM)
- `res://modules/camera/camera.gd` (CAM): rig `Node2D` + `Camera2D` (pan/rotación; zoom/inclinación fijos), límites según `region`.
- `res://scenes/world/world_root.tscn` + script: instancia capas `TileMapLayer` (y_sort), cámara, y al ejecutar llama `world_gen.generate()` con un `WorldGenRequest` de prueba del bioma campo. Sirve de banco de pruebas y de objetivo del editor.

## 5. Addon `uf_map_editor` (editor completo)
`res://addons/uf_map_editor/` (`plugin.cfg` + `EditorPlugin` `@tool`), solo API pública de `world`/`world_gen`:
- Dock (`add_control_to_dock`): seleccionar `BiomeDef`/`TileCatalog`, editar `WorldGenRequest` (bioma, tamaño, semilla, params de agua/camino), botón **Generar** sobre la escena de mundo abierta.
- **Pintado manual**: seleccionar `TileDef` y pintar celda con clic en el viewport 2D (`_forward_canvas_gui_input`); **edición de `z`** por celda (rueda/modificador) sobre `MapHeightField`.
- Guardar/cargar **presets** (`WorldGenRequest.tres`) y **mapa generado** (escena + `MapHeightField.tres`) en `res://assets/world/`.
- Registrar en `project.godot` `[editor_plugins]`.

## 6. Motor de NPC: `attributes` (ATR), `appearance` (APP), `npc` (NPC)
Resources/escenas guardables, jerarquía por **datos** (no herencia profunda):
- `attributes`: `attribute_set.gd` (`AttributeSet`: strength/agility/willpower/vitality/perception/charisma), `vitals_template.gd` (`VitalsTemplate`) y `npc_vitals.gd` (`NpcVitals` runtime).
- `appearance`: `body_part_map.gd` (`BodyPartMap`: slots humanoide head/body/arm_left/...), `part_visual_def.gd` (`PartVisualDef` por orientación), `npc_appearance_controller.gd` (nodo: capas Base/Equipment/Injury por slot, `sync_from_instance`).
- `npc`: `npc_archetype.gd` (`NpcArchetype` con `parent` encadenable), `npc_instance_data.gd` (`NpcInstanceData` RefCounted: uid, grid_cell `Vector3i`, orientation, vitals, attributes), fachada `npc.gd` (`spawn(archetype, cell)` según pipeline §5.6 del diseño).
- Escena `res://scenes/npc/npc_base.tscn`: `NpcRoot(Node2D, y_sort)` -> `NpcAppearanceController` + `VisualRig` con `Slot_*` (Base/Equipment/Injury) + `AnimationPlayer` + `Area2D`.
- Arquetipos `.tres` (cadena): `res://assets/data/archetypes/npc_root.tres` -> `humanoid.tres` -> `human.tres`.
- **Asset aleatorio principal**: `_private` `@tool` o script genera un humano aleatorio (atributos/colores de partes placeholder) y lo guarda como `res://assets/data/archetypes/main_character.tres` (+ visuals placeholder en `res://assets/visuals/parts/`); instanciable en una escena de prueba.

## 7. Documentación
- Actualizar [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) §12 (registro de módulos: world, world_gen, camera, npc, appearance, attributes + addon) y estructura.
- Actualizar [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): formato de `TileDef` (flags no exclusivos, reglas por lado, modificadores dato+overlay, reglas de colocación) en §4 y registro de assets.

## Verificación
- Validar import/escenas con el MCP `user-godot` (abrir proyecto, generar mapa de prueba, instanciar personaje) o, en su defecto, ejecutar la escena `world_root` con un NPC de prueba.