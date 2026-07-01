@tool
class_name MapDecorDef
extends Resource
## Small decorative sprite on terrain (pebble, flower). No gameplay effect.

@export var id: StringName = &""
@export var display_name_key: String = ""

@export_group("Visual")
@export var sprite_texture: Texture2D
## Max random offset from tile center in local pixels.
@export var offset_spread: Vector2 = Vector2(14.0, 8.0)
## Optional scale jitter range (min, max).
@export var scale_range: Vector2 = Vector2(0.85, 1.15)

func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(id)
