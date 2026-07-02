@tool
extends RefCounted
## Styled panel block with title header for item editor columns.

const _PAD := 10
const _HEADER_COLOR := Color(0.72, 0.84, 1.0)
const _PANEL_BG := Color(0.11, 0.12, 0.14, 0.92)
const _PANEL_BORDER := Color(0.26, 0.30, 0.36, 1.0)

const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")

static func create(title_key: String) -> Dictionary:
	_I18N.ensure_loaded()
	var title := _I18N.translate_key(title_key) if not title_key.is_empty() else ""
	var block := PanelContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	block.add_theme_stylebox_override("panel", make_panel_style())
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", _PAD)
	outer.add_theme_constant_override("margin_right", _PAD)
	outer.add_theme_constant_override("margin_top", _PAD)
	outer.add_theme_constant_override("margin_bottom", _PAD)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	block.add_child(outer)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var header: Label = null
	if not title_key.is_empty():
		header = Label.new()
		header.text = title
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", _HEADER_COLOR)
		header.custom_minimum_size = Vector2(0, 22)
		body.add_child(header)
	return {"block": block, "body": body, "header": header, "title_key": title_key}

static func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _PANEL_BG
	style.border_color = _PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
