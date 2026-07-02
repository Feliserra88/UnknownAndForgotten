@tool
extends VBoxContainer
## Dock UI for the map editor. Calls plugin methods via callv (EditorPlugin has no custom API type).

const _LAYER_NAMES := ["Ground", "Terrain", "Objects", "Structures"]
const _GRID_COLUMNS := 2

var _plugin: EditorPlugin
var _content: VBoxContainer
var _tile_ids: Array[StringName] = []
var _structure_piece_ids: Array[StringName] = []
var _map_paths: Array[String] = []
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
var _map_list: ItemList
var _open_dialog: EditorFileDialog
var _save_dialog: EditorFileDialog
var _status: Label

func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_build()
	call_deferred("refresh_map_browser")

func _build() -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)

	_title("UF Map Editor")
	var hint := Label.new()
	hint.text = "New/Open map opens map_editor_workspace.tscn automatically. Baked tiles live under res://local/world/maps/ (gitignored) or res://assets/world/maps/."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(hint)

	_separator()
	_title("Maps")
	_map_name = _line("editor_session")
	_map_list = ItemList.new()
	_map_list.custom_minimum_size = Vector2(0, 88)
	_map_list.item_activated.connect(_on_map_activated)
	_add(_map_list)

	var map_grid := _grid()
	_grid_button(map_grid, "Refresh list", _on_refresh_maps_pressed)
	_grid_button(map_grid, "New map", _on_new_map_pressed)
	_grid_button(map_grid, "Open file…", _on_open_file_pressed)
	_grid_button(map_grid, "Save map", _on_save_current_pressed)
	_grid_button(map_grid, "Save as…", _on_save_as_pressed)
	_grid_button(map_grid, "Duplicate", _on_duplicate_pressed)
	_add(map_grid)

	_open_dialog = EditorFileDialog.new()
	_open_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_open_dialog.add_filter("*.tscn", "Baked map scene")
	_open_dialog.file_selected.connect(_on_open_dialog_selected)
	add_child(_open_dialog)
	_save_dialog = EditorFileDialog.new()
	_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_save_dialog.add_filter("*.tscn", "Baked map scene")
	_save_dialog.file_selected.connect(_on_save_dialog_selected)
	add_child(_save_dialog)

	_separator()
	_title("Area / seed")
	var area_grid := _grid()
	_width = _grid_spin(area_grid, "Width", 4, 256, 28)
	_height = _grid_spin(area_grid, "Height", 4, 256, 28)
	_seed = _grid_spin(area_grid, "Seed", 0, 999999, 1337)
	_water = _grid_spin(area_grid, "Water (-1=biome)", -1, 32, -1)
	_path = _grid_spin(area_grid, "Paths (-1=biome)", -1, 16, -1)
	_add(area_grid)

	var gen_grid := _grid()
	_grid_button(gen_grid, "Prepare grass", _on_prepare_pressed)
	_grid_button(gen_grid, "Generate map", _on_generate_pressed)
	_add(gen_grid)

	_separator()
	_title("Manual painting")
	_tile = _make_option([])
	_tile.item_selected.connect(_on_tile_selected)
	_layer = _make_option(_LAYER_NAMES)
	_layer.item_selected.connect(_on_layer_selected)
	_structure_piece = _make_option([])
	_structure_piece.item_selected.connect(_on_structure_piece_selected)
	_mode = _make_option(["Paint tile", "Edit height (wheel / +/-)", "Place structure"])
	_mode.item_selected.connect(_on_mode_selected)
	refresh_tile_options()
	refresh_structure_options()

	var paint_grid := _grid()
	_grid_field(paint_grid, "Tile", _tile)
	_grid_field(paint_grid, "Layer", _layer)
	_grid_field(paint_grid, "Structure", _structure_piece)
	_grid_field(paint_grid, "Mode", _mode)
	_add(paint_grid)

	var paint_actions := _grid()
	_grid_button(paint_actions, "Refresh tiles", _on_refresh_tiles_pressed)
	_add(paint_actions)

	var paint := CheckButton.new()
	paint.text = "Paint enabled"
	paint.toggled.connect(_on_paint_toggled)
	_add(paint)
	var height_overlay := CheckButton.new()
	height_overlay.text = "Height overlay (blue=up, red=down)"
	height_overlay.button_pressed = true
	height_overlay.toggled.connect(_on_height_overlay_toggled)
	_add(height_overlay)
	var height_hint := Label.new()
	height_hint.text = "Edit height: enable Paint, Edit height mode, wheel or +/- on a tile."
	height_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(height_hint)
	var structure_hint := Label.new()
	structure_hint.text = "Place structure: Place structure mode, L=place, R=erase. Floors use Paint tile on Ground."
	structure_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(structure_hint)

	_separator()
	_title("Presets")
	_preset_path = _line("res://assets/world/presets/field_default.tres")
	var preset_grid := _grid()
	_grid_button(preset_grid, "Save preset", _on_save_preset_pressed)
	_grid_button(preset_grid, "Load preset", _on_load_preset)
	_add(preset_grid)

	_separator()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 40)
	_add(_status)

func refresh_map_browser() -> void:
	if _map_list == null:
		return
	var paths: Variant = _plugin_call(&"list_maps")
	if paths == null:
		return
	_map_paths.clear()
	_map_list.clear()
	for path in paths:
		var map_path := String(path)
		_map_paths.append(map_path)
		var label := map_path.get_file().get_basename()
		if map_path.begins_with(WorldModule.ASSETS_MAPS_DIR):
			label = "[assets] %s" % label
		else:
			label = "[local] %s" % label
		_map_list.add_item(label)
	var current: String = String(_plugin_call(&"get_current_map_path"))
	if not current.is_empty():
		var idx := _map_paths.find(current)
		if idx >= 0:
			_map_list.select(idx)

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

func _selected_map_path() -> String:
	if _map_list == null:
		return ""
	var selected := _map_list.get_selected_items()
	if selected.is_empty():
		return ""
	var idx: int = selected[0]
	if idx < 0 or idx >= _map_paths.size():
		return ""
	return _map_paths[idx]

func _on_refresh_maps_pressed() -> void:
	refresh_map_browser()

func _on_new_map_pressed() -> void:
	_plugin_call(&"new_map", [_map_name.text, _region()])

func _on_open_selected_pressed() -> void:
	var path := _selected_map_path()
	if path.is_empty():
		set_status("Double-click a map in the list, or use Open file…")
		return
	_plugin_call(&"open_map", [path])

func _on_map_activated(_index: int) -> void:
	_on_open_selected_pressed()

func _on_open_file_pressed() -> void:
	if _open_dialog == null:
		return
	_open_dialog.current_dir = WorldModule.LOCAL_MAPS_DIR
	_open_dialog.popup_centered_ratio(0.55)

func _on_open_dialog_selected(path: String) -> void:
	_plugin_call(&"open_map", [path])

func _on_save_current_pressed() -> void:
	_plugin_call(&"save_current_map")

func _on_save_as_pressed() -> void:
	if _save_dialog == null:
		return
	_save_dialog.current_dir = WorldModule.LOCAL_MAPS_DIR
	_save_dialog.current_file = "%s.tscn" % WorldModule.sanitize_map_id(_map_name.text)
	_save_dialog.popup_centered_ratio(0.55)

func _on_save_dialog_selected(path: String) -> void:
	_plugin_call(&"save_map_as", [path])

func _on_duplicate_pressed() -> void:
	var source := _selected_map_path()
	if source.is_empty():
		set_status("Select a map to duplicate.")
		return
	_plugin_call(&"duplicate_map", [source, _map_name.text])

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

func _add(node: Control) -> void:
	_content.add_child(node)

func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = _GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	return grid

func _grid_button(grid: GridContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	grid.add_child(button)

func _grid_field(grid: GridContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)

func _grid_spin(grid: GridContainer, label_text: String, lo: float, hi: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_field(grid, label_text, spin)
	return spin

func _title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_add(label)

func _make_option(items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.clip_text = true
	for item in items:
		option.add_item(str(item))
	return option

func _line(value: String) -> LineEdit:
	var line := LineEdit.new()
	line.text = value
	line.placeholder_text = "Map id (filename without .tscn)"
	_add(line)
	return line

func _separator() -> void:
	_add(HSeparator.new())
