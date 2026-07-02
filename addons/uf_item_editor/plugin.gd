@tool
extends EditorPlugin
## Item editor plugin: main-screen workspace for ItemDef authoring via ItemsModule public API.

const _WorkspaceScript := preload("res://addons/uf_item_editor/workspace.gd")
const _ICON := preload("res://addons/uf_item_editor/icon.svg")

var _workspace: Control

func _enter_tree() -> void:
	_workspace = _WorkspaceScript.new()
	_workspace.name = "UF Item Editor"
	_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EditorInterface.get_editor_main_screen().add_child(_workspace)
	_workspace.setup()
	_workspace.hide()

func _exit_tree() -> void:
	if _workspace != null:
		_workspace.queue_free()
		_workspace = null

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Items"

func _get_plugin_icon() -> Texture2D:
	return _ICON

func _make_visible(visible: bool) -> void:
	if _workspace != null:
		_workspace.visible = visible
		if visible:
			_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_workspace.call_deferred("ensure_ready")
			_workspace.call_deferred("sync_layout")
