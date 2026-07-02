@tool
extends PanelContainer
## One row in the item editor browse list (sprite template or saved ItemDef).

signal row_selected(meta: Dictionary)

var _meta: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

## Fills the row from [param row_data] returned by ItemsModule.resolve_list_row or sprite templates.
func setup(row_data: Dictionary, is_sprite_template: bool = false) -> void:
	_meta = row_data.duplicate()
	_meta["is_sprite_template"] = is_sprite_template
	for child in get_children():
		child.queue_free()
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Texture2D = row_data.get("icon")
	if tex == null and row_data.has("library_path"):
		var path: String = row_data.get("library_path", "")
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
	icon_rect.texture = tex
	row.add_child(icon_rect)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title := Label.new()
	if is_sprite_template:
		title.text = String(row_data.get("label", ""))
	else:
		var key: String = row_data.get("display_name_key", "")
		title.text = tr(key) if not key.is_empty() else String(row_data.get("id", ""))
	info.add_child(title)
	if is_sprite_template:
		info.add_child(_muted_label("Sprite template"))
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
				tr(state_key) if not state_key.is_empty() else "-",
				tr(quality_key) if not quality_key.is_empty() else "-",
			]))
	gui_input.connect(_on_gui_input)

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
	return label

func _string_names(arr: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for v in arr:
		out.append(String(v))
	return out
