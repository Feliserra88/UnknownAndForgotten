@tool
class_name PartVisualDef
extends Resource
## Visual definition of a body part's base layer (see docs/GAME_DESIGN.md section 5.5.4).
## Placeholder build uses a flat colour rectangle; real art supplies per-orientation textures.
## Saveable as a .tres asset.

@export var part_id: StringName = &""
## Optional textures keyed by orientation (front/back/side_left/side_right).
@export var textures: Dictionary = {}
@export_group("Placeholder")
@export var placeholder_color: Color = Color(0.8, 0.7, 0.6)
@export var size: Vector2i = Vector2i(16, 16)
## Offset in pixels from the NPC root where this part's slot is anchored.
@export var offset: Vector2 = Vector2.ZERO
@export var z_index: int = 0

## Returns the texture for [param orientation], or null when none is defined.
func get_texture(orientation: StringName) -> Texture2D:
	return textures.get(orientation, null)
