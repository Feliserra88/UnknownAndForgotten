extends SceneTree
## Headless architecture lint enforcing the dependency matrix (see docs/ARCHITECTURE.md section 4).
## Run from project root:
##   godot --headless --path . --script res://tools/check_architecture.gd
##
## Rules checked:
##   A) A module script must not reference another module's _private/ folder.
##   B) Presentation code (scenes/, ui/, our addons) must not reference any module _private/.
##   C) A module must not reference res://scenes/ or res://ui/ unless allowed below.

## Roots scanned as "presentation" for rule B.
const _PRESENTATION_ROOTS := [
	"res://scenes",
	"res://ui",
	"res://addons/uf_map_editor",
	"res://addons/uf_gui_tools",
]

## Allowed module -> presentation references for rule C, as {from: module dir, to: path prefix}.
const _SCENE_REF_ALLOWLIST := [
	{"from": "res://modules/npc/", "to": "res://scenes/npc/npc_base.tscn"},
	{"from": "res://modules/gui/", "to": "res://ui/"},
]

var _private_re: RegEx
var _scene_ui_re: RegEx
var _failures: Array[String] = []

func _initialize() -> void:
	_private_re = RegEx.new()
	_private_re.compile("res://modules/([a-z0-9_]+)/_private/")
	_scene_ui_re = RegEx.new()
	_scene_ui_re.compile("res://(?:scenes|ui)/[A-Za-z0-9_./-]+")

	var module_files := _gd_files_in("res://modules")
	for path in module_files:
		_check_module_file(path)

	for root in _PRESENTATION_ROOTS:
		for path in _gd_files_in(root):
			_check_presentation_file(path)

	if _failures.is_empty():
		print("OK: architecture lint passed (%d module files scanned)" % module_files.size())
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		printerr("Architecture lint failed with %d violation(s)." % _failures.size())
		quit(1)

## Rule A + C: cross-module _private access and disallowed presentation references.
func _check_module_file(path: String) -> void:
	var owner_module := _module_of(path)
	var text := _read(path)
	for m in _private_re.search_all(text):
		if m.get_string(1) != owner_module:
			_failures.append("%s references foreign _private module '%s'" % [path, m.get_string(1)])
	for m in _scene_ui_re.search_all(text):
		var ref := m.get_string()
		if not _is_scene_ref_allowed(path, ref):
			_failures.append("%s (module '%s') references presentation path %s" % [path, owner_module, ref])

## Rule B: presentation code must not reach into any module _private/.
func _check_presentation_file(path: String) -> void:
	var text := _read(path)
	for m in _private_re.search_all(text):
		_failures.append("%s references module _private '%s'" % [path, m.get_string(1)])

func _is_scene_ref_allowed(file_path: String, ref: String) -> bool:
	for rule in _SCENE_REF_ALLOWLIST:
		if file_path.begins_with(rule["from"]) and ref.begins_with(rule["to"]):
			return true
	return false

## Returns the module directory name for a file under res://modules/<name>/...
func _module_of(path: String) -> String:
	var rest := path.trim_prefix("res://modules/")
	var slash := rest.find("/")
	return rest.substr(0, slash) if slash >= 0 else rest

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

## Returns every .gd file below [param root] (recursive), skipping hidden dirs.
func _gd_files_in(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_gd_files_in("%s/%s" % [root, name]))
		elif name.ends_with(".gd"):
			out.append("%s/%s" % [root, name])
		name = dir.get_next()
	dir.list_dir_end()
	return out
