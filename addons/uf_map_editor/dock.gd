@tool
extends VBoxContainer
## Dock UI for the map editor. Calls plugin methods via callv (EditorPlugin has no custom API type).

const _TILE_IDS: Array[StringName] = [&"grass", &"dirt_path", &"pond_water", &"rock_wall", &"bush", &"open_door"]
const _LAYER_NAMES := ["Ground", "Terrain", "Objects", "Structures"]

var _plugin: EditorPlugin
var _width: SpinBox
var _height: SpinBox
var _seed: SpinBox
var _water: SpinBox
var _path: SpinBox
var _tile: OptionButton
var _layer: OptionButton
var _mode: OptionButton
var _preset_path: LineEdit
var _map_name: LineEdit
var _status: Label

func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_build()

func _build() -> void:
	add_theme_constant_override("separation", 4)
	_title("UF Map Editor")
	var hint := Label.new()
	hint.text = "Open world_root.tscn, then Generate or Prepare."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	_title("Area / seed")
	_width = _spin("Width", 4, 256, 28)
	_height = _spin("Height", 4, 256, 28)
	_seed = _spin("Seed", 0, 999999, 1337)
	_water = _spin("Water bodies (-1 = biome)", -1, 32, -1)
	_path = _spin("Paths (-1 = biome)", -1, 16, -1)

	_button("Prepare flat grass", _on_prepare_pressed)
	_button("Generate field map", _on_generate_pressed)

	_separator()
	_title("Manual painting")
	_tile = _options("Tile", _tile_labels())
	_tile.item_selected.connect(_on_tile_selected)
	_layer = _options("Layer", _LAYER_NAMES)
	_layer.item_selected.connect(_on_layer_selected)
	_mode = _options("Mode", ["Paint tile", "Edit height (wheel / +/-)"])
	_mode.item_selected.connect(_on_mode_selected)
	var paint := CheckButton.new()
	paint.text = "Paint enabled (select WorldRoot in scene tree)"
	paint.toggled.connect(_on_paint_toggled)
	add_child(paint)
	var height_hint := Label.new()
	height_hint.text = "Height: Generate map first, enable Paint, Mode = Edit height, hover a tile and use mouse wheel or +/- keys."
	height_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(height_hint)

	_separator()
	_title("Presets / save")
	_preset_path = _line("res://assets/world/presets/field_default.tres")
	_button("Save preset", _on_save_preset_pressed)
	_button("Load preset", _on_load_preset)
	_map_name = _line("field_map")
	_button("Save map + scene", _on_save_map_pressed)

	_separator()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 48)
	add_child(_status)

func _plugin_call(method: StringName, args: Array = []) -> Variant:
	if _plugin == null:
		set_status("Map editor plugin not ready — reload the project.")
		return null
	if not _plugin.has_method(method):
		set_status("Missing plugin method: %s" % method)
		return null
	return _plugin.callv(method, args)

func _plugin_set(prop: StringName, value: Variant) -> void:
	if _plugin != null:
		_plugin.set(prop, value)

func _on_prepare_pressed() -> void:
	_plugin_call(&"prepare_field_map", [_region()])

func _on_generate_pressed() -> void:
	_plugin_call(&"generate_field_map", [_region(), int(_seed.value), int(_water.value), int(_path.value)])

func _on_save_preset_pressed() -> void:
	_plugin_call(&"save_preset", [_preset_path.text, _region(), int(_seed.value), int(_water.value), int(_path.value)])

func _on_save_map_pressed() -> void:
	_plugin_call(&"save_map", [_map_name.text])

func _on_tile_selected(index: int) -> void:
	_plugin_set(&"selected_tile", _TILE_IDS[index])

func _on_layer_selected(index: int) -> void:
	_plugin_set(&"selected_layer", index)

func _on_mode_selected(index: int) -> void:
	_plugin_set(&"mode", index)

func _on_paint_toggled(on: bool) -> void:
	_plugin_set(&"paint_enabled", on)

func set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func _on_load_preset() -> void:
	var request: Resource = _plugin_call(&"load_preset", [_preset_path.text])
	if request == null or not (request is WorldGenRequest):
		return
	var req := request as WorldGenRequest
	_width.value = req.area.size.x
	_height.value = req.area.size.y
	_seed.value = req.gen_seed
	_water.value = req.water_body_count
	_path.value = req.path_count

func _region() -> Rect2i:
	return Rect2i(0, 0, int(_width.value), int(_height.value))

func _tile_labels() -> Array:
	var labels := []
	for id in _TILE_IDS:
		labels.append(String(id))
	return labels

func _title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(label)

func _spin(label: String, lo: float, hi: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.value = value
	row.add_child(spin)
	add_child(row)
	return spin

func _options(label: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var option := OptionButton.new()
	for item in items:
		option.add_item(str(item))
	row.add_child(option)
	add_child(row)
	return option

func _line(value: String) -> LineEdit:
	var line := LineEdit.new()
	line.text = value
	add_child(line)
	return line

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	add_child(button)

func _separator() -> void:
	add_child(HSeparator.new())
