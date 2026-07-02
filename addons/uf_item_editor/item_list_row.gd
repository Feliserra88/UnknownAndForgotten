@tool
extends PanelContainer
## One row in the item editor browse list (sprite template or saved ItemDef).

signal row_selected(meta: Dictionary)

const _PAD := 8
const _ROW_SEP := 10
const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")
const _ITEMS := preload("res://modules/items/items.gd")

var _meta: Dictionary = {}
var _selected: bool = false
var _items: ItemsModule

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_selection_style()

func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	_apply_selection_style()

func _apply_selection_style() -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	if _selected:
		style.bg_color = Color(0.22, 0.42, 0.62, 0.55)
		style.border_color = Color(0.55, 0.78, 1.0)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.14, 0.15, 0.17, 0.4)
		style.border_color = Color(0.28, 0.30, 0.34)
		style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

## Fills the row from [param row_data] returned by ItemsModule.resolve_list_row or sprite templates.
func setup(row_data: Dictionary, is_sprite_template: bool = false) -> void:
	_meta = row_data.duplicate()
	_meta["is_sprite_template"] = is_sprite_template
	for child in get_children():
		child.queue_free()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _PAD)
	margin.add_theme_constant_override("margin_right", _PAD)
	margin.add_theme_constant_override("margin_top", _PAD)
	margin.add_theme_constant_override("margin_bottom", _PAD)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _ROW_SEP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(52, 52)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.texture = _resolve_row_icon(row_data, is_sprite_template)
	row.add_child(icon_rect)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title := Label.new()
	if is_sprite_template:
		title.text = String(row_data.get("label", ""))
	else:
		var key: String = row_data.get("display_name_key", "")
		title.text = _I18N.translate_key(key) if not key.is_empty() else String(row_data.get("id", ""))
	info.add_child(title)
	if is_sprite_template:
		var family := String(row_data.get("family", ""))
		var design := String(row_data.get("design_type", ""))
		var detail := _I18N.translate_key("item_editor.row.art_source")
		if not family.is_empty():
			detail = "%s — %s" % [detail, family]
			if not design.is_empty():
				detail = "%s / %s" % [detail, design]
		info.add_child(_muted_label(detail))
	else:
		info.add_child(_muted_label(
			"w:%.1f  price:%.0f  dur:%.0f  grid:%dx%d" % [
				float(row_data.get("weight", 0)),
				float(row_data.get("price", 0)),
				float(row_data.get("durability", 0)),
				int(row_data.get("inventory_size", Vector2i.ONE).x),
				int(row_data.get("inventory_size", Vector2i.ONE).y),
			]
		))
		var tags: Array = row_data.get("tags", [])
		if not tags.is_empty():
			info.add_child(_muted_label("tags: %s" % ", ".join(_string_names(tags))))
		var state_key: String = row_data.get("state_key", "")
		var quality_key: String = row_data.get("quality_key", "")
		if not state_key.is_empty() or not quality_key.is_empty():
			info.add_child(_muted_label("%s / %s" % [
				_I18N.translate_key(state_key) if not state_key.is_empty() else "-",
				_I18N.translate_key(quality_key) if not quality_key.is_empty() else "-",
			]))
		var mods: Array = row_data.get("modifier_ids", [])
		if not mods.is_empty():
			info.add_child(_muted_label("mods: %s" % ", ".join(_string_names(mods))))
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	_apply_selection_style()

func get_meta_data() -> Dictionary:
	return _meta

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		row_selected.emit(_meta)

func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _string_names(arr: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for v in arr:
		out.append(String(v))
	return out

func _resolve_row_icon(row_data: Dictionary, is_sprite_template: bool) -> Texture2D:
	var tex: Texture2D = row_data.get("icon")
	if tex != null:
		return tex
	var path: String = row_data.get("sprite_library_path", "")
	if path.is_empty():
		path = row_data.get("library_path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if is_sprite_template:
		if _items == null:
			_items = _ITEMS.new()
		return _items.resolve_strip_icon(path, int(row_data.get("strip_state_index", 0)))
	if _items == null:
		_items = _ITEMS.new()
	return _items.resolve_strip_icon(
		path,
		int(row_data.get("strip_state_index", 0)),
	)
