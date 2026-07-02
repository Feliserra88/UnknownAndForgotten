@tool
class_name EquipmentState
extends RefCounted
## Mutable runtime equipment and inventory for a single NPC (see docs/GAME_DESIGN.md section 7).
## Maps slot -> ItemInstance; portable items live in inventory arrays.

var _by_slot: Dictionary = {}
var _inventory: Array = []
var _death_loot: Array = []

## Equips [param instance] into [param slot], replacing any previous item there.
func equip(slot: StringName, instance: ItemInstance) -> void:
	if instance != null:
		instance.ensure_uid()
	_by_slot[slot] = instance

## Clears the item in [param slot] if any.
func unequip(slot: StringName) -> void:
	_by_slot.erase(slot)

## Returns the ItemInstance equipped in [param slot], or null when empty.
func get_instance(slot: StringName) -> ItemInstance:
	return _by_slot.get(slot, null)

## Returns the definition id equipped in [param slot], or empty when none.
func get_item(slot: StringName) -> StringName:
	var inst: ItemInstance = get_instance(slot)
	return inst.def_id if inst != null else &""

## Returns whether [param slot] currently holds an item.
func has_item(slot: StringName) -> bool:
	return _by_slot.has(slot) and _by_slot[slot] != null

## Returns the occupied slot ids.
func occupied_slots() -> Array:
	return _by_slot.keys()

## Returns equipped ItemInstances for every occupied slot.
func equipped_instances() -> Array:
	var out: Array = []
	for slot in occupied_slots():
		var inst: ItemInstance = _by_slot[slot]
		if inst != null:
			out.append(inst)
	return out

## Returns definition ids for every equipped instance (legacy helper).
func item_ids() -> Array:
	var out: Array = []
	for inst in equipped_instances():
		out.append((inst as ItemInstance).def_id)
	return out

## Adds [param instance] to the portable inventory bag.
func add_to_inventory(instance: ItemInstance) -> void:
	if instance != null:
		instance.ensure_uid()
		_inventory.append(instance)

## Returns a copy of the portable inventory array.
func inventory_items() -> Array:
	return _inventory.duplicate()

## Adds [param instance] to the death-loot bag.
func add_to_death_loot(instance: ItemInstance) -> void:
	if instance != null:
		instance.ensure_uid()
		_death_loot.append(instance)

## Returns a copy of the death-loot array.
func death_loot_items() -> Array:
	return _death_loot.duplicate()
