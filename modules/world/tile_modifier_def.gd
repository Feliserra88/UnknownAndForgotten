@tool
class_name TileModifierDef
extends Resource
## Optional state layered over a tile (wet, snowy, burning): gameplay data plus an
## optional visual overlay drawn on the modifiers layer. Saveable as a .tres asset.

@export var id: StringName = &""
@export var display_name_key: String = ""

@export_group("Visual overlay")
## Overlay texture; when null a flat tinted diamond is generated as placeholder.
@export var overlay_texture: Texture2D
@export var overlay_color: Color = Color(1.0, 1.0, 1.0, 0.5)

@export_group("Gameplay")
## Extra tile tags contributed while the modifier is active (e.g. burning adds Hazard).
@export_flags("Ground", "Walkable", "Wall", "Water", "Hazard", "Interactable", "Cover", "VisionBlocker") var adds_tags: int = 0
## Multiplier applied to movement cost over the tile (e.g. snow slows down).
@export var movement_cost_mult: float = 1.0
## When false the modifier may expire or spread over time; when true it is static.
@export var permanent: bool = false

## Returns the localized display name for this modifier.
func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(id)
