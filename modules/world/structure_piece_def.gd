@tool
class_name StructurePieceDef
extends Resource
## One modular building sprite (wall, door, roof…) placed on the Props layer by the map editor.

enum PieceType { WALL, CORNER, DOOR, WINDOW, ROOF, FLOOR_REF, OTHER }

@export var id: StringName = &""
@export var kit_id: StringName = &""
@export var display_name_key: String = ""
@export var piece_type: PieceType = PieceType.WALL

@export_group("Visual")
@export var sprite_texture: Texture2D
## Pixels up from texture bottom for y-sort anchor (0 = sprite foot at cell center).
@export var y_sort_origin: int = 0
## Extra offset from anchor cell center in layer-local pixels.
@export var local_offset: Vector2 = Vector2.ZERO

@export_group("Placement")
## Footprint in cells from anchor (x = east, y = south on the map grid).
@export var footprint: Vector2i = Vector2i(1, 1)
## Editor-only hints for which sides should connect to neighbours (not from PixelLab).
@export_flags("North", "East", "South", "West") var connect_hints: int = 0

@export_group("Gameplay")
@export var blocks_cell: bool = true

func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(id)

func has_connect_hint(flag: int) -> bool:
	return (connect_hints & flag) != 0

func footprint_cells(anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size := footprint
	if size.x < 1:
		size.x = 1
	if size.y < 1:
		size.y = 1
	for dx in size.x:
		for dy in size.y:
			cells.append(anchor + Vector2i(dx, dy))
	return cells
