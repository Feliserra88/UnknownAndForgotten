extends RefCounted
## Scans and filters ItemDef assets under res://assets/data/items/.

const DIR := "res://assets/data/items"

## Returns every ItemDef on disk.
static func list_all() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	var dir := _open_dir(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var item := load("%s/%s" % [DIR, file]) as ItemDef
		if item != null:
			out.append(item)
	return out

## Returns ItemDefs matching optional [param filter] keys: category_id, tag, equip_slot.
static func list_filtered(filter: Dictionary) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for item in list_all():
		if not _matches_filter(item, filter):
			continue
		out.append(item)
	return out

## Returns the ItemDef loaded from [param id], or null.
static func load_def(id: StringName) -> ItemDef:
	if String(id).is_empty():
		return null
	var path := "%s/%s.tres" % [DIR, id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ItemDef

static func _matches_filter(item: ItemDef, filter: Dictionary) -> bool:
	if filter.is_empty():
		return true
	if filter.has("category_id"):
		if item.category_id != filter["category_id"]:
			return false
	if filter.has("tag"):
		if not item.tags.has(filter["tag"]):
			return false
	if filter.has("tags_any"):
		var wanted: Array = filter["tags_any"]
		if not wanted.is_empty() and not tags_overlap_any(item.tags, wanted):
			return false
	if filter.has("equip_slot"):
		if item.get_equip_slot() != filter["equip_slot"]:
			return false
	return true

## True when [param item_tags] contains at least one id from [param filter_tags].
static func tags_overlap_any(item_tags: Array, filter_tags: Array) -> bool:
	if filter_tags.is_empty():
		return true
	for raw in filter_tags:
		var wanted := StringName(String(raw))
		for item_tag in item_tags:
			if StringName(String(item_tag)) == wanted:
				return true
	return false

static func _open_dir(dir_path: String) -> DirAccess:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		dir = DirAccess.open(ProjectSettings.globalize_path(dir_path))
	return dir
