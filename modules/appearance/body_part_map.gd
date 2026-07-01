@tool
class_name BodyPartMap
extends Resource
## Catalogue of anatomical part ids for an archetype (humanoid vs quadruped, ...).
## Drives which Slot_<id> nodes the appearance rig builds. Saveable as a .tres asset.

@export var parts: Array[StringName] = []

## Returns whether [param part_id] belongs to this body map.
func has_part(part_id: StringName) -> bool:
	return parts.has(part_id)

## Builds the standard humanoid body map (head, body, arms, legs).
static func humanoid() -> BodyPartMap:
	var map := BodyPartMap.new()
	map.parts = [&"body", &"head", &"arm_left", &"arm_right", &"leg_left", &"leg_right"]
	return map
