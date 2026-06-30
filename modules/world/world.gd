@tool
class_name WorldModule
extends Node2D
## Public facade for the map: tile read/write, height field and grid<->world conversion.
## Holds the standard TileMapLayers and exposes queries (passability, vision, cover, modifiers).
## @tool: scene root receives height_field / tile_catalog synced from the map editor session.

const _LOG := "WLD"

enum Layer { GROUND, TERRAIN, OBJECTS, STRUCTURES }

func _ready() -> void:
	if Engine.is_editor_hint():
		_ensure_layers()

var ground_layer: TileMapLayer
var terrain_layer: TileMapLayer
var objects_layer: TileMapLayer
var structures_layer: TileMapLayer
var modifiers_layer: TileMapLayer
var layers: Node2D

var tile_catalog: TileCatalog
var height_field: MapHeightField
var height_step: int = 8
var max_climb: int = 1

var _tileset: TileSet
var _modifier_tileset: TileSet
var _modifier_source_id: int = -1
var _modifier_coords: Dictionary = {}
var _modifier_defs: Dictionary = {}
var _modifiers: Dictionary = {}

## Builds the placeholder tilesets from [param catalog] and [param modifiers], assigns them to
## every layer, and prepares the height field for [param region]. Must run before painting.
## Pass [param shared_tileset] / [param shared_modifier_pack] from uf_map_editor to avoid
## rebuilding TileSets on every click (prevents editor crashes).
func configure(
	catalog: TileCatalog,
	modifiers: Array,
	region: Rect2i,
	shared_tileset: TileSet = null,
	shared_modifier_pack: Dictionary = {},
) -> void:
	if not _ensure_layers():
		push_error("[%s] configure: map layers are not wired" % _LOG)
		return
	clear_all_cells()
	tile_catalog = catalog
	height_step = Config.get_int("WORLD_HEIGHT_STEP", height_step)
	var tile_size := Vector2i(Config.get_int("WORLD_TILE_WIDTH", 64), Config.get_int("WORLD_TILE_HEIGHT", 32))
	if shared_tileset != null:
		_tileset = shared_tileset
	else:
		_tileset = PlaceholderTileSet.build_tiles(catalog.tiles, tile_size)
	for layer in [ground_layer, terrain_layer, objects_layer, structures_layer]:
		if layer != null and is_instance_valid(layer):
			if layer.tile_set != _tileset:
				layer.tile_set = _tileset
			layer.y_sort_enabled = true
	if shared_modifier_pack.has("tileset"):
		_modifier_tileset = shared_modifier_pack["tileset"]
		_modifier_source_id = shared_modifier_pack["source_id"]
		_modifier_coords = shared_modifier_pack["coords"]
	else:
		var overlay := PlaceholderTileSet.build_modifier_overlays(modifiers, tile_size)
		_modifier_tileset = overlay["tileset"]
		_modifier_source_id = overlay["source_id"]
		_modifier_coords = overlay["coords"]
	_modifier_defs.clear()
	for m in modifiers:
		_modifier_defs[m.id] = m
	if modifiers_layer != null and is_instance_valid(modifiers_layer):
		if modifiers_layer.tile_set != _modifier_tileset:
			modifiers_layer.tile_set = _modifier_tileset
		modifiers_layer.y_sort_enabled = true
	height_field = MapHeightField.new()
	height_field.height_step = height_step
	height_field.resize(region)
	_modifiers.clear()
	Log.info(_LOG, "init", "configured region=%s tiles=%d" % [region, catalog.tiles.size()])

## Converts a logical cell (x, y, z) to the global position where an actor's feet stand.
## Uses the bottom vertex of the isometric diamond (map_to_local is the cell center).
func grid_to_world(cell: Vector3i) -> Vector2:
	_ensure_layers()
	var local := ground_layer.map_to_local(Vector2i(cell.x, cell.y))
	local += _tile_foot_offset() + Vector2(0, -cell.z * height_step)
	return ground_layer.to_global(local)

## Node2D parent for actors; shares y-sort with tile layers (see docs/GAME_DESIGN.md §3.4).
func get_actor_parent() -> Node2D:
	_ensure_layers()
	return layers

func _tile_foot_offset() -> Vector2:
	if ground_layer == null or ground_layer.tile_set == null:
		return Vector2.ZERO
	var tile_h := float(ground_layer.tile_set.tile_size.y)
	return Vector2(0, tile_h * 0.5)

## Returns the map cell (x, y) under [param world_pos].
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_pos))

## Returns the z height stored for [param cell].
func cell_height(cell: Vector2i) -> int:
	return height_field.get_height(cell) if height_field != null else 0

## Returns the full logical cell (x, y, z) for the plane coordinate [param cell].
func cell3(cell: Vector2i) -> Vector3i:
	return Vector3i(cell.x, cell.y, cell_height(cell))

## Paints [param tile_id] on [param layer] at [param cell]. Logs a warning on unknown ids.
func set_tile(layer: int, cell: Vector2i, tile_id: StringName) -> void:
	var def := tile_catalog.get_tile(tile_id) if tile_catalog != null else null
	if def == null:
		Log.warn(_LOG, "set_tile unknown id=%s" % tile_id)
		return
	var map_layer := _layer(layer)
	if map_layer == null or not is_instance_valid(map_layer):
		return
	map_layer.set_cell(cell, def.source_id, def.atlas_coords)

## Clears any tile on [param layer] at [param cell].
func clear_tile(layer: int, cell: Vector2i) -> void:
	_layer(layer).erase_cell(cell)

## Sets the z height at [param cell].
func set_height(cell: Vector2i, z: int) -> void:
	if height_field != null:
		height_field.set_height(cell, z)

## Returns the top-most TileDef present at plane [param cell], searching from structures to ground.
func get_tile_def_at(cell: Vector2i) -> TileDef:
	for layer in [structures_layer, objects_layer, terrain_layer, ground_layer]:
		var def := _tile_def_on(layer, cell)
		if def != null:
			return def
	return null

## Applies [param modifier] (a TileModifierDef) to [param cell] and shows its overlay.
func add_modifier(cell: Vector2i, modifier: TileModifierDef) -> void:
	if modifier == null or modifiers_layer == null or not is_instance_valid(modifiers_layer):
		return
	_modifiers.get_or_add(cell, []).append(modifier)
	if _modifier_coords.has(modifier.id):
		modifiers_layer.set_cell(cell, _modifier_source_id, _modifier_coords[modifier.id])

## Removes every modifier from [param cell] and hides its overlay.
func clear_modifiers(cell: Vector2i) -> void:
	_modifiers.erase(cell)
	modifiers_layer.erase_cell(cell)

## Returns the modifiers currently applied to [param cell].
func get_modifiers(cell: Vector2i) -> Array:
	return _modifiers.get(cell, [])

## Returns the configured TileModifierDef registered under [param id], or null.
func get_modifier_def(id: StringName) -> TileModifierDef:
	return _modifier_defs.get(id, null)

## Returns whether an actor may move from [param from] to the adjacent cell in [param dir],
## honouring walkable tags, per-side rules on both tiles, and the max_climb height step.
func can_move(from: Vector3i, dir: int) -> bool:
	var from_cell := Vector2i(from.x, from.y)
	var to_cell := from_cell + Direction.to_vector(dir)
	var from_def := get_tile_def_at(from_cell)
	var to_def := get_tile_def_at(to_cell)
	if to_def == null:
		return false
	if from_def != null and not from_def.is_walkable_from(dir):
		return false
	if not to_def.is_walkable_from(Direction.opposite(dir)):
		return false
	return absi(cell_height(to_cell) - cell_height(from_cell)) <= max_climb

## Returns whether vision from [param cell] is blocked toward [param dir].
func blocks_vision(cell: Vector2i, dir: int) -> bool:
	var def := get_tile_def_at(cell)
	return def != null and def.blocks_vision_from(dir)

## Returns whether the tile at [param cell] grants cover toward [param dir].
func provides_cover(cell: Vector2i, dir: int) -> bool:
	var def := get_tile_def_at(cell)
	return def != null and def.provides_cover_to(dir)

## Clears every painted cell on all map layers (required before swapping TileSet in the editor).
func clear_all_cells() -> void:
	if not _ensure_layers():
		return
	for layer in [ground_layer, terrain_layer, objects_layer, structures_layer, modifiers_layer]:
		if layer == null or not is_instance_valid(layer):
			continue
		if Engine.is_editor_hint():
			for cell in layer.get_used_cells():
				layer.erase_cell(cell)
		else:
			layer.clear()

## Resolves the layer node references from the scene; safe to call repeatedly.
func ensure_layers() -> void:
	_ensure_layers()

## Wires TileMapLayer nodes from [param root] (uf_map_editor session; root is not this node).
func bind_edited_root(root: Node2D) -> void:
	var layers_node := root.get_node_or_null("Layers")
	if layers_node == null:
		push_error("[WLD] bind_edited_root: missing Layers node on %s" % root.name)
		return
	ground_layer = layers_node.get_node_or_null("Ground") as TileMapLayer
	terrain_layer = layers_node.get_node_or_null("Terrain") as TileMapLayer
	objects_layer = layers_node.get_node_or_null("Objects") as TileMapLayer
	structures_layer = layers_node.get_node_or_null("Structures") as TileMapLayer
	modifiers_layer = layers_node.get_node_or_null("Modifiers") as TileMapLayer
	layers = layers_node as Node2D

## Forces TileMapLayer redraw after procedural or manual edits.
func refresh_map_layers() -> void:
	if not _ensure_layers():
		return
	if Engine.is_editor_hint():
		return
	for layer in [ground_layer, terrain_layer, objects_layer, structures_layer, modifiers_layer]:
		if layer != null and is_instance_valid(layer):
			layer.queue_redraw()

## Returns a canvas-space rect covering [param region] (for editor framing).
func get_map_canvas_rect(region: Rect2i) -> Rect2:
	_ensure_layers()
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var corners := [
		region.position,
		region.position + Vector2i(region.size.x - 1, 0),
		region.position + Vector2i(0, region.size.y - 1),
		region.position + region.size - Vector2i.ONE,
	]
	for c in corners:
		var p := ground_layer.to_global(ground_layer.map_to_local(c))
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return Rect2(min_p, max_p - min_p)

## Off-tree world used by uf_map_editor so generation does not touch the edited scene.
static func create_scratch() -> WorldModule:
	var world := WorldModule.new()
	world.name = "ScratchWorld"
	var layers_node := Node2D.new()
	layers_node.name = "Layers"
	world.add_child(layers_node)
	for layer_name in ["Ground", "Terrain", "Objects", "Structures", "Modifiers"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layers_node.add_child(layer)
	world.ensure_layers()
	return world

## Copies tilesets, cells, height and modifier state from [param source] into this world.
func apply_map_from(source: WorldModule) -> void:
	apply_map_metadata_from(source)
	apply_map_layer_from(source, &"ground")
	apply_map_layer_from(source, &"terrain")
	apply_map_layer_from(source, &"objects")
	apply_map_layer_from(source, &"structures")
	apply_map_layer_from(source, &"modifiers")

## Copies catalog, height field and modifier bookkeeping from [param source].
func apply_map_metadata_from(source: WorldModule) -> void:
	if source == null:
		return
	_tileset = source._tileset
	_modifier_tileset = source._modifier_tileset
	_modifier_source_id = source._modifier_source_id
	_modifier_coords = source._modifier_coords.duplicate(true)
	_modifier_defs = source._modifier_defs.duplicate(true)
	_modifiers = source._modifiers.duplicate(true)
	tile_catalog = source.tile_catalog
	height_field = source.height_field.duplicate(true) if source.height_field != null else null

## Copies one TileMapLayer from [param source] by [param layer_key].
func apply_map_layer_from(source: WorldModule, layer_key: StringName) -> void:
	if source == null or not source._ensure_layers() or not _ensure_layers():
		return
	match layer_key:
		&"ground":
			_copy_layer_from(source.ground_layer, ground_layer, _tileset)
		&"terrain":
			_copy_layer_from(source.terrain_layer, terrain_layer, _tileset)
		&"objects":
			_copy_layer_from(source.objects_layer, objects_layer, _tileset)
		&"structures":
			_copy_layer_from(source.structures_layer, structures_layer, _tileset)
		&"modifiers":
			_copy_layer_from(source.modifiers_layer, modifiers_layer, _modifier_tileset)

func _copy_layer_from(src: TileMapLayer, dst: TileMapLayer, tileset: TileSet) -> void:
	if src == null or dst == null or not is_instance_valid(dst):
		return
	if tileset != null:
		dst.tile_set = tileset.duplicate(true) as TileSet if Engine.is_editor_hint() else tileset
	if Engine.is_editor_hint():
		for cell in dst.get_used_cells():
			dst.erase_cell(cell)
	else:
		dst.clear()
	for cell in src.get_used_cells():
		dst.set_cell(
			cell,
			src.get_cell_source_id(cell),
			src.get_cell_atlas_coords(cell),
			src.get_cell_alternative_tile(cell),
		)

func _ensure_layers() -> bool:
	if ground_layer != null and is_instance_valid(ground_layer):
		return true
	ground_layer = null
	terrain_layer = null
	objects_layer = null
	structures_layer = null
	modifiers_layer = null
	layers = null
	var layers_node := get_node_or_null("Layers")
	if layers_node == null:
		return false
	ground_layer = layers_node.get_node_or_null("Ground") as TileMapLayer
	terrain_layer = layers_node.get_node_or_null("Terrain") as TileMapLayer
	objects_layer = layers_node.get_node_or_null("Objects") as TileMapLayer
	structures_layer = layers_node.get_node_or_null("Structures") as TileMapLayer
	modifiers_layer = layers_node.get_node_or_null("Modifiers") as TileMapLayer
	layers = layers_node as Node2D
	return ground_layer != null

func _tile_def_on(layer: TileMapLayer, cell: Vector2i) -> TileDef:
	if layer == null or layer.get_cell_source_id(cell) == -1:
		return null
	var data := layer.get_cell_tile_data(cell)
	if data == null or tile_catalog == null:
		return null
	return tile_catalog.get_tile(data.get_custom_data("tile_def_id"))

func _layer(layer: int) -> TileMapLayer:
	match layer:
		Layer.GROUND: return ground_layer
		Layer.TERRAIN: return terrain_layer
		Layer.OBJECTS: return objects_layer
		Layer.STRUCTURES: return structures_layer
		_: return ground_layer
