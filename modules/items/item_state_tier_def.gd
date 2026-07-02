@tool
class_name ItemStateTierDef
extends Resource
## One wear/condition tier for an item definition (see docs/GAME_DESIGN.md section 7).
## Sprite index maps to a column in a merged weapon state strip (64px wide).

@export var id: StringName = &""
@export var display_name_key: String = ""
## Column index in a horizontal sprite strip (0 = pristine … 4 = battered).
@export var sprite_index: int = 0
@export var icon_override: Texture2D
@export var stat_multiplier: float = 1.0
@export var price_multiplier: float = 1.0
@export var durability_multiplier: float = 1.0
