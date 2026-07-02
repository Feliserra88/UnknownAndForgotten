extends SceneTree
## Headless syntax check for editor addon scripts. Run from project root:
##   godot --headless --path . --script res://tools/validate_scripts.gd

const _PATHS := [
	"res://addons/uf_map_editor/plugin.gd",
	"res://addons/uf_map_editor/dock.gd",
	"res://core/events.gd",
	"res://autoload/event_bus.gd",
	"res://modules/attributes/attributes.gd",
	"res://modules/appearance/appearance.gd",
	"res://modules/appearance/inspection_layout_def.gd",
	"res://modules/npc/npc.gd",
	"res://modules/npc/npc_archetype.gd",
	"res://modules/npc/npc_instance_data.gd",
	"res://modules/appearance/npc_appearance_controller.gd",
	"res://modules/modifier/modifier_def.gd",
	"res://modules/modifier/modifier.gd",
	"res://modules/faction/faction_def.gd",
	"res://modules/faction/faction.gd",
	"res://modules/equipment/item_def.gd",
	"res://modules/equipment/equipment_visual_def.gd",
	"res://modules/equipment/equipment_slot_map.gd",
	"res://modules/equipment/equipment_state.gd",
	"res://modules/equipment/equipment.gd",
	"res://modules/world/world.gd",
	"res://modules/gui/gui.gd",
	"res://modules/gui/uf_panel.gd",
	"res://modules/gui/uf_panel_ingame.gd",
	"res://modules/gui/uf_info_panel.gd",
	"res://modules/gui/uf_dialog_panel.gd",
	"res://modules/gui/uf_tabbed_panel.gd",
	"res://modules/gui/uf_inspection_panel.gd",
	"res://modules/gui/uf_panel_ingame_loot.gd",
	"res://modules/gui/widgets/uf_label.gd",
	"res://modules/gui/widgets/uf_button.gd",
	"res://modules/gui/widgets/uf_list.gd",
	"res://modules/gui/widgets/uf_grid_container.gd",
	"res://modules/gui/widgets/uf_layout_region.gd",
	"res://modules/gui/widgets/uf_equipment_slot.gd",
	"res://modules/gui/widgets/uf_item_slot.gd",
	"res://modules/gui/widgets/uf_tab.gd",
	"res://addons/uf_gui_tools/plugin.gd",
	"res://addons/uf_gui_tools/dock.gd",
	"res://addons/uf_gui_tools/palette_item.gd",
	"res://addons/uf_gui_tools/widget_palette.gd",
	"res://addons/uf_npc_editor/plugin.gd",
	"res://addons/uf_npc_editor/workspace.gd",
	"res://addons/uf_npc_editor/compatible_item.gd",
	"res://scenes/game/game_session.gd",
	"res://scenes/game/game_bootstrap.gd",
	"res://scenes/game/game_hud.gd",
	"res://scenes/game/player_controller.gd",
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
