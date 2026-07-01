@tool
class_name EquipmentState
extends RefCounted
## Mutable runtime equipment for a single NPC: maps slot -> item id. Owned per instance,
## never a shared .tres (see docs/GAME_DESIGN.md section 5.7).

var _by_slot: Dictionary = {}

## Equips [param item_id] into [param slot], replacing any previous item there.
func equip(slot: StringName, item_id: StringName) -> void:
	_by_slot[slot] = item_id

## Clears the item in [param slot] if any.
func unequip(slot: StringName) -> void:
	_by_slot.erase(slot)

## Returns the item id equipped in [param slot], or &"" when empty.
func get_item(slot: StringName) -> StringName:
	return _by_slot.get(slot, &"")

## Returns whether [param slot] currently holds an item.
func has_item(slot: StringName) -> bool:
	return _by_slot.has(slot)

## Returns the occupied slot ids.
func occupied_slots() -> Array:
	return _by_slot.keys()

## Returns the equipped item id for every occupied slot.
func item_ids() -> Array:
	return _by_slot.values()
