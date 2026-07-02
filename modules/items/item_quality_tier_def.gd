@tool
class_name ItemQualityTierDef
extends Resource
## One rarity/quality tier for an item definition (common, uncommon, rare, …).

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var stat_multiplier: float = 1.0
@export var price_multiplier: float = 1.0
@export var tint_color: Color = Color.WHITE
