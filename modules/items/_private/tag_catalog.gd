extends RefCounted
## Loads ItemTagDef assets from res://assets/data/item_tags/.

const DIR := "res://assets/data/item_tags"

static func list_all() -> Array[ItemTagDef]:
	var out: Array[ItemTagDef] = []
	var dir := _open_dir(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var def := load("%s/%s" % [DIR, file]) as ItemTagDef
		if def != null:
			out.append(def)
	out.sort_custom(func(a: ItemTagDef, b: ItemTagDef) -> bool:
		return String(a.id) < String(b.id)
	)
	return out

static func list_for_category(category_id: StringName) -> Array[ItemTagDef]:
	var out: Array[ItemTagDef] = []
	for def in list_all():
		if def.applies_to_category(category_id):
			out.append(def)
	return out

## Tags shown on a picker tab ([code]general[/code] = tags with no category list).
static func list_for_group(group_id: StringName) -> Array[ItemTagDef]:
	var out: Array[ItemTagDef] = []
	for def in list_all():
		if _tag_in_group(def, group_id):
			out.append(def)
	return out

static func _tag_in_group(def: ItemTagDef, group_id: StringName) -> bool:
	if def == null:
		return false
	if group_id == &"general":
		return def.categories.is_empty()
	return def.categories.has(group_id)

static func load_def(id: StringName) -> ItemTagDef:
	if String(id).is_empty():
		return null
	for def in list_all():
		if def.id == id:
			return def
	return null

static func normalize(tags: Array, category_id: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for raw in tags:
		var tid := StringName(String(raw).strip_edges())
		if String(tid).is_empty():
			continue
		var def := load_def(tid)
		if def == null:
			continue
		if not String(category_id).is_empty() and not def.applies_to_category(category_id):
			continue
		if not out.has(tid):
			out.append(tid)
	return out

static func _open_dir(dir_path: String) -> DirAccess:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		dir = DirAccess.open(ProjectSettings.globalize_path(dir_path))
	return dir
