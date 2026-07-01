@tool
extends VBoxContainer
## Dock UI for the map editor. Calls plugin methods via callv (EditorPlugin has no custom API type).

const _LAYER_NAMES := ["Ground", "Terrain", "Objects", "Structures"]

var _plugin: EditorPlugin
var _tile_ids: Array[StringName] = []
var _structure_piece_ids: Array[StringName] = []
var _width: SpinBox
var _height: SpinBox
var _seed: SpinBox
var _water: SpinBox
var _path: SpinBox
var _tile: OptionButton
var _structure_piece: OptionButton
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
	hint.text = "Open world_root.tscn, then Generate or Prepare. Tile data is kept in res://local/ (not git); use Save session map."
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
	_tile = _options("Tile", [])
	_tile.item_selected.connect(_on_tile_selected)
	refresh_tile_options()
	_button("Refresh tile catalog / visuals", _on_refresh_tiles_pressed)
	_layer = _options("Layer", _LAYER_NAMES)
	_layer.item_selected.connect(_on_layer_selected)
	_structure_piece = _options("Structure piece", [])
	_structure_piece.item_selected.connect(_on_structure_piece_selected)
	refresh_structure_options()
	_mode = _options("Mode", ["Paint tile", "Edit height (wheel / +/-)", "Place structure piece"])
	_mode.item_selected.connect(_on_mode_selected)
	var paint := CheckButton.new()
	paint.text = "Paint enabled (select WorldRoot in scene tree)"
	paint.toggled.connect(_on_paint_toggled)
	add_child(paint)
	var height_overlay := CheckButton.new()
	height_overlay.text = "Show height overlay (blue=up, red=down, z label)"
	height_overlay.button_pressed = true
	height_overlay.toggled.connect(_on_height_overlay_toggled)
	add_child(height_overlay)
	var height_hint := Label.new()
	height_hint.text = "Edit height: enable Paint, pick Edit height mode, hover a tile, wheel or +/- keys. Overlay tints each cell and shows z."
	height_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(height_hint)
	var structure_hint := Label.new()
	structure_hint.text = "Place structure: enable Paint, pick Place structure mode, choose a piece. Left click places; right click removes. Floors still use Paint tile on Ground."
	structure_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(structure_hint)

	_separator()
	_title("Presets / session save")
	_preset_path = _line("res://assets/world/presets/field_default.tres")
	_button("Save preset", _on_save_preset_pressed)
	_button("Load preset", _on_load_preset)
	_map_name = _line("editor_session")
	_button("Save session map", _on_save_map_pressed)

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
	if index < 0 or index >= _tile_ids.size():
		return
	_plugin_set(&"selected_tile", _tile_ids[index])

func _on_structure_piece_selected(index: int) -> void:
	if index < 0 or index >= _structure_piece_ids.size():
		return
	_plugin_set(&"selected_structure_piece", _structure_piece_ids[index])

func refresh_structure_options() -> void:
	var catalog: StructureCatalog = _plugin_call(&"get_structure_catalog")
	if catalog == null or _structure_piece == null:
		return
	var selected: StringName = &"wall_straight"
	if _plugin != null:
		selected = _plugin.get("selected_structure_piece")
	_structure_piece_ids = catalog.ids()
	_structure_piece.clear()
	var select_index := 0
	for i in _structure_piece_ids.size():
		var id := _structure_piece_ids[i]
		var def := catalog.get_piece(id)
		var label := String(id)
		if def != null:
			if not def.display_name_key.is_empty():
				label = def.get_display_name()
			if def.sprite_texture == null:
				label += " (no texture)"
		_structure_piece.add_item(label)
		if id == selected:
			select_index = i
	if _structure_piece_ids.is_empty():
		return
	_structure_piece.select(select_index)
	_on_structure_piece_selected(select_index)

func refresh_tile_options() -> void:
	var catalog: TileCatalog = _plugin_call(&"get_field_catalog")
	if catalog == null or _tile == null:
		return
	var selected: StringName = &"grass"
	if _plugin != null:
		selected = _plugin.get("selected_tile")
	_tile_ids = catalog.ids()
	_tile.clear()
	var select_index := 0
	for i in _tile_ids.size():
		var id := _tile_ids[i]
		var def := catalog.get_tile(id)
		var label := String(id)
		if def != null:
			if not def.display_name_key.is_empty():
				label = def.get_display_name()
			if def.art_texture == null:
				label += " (placeholder)"
		_tile.add_item(label)
		if id == selected:
			select_index = i
	if _tile_ids.is_empty():
		return
	_tile.select(select_index)
	_on_tile_selected(select_index)

func _on_refresh_tiles_pressed() -> void:
	_plugin_call(&"refresh_field_tilesets")
	refresh_tile_options()

func _on_layer_selected(index: int) -> void:
	_plugin_set(&"selected_layer", index)

func _on_mode_selected(index: int) -> void:
	_plugin_set(&"mode", index)
	if index == 1:
		_plugin_set(&"show_height_overlay", true)
	if index == 2:
		_plugin_call(&"queue_viewport_redraw")

func _on_height_overlay_toggled(on: bool) -> void:
	_plugin_set(&"show_height_overlay", on)
	_plugin_call(&"queue_viewport_redraw")

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
