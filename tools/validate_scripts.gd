extends SceneTree
## Headless syntax check for editor addon scripts. Run from project root:
##   godot --headless --path . --script res://tools/validate_scripts.gd

const _PATHS := [
	"res://addons/uf_map_editor/plugin.gd",
	"res://addons/uf_map_editor/dock.gd",
	"res://modules/world/world.gd",
	"res://modules/gui/gui.gd",
	"res://modules/gui/uf_panel.gd",
	"res://modules/gui/uf_info_panel.gd",
	"res://modules/gui/uf_dialog_panel.gd",
	"res://modules/gui/uf_tabbed_panel.gd",
	"res://modules/gui/widgets/uf_label.gd",
	"res://modules/gui/widgets/uf_button.gd",
	"res://modules/gui/widgets/uf_list.gd",
	"res://modules/gui/widgets/uf_grid_container.gd",
	"res://modules/gui/widgets/uf_layout_region.gd",
	"res://addons/uf_gui_tools/plugin.gd",
	"res://addons/uf_gui_tools/dock.gd",
	"res://addons/uf_gui_tools/palette_item.gd",
	"res://addons/uf_gui_tools/widget_palette.gd",
	"res://scenes/ui/world_hud.gd",
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
