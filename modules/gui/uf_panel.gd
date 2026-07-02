@tool
@icon("res://ui/templates/icons/panel.svg")
class_name UfPanel
extends PanelContainer
## Bare movable panel shell (see docs/GAME_DESIGN.md section 10.4). Builds only [code]Layout[/code] and
## [code]ContentSlot[/code] — no header chrome. For in-game title bar + window buttons use
## [class UfPanelIngame].
## @tool: structure previews while editing panel scenes in the Godot editor.

const _LOG := "GUI"

signal panel_focused

func _enter_tree() -> void:
	_ensure_structure()

func _ready() -> void:
	if not gui_input.is_connected(_on_panel_input):
		gui_input.connect(_on_panel_input)

## Returns the container where panel content must be added.
func get_content_slot() -> Container:
	_ensure_structure()
	return get_node_or_null("Layout/ContentSlot") as Container

## Builds [code]Layout[/code] and [code]ContentSlot[/code] when missing. Idempotent for editor tools.
func _ensure_structure() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(
			Config.get_int("GUI_DEFAULT_PANEL_WIDTH", 280),
			Config.get_int("GUI_DEFAULT_PANEL_HEIGHT", 200),
		)
	var layout := get_node_or_null("Layout") as VBoxContainer
	if layout == null:
		layout = VBoxContainer.new()
		layout.name = "Layout"
		layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_add_structural_child(self, layout)
	if layout.get_node_or_null("ContentSlot") == null:
		var content := VBoxContainer.new()
		content.name = "ContentSlot"
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_add_structural_child(layout, content)
	_sync_structure_owners()

## Adds [param child] under [param parent] and assigns scene [owner] in the editor.
func _add_structural_child(parent: Node, child: Node) -> void:
	parent.add_child(child)
	_assign_editor_owner_tree(child)

func _sync_structure_owners() -> void:
	var layout := get_node_or_null("Layout")
	if layout != null:
		_assign_editor_owner_tree(layout)

func _assign_editor_owner_tree(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var root := get_tree().edited_scene_root
	if root == null or node == null:
		return
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		current.owner = root
		for child in current.get_children():
			if child.scene_file_path.is_empty():
				pending.append(child)

## No-op on bare panels; [class UfPanelIngame] overrides to set the header title.
func set_title_key(_key: String) -> void:
	pass

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		panel_focused.emit()
