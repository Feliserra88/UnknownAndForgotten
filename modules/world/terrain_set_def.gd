@tool
class_name TerrainSetDef
extends Resource
## Wang autotile TileSet reference for terrain transitions (water, paths, cave floors, walls).

@export var id: StringName = &""
@export var display_name_key: String = ""
## Prebuilt TileSet with terrain sets configured (from PixelLab Wang pipeline).
@export var tileset: TileSet
## Index of the terrain set inside [member tileset] (usually 0).
@export var terrain_set_index: int = 0
## Maps logical terrain names to Godot terrain indices inside the set.
@export var terrain_ids: Dictionary = {}

func get_terrain_index(terrain_name: StringName) -> int:
	return int(terrain_ids.get(terrain_name, -1))

func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(id)
