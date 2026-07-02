@tool
class_name GuiModule
extends Node
## Public facade for game UI (see docs/GAME_DESIGN.md section 10). Creates movable UfPanel
## instances, loads saved game panel assets and applies the shared theme. Panels built
## by the uf_gui_tools plugin are saved as PackedScene assets under res://ui/panels/.

const _LOG := "GUI"
const THEME_PATH := "res://ui/theme/uf_theme.tres"
const PANELS_DIR := "res://ui/panels"
const TEMPLATES_DIR := "res://ui/templates"

## Maps a panel kind to the script that implements it.
const _PANEL_SCRIPTS := {
	&"panel": "res://modules/gui/uf_panel.gd",
	&"ingame": "res://modules/gui/uf_panel_ingame.gd",
	&"info": "res://modules/gui/uf_info_panel.gd",
	&"dialog": "res://modules/gui/uf_dialog_panel.gd",
	&"tabbed": "res://modules/gui/uf_tabbed_panel.gd",
	&"inspection": "res://modules/gui/uf_inspection_panel.gd",
	&"loot": "res://modules/gui/uf_panel_ingame_loot.gd",
	&"inventory": "res://modules/gui/uf_panel_ingame_inventory.gd",
}

## Base PackedScene paths for editor palette drag-and-drop (see GAME_DESIGN section 10.9).
const PANEL_SCENES := {
	&"panel": "res://ui/templates/uf_panel.tscn",
	&"ingame": "res://ui/templates/uf_panel_ingame.tscn",
	&"info": "res://ui/templates/uf_panel_info.tscn",
	&"dialog": "res://ui/templates/uf_panel_dialog.tscn",
	&"tabbed": "res://ui/templates/uf_panel_tabbed.tscn",
	&"inspection": "res://ui/templates/uf_panel_ingame_inspection.tscn",
	&"loot": "res://ui/templates/uf_panel_ingame_loot.tscn",
	&"inventory": "res://ui/panels/uf_inventory.tscn",
}

const WIDGET_SCENES := {
	"label": "res://ui/widgets/uf_label.tscn",
	"button": "res://ui/widgets/uf_button.tscn",
	"check_button": "res://ui/widgets/uf_check_button.tscn",
	"list": "res://ui/widgets/uf_list.tscn",
	"grid": "res://ui/widgets/uf_grid_container.tscn",
	"layout_region": "res://ui/widgets/uf_layout_region.tscn",
	"equipment_slot": "res://ui/widgets/uf_equipment_slot.tscn",
	"item_slot": "res://ui/widgets/uf_item_slot.tscn",
	"progress_bar": "res://ui/widgets/uf_progress_bar.tscn",
	"separator": "res://ui/widgets/uf_separator.tscn",
	"tab": "res://ui/widgets/uf_tab.tscn",
}

## Returns the panel kinds accepted by [method create_panel].
func panel_kinds() -> Array:
	return _PANEL_SCRIPTS.keys()

## Creates a panel of [param kind] ("panel"/"info"/"dialog"/"tabbed") with [param title_key] set,
## the shared theme applied and its structure built. Returns null for an unknown kind.
func create_panel(kind: StringName = &"panel", title_key: String = "") -> UfPanel:
	var panel := _instantiate_panel_scene(kind)
	if panel == null:
		panel = _create_panel_from_script(kind)
	if panel == null:
		return null
	if not title_key.is_empty():
		panel.set_title_key(title_key)
	apply_theme(panel)
	Log.detail(_LOG, "create", "panel kind=%s" % kind)
	return panel

## Creates an inspection panel for [param archetype] using its resolved layout. Returns null when the
## archetype has no inspection layout. Used by uf_npc_editor and in-game NPC inspection.
func create_inspection_panel_for_archetype(
	archetype: NpcArchetype,
	title_key: String = "gui.inspection.title",
) -> UfInspectionPanel:
	if archetype == null:
		return null
	return create_inspection_panel(archetype.resolve_inspection_layout(), title_key)

## Creates an inspection panel built from [param layout] with the shared theme applied. Returns null
## when the panel asset is missing. Used by uf_npc_editor and in-game NPC inspection.
func create_inspection_panel(layout: InspectionLayoutDef, title_key: String = "gui.inspection.title") -> UfInspectionPanel:
	if layout != null and not layout.panel_path.is_empty():
		var scene_panel := load_panel(layout.panel_path) as UfInspectionPanel
		if scene_panel != null:
			if not title_key.is_empty():
				scene_panel.set_title_key(title_key)
			apply_theme(scene_panel)
			scene_panel.bind_scene_slots()
			return scene_panel
	var panel := create_panel(&"inspection", title_key) as UfInspectionPanel
	if panel == null:
		return null
	panel._ensure_structure()
	if layout != null:
		panel.build_from_layout(layout)
	return panel

## Returns the PackedScene path for a widget id used by uf_gui_tools ("label", "button", …).
func widget_scene_path(widget_id: String) -> String:
	return WIDGET_SCENES.get(widget_id, "")

## Returns palette entries for uf_gui_tools: each item has label, path and optional icon.
func widget_palette_entries() -> Array:
	return _palette_entries(WIDGET_SCENES)

## Returns palette entries for base panel scenes keyed by panel kind.
func panel_palette_entries() -> Array:
	return _palette_entries(PANEL_SCENES)

## Instantiates a widget scene by id, or null when the id or asset is missing.
func instantiate_widget(widget_id: String) -> Control:
	var path := widget_scene_path(widget_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		Log.warn(_LOG, "instantiate_widget: missing id=%s" % widget_id)
		return null
	var scene := load(path) as PackedScene
	return scene.instantiate() as Control

func _instantiate_panel_scene(kind: StringName) -> UfPanel:
	var path: String = PANEL_SCENES.get(kind, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	return scene.instantiate() as UfPanel

func _create_panel_from_script(kind: StringName) -> UfPanel:
	var script_path: String = _PANEL_SCRIPTS.get(kind, "")
	if script_path.is_empty():
		Log.warn(_LOG, "create_panel: unknown kind=%s" % kind)
		return null
	var script := load(script_path) as GDScript
	return script.new() as UfPanel

func _palette_entries(scene_map: Dictionary) -> Array:
	var entries: Array = []
	for key in scene_map.keys():
		var path: String = scene_map[key]
		if not ResourceLoader.exists(path):
			continue
		entries.append({
			"id": String(key),
			"label": String(key),
			"path": path,
		})
	return entries

## Loads a saved game panel PackedScene from [param path] and returns a fresh instance, or null.
func load_panel(path: String) -> UfPanel:
	if not ResourceLoader.exists(path):
		Log.warn(_LOG, "load_panel: missing %s" % path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as UfPanel

## Applies the shared UF theme to [param control] when the theme asset exists.
func apply_theme(control: Control) -> void:
	if control != null and ResourceLoader.exists(THEME_PATH):
		control.theme = load(THEME_PATH)
