extends RefCounted
## Scans sprite libraries under res://assets/visuals/equipment/ for editor templates.

const WEAPONS_DIR := "res://assets/visuals/equipment/weapons"
const SHIELDS_DIR := "res://assets/visuals/equipment/shields"
const ICONS_DIR := "res://assets/visuals/equipment/icons/generic"

## Returns sprite template dicts for [param category_id] and optional [param family] filter.
static func list_templates(category_id: StringName, family: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match category_id:
		&"weapon":
			_scan_weapon_family(out, family)
		&"armor":
			_scan_icons(out, family)
		_:
			_scan_icons(out, family)
	return out

static func _scan_weapon_family(out: Array[Dictionary], family: StringName) -> void:
	var dir := _open_dir(WEAPONS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			if not String(family).is_empty() and StringName(entry) != family:
				entry = dir.get_next()
				continue
			_scan_weapon_types(out, "%s/%s" % [WEAPONS_DIR, entry], entry)
		entry = dir.get_next()
	dir.list_dir_end()

static func _scan_weapon_types(out: Array[Dictionary], family_path: String, family_name: String) -> void:
	var dir := _open_dir(family_path)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		if file.ends_with(".import"):
			continue
		var base := file.get_basename()
		if not base.begins_with("type"):
			continue
		var path := "%s/%s" % [family_path, file]
		out.append({
			"category_id": &"weapon",
			"family": StringName(family_name),
			"design_type": StringName(base),
			"library_path": path,
			"label": "%s / %s" % [family_name, base],
		})

static func _scan_icons(out: Array[Dictionary], family: StringName) -> void:
	var dir := _open_dir(ICONS_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		var path := "%s/%s" % [ICONS_DIR, file]
		var name := file.get_basename()
		if not String(family).is_empty() and StringName(name) != family:
			continue
		out.append({
			"category_id": &"armor",
			"family": StringName(name),
			"design_type": &"",
			"library_path": path,
			"label": name,
		})

static func _open_dir(dir_path: String) -> DirAccess:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		dir = DirAccess.open(ProjectSettings.globalize_path(dir_path))
	return dir
