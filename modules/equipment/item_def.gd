class_name ItemDef
extends Resource
## Data-driven equipable item (see docs/GAME_DESIGN.md section 7). Binds an inventory slot to an
## optional visual and attribute modifier. Saveable as a .tres asset under res://assets/data/items/.

@export var id: StringName = &""
@export var display_name_key: String = ""
## Equipment slot this item occupies (e.g. "head", "body", "arm_left").
@export var slot: StringName = &""
## Archetype tags allowed to equip this item; empty means any archetype.
@export var allowed_archetype_tags: Array[StringName] = []
@export var icon: Texture2D
@export var visual: EquipmentVisualDef
## Optional ModifierDef id applied while equipped.
@export var attribute_modifier_id: StringName = &""

## Returns whether this item can be equipped by an archetype exposing [param archetype_tags].
func allows_archetype(archetype_tags: Array) -> bool:
	if allowed_archetype_tags.is_empty():
		return true
	for tag in allowed_archetype_tags:
		if archetype_tags.has(tag):
			return true
	return false
