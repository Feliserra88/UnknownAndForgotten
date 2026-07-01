class_name GuiModule
extends Node
## Public facade for game UI (see docs/GAME_DESIGN.md section 10). Creates movable UfPanel
## instances, loads saved domain panel assets and applies the shared theme. Domain panels built
## by the uf_gui_tools plugin are saved as PackedScene assets under res://ui/domain/.

const _LOG := "GUI"
const THEME_PATH := "res://ui/theme/uf_theme.tres"
const DOMAIN_DIR := "res://ui/domain"

## Maps a panel kind to the script that implements it.
const _PANEL_SCRIPTS := {
	&"panel": "res://modules/gui/uf_panel.gd",
	&"info": "res://modules/gui/uf_info_panel.gd",
	&"dialog": "res://modules/gui/uf_dialog_panel.gd",
	&"tabbed": "res://modules/gui/uf_tabbed_panel.gd",
}

## Returns the panel kinds accepted by [method create_panel].
func panel_kinds() -> Array:
	return _PANEL_SCRIPTS.keys()

## Creates a panel of [param kind] ("panel"/"info"/"dialog"/"tabbed") with [param title_key] set,
## the shared theme applied and its structure built. Returns null for an unknown kind.
func create_panel(kind: StringName = &"panel", title_key: String = "") -> UfPanel:
	var path: String = _PANEL_SCRIPTS.get(kind, "")
	if path.is_empty():
		Log.warn(_LOG, "create_panel: unknown kind=%s" % kind)
		return null
	var script := load(path) as GDScript
	var panel := script.new() as UfPanel
	panel.set_title_key(title_key)
	apply_theme(panel)
	Log.detail(_LOG, "create", "panel kind=%s" % kind)
	return panel

## Loads a saved domain panel PackedScene from [param path] and returns a fresh instance, or null.
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
