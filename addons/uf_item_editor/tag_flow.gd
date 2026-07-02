@tool
extends VBoxContainer
## Grid of tag chips for list filtering (toggle) or palette (drag source).

signal filter_changed(active_tags: Array[StringName])
signal palette_tag_selected(tag_id: StringName)

const _CHIP := preload("res://addons/uf_item_editor/tag_chip.gd")
const _BLOCK := preload("res://addons/uf_item_editor/editor_block.gd")
const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")
const _FILTER_BTN_H := 22
const _FILTER_FLOW_SEP := 4

var _mode: int = _CHIP.Mode.FILTER
var _items: ItemsModule
var _container: Container
var _active: Dictionary = {}

func _init() -> void:
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_set_container_for_mode(_mode)

func configure(mode: int, items: ItemsModule, category_id: StringName) -> void:
	if _mode != mode:
		_set_container_for_mode(mode)
	_mode = mode
	_items = items
	_active.clear()
	_rebuild(items.list_tag_defs(category_id))

func refresh(category_id: StringName) -> void:
	if _items == null:
		return
	_rebuild(_items.list_tag_defs(category_id))

func get_active_filter_tags() -> Array[StringName]:
	var out: Array[StringName] = []
	for key in _active.keys():
		if _active[key]:
			out.append(StringName(key))
	return out

func clear_filter() -> void:
	_active.clear()
	for child in _container.get_children():
		if child is Button:
			var btn := child as Button
			btn.button_pressed = false
			_apply_filter_button_style(btn, btn.get_meta("chip_color", Color.GRAY), false)
		elif child is _CHIP:
			(child as _CHIP).set_filter_active(false)

func _set_container_for_mode(mode: int) -> void:
	if _container != null:
		remove_child(_container)
		_container.queue_free()
	if mode == _CHIP.Mode.FILTER:
		var flow := FlowContainer.new()
		flow.add_theme_constant_override("h_separation", _FILTER_FLOW_SEP)
		flow.add_theme_constant_override("v_separation", _FILTER_FLOW_SEP)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_container = flow
	else:
		_container = _BLOCK.create_button_grid()
	add_child(_container)

func _rebuild(defs: Array[ItemTagDef]) -> void:
	for child in _container.get_children():
		child.queue_free()
	for def in defs:
		if def == null:
			continue
		if _mode == _CHIP.Mode.FILTER:
			_add_filter_button(def)
		else:
			var chip := _CHIP.new()
			chip.setup(def.id, _tag_label(def), _CHIP.Mode.PALETTE, def.chip_color)
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chip.activated.connect(_on_palette_chip.bind(def.id))
			_container.add_child(chip)

func _add_filter_button(def: ItemTagDef) -> void:
	var key := String(def.id)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.text = _tag_label(def)
	btn.button_pressed = _active.get(key, false)
	btn.custom_minimum_size = Vector2(0, _FILTER_BTN_H)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.set_meta("chip_color", def.chip_color)
	btn.set_meta("tag_id", def.id)
	_apply_filter_button_style(btn, def.chip_color, btn.button_pressed)
	btn.toggled.connect(_on_filter_button_toggled.bind(def.id, btn))
	_container.add_child(btn)

func _on_filter_button_toggled(pressed: bool, tag_id: StringName, btn: Button) -> void:
	var key := String(tag_id)
	_active[key] = pressed
	var color: Color = btn.get_meta("chip_color", Color.GRAY)
	_apply_filter_button_style(btn, color, pressed)
	filter_changed.emit(get_active_filter_tags())

func _apply_filter_button_style(btn: Button, base_color: Color, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	if active:
		style.bg_color = base_color.lightened(0.08)
		style.bg_color.a = 0.95
		style.border_color = base_color.lightened(0.42)
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
		btn.add_theme_font_size_override("font_size", 12)
	else:
		style.bg_color = Color(0.11, 0.12, 0.14, 0.35)
		style.border_color = Color(0.34, 0.37, 0.42, 0.9)
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.52, 0.56, 0.62))
		btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("hover", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	if active:
		hover_style.bg_color = base_color.lightened(0.14)
	else:
		hover_style.bg_color = Color(0.14, 0.15, 0.17, 0.5)
	btn.add_theme_stylebox_override("hover", hover_style)

func _on_palette_chip(tag_id: StringName) -> void:
	palette_tag_selected.emit(tag_id)

func _tag_label(def: ItemTagDef) -> String:
	if def.display_name_key.is_empty():
		return String(def.id)
	return _I18N.translate_key(def.display_name_key)
