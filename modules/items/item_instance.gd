@tool
class_name ItemInstance
extends RefCounted
## Mutable runtime item stack (see docs/GAME_DESIGN.md section 7). Never saved as a shared .tres.

var def_id: StringName = &""
var state_index: int = 0
var quality_index: int = 0
var modifier_ids: Array[StringName] = []
var durability: float = -1.0
var count: int = 1
var instance_uid: String = ""

static var _next_uid: int = 1

## Assigns a unique instance id when [member instance_uid] is empty.
func ensure_uid() -> void:
	if instance_uid.is_empty():
		instance_uid = "itm_%d" % _next_uid
		_next_uid += 1

## Returns a shallow duplicate suitable for inventory moves.
func duplicate_instance() -> ItemInstance:
	var copy := ItemInstance.new()
	copy.def_id = def_id
	copy.state_index = state_index
	copy.quality_index = quality_index
	copy.modifier_ids = modifier_ids.duplicate()
	copy.durability = durability
	copy.count = count
	copy.instance_uid = instance_uid
	return copy
