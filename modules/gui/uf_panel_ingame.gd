@tool
@icon("res://ui/templates/icons/panel_ingame.svg")
class_name UfPanelIngame
extends UfPanel
## In-game panel with centered localized title and header chrome (minimize, drag, close).
## Extends bare [class UfPanel]; use this template for HUD windows opened during play.

const _ICON_CLOSE := preload("res://assets/ui/icons/art/icon_close.png")
const _ICON_MINIMIZE := preload("res://assets/ui/icons/art/icon_minus.png")
const _ICON_DRAG := preload("res://assets/ui/icons/art/icon_menu.png")
const _HEADER_VARIATION := &"UfPanelHeader"
const _CHROME_BUTTON_SIZE := Vector2(20, 20)
const _HEADER_HEIGHT := 26
const _CHROME_WIDTH := 70

signal panel_closed
signal panel_moved(new_position: Vector2)
signal panel_minimized(minimized: bool)

@export var title_key: String = "":
	set(value):
		title_key = value
		_refresh_title()
@export var draggable: bool = true
@export var show_close_button: bool = true
@export var show_minimize_button: bool = true
@export var show_drag_handle: bool = true

var _dragging: bool = false
var _minimized: bool = false

func _ready() -> void:
	super._ready()
	_refresh_title()
	_wire_header()

func set_title_key(key: String) -> void:
	title_key = key

func enable_drag(enabled: bool) -> void:
	draggable = enabled

func reset_position() -> void:
	position = Vector2.ZERO

func restore_from_minimized() -> void:
	if not _minimized:
		return
	_minimized = false
	var slot := get_content_slot()
	if slot != null:
		slot.visible = true
	panel_minimized.emit(false)

func _ensure_structure() -> void:
	super._ensure_structure()
	var layout := get_node_or_null("Layout") as VBoxContainer
	if layout == null:
		return
	_ensure_header(layout)
	_sync_structure_owners()
	_refresh_title()
	_apply_chrome_visibility()

func _ensure_header(layout: VBoxContainer) -> void:
	var header := layout.get_node_or_null("Header")
	if header is PanelContainer and header.theme_type_variation == _HEADER_VARIATION:
		if header.get_node_or_null("Body/Chrome") != null:
			return
	if header != null:
		layout.remove_child(header)
		header.free()
	header = _build_header()
	_add_structural_child(layout, header)
	layout.move_child(header, 0)

func _build_header() -> PanelContainer:
	var header := PanelContainer.new()
	header.name = "Header"
	header.theme_type_variation = _HEADER_VARIATION
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.custom_minimum_size = Vector2(0, _HEADER_HEIGHT)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body := Control.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header.add_child(body)

	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(title)

	var chrome := HBoxContainer.new()
	chrome.name = "Chrome"
	chrome.mouse_filter = Control.MOUSE_FILTER_STOP
	chrome.alignment = BoxContainer.ALIGNMENT_CENTER
	chrome.add_theme_constant_override("separation", 2)
	chrome.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chrome.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chrome.offset_left = -_CHROME_WIDTH
	chrome.offset_top = 2
	chrome.offset_right = -4
	chrome.offset_bottom = _HEADER_HEIGHT - 2

	chrome.add_child(_make_chrome_button("MinimizeButton", _ICON_MINIMIZE, "gui.header.minimize"))
	chrome.add_child(_make_chrome_button("DragHandle", _ICON_DRAG, "gui.header.drag"))
	chrome.add_child(_make_chrome_button("CloseButton", _ICON_CLOSE, "gui.header.close"))
	body.add_child(chrome)
	return header

func _make_chrome_button(button_name: String, icon_tex: Texture2D, tooltip_key: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.flat = true
	button.custom_minimum_size = _CHROME_BUTTON_SIZE
	button.icon = icon_tex
	button.expand_icon = false
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tr(tooltip_key) if not tooltip_key.is_empty() else ""
	return button

func _wire_header() -> void:
	var title := _title_label()
	if title != null and not title.gui_input.is_connected(_on_drag_area_input):
		title.gui_input.connect(_on_drag_area_input)
	var drag := _drag_handle()
	if drag != null and not drag.gui_input.is_connected(_on_drag_area_input):
		drag.gui_input.connect(_on_drag_area_input)
	var close := _close_button()
	if close != null and not close.pressed.is_connected(_on_close_pressed):
		close.pressed.connect(_on_close_pressed)
	var minimize := _minimize_button()
	if minimize != null and not minimize.pressed.is_connected(_on_minimize_pressed):
		minimize.pressed.connect(_on_minimize_pressed)
	_apply_chrome_visibility()

func _apply_chrome_visibility() -> void:
	var minimize := _minimize_button()
	if minimize != null:
		minimize.visible = show_minimize_button
	var drag := _drag_handle()
	if drag != null:
		drag.visible = show_drag_handle
	var close := _close_button()
	if close != null:
		close.visible = show_close_button

func _title_label() -> Label:
	return get_node_or_null("Layout/Header/Body/Title") as Label

func _close_button() -> Button:
	return get_node_or_null("Layout/Header/Body/Chrome/CloseButton") as Button

func _minimize_button() -> Button:
	return get_node_or_null("Layout/Header/Body/Chrome/MinimizeButton") as Button

func _drag_handle() -> Button:
	return get_node_or_null("Layout/Header/Body/Chrome/DragHandle") as Button

func _refresh_title() -> void:
	var label := _title_label()
	if label == null:
		return
	label.text = tr(title_key) if not title_key.is_empty() else ""

func _refresh_chrome_tooltips() -> void:
	var close := _close_button()
	if close != null:
		close.tooltip_text = tr("gui.header.close")
	var minimize := _minimize_button()
	if minimize != null:
		minimize.tooltip_text = tr("gui.header.minimize")
	var drag := _drag_handle()
	if drag != null:
		drag.tooltip_text = tr("gui.header.drag")

func _on_drag_area_input(event: InputEvent) -> void:
	if not draggable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			panel_focused.emit()
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
		panel_moved.emit(position)

func _on_close_pressed() -> void:
	hide()
	panel_closed.emit()

func _on_minimize_pressed() -> void:
	_minimized = not _minimized
	var slot := get_content_slot()
	if slot != null:
		slot.visible = not _minimized
	panel_minimized.emit(_minimized)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_title()
		_refresh_chrome_tooltips()
