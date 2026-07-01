@tool
@icon("res://ui/panels/icons/panel.svg")
class_name UfPanel
extends PanelContainer
## Movable base panel for game UI (see docs/GAME_DESIGN.md section 10.4). Builds a Header
## (drag handle + title) and a ContentSlot where specialized panels and domain widgets add their
## controls. Structure is generated on demand so a bare UfPanel node, a runtime instance and the
## uf_gui_tools plugin all end up with the same layout.
## @tool: chrome previews while editing panel scenes in the Godot editor.

const _LOG := "GUI"

signal panel_closed
signal panel_moved(new_position: Vector2)
signal panel_focused

@export var title_key: String = "":
	set(value):
		title_key = value
		_refresh_title()
## When true the panel can be dragged by its header bar.
@export var draggable: bool = true

var _dragging: bool = false

func _enter_tree() -> void:
	_ensure_structure()

func _ready() -> void:
	_refresh_title()
	var header := _header()
	if header != null and not header.gui_input.is_connected(_on_header_input):
		header.gui_input.connect(_on_header_input)
	if not gui_input.is_connected(_on_panel_input):
		gui_input.connect(_on_panel_input)

## Returns the container where panel content must be added.
func get_content_slot() -> Container:
	_ensure_structure()
	return get_node_or_null("Layout/ContentSlot") as Container

## Sets the localization [param key] used for the panel title and refreshes the label.
func set_title_key(key: String) -> void:
	title_key = key

## Enables or disables header dragging.
func enable_drag(enabled: bool) -> void:
	draggable = enabled

## Moves the panel back to the top-left of its parent.
func reset_position() -> void:
	position = Vector2.ZERO

## Builds any missing structural nodes (Layout, Header, Title, ContentSlot). Idempotent, so it is
## safe to call from _enter_tree, the editor tool and the uf_gui_tools plugin.
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
		add_child(layout)
	if layout.get_node_or_null("Header") == null:
		var header := HBoxContainer.new()
		header.name = "Header"
		header.mouse_filter = Control.MOUSE_FILTER_STOP
		header.custom_minimum_size = Vector2(0, 22)
		var title := Label.new()
		title.name = "Title"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		layout.add_child(header)
		layout.move_child(header, 0)
	if layout.get_node_or_null("ContentSlot") == null:
		var content := VBoxContainer.new()
		content.name = "ContentSlot"
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layout.add_child(content)
	_refresh_title()

func _header() -> Control:
	return get_node_or_null("Layout/Header") as Control

func _title_label() -> Label:
	return get_node_or_null("Layout/Header/Title") as Label

func _refresh_title() -> void:
	var label := _title_label()
	if label == null:
		return
	label.text = tr(title_key) if not title_key.is_empty() else ""

func _on_header_input(event: InputEvent) -> void:
	if not draggable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			panel_focused.emit()
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
		panel_moved.emit(position)

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		panel_focused.emit()
