@tool
class_name EquipmentVisualDef
extends Resource
## How an equipped item is drawn over a body part's EquipmentLayer (see docs/GAME_DESIGN.md
## section 5.5). Saveable as a .tres asset under res://assets/visuals/equipment/.

## How the item covers the base layer beneath it.
enum Coverage { NONE, PARTIAL, FULL }

## Anatomical part id this visual attaches to (e.g. "head", "arm_left").
@export var slot: StringName = &""
@export var base_coverage: Coverage = Coverage.PARTIAL
## Textures keyed by orientation (front/back/side_left/side_right).
@export var textures: Dictionary = {}
@export var z_offset: int = 0

## Returns the texture for [param orientation], or null when none is defined.
func get_texture(orientation: StringName) -> Texture2D:
	return textures.get(orientation, null)
