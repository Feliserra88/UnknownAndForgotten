@tool
extends PanelContainer
## Rounded tag pill for filter toggle, palette drag source, or assigned tag display.

const PAYLOAD_TYPE := &"item_tag"
const _COMPACT_H := 22
const _COMPACT_PAD_H := 6
const _COMPACT_PAD_V := 2
const _COMPACT_RADIUS := 10

signal activated(tag_id: StringName)
signal remove_requested(tag_id: StringName)

enum Mode { FILTER, PALETTE, ASSIGNED }

var _tag_id: StringName = &""
var _mode: Mode = Mode.PALETTE
var _filter_active: bool = false
var _base_color: Color = Color(0.32, 0.46, 0.62)
var _label: Label
var _label_text: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()

func setup(tag_id: StringName, label: String, mode: Mode, chip_color: Color = Color(0.32, 0.46, 0.62)) -> void:
	_tag_id = tag_id
	_mode = mode
	_base_color = chip_color
	_label_text = label
	tooltip_text = _tooltip_for_mode()
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for child in get_children():
		child.queue_free()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _COMPACT_PAD_H)
	margin.add_theme_constant_override("margin_right", _COMPACT_PAD_H)
	margin.add_theme_constant_override("margin_top", _COMPACT_PAD_V)
	margin.add_theme_constant_override("margin_bottom", _COMPACT_PAD_V)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)
	custom_minimum_size = Vector2(0, _COMPACT_H)
	_update_label_appearance()
	_apply_style()
	call_deferred("_sync_chip_size")

func _sync_chip_size() -> void:
	if _label == null:
		return
	_label.reset_size()
	var text_w := int(_label.get_minimum_size().x)
	if text_w < 1:
		text_w = int(_label.get_combined_minimum_size().x)
	custom_minimum_size = Vector2(maxi(text_w + _COMPACT_PAD_H * 2, 24), _COMPACT_H)

func get_tag_id() -> StringName:
	return _tag_id

func set_filter_active(active: bool) -> void:
	if _filter_active == active:
		return
	_filter_active = active
	tooltip_text = _tooltip_for_mode()
	_update_label_appearance()
	_apply_style()

const _I18N := preload("res://addons/uf_editor_ui/editor_i18n.gd")

func _tooltip_for_mode() -> String:
	match _mode:
		Mode.FILTER:
			if _filter_active:
				return "%s — %s" % [String(_tag_id), _I18N.translate_key("item_editor.tags.filter_active")]
			return "%s — %s" % [String(_tag_id), _I18N.translate_key("item_editor.tags.filter_inactive")]
		Mode.ASSIGNED:
			return "%s — %s" % [String(_tag_id), _I18N.translate_key("item_editor.tags.remove_hint")]
		_:
			return String(_tag_id)

func _update_label_appearance() -> void:
	if _label == null:
		return
	_label.text = _label_text
	match _mode:
		Mode.FILTER:
			if _filter_active:
				_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
				_label.add_theme_font_size_override("font_size", 13)
			else:
				_label.add_theme_color_override("font_color", Color(0.52, 0.56, 0.62))
				_label.add_theme_font_size_override("font_size", 12)
		Mode.ASSIGNED:
			_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.97))
			_label.add_theme_font_size_override("font_size", 12)
		Mode.PALETTE:
			_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
			_label.add_theme_font_size_override("font_size", 11)

func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(_COMPACT_RADIUS if _mode != Mode.FILTER else 14)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	if _mode == Mode.FILTER:
		if _filter_active:
			style.bg_color = _base_color.lightened(0.08)
			style.bg_color.a = 0.95
			style.border_color = _base_color.lightened(0.42)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.11, 0.12, 0.14, 0.35)
			style.border_color = Color(0.34, 0.37, 0.42, 0.9)
			style.set_border_width_all(1)
	elif _mode == Mode.ASSIGNED:
		style.bg_color = _base_color.darkened(0.02)
		style.bg_color.a = 0.92
		style.border_color = _base_color.lightened(0.25)
		style.set_border_width_all(1)
	else:
		style.bg_color = _base_color.darkened(0.18)
		style.bg_color.a = 0.75
		style.border_color = _base_color.darkened(0.05)
		style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if _mode == Mode.ASSIGNED and event.button_index == MOUSE_BUTTON_RIGHT:
		remove_requested.emit(_tag_id)
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _mode == Mode.ASSIGNED:
		return
	activated.emit(_tag_id)
	accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _mode != Mode.PALETTE or String(_tag_id).is_empty():
		return null
	var preview := Label.new()
	preview.text = _label_text
	set_drag_preview(preview)
	return {"type": PAYLOAD_TYPE, "tag_id": _tag_id}
