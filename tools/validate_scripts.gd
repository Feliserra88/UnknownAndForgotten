extends SceneTree
## Headless syntax check for editor addon scripts. Run from project root:
##   godot --headless --path . --script res://tools/validate_scripts.gd

const _PATHS := [
	"res://addons/uf_map_editor/plugin.gd",
	"res://addons/uf_map_editor/dock.gd",
	"res://modules/world/world.gd",
]

func _initialize() -> void:
	var failed := false
	for path in _PATHS:
		var script: Variant = load(path)
		if script == null:
			push_error("FAIL load: %s" % path)
			failed = true
		else:
			print("OK: %s" % path)
	quit(1 if failed else 0)
