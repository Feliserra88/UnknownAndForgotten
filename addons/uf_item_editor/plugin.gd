@tool
extends EditorPlugin
## Item editor plugin: main-screen workspace for ItemDef authoring via ItemsModule public API.

const _WorkspaceScript := preload("res://addons/uf_item_editor/workspace.gd")
const _ICON := preload("res://addons/uf_item_editor/icon.svg")

var _workspace: Control
var _main_screen: Control

func _enter_tree() -> void:
	_workspace = _WorkspaceScript.new()
	_workspace.name = "UF Item Editor"
	_main_screen = EditorInterface.get_editor_main_screen()
	_main_screen.add_child(_workspace)
	if not _main_screen.resized.is_connected(_on_main_screen_resized):
		_main_screen.resized.connect(_on_main_screen_resized)
	_workspace.setup()
	_workspace.hide()
	call_deferred("_fit_workspace_to_main_screen")

func _exit_tree() -> void:
	if _main_screen != null and _main_screen.resized.is_connected(_on_main_screen_resized):
		_main_screen.resized.disconnect(_on_main_screen_resized)
	if _workspace != null:
		_workspace.queue_free()
		_workspace = null
	_main_screen = null

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Items"

func _get_plugin_icon() -> Texture2D:
	return _ICON

func _make_visible(visible: bool) -> void:
	if _workspace == null:
		return
	_workspace.visible = visible
	if visible:
		_fit_workspace_to_main_screen()
		_workspace.ensure_ready()
		_workspace.call_deferred("sync_layout")

func _on_main_screen_resized() -> void:
	if _workspace != null and _workspace.visible:
		_fit_workspace_to_main_screen()
		_workspace.sync_layout()

func _fit_workspace_to_main_screen() -> void:
	if _workspace == null or _main_screen == null:
		return
	_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _main_screen.size.x > 8 and _main_screen.size.y > 8:
		_workspace.size = _main_screen.size
