@tool
extends EditorPlugin
## NPC editor plugin: a main-screen workspace (tab next to 2D/3D/Script) that composes NPCs from
## archetypes, factions and modifiers using only the public module APIs (npc, appearance, equipment,
## faction, modifier, gui). See docs/GAME_DESIGN.md sections 5-8 and 11.4.

const _WorkspaceScript := preload("res://addons/uf_npc_editor/workspace.gd")
const _ICON := preload("res://addons/uf_npc_editor/icon.svg")

var _workspace: Control

func _enter_tree() -> void:
	_workspace = _WorkspaceScript.new()
	_workspace.name = "UF NPC Editor"
	_workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	return "NPC"

func _get_plugin_icon() -> Texture2D:
	return _ICON

func _make_visible(visible: bool) -> void:
	if _workspace != null:
		_workspace.visible = visible
