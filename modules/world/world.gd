@tool
class_name WorldModule
extends Node2D
## Public facade for the map: tile read/write, height field and grid<->world conversion.
## Holds the standard TileMapLayers and exposes queries (passability, vision, cover, modifiers).
## @tool: scene root receives height_field / tile_catalog synced from the map editor session.

const _LOG := "WLD"
const _MapSprites := preload("res://modules/world/_private/map_sprite_layer.gd")
const _WangPainter := preload("res://modules/world/_private/wang_terrain_painter.gd")
## Default path for editor-painted tile data (under gitignored `res://local/`).
const EDITOR_SESSION_MAP_PATH := "res://local/world/maps/editor_session.tscn"

enum Layer { GROUND, TERRAIN, OBJECTS, STRUCTURES }

## When set, the editor loads baked tiles from this scene on open (see `save_baked_map`).
@export_file("*.tscn") var editor_baked_map: String = EDITOR_SESSION_MAP_PATH

func _ready() -> void:
	if Engine.is_editor_hint():
		_ensure_layers()
		if not editor_baked_map.is_empty():
			load_baked_map(editor_baked_map)

var ground_layer: TileMapLayer
var terrain_layer: TileMapLayer
var objects_layer: TileMapLayer
var structures_layer: TileMapLayer
var modifiers_layer: TileMapLayer
var props_layer: Node2D
var decor_layer: Node2D
var layers: Node2D
var actors: Node2D

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
var _prop_defs: Dictionary = {}
var _decor_defs: Dictionary = {}
var _terrain_set_defs: Dictionary = {}
var _blocked_prop_cells: Dictionary = {}

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
	sprite_catalog: MapSpriteCatalog = null,
	terrain_sets: Array = [],
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
		PlaceholderTileSet.assign_tile_mapping(catalog.tiles, _tileset)
	else:
		_tileset = PlaceholderTileSet.build_tiles(catalog.tiles, tile_size)
	for layer in [ground_layer, terrain_layer, objects_layer, structures_layer]:
		if layer != null and is_instance_valid(layer):
			if layer.tile_set != _tileset:
				layer.tile_set = _tileset
	_flatten_legacy_tile_layers()
	_apply_cell_tile_layer_settings(ground_layer)
	_clear_legacy_tile_map_layers()
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
	_prop_defs.clear()
	_decor_defs.clear()
	_blocked_prop_cells.clear()
	if sprite_catalog != null:
		for p in sprite_catalog.props:
			if p != null:
				_prop_defs[p.id] = p
		for d in sprite_catalog.decors:
			if d != null:
				_decor_defs[d.id] = d
	_terrain_set_defs.clear()
	for ts in terrain_sets:
		if ts is TerrainSetDef:
			_terrain_set_defs[ts.id] = ts
	if modifiers_layer != null and is_instance_valid(modifiers_layer):
		if modifiers_layer.tile_set != _modifier_tileset:
			modifiers_layer.tile_set = _modifier_tileset
		modifiers_layer.y_sort_enabled = false
		modifiers_layer.z_index = 1
	height_field = MapHeightField.new()
	height_field.height_step = height_step
	height_field.resize(region)
	_modifiers.clear()
	_clear_sprite_layers()
	Log.info(_LOG, "init", "configured region=%s tiles=%d props=%d decors=%d terrains=%d" % [
		region, catalog.tiles.size(), _prop_defs.size(), _decor_defs.size(), _terrain_set_defs.size(),
	])

## Converts a logical cell (x, y, z) to the global position at the tile center (map_to_local).
func grid_to_world(cell: Vector3i) -> Vector2:
	_ensure_layers()
	var local := ground_layer.map_to_local(Vector2i(cell.x, cell.y))
	local += Vector2(0, -cell.z * height_step)
	return ground_layer.to_global(local)

## Applies draw-order settings for a spawned actor (tile center position, y-sort among layers).
func apply_actor_y_sort(actor: Node2D) -> void:
	if actor == null:
		return
	actor.y_sort_enabled = true

## TileMap container (stays at origin; view rotation is on CameraRig).
func get_map_layers() -> Node2D:
	_ensure_layers()
	return layers

## Node2D parent for actors; shares y-sort with tile layers (see docs/GAME_DESIGN.md §3.4).
func get_actor_parent() -> Node2D:
	_ensure_layers()
	_ensure_actors()
	return actors

## Counter-rotates actor sprites so they stay upright when the camera rig is rotated.
func sync_actor_display_rotations() -> void:
	_ensure_actors()
	if actors == null:
		return
	var upright := -_get_view_rotation_rad()
	for child in actors.get_children():
		if child is Node2D:
			(child as Node2D).rotation = upright

func _get_view_rotation_rad() -> float:
	var cam := get_node_or_null("CameraRig") as CameraRig
	if cam != null:
		return cam.get_view_rotation_rad()
	return 0.0

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
	if Engine.is_editor_hint() and map_layer == ground_layer:
		map_layer.queue_redraw()

## Clears any tile on [param layer] at [param cell].
func clear_tile(layer: int, cell: Vector2i) -> void:
	_layer(layer).erase_cell(cell)

## Sets the z height at [param cell].
func set_height(cell: Vector2i, z: int) -> void:
	if height_field != null:
		height_field.set_height(cell, z)

## Returns the top-most TileDef present at plane [param cell] (single y-sorted cell layer).
func get_tile_def_at(cell: Vector2i) -> TileDef:
	return _tile_def_on(ground_layer, cell)

## Returns the configured MapPropDef registered under [param id], or null.
func get_prop_def(id: StringName) -> MapPropDef:
	return _prop_defs.get(id, null)

## Returns the configured MapDecorDef registered under [param id], or null.
func get_decor_def(id: StringName) -> MapDecorDef:
	return _decor_defs.get(id, null)

## Returns the configured TerrainSetDef registered under [param id], or null.
func get_terrain_set_def(id: StringName) -> TerrainSetDef:
	return _terrain_set_defs.get(id, null)

## Places a tall prop sprite at [param cell] with optional [param local_offset] (random if null).
func add_prop(cell: Vector2i, prop: MapPropDef, rng: RandomNumberGenerator = null, local_offset: Variant = null) -> void:
	if prop == null or not _ensure_layers():
		return
	var offset: Vector2 = local_offset if local_offset is Vector2 else _MapSprites.random_offset(
		rng if rng != null else RandomNumberGenerator.new(), prop.offset_spread)
	_MapSprites.spawn_prop(props_layer, ground_layer, cell, prop, offset)
	if prop.blocks_cell:
		_blocked_prop_cells[cell] = true

## Places a decorative sprite at [param cell] with random offset/scale inside the tile.
func add_decor(cell: Vector2i, decor: MapDecorDef, rng: RandomNumberGenerator) -> void:
	if decor == null or rng == null or not _ensure_layers():
		return
	var offset := _MapSprites.random_offset(rng, decor.offset_spread)
	var scale_factor := _MapSprites.random_scale(rng, decor.scale_range)
	_MapSprites.spawn_decor(decor_layer, ground_layer, cell, decor, offset, scale_factor)

## Paints [param cells] with Wang autotile [param terrain_name] from [param terrain_set].
func paint_terrain(cells: Array, terrain_set: TerrainSetDef, terrain_name: StringName) -> bool:
	_ensure_layers()
	return _WangPainter.paint_cells(terrain_layer, cells, terrain_set, terrain_name)

## Returns whether a prop marked [member MapPropDef.blocks_cell] occupies [param cell].
func is_prop_blocked(cell: Vector2i) -> bool:
	return _blocked_prop_cells.has(cell)

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
	var to_def := get_tile_def_at(to_cell)
	if to_def == null:
		return false
	if is_prop_blocked(to_cell):
		return false
	if not to_def.has_tag(TileTags.Tag.WALKABLE):
		return false
	if absi(cell_height(to_cell) - cell_height(from_cell)) > max_climb:
		return false
	if Direction.is_diagonal(dir):
		return _can_move_diagonal(from_cell, to_cell, dir, to_def)
	var from_def := get_tile_def_at(from_cell)
	if from_def != null and not from_def.is_walkable_from(dir):
		return false
	if not to_def.is_walkable_from(Direction.opposite(dir)):
		return false
	return true

func _can_move_diagonal(from_cell: Vector2i, _to_cell: Vector2i, dir: int, to_def: TileDef) -> bool:
	var offset := Direction.to_vector(dir)
	var side_x := from_cell + Vector2i(offset.x, 0)
	var side_y := from_cell + Vector2i(0, offset.y)
	for side in [side_x, side_y]:
		var side_def := get_tile_def_at(side)
		if side_def == null or not side_def.has_tag(TileTags.Tag.WALKABLE):
			return false
	if not to_def.is_walkable_from(Direction.opposite(dir)):
		return false
	return true

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
	_clear_sprite_layers()
	_blocked_prop_cells.clear()

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
	props_layer = layers_node.get_node_or_null("Props") as Node2D
	decor_layer = layers_node.get_node_or_null("Decor") as Node2D
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

## Writes tile layers (and optional height field) to [param map_path] for local/editor persistence.
func save_baked_map(map_path: String) -> Error:
	if not _ensure_layers():
		return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(map_path.get_base_dir())
	var bake_root := Node2D.new()
	bake_root.name = "BakedMap"
	var layers_copy: Node2D = layers.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node2D
	bake_root.add_child(layers_copy)
	layers_copy.owner = bake_root
	for child in layers_copy.get_children():
		child.owner = bake_root
	var packed := PackedScene.new()
	var pack_err := packed.pack(bake_root)
	bake_root.queue_free()
	if pack_err != OK:
		return pack_err
	var err := ResourceSaver.save(packed, map_path)
	if err == OK and height_field != null:
		err = ResourceSaver.save(height_field, _baked_height_path_for(map_path))
	return err

## Loads baked tiles from [param map_path] into this world (editor session restore).
func load_baked_map(map_path: String) -> bool:
	if map_path.is_empty() or not ResourceLoader.exists(map_path):
		return false
	var packed := load(map_path) as PackedScene
	if packed == null:
		return false
	var inst := packed.instantiate()
	var layers_node: Node2D = inst.get_node_or_null("Layers") as Node2D
	if layers_node == null:
		inst.queue_free()
		return false
	var wrapper := Node2D.new()
	wrapper.name = "BakeWrapper"
	inst.remove_child(layers_node)
	wrapper.add_child(layers_node)
	var temp := create_scratch()
	temp.bind_edited_root(wrapper)
	if temp.ground_layer != null:
		temp._tileset = temp.ground_layer.tile_set
	if temp.modifiers_layer != null:
		temp._modifier_tileset = temp.modifiers_layer.tile_set
	apply_map_from(temp)
	_ensure_editor_tile_catalog()
	_refresh_editor_tilesets_from_catalog()
	var height_path := _baked_height_path_for(map_path)
	if ResourceLoader.exists(height_path):
		height_field = (load(height_path) as MapHeightField).duplicate(true)
	wrapper.queue_free()
	inst.queue_free()
	Log.info(_LOG, "load_bake", map_path)
	return true

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
	var props_node := Node2D.new()
	props_node.name = "Props"
	props_node.y_sort_enabled = true
	layers_node.add_child(props_node)
	var decor_node := Node2D.new()
	decor_node.name = "Decor"
	decor_node.y_sort_enabled = true
	layers_node.add_child(decor_node)
	var actors_node := Node2D.new()
	actors_node.name = "Actors"
	actors_node.y_sort_enabled = true
	layers_node.add_child(actors_node)
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
	_copy_sprite_layer_from(source.props_layer, props_layer)
	_copy_sprite_layer_from(source.decor_layer, decor_layer)
	_flatten_legacy_tile_layers()
	_apply_cell_tile_layer_settings(ground_layer)
	_clear_legacy_tile_map_layers()

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
	_prop_defs = source._prop_defs.duplicate(true)
	_decor_defs = source._decor_defs.duplicate(true)
	_terrain_set_defs = source._terrain_set_defs.duplicate(true)
	_blocked_prop_cells = source._blocked_prop_cells.duplicate(true)
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
		&"props":
			_copy_sprite_layer_from(source.props_layer, props_layer)
		&"decor":
			_copy_sprite_layer_from(source.decor_layer, decor_layer)

func _copy_sprite_layer_from(src: Node2D, dst: Node2D) -> void:
	if src == null or dst == null or not is_instance_valid(dst):
		return
	_MapSprites.clear_layer(dst)
	for child in src.get_children():
		if child is Sprite2D:
			var copy := child.duplicate() as Sprite2D
			dst.add_child(copy)

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

func _baked_height_path_for(map_path: String) -> String:
	return "%s_height.tres" % map_path.get_basename()

func _ensure_editor_tile_catalog() -> void:
	if tile_catalog != null:
		return
	var world_gen := WorldGenModule.new()
	tile_catalog = world_gen.build_field_catalog()
	world_gen.free()

## Rebuilds TileSets from [param catalog] without clearing painted cells or the height field.
func refresh_tilesets(
	catalog: TileCatalog,
	modifiers: Array,
	shared_tileset: TileSet = null,
	shared_modifier_pack: Dictionary = {},
) -> void:
	if not _ensure_layers() or catalog == null:
		return
	tile_catalog = catalog
	var tile_size := Vector2i(Config.get_int("WORLD_TILE_WIDTH", 64), Config.get_int("WORLD_TILE_HEIGHT", 32))
	if shared_tileset != null:
		_tileset = shared_tileset
		PlaceholderTileSet.assign_tile_mapping(catalog.tiles, _tileset)
	else:
		_tileset = PlaceholderTileSet.build_tiles(catalog.tiles, tile_size)
	for layer in [ground_layer, terrain_layer, objects_layer, structures_layer]:
		if layer != null and is_instance_valid(layer):
			if layer.tile_set != _tileset:
				layer.tile_set = _tileset
	_flatten_legacy_tile_layers()
	_apply_cell_tile_layer_settings(ground_layer)
	_clear_legacy_tile_map_layers()
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
		modifiers_layer.tile_set = _modifier_tileset
		modifiers_layer.y_sort_enabled = false
		modifiers_layer.z_index = 1

func _refresh_editor_tilesets_from_catalog() -> void:
	if not Engine.is_editor_hint() or tile_catalog == null:
		return
	var world_gen := WorldGenModule.new()
	var modifiers := world_gen.build_field_modifiers()
	world_gen.free()
	refresh_tilesets(tile_catalog, modifiers)

func _ensure_layers() -> bool:
	if ground_layer != null and is_instance_valid(ground_layer):
		return true
	ground_layer = null
	terrain_layer = null
	objects_layer = null
	structures_layer = null
	modifiers_layer = null
	props_layer = null
	decor_layer = null
	layers = null
	actors = null
	var layers_node := get_node_or_null("Layers")
	if layers_node == null:
		return false
	ground_layer = layers_node.get_node_or_null("Ground") as TileMapLayer
	terrain_layer = layers_node.get_node_or_null("Terrain") as TileMapLayer
	objects_layer = layers_node.get_node_or_null("Objects") as TileMapLayer
	structures_layer = layers_node.get_node_or_null("Structures") as TileMapLayer
	modifiers_layer = layers_node.get_node_or_null("Modifiers") as TileMapLayer
	props_layer = layers_node.get_node_or_null("Props") as Node2D
	decor_layer = layers_node.get_node_or_null("Decor") as Node2D
	layers = layers_node as Node2D
	actors = layers_node.get_node_or_null("Actors") as Node2D
	_apply_cell_tile_layer_settings(ground_layer)
	return ground_layer != null

func _ensure_actors() -> void:
	if actors != null and is_instance_valid(actors):
		return
	if layers == null:
		return
	actors = layers.get_node_or_null("Actors") as Node2D
	if actors == null:
		actors = Node2D.new()
		actors.name = "Actors"
		actors.y_sort_enabled = true
		layers.add_child(actors)

func _tile_def_on(layer: TileMapLayer, cell: Vector2i) -> TileDef:
	if layer == null or layer.get_cell_source_id(cell) == -1:
		return null
	var data := layer.get_cell_tile_data(cell)
	if data == null or tile_catalog == null:
		return null
	return tile_catalog.get_tile(data.get_custom_data("tile_def_id"))

func _layer(layer: int) -> TileMapLayer:
	# All gameplay cell tiles share Ground so y-sort is per cell, not paint order / layer tree order.
	match layer:
		Layer.GROUND, Layer.TERRAIN, Layer.OBJECTS, Layer.STRUCTURES:
			return ground_layer
		_:
			return ground_layer

## Y-sort anchor at the diamond foot: higher grid y draws in front at the same z.
func _apply_cell_tile_layer_settings(map_layer: TileMapLayer) -> void:
	if map_layer == null or not is_instance_valid(map_layer) or map_layer.tile_set == null:
		return
	map_layer.y_sort_enabled = true
	map_layer.y_sort_origin = map_layer.tile_set.tile_size.y / 2

## Merges legacy Terrain/Objects/Structures cells into Ground (older maps and generator splits).
func _flatten_legacy_tile_layers() -> void:
	if not _ensure_layers() or ground_layer == null:
		return
	var winner: Dictionary = {}
	for src in [ground_layer, terrain_layer, objects_layer, structures_layer]:
		if src == null or not is_instance_valid(src):
			continue
		for cell in src.get_used_cells():
			if src.get_cell_source_id(cell) == -1:
				continue
			winner[cell] = {
				"source": src.get_cell_source_id(cell),
				"atlas": src.get_cell_atlas_coords(cell),
				"alt": src.get_cell_alternative_tile(cell),
			}
	if winner.is_empty():
		return
	for src in [ground_layer, terrain_layer, objects_layer, structures_layer]:
		if src == null or not is_instance_valid(src):
			continue
		if Engine.is_editor_hint():
			for cell in src.get_used_cells():
				src.erase_cell(cell)
		else:
			src.clear()
	for cell in winner:
		var w: Dictionary = winner[cell]
		ground_layer.set_cell(cell, w["source"], w["atlas"], w["alt"])

func _clear_legacy_tile_map_layers() -> void:
	for legacy in [terrain_layer, objects_layer, structures_layer]:
		if legacy == null or not is_instance_valid(legacy) or legacy == ground_layer:
			continue
		if Engine.is_editor_hint():
			for cell in legacy.get_used_cells():
				legacy.erase_cell(cell)
		else:
			legacy.clear()
		legacy.y_sort_enabled = false

func _clear_sprite_layers() -> void:
	_MapSprites.clear_layer(props_layer)
	_MapSprites.clear_layer(decor_layer)
