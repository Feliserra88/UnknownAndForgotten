@tool
@icon("res://ui/templates/icons/panel_dialog.svg")
class_name UfDialogPanel
extends UfPanel
## Panel with accept/cancel actions in a footer chrome bar (see docs/GAME_DESIGN.md section 10.5).
## [code]Footer/Chrome[/code] mirrors the header pattern: fixed-height bar with shrink-sized buttons
## aligned to the end so they do not stretch to the full panel width.

signal confirmed
signal cancelled

const _FOOTER_VARIATION := &"UfPanelFooter"
const _FOOTER_HEIGHT := 36
const _DEFAULT_BUTTON_SIZE := Vector2(96, 28)
const _CHROME_SEPARATION := 8

@export var accept_key: String = "gui.action.accept":
	set(value):
		accept_key = value
		_refresh_footer()
@export var cancel_key: String = "gui.action.cancel":
	set(value):
		cancel_key = value
		_refresh_footer()
@export var footer_button_min_size: Vector2 = _DEFAULT_BUTTON_SIZE:
	set(value):
		footer_button_min_size = value.max(Vector2(48, 24))
		_apply_footer_button_sizes()

func _ensure_structure() -> void:
	super._ensure_structure()
	var layout := get_node_or_null("Layout") as VBoxContainer
	if layout == null:
		return
	_remove_stray_header(layout)
	_ensure_footer(layout)
	_refresh_footer()
	_apply_footer_button_sizes()

func _ready() -> void:
	super._ready()
	var accept := _accept_button()
	if accept != null and not accept.pressed.is_connected(_on_accept):
		accept.pressed.connect(_on_accept)
	var cancel := _cancel_button()
	if cancel != null and not cancel.pressed.is_connected(_on_cancel):
		cancel.pressed.connect(_on_cancel)

func _accept_button() -> Button:
	return get_node_or_null("Layout/Footer/Chrome/AcceptButton") as Button

func _cancel_button() -> Button:
	return get_node_or_null("Layout/Footer/Chrome/CancelButton") as Button

func _refresh_footer() -> void:
	var accept := _accept_button()
	if accept != null:
		accept.text = tr(accept_key)
	var cancel := _cancel_button()
	if cancel != null:
		cancel.text = tr(cancel_key)

func _apply_footer_button_sizes() -> void:
	for button in [_accept_button(), _cancel_button()]:
		if button != null:
			button.custom_minimum_size = footer_button_min_size

func _remove_stray_header(layout: VBoxContainer) -> void:
	var header := layout.get_node_or_null("Header")
	if header != null:
		layout.remove_child(header)
		header.free()

func _ensure_footer(layout: VBoxContainer) -> void:
	var footer := layout.get_node_or_null("Footer")
	if footer is PanelContainer and footer.theme_type_variation == _FOOTER_VARIATION:
		if footer.get_node_or_null("Chrome") != null:
			return
	var cancel := _find_legacy_button(layout, "CancelButton")
	var accept := _find_legacy_button(layout, "AcceptButton")
	if footer != null:
		layout.remove_child(footer)
		footer.free()
	footer = _build_footer()
	_add_structural_child(layout, footer)
	var chrome := footer.get_node_or_null("Chrome") as HBoxContainer
	if chrome != null:
		if cancel != null:
			chrome.add_child(cancel)
		else:
			chrome.add_child(_make_footer_button("CancelButton"))
		if accept != null:
			chrome.add_child(accept)
		else:
			chrome.add_child(_make_footer_button("AcceptButton"))

func _find_legacy_button(layout: VBoxContainer, button_name: String) -> Button:
	var footer := layout.get_node_or_null("Footer")
	if footer == null:
		return null
	var button := footer.get_node_or_null("Chrome/%s" % button_name) as Button
	if button != null:
		return button
	return footer.get_node_or_null(button_name) as Button

func _build_footer() -> PanelContainer:
	var footer := PanelContainer.new()
	footer.name = "Footer"
	footer.theme_type_variation = _FOOTER_VARIATION
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.custom_minimum_size = Vector2(0, _FOOTER_HEIGHT)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var chrome := HBoxContainer.new()
	chrome.name = "Chrome"
	chrome.alignment = BoxContainer.ALIGNMENT_END
	chrome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chrome.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chrome.add_theme_constant_override("separation", _CHROME_SEPARATION)
	footer.add_child(chrome)
	return footer

func _make_footer_button(button_name: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = footer_button_min_size
	return button

func _on_accept() -> void:
	confirmed.emit()

func _on_cancel() -> void:
	cancelled.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_footer()
