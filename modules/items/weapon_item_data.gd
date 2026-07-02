@tool
class_name WeaponItemData
extends Resource
## Category payload for weapons (see docs/GAME_DESIGN.md section 7).

@export var weapon_family: StringName = &""
@export var design_type: StringName = &""
@export var slot: StringName = &"arm_right"
@export var visual: EquipmentVisualDef
@export var hands: int = 1
@export var attribute_modifier_id: StringName = &""
