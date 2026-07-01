class_name EquipmentModule
extends RefCounted
## Public facade for items and equipment (see docs/GAME_DESIGN.md section 7). Loads ItemDef assets,
## answers slot/archetype compatibility and resolves visuals. Callers use this facade, never
## ItemDef internals.

const _LOG := "EQP"
const DIR := "res://assets/data/items"

## Returns the ItemDef for [param id] loaded from DIR, or null when missing.
func load_item(id: StringName) -> ItemDef:
	if String(id).is_empty():
		return null
	var path := "%s/%s.tres" % [DIR, id]
	if not ResourceLoader.exists(path):
		Log.warn(_LOG, "load_item: missing %s" % path)
		return null
	return load(path) as ItemDef

## Returns every ItemDef asset found in DIR.
func list_items() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var item := load("%s/%s" % [DIR, file]) as ItemDef
		if item != null:
			out.append(item)
	return out

## Returns items that fit [param slot] and are allowed for [param archetype_tags].
func compatible_items(archetype_tags: Array, slot: StringName) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for item in list_items():
		if item.slot == slot and item.allows_archetype(archetype_tags):
			out.append(item)
	return out

## Returns the EquipmentVisualDef bound to [param item_id], or null.
func resolve_visual(item_id: StringName) -> EquipmentVisualDef:
	var item := load_item(item_id)
	return item.visual if item != null else null

## Returns the ModifierDef ids granted by items equipped in [param state].
func attribute_modifier_ids(state: EquipmentState) -> Array[StringName]:
	var out: Array[StringName] = []
	if state == null:
		return out
	for item_id in state.item_ids():
		var item := load_item(StringName(item_id))
		if item != null and not String(item.attribute_modifier_id).is_empty():
			out.append(item.attribute_modifier_id)
	return out
