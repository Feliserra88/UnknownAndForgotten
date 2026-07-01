@tool
class_name MapPropDef
extends Resource
## Tall map prop placed as a free Sprite2D (tree, large rock). Foot at cell center + offset.

@export var id: StringName = &""
@export var display_name_key: String = ""

@export_group("Visual")
@export var sprite_texture: Texture2D
## Y-sort anchor from sprite bottom (pixels up from texture bottom).
@export var y_sort_origin: int = 0
## Max random offset from tile center in local pixels (x, y).
@export var offset_spread: Vector2 = Vector2(10.0, 6.0)

@export_group("Gameplay")
@export_flags("Ground", "Walkable", "Wall", "Water", "Hazard", "Interactable", "Cover", "VisionBlocker") var tags: int = 0
## When true the prop's cell is treated as blocked for pathfinding queries.
@export var blocks_cell: bool = false

func has_tag(tag: int) -> bool:
	return (tags & tag) != 0

func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(id)
