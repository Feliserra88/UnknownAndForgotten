extends RefCounted
## Paints Wang terrain regions via TileMapLayer.set_cells_terrain_connect. Internal to world.

static func paint_cells(
	terrain_layer: TileMapLayer,
	cells: Array,
	terrain_set: TerrainSetDef,
	terrain_name: StringName,
) -> bool:
	if terrain_layer == null or terrain_set == null or terrain_set.tileset == null:
		return false
	var terrain_id := terrain_set.get_terrain_index(terrain_name)
	if terrain_id < 0:
		push_warning("WangTerrainPainter: unknown terrain '%s' in set '%s'" % [terrain_name, terrain_set.id])
		return false
	if terrain_layer.tile_set != terrain_set.tileset:
		terrain_layer.tile_set = terrain_set.tileset
	var typed: Array[Vector2i] = []
	for c in cells:
		typed.append(c)
	if typed.is_empty():
		return false
	terrain_layer.set_cells_terrain_connect(typed, terrain_set.terrain_set_index, terrain_id)
	return true
