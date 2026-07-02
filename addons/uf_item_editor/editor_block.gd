@tool
extends RefCounted
## Section block with title + horizontal rule for item editor zones.

const _HEADER_COLOR := Color(0.72, 0.84, 1.0)
const _PANEL_BG := Color(0.11, 0.12, 0.14, 0.92)
const _PANEL_BORDER := Color(0.26, 0.30, 0.36, 1.0)

const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")

static func create(title_key: String, expand_vertical: bool = false) -> Dictionary:
	_I18N.ensure_loaded()
	var title := _I18N.translate_key(title_key) if not title_key.is_empty() else ""
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand_vertical else Control.SIZE_SHRINK_BEGIN
	var header: Label = null
	if not title_key.is_empty():
		header = Label.new()
		header.text = title
		style_block_header(header)
		section.add_child(header)
		section.add_child(HSeparator.new())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand_vertical else Control.SIZE_SHRINK_BEGIN
	section.add_child(body)
	return {"block": section, "body": body, "header": header, "title_key": title_key}

static func style_block_header(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", _HEADER_COLOR)
	label.custom_minimum_size = Vector2(0, 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

static func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _PANEL_BG
	style.border_color = _PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

const BTN_GRID_COLS := 2

static func create_button_grid(columns: int = BTN_GRID_COLS, separation: int = 4) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = maxi(1, columns)
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return grid

static func add_grid_button(grid: GridContainer, height: int = 26) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, height)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(btn)
	return btn

static func make_preview_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.14, 0.20, 0.95)
	style.border_color = Color(0.38, 0.58, 0.82, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func create_bordered_panel(title_key: String) -> Dictionary:
	_I18N.ensure_loaded()
	var title := _I18N.translate_key(title_key) if not title_key.is_empty() else ""
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", make_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(body)
	if not title_key.is_empty():
		var header := Label.new()
		header.text = title
		style_block_header(header)
		body.add_child(header)
	return {"panel": panel, "body": body, "title_key": title_key}
