@tool
extends EditorPlugin
## Map editor plugin: drives the world / world_gen public API to generate, paint and save field
## maps. Procedural work runs on an off-tree scratch WorldModule; results are copied to the
## dedicated map_editor_workspace scene (independent of game_session).

const _DockScript := preload("res://addons/uf_map_editor/dock.gd")
const _HeightOverlay := preload("res://addons/uf_map_editor/height_overlay.gd")
const _StructureOverlay := preload("res://addons/uf_map_editor/structure_overlay.gd")
const _WORLD_SCRIPT_PATH := "res://modules/world/world.gd"

enum Mode { PAINT_TILE, EDIT_HEIGHT, PLACE_STRUCTURE }

var _dock: Control
var _world_gen: WorldGenModule
## Bound to the map editor workspace TileMapLayers for paint/save/apply.
var _map_session: WorldModule
## Off-tree target for procedural generation (editor does not watch these layers).
var _scratch_world: WorldModule
var _field_catalog: TileCatalog
var _field_modifiers: Array
var _field_sprite_catalog: MapSpriteCatalog
var _field_terrain_sets: Array
var _structure_catalog: StructureCatalog
var _field_tileset: TileSet
var _field_modifier_pack: Dictionary
var _session_tilesets_refreshed: bool = false
var _current_map_path: String = ""
var _pending_workspace_callback: Callable = Callable()

var paint_enabled: bool = false
var mode: int = Mode.PAINT_TILE
var show_height_overlay: bool = true
var selected_tile: StringName = &"grass"
var selected_structure_piece: StringName = &"wall_straight"
var selected_layer: int = 0
var _hover_cell: Vector2i = Vector2i(-999999, -999999)

func _enter_tree() -> void:
	_world_gen = WorldGenModule.new()
	add_child(_world_gen)
	_map_session = WorldModule.new()
	_scratch_world = WorldModule.create_scratch()
	_cache_field_tilesets()
	_dock = _DockScript.new()
	_dock.name = "UF Map"
	_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.setup(self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	get_editor_interface().scene_changed.connect(_on_editor_scene_changed)

func _exit_tree() -> void:
	if get_editor_interface().scene_changed.is_connected(_on_editor_scene_changed):
		get_editor_interface().scene_changed.disconnect(_on_editor_scene_changed)
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null
	if _world_gen != null:
		_world_gen.queue_free()
		_world_gen = null
	_map_session = null
	_scratch_world = null
	_field_catalog = null
	_field_tileset = null
	_field_modifier_pack.clear()
	_pending_workspace_callback = Callable()

func _on_editor_scene_changed(_scene_root: Node) -> void:
	if not _pending_workspace_callback.is_valid():
		return
	if not _is_workspace_root(get_editor_interface().get_edited_scene_root()):
		return
	var callback := _pending_workspace_callback
	_pending_workspace_callback = Callable()
	callback.call()

func list_maps() -> PackedStringArray:
	return WorldModule.list_baked_map_paths()

func get_current_map_path() -> String:
	return _current_map_path

func new_map(region: Rect2i) -> void:
	var path := WorldModule.map_path_in_local(WorldModule.suggest_unused_local_map_id())
	_run_with_workspace(func() -> void:
		_current_map_path = path
		_session_tilesets_refreshed = false
		var world := _active_world()
		if world == null:
			return
		_configure_world_for_region(world, region)
		_set_scene_editor_baked_map(path)
		var err := world.save_baked_map(path)
		_sync_session_to_scene_root(world)
		get_editor_interface().mark_scene_as_unsaved()
		if err == OK:
			set_dock_status("New map saved: %s" % path)
		else:
			set_dock_status("New map configured but save failed (%d)." % err)
		_refresh_map_browser()
	)

func open_map(map_path: String) -> void:
	if map_path.is_empty():
		set_dock_status("Choose a map to open.")
		return
	if not ResourceLoader.exists(map_path):
		set_dock_status("Map not found: %s" % map_path)
		return
	_run_with_workspace(func() -> void:
		_current_map_path = map_path
		_session_tilesets_refreshed = false
		var world := _active_world()
		if world == null:
			return
		if not world.load_baked_map(map_path):
			set_dock_status("Failed to load map: %s" % map_path)
			return
		_set_scene_editor_baked_map(map_path)
		_ensure_world_tilesets(world)
		_sync_session_to_scene_root(world)
		get_editor_interface().mark_scene_as_unsaved()
		_queue_viewport_redraw()
		set_dock_status("Opened map: %s" % map_path)
		_refresh_map_browser()
	)

func save_current_map() -> void:
	var world := _active_world()
	if world == null:
		return
	if _current_map_path.is_empty():
		set_dock_status("No map open — use New map first.")
		return
	_save_map_to_path(world, _current_map_path)

func rename_map(source_path: String, new_map_id: String) -> void:
	if source_path.is_empty():
		set_dock_status("Select a map to rename.")
		return
	if _current_map_path == source_path:
		var world := _active_world()
		if world != null:
			_save_map_to_path(world, source_path)
	var new_path := WorldModule.rename_baked_map(source_path, new_map_id)
	if new_path.is_empty():
		set_dock_status("Rename failed (invalid name, file exists, or file locked).")
		return
	var fs := get_editor_interface().get_resource_filesystem()
	if fs != null:
		fs.scan()
	if _current_map_path == source_path:
		_current_map_path = new_path
		_set_scene_editor_baked_map(new_path)
		get_editor_interface().mark_scene_as_unsaved()
	set_dock_status("Renamed to: %s" % new_path)
	_refresh_map_browser()

func duplicate_map(source_path: String) -> void:
	if source_path.is_empty():
		set_dock_status("Select a map to duplicate.")
		return
	var dest_id := WorldModule.suggest_duplicate_map_id(source_path)
	var dest_path := "%s/%s.tscn" % [source_path.get_base_dir(), WorldModule.sanitize_map_id(dest_id)]
	var err := WorldModule.duplicate_baked_map(source_path, dest_path)
	if err == OK:
		set_dock_status("Duplicated to: %s" % dest_path)
		_refresh_map_browser()
	else:
		set_dock_status("Duplicate failed (%d)." % err)

func _save_map_to_path(world: WorldModule, map_path: String) -> void:
	if world.height_field == null:
		set_dock_status("Nothing to save: prepare or generate first.")
		return
	_sync_session_to_scene_root(world)
	var err := world.save_baked_map(map_path)
	if err == OK:
		set_dock_status("Map saved: %s" % map_path)
		_refresh_map_browser()
	else:
		set_dock_status("Map save failed (%d)." % err)

func _run_with_workspace(callback: Callable) -> void:
	if _is_workspace_root(get_editor_interface().get_edited_scene_root()):
		callback.call()
		return
	if not ResourceLoader.exists(WorldModule.MAP_EDITOR_WORKSPACE_PATH):
		set_dock_status("Missing workspace scene: %s" % WorldModule.MAP_EDITOR_WORKSPACE_PATH)
		return
	_pending_workspace_callback = callback
	set_dock_status("Opening map editor workspace…")
	get_editor_interface().open_scene_from_path(WorldModule.MAP_EDITOR_WORKSPACE_PATH)

func _configure_world_for_region(world: WorldModule, region: Rect2i) -> void:
	_cache_field_tilesets()
	world.configure(
		_field_catalog,
		_field_modifiers,
		region,
		_field_tileset,
		_field_modifier_pack,
		_field_sprite_catalog,
		_field_terrain_sets,
		_structure_catalog,
	)

func _ensure_world_tilesets(world: WorldModule) -> void:
	if _session_tilesets_refreshed and world.tile_catalog != null:
		return
	_cache_field_tilesets()
	world.refresh_tilesets(_field_catalog, _field_modifiers, _field_tileset, _field_modifier_pack)
	_sync_session_to_scene_root(world)
	_session_tilesets_refreshed = true

func _set_scene_editor_baked_map(map_path: String) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root is WorldModule:
		(root as WorldModule).editor_baked_map = map_path

func _refresh_map_browser() -> void:
	if _dock != null and _dock.has_method("refresh_map_browser"):
		_dock.refresh_map_browser()

func _cache_field_tilesets() -> void:
	_field_catalog = _world_gen.build_field_catalog()
	_field_modifiers = _world_gen.build_field_modifiers()
	_field_sprite_catalog = _world_gen.build_field_sprite_catalog()
	_field_terrain_sets = _world_gen.build_field_terrain_sets()
	_structure_catalog = _world_gen.build_dark_medieval_wood_catalog()
	var tile_size := Vector2i(
		Config.get_int("WORLD_TILE_WIDTH", 64),
		Config.get_int("WORLD_TILE_HEIGHT", 32),
	)
	_field_tileset = WorldModule.build_tileset(_field_catalog.tiles, tile_size)
	_field_modifier_pack = WorldModule.build_modifier_overlay_pack(_field_modifiers, tile_size)

func _handles(object: Object) -> bool:
	return object is Node and _is_world_node(object as Node)

func _edit(_object: Object) -> void:
	_session_tilesets_refreshed = false

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var world := _active_world()
	if world == null or not paint_enabled:
		return false
	if mode == Mode.EDIT_HEIGHT:
		if event is InputEventMouseMotion:
			var cell := _canvas_mouse_to_cell(world, event)
			if cell != _hover_cell:
				_hover_cell = cell
				_queue_viewport_redraw()
		elif event is InputEventMouseButton and event.pressed:
			var delta := 0
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				delta = 1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				delta = -1
			if delta != 0:
				_edit_height_at_canvas(event, world, delta)
				return true
	if mode == Mode.PLACE_STRUCTURE:
		if event is InputEventMouseMotion:
			var cell := _canvas_mouse_to_cell(world, event)
			if cell != _hover_cell:
				_hover_cell = cell
				_queue_viewport_redraw()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_place_structure_at_canvas(event, world)
				return true
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_erase_structure_at_canvas(event, world)
				return true
	if mode == Mode.PAINT_TILE:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_paint_at_canvas(event, world)
			return true
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_paint_at_canvas(event, world)
			return true
	return false

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not paint_enabled:
		return
	var world := _bound_world_silent()
	if world == null or world.ground_layer == null:
		return
	var vp := get_editor_interface().get_editor_viewport_2d()
	if vp == null:
		return
	var canvas_xform := vp.global_canvas_transform
	if show_height_overlay and world.height_field != null:
		_HeightOverlay.draw_field(
			overlay,
			world.ground_layer,
			world.height_field,
			canvas_xform,
			_hover_cell,
			mode == Mode.EDIT_HEIGHT,
		)
	if mode == Mode.PLACE_STRUCTURE:
		var piece := _selected_structure_piece_def()
		if piece != null:
			_StructureOverlay.draw_preview(
				overlay, world.ground_layer, canvas_xform, _hover_cell, piece)
			_StructureOverlay.draw_connect_hints(
				overlay, world.ground_layer, canvas_xform, _hover_cell, piece)

func _input(event: InputEvent) -> void:
	if not paint_enabled or mode != Mode.EDIT_HEIGHT:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var delta := 0
	match event.keycode:
		KEY_EQUAL, KEY_KP_ADD:
			delta = 1
		KEY_MINUS, KEY_KP_SUBTRACT:
			delta = -1
		_:
			return
	var world := _active_world()
	if world == null:
		return
	var cell := _cell_under_editor_mouse(world)
	_apply_height_delta(world, cell, delta)
	get_viewport().set_input_as_handled()

func get_field_catalog() -> TileCatalog:
	_cache_field_tilesets()
	return _field_catalog

func get_structure_catalog() -> StructureCatalog:
	_cache_field_tilesets()
	return _structure_catalog

func refresh_field_tilesets() -> void:
	var world := _bound_world_silent()
	if world == null:
		set_dock_status("Open a map in the map editor workspace first.")
		return
	_cache_field_tilesets()
	world.refresh_tilesets(_field_catalog, _field_modifiers, _field_tileset, _field_modifier_pack)
	_sync_session_to_scene_root(world)
	get_editor_interface().mark_scene_as_unsaved()
	set_dock_status("TileSet refreshed from catalog (%d tiles)." % _field_catalog.tiles.size())
	if _dock != null and _dock.has_method("refresh_tile_options"):
		_dock.refresh_tile_options()
	_queue_viewport_redraw()

func prepare_field_map(region: Rect2i) -> void:
	_run_on_scratch(region, func(scratch: WorldModule) -> String:
		var biome: BiomeDef = _world_gen.build_field_biome()
		for x in region.size.x:
			for y in region.size.y:
				scratch.set_tile(WorldModule.Layer.GROUND, region.position + Vector2i(x, y), biome.ground_tile)
		return "Prepared %dx%d flat grass (no water/paths)." % [region.size.x, region.size.y]
	)

func generate_field_map(region: Rect2i, gen_seed: int, water_count: int, path_count: int) -> void:
	_run_on_scratch(region, func(scratch: WorldModule) -> String:
		var request: WorldGenRequest = _world_gen.build_field_request(region, gen_seed)
		request.water_body_count = water_count
		request.path_count = path_count
		var report: Dictionary = _world_gen.generate(request, scratch)
		return "Generated seed=%d walkable=%s." % [gen_seed, report.get("walkable", 0)]
	)

var _pending_status: String = ""
var _copy_target: WorldModule
var _copy_step: int = -1
const _COPY_LAYER_KEYS: Array[StringName] = [&"ground", &"terrain", &"objects", &"structures", &"modifiers", &"props", &"decor"]

func _run_on_scratch(region: Rect2i, build_fn: Callable) -> void:
	_run_with_workspace(func() -> void:
		var world := _active_world()
		if world == null or _scratch_world == null:
			return
		_cache_field_tilesets()
		_scratch_world.configure(
			_field_catalog,
			_field_modifiers,
			region,
			_field_tileset,
			_field_modifier_pack,
			_field_sprite_catalog,
			_field_terrain_sets,
			_structure_catalog,
		)
		_pending_status = build_fn.call(_scratch_world)
		_copy_target = world
		_copy_step = -1
		call_deferred("_copy_next_layer")
	)

func _copy_next_layer() -> void:
	if _copy_target == null or _scratch_world == null:
		return
	if _copy_step == -1:
		_copy_target.apply_map_metadata_from(_scratch_world)
		_copy_step = 0
		call_deferred("_copy_next_layer")
		return
	if _copy_step >= _COPY_LAYER_KEYS.size():
		call_deferred("_finish_map_edit", _copy_target)
		_copy_target = null
		return
	_copy_target.apply_map_layer_from(_scratch_world, _COPY_LAYER_KEYS[_copy_step])
	_copy_step += 1
	call_deferred("_copy_next_layer")

func _finish_map_edit(world: WorldModule) -> void:
	_sync_session_to_scene_root(world)
	if _current_map_path.is_empty():
		_current_map_path = WorldModule.EDITOR_SESSION_MAP_PATH
	_set_scene_editor_baked_map(_current_map_path)
	var save_err := world.save_baked_map(_current_map_path)
	_queue_viewport_redraw()
	_refresh_map_browser()
	if not _pending_status.is_empty():
		var suffix := "" if save_err == OK else " (map save failed: %d)" % save_err
		set_dock_status(_pending_status + suffix)

func save_preset(path: String, region: Rect2i, gen_seed: int, water_count: int, path_count: int) -> void:
	var request: WorldGenRequest = _world_gen.build_field_request(region, gen_seed)
	request.biome = _world_gen.build_field_biome()
	request.water_body_count = water_count
	request.path_count = path_count
	var err := ResourceSaver.save(request, path)
	if err == OK:
		set_dock_status("Preset saved: %s" % path)
	else:
		set_dock_status("Preset save failed (%d)." % err)

func load_preset(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		set_dock_status("Preset not found: %s" % path)
		return null
	set_dock_status("Preset loaded: %s" % path)
	return load(path)

func set_dock_status(text: String) -> void:
	if _dock != null and _dock.has_method("set_status"):
		_dock.set_status(text)
	push_warning("[UF Map] %s" % text)

func _active_world() -> WorldModule:
	if _map_session == null:
		return null
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not _is_world_node(root):
		set_dock_status("Use New map or Open map — the plugin opens map_editor_workspace.tscn.")
		return null
	if not _is_workspace_root(root):
		set_dock_status("UF Map Editor requires map_editor_workspace.tscn.")
		return null
	_map_session.bind_edited_root(root as Node2D)
	if _map_session.ground_layer == null or not is_instance_valid(_map_session.ground_layer):
		set_dock_status("Workspace is missing Layers/Ground.")
		return null
	_sync_scene_root_to_session(_map_session)
	if _current_map_path.is_empty() and root is WorldModule:
		var baked := (root as WorldModule).editor_baked_map
		if not baked.is_empty():
			_current_map_path = baked
	_ensure_world_tilesets(_map_session)
	if _map_session.tile_catalog != null and _field_tileset != null:
		WorldModule.assign_tile_mapping(_map_session.tile_catalog.tiles, _field_tileset)
	_map_session.register_structure_catalog(_structure_catalog)
	return _map_session

func _is_world_node(node: Node) -> bool:
	if node == null:
		return false
	var script: Script = node.get_script()
	return script != null and script.resource_path == _WORLD_SCRIPT_PATH

func _is_workspace_root(node: Node) -> bool:
	if node == null:
		return false
	return node.scene_file_path == WorldModule.MAP_EDITOR_WORKSPACE_PATH

func _sync_session_to_scene_root(session: WorldModule) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not (root is WorldModule):
		return
	var scene_world := root as WorldModule
	scene_world.height_field = session.height_field
	scene_world.tile_catalog = session.tile_catalog

func _sync_scene_root_to_session(session: WorldModule) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not (root is WorldModule):
		return
	var scene_world := root as WorldModule
	if scene_world.height_field != null:
		session.height_field = scene_world.height_field
	if scene_world.tile_catalog != null:
		session.tile_catalog = scene_world.tile_catalog

func _editor_canvas_transform() -> Transform2D:
	var vp := get_editor_interface().get_editor_viewport_2d()
	if vp == null:
		return Transform2D()
	return vp.global_canvas_transform

func _canvas_mouse_to_cell(world: WorldModule, event: InputEvent) -> Vector2i:
	if world.ground_layer == null:
		return Vector2i.ZERO
	if not event is InputEventMouse:
		return Vector2i.ZERO
	var mouse := event as InputEventMouse
	var canvas_pos: Vector2 = _editor_canvas_transform().affine_inverse() * mouse.position
	return world.ground_layer.local_to_map(world.ground_layer.to_local(canvas_pos))

func _cell_under_editor_mouse(world: WorldModule) -> Vector2i:
	var vp := get_editor_interface().get_editor_viewport_2d()
	if vp == null or world.ground_layer == null:
		return Vector2i.ZERO
	var canvas_pos: Vector2 = vp.global_canvas_transform.affine_inverse() * vp.get_mouse_position()
	return world.ground_layer.local_to_map(world.ground_layer.to_local(canvas_pos))

func _paint_at_canvas(event: InputEvent, world: WorldModule) -> void:
	if world.tile_catalog == null:
		set_dock_status("Generate or prepare the map before painting.")
		return
	var cell := _canvas_mouse_to_cell(world, event)
	world.set_tile(selected_layer, cell, selected_tile)
	get_editor_interface().mark_scene_as_unsaved()

func _place_structure_at_canvas(event: InputEvent, world: WorldModule) -> void:
	var piece := _selected_structure_piece_def()
	if piece == null:
		set_dock_status("No structure piece selected.")
		return
	var cell := _canvas_mouse_to_cell(world, event)
	world.add_structure_piece(cell, piece)
	get_editor_interface().mark_scene_as_unsaved()
	set_dock_status("Placed %s at %s." % [piece.id, cell])

func _erase_structure_at_canvas(event: InputEvent, world: WorldModule) -> void:
	var cell := _canvas_mouse_to_cell(world, event)
	if world.remove_structure_piece_at(cell):
		get_editor_interface().mark_scene_as_unsaved()
		set_dock_status("Removed structure at %s." % cell)
	else:
		set_dock_status("No structure at %s." % cell)

func _selected_structure_piece_def() -> StructurePieceDef:
	if _structure_catalog == null:
		return null
	return _structure_catalog.get_piece(selected_structure_piece)

func _edit_height_at_canvas(event: InputEvent, world: WorldModule, delta: int) -> void:
	_apply_height_delta(world, _canvas_mouse_to_cell(world, event), delta)

func _apply_height_delta(world: WorldModule, cell: Vector2i, delta: int) -> void:
	if world.height_field == null:
		set_dock_status("No height data — Generate or Prepare the map first.")
		return
	if not world.height_field.region.has_point(cell):
		set_dock_status("Height at %s is outside the map region." % cell)
		return
	world.height_field.add_height(cell, delta)
	_sync_session_to_scene_root(world)
	get_editor_interface().mark_scene_as_unsaved()
	_queue_viewport_redraw()
	set_dock_status("Height at %s = %d (z). Use +/- keys if wheel zoom steals input." % [cell, world.height_field.get_height(cell)])

func _bound_world_silent() -> WorldModule:
	if _map_session == null:
		return null
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not _is_world_node(root) or not _is_workspace_root(root):
		return null
	_map_session.bind_edited_root(root as Node2D)
	if _map_session.ground_layer == null or not is_instance_valid(_map_session.ground_layer):
		return null
	_sync_scene_root_to_session(_map_session)
	return _map_session

func _queue_viewport_redraw() -> void:
	var vp := get_editor_interface().get_editor_viewport_2d()
	if vp != null:
		vp.queue_redraw()

func queue_viewport_redraw() -> void:
	_queue_viewport_redraw()
