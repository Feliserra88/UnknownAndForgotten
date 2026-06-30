@tool
extends VBoxContainer
## Dock UI for the map editor. Reads its own controls and calls the plugin's public actions
## (prepare, generate, paint toggles, save/load presets and maps). Built entirely in code.

const _TILE_IDS: Array[StringName] = [&"grass", &"dirt_path", &"pond_water", &"rock_wall", &"bush", &"open_door"]
const _LAYER_NAMES := ["Ground", "Terrain", "Objects", "Structures"]

var _plugin
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

## Stores the owning plugin and builds the dock controls.
func setup(plugin) -> void:
	_plugin = plugin
	_build()

func _build() -> void:
	add_theme_constant_override("separation", 4)
	_title("UF Map Editor")

	_title("Area / seed")
	_width = _spin("Width", 4, 256, 28)
	_height = _spin("Height", 4, 256, 28)
	_seed = _spin("Seed", 0, 999999, 1337)
	_water = _spin("Water bodies (-1 = biome)", -1, 32, -1)
	_path = _spin("Paths (-1 = biome)", -1, 16, -1)

	_button("Prepare blank map", func(): _plugin.prepare(_region()))
	_button("Generate field map", func(): _plugin.generate(_region(), int(_seed.value), int(_water.value), int(_path.value)))

	_separator()
	_title("Manual painting")
	_tile = _options("Tile", _tile_labels())
	_tile.item_selected.connect(func(i): _plugin.selected_tile = _TILE_IDS[i])
	_layer = _options("Layer", _LAYER_NAMES)
	_layer.item_selected.connect(func(i): _plugin.selected_layer = i)
	_mode = _options("Mode", ["Paint tile", "Edit height (wheel)"])
	_mode.item_selected.connect(func(i): _plugin.mode = i)
	var paint := CheckButton.new()
	paint.text = "Paint enabled (select WorldRoot)"
	paint.toggled.connect(func(on): _plugin.paint_enabled = on)
	add_child(paint)

	_separator()
	_title("Presets / save")
	_preset_path = _line("res://assets/world/presets/field_default.tres")
	_button("Save preset", func(): _plugin.save_preset(_preset_path.text, _region(), int(_seed.value), int(_water.value), int(_path.value)))
	_button("Load preset", _on_load_preset)
	_map_name = _line("field_map")
	_button("Save map + scene", func(): _plugin.save_map(_map_name.text))

	_separator()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 48)
	add_child(_status)

## Updates the dock status line with [param text].
func set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func _on_load_preset() -> void:
	var request: WorldGenRequest = _plugin.load_preset(_preset_path.text)
	if request == null:
		return
	_width.value = request.area.size.x
	_height.value = request.area.size.y
	_seed.value = request.gen_seed
	_water.value = request.water_body_count
	_path.value = request.path_count

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
