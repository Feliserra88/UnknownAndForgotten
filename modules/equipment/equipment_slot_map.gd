@tool
class_name EquipmentSlotMap
extends Resource
## Catalogue of equipment (object) slots for an archetype, distinct from anatomical BodyPartMap
## (see docs/GAME_DESIGN.md section 7.1). Saveable as a .tres asset.

@export var slots: Array[StringName] = []

## Returns whether [param slot] belongs to this map.
func has_slot(slot: StringName) -> bool:
	return slots.has(slot)

## Builds the standard humanoid equipment slot map (section 7.1).
static func humanoid() -> EquipmentSlotMap:
	var map := EquipmentSlotMap.new()
	map.slots = [
		&"head", &"body", &"arm_left", &"arm_right", &"belt",
		&"neck", &"ring_1", &"ring_2", &"feet", &"back",
	]
	return map
