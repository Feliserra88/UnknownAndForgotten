class_name WorldModule
extends Node2D
## Public facade for the map: tile read/write, height field and grid<->world conversion.
## Holds the standard TileMapLayers and exposes queries (passability, vision, cover, modifiers).

const _LOG := "WLD"

enum Layer { GROUND, TERRAIN, OBJECTS, STRUCTURES }

var ground_layer: TileMapLayer
var terrain_layer: TileMapLayer
var objects_layer: TileMapLayer
var structures_layer: TileMapLayer
var modifiers_layer: TileMapLayer

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
func configure(catalog: TileCatalog, modifiers: Array, region: Rect2i) -> void:
	_ensure_layers()
	tile_catalog = catalog
	height_step = Config.get_int("WORLD_HEIGHT_STEP", height_step)
	var tile_size := Vector2i(Config.get_int("WORLD_TILE_WIDTH", 64), Config.get_int("WORLD_TILE_HEIGHT", 32))
	_tileset = PlaceholderTileSet.build_tiles(catalog.tiles, tile_size)
	for layer in [ground_layer, terrain_layer, objects_layer, structures_layer]:
		layer.tile_set = _tileset
		layer.y_sort_enabled = true
	var overlay := PlaceholderTileSet.build_modifier_overlays(modifiers, tile_size)
	_modifier_tileset = overlay["tileset"]
	_modifier_source_id = overlay["source_id"]
	_modifier_coords = overlay["coords"]
	_modifier_defs.clear()
	for m in modifiers:
		_modifier_defs[m.id] = m
	modifiers_layer.tile_set = _modifier_tileset
	modifiers_layer.y_sort_enabled = true
	height_field = MapHeightField.new()
	height_field.height_step = height_step
	height_field.resize(region)
	_modifiers.clear()
	Log.info(_LOG, "init", "configured region=%s tiles=%d" % [region, catalog.tiles.size()])

## Converts a logical cell (x, y, z) to its 2D world position, offsetting by z * height_step.
func grid_to_world(cell: Vector3i) -> Vector2:
	var base := ground_layer.map_to_local(Vector2i(cell.x, cell.y))
	return base + Vector2(0, -cell.z * height_step)

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
	_layer(layer).set_cell(cell, def.source_id, def.atlas_coords)

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
	if modifier == null:
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

## Resolves the layer node references from the scene; safe to call repeatedly.
func _ensure_layers() -> void:
	if ground_layer != null:
		return
	ground_layer = $Layers/Ground
	terrain_layer = $Layers/Terrain
	objects_layer = $Layers/Objects
	structures_layer = $Layers/Structures
	modifiers_layer = $Layers/Modifiers

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
