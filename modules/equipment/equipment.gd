@tool
class_name EquipmentModule
extends RefCounted
## Public facade for equipping items on NPCs (see docs/GAME_DESIGN.md section 7). Item definitions
## live in ItemsModule; this module validates slots and resolves equipment visuals.

const _LOG := "EQP"
const DIR := "res://assets/data/items"

var _items: ItemsModule = ItemsModule.new()

## Returns the ItemDef for [param id] via ItemsModule.
func load_item(id: StringName) -> ItemDef:
	return _items.load_def(id)

## Returns every ItemDef asset found in DIR.
func list_items() -> Array[ItemDef]:
	return _items.list_defs()

## Returns items that fit [param slot] and are allowed for [param archetype_tags].
func compatible_items(archetype_tags: Array, slot: StringName) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for item in list_items():
		if item.get_equip_slot() == slot and item.allows_archetype(archetype_tags):
			out.append(item)
	return out

## Returns the EquipmentVisualDef bound to [param item_id], or null.
func resolve_visual(item_id: StringName) -> EquipmentVisualDef:
	var item := load_item(item_id)
	return item.get_visual() if item != null else null

## Returns the ModifierDef ids granted by equipped instances in [param state].
func attribute_modifier_ids(state: EquipmentState) -> Array[StringName]:
	var out: Array[StringName] = []
	if state == null:
		return out
	for inst in state.equipped_instances():
		for mid in _items.instance_modifier_ids(inst):
			if not out.has(mid):
				out.append(mid)
	return out

## Returns true when [param instance] can be equipped in [param slot] for [param archetype_tags].
func can_equip(instance: ItemInstance, slot: StringName, archetype_tags: Array) -> bool:
	if instance == null:
		return false
	var item := _items.load_def(instance.def_id)
	if item == null:
		return false
	return item.get_equip_slot() == slot and item.allows_archetype(archetype_tags)

## Returns the display icon for an equipped [param instance].
func resolve_equipped_icon(instance: ItemInstance) -> Texture2D:
	return _items.resolve_icon(instance)
