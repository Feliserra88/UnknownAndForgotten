@tool
extends EditorPlugin
## Map editor plugin: drives the world / world_gen public API to generate, paint and save field
## maps. Painting is forwarded onto the selected WorldModule node in the 2D canvas.

const _DockScript := preload("res://addons/uf_map_editor/dock.gd")

enum Mode { PAINT_TILE, EDIT_HEIGHT }

var _dock: Control
var _world: WorldModule
var _world_gen: WorldGenModule

var paint_enabled: bool = false
var mode: int = Mode.PAINT_TILE
var selected_tile: StringName = &"grass"
var selected_layer: int = 0

func _enter_tree() -> void:
	_world_gen = WorldGenModule.new()
	add_child(_world_gen)
	_dock = _DockScript.new()
	_dock.name = "UF Map"
	_dock.setup(self)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
	if _world_gen != null:
		_world_gen.queue_free()

func _handles(object: Object) -> bool:
	return object is WorldModule

func _edit(object: Object) -> void:
	_world = object as WorldModule

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _world == null or not paint_enabled:
		return false
	if mode == Mode.PAINT_TILE:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_paint_at_mouse()
			return true
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_paint_at_mouse()
			return true
	elif mode == Mode.EDIT_HEIGHT and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_edit_height_at_mouse(1)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_edit_height_at_mouse(-1)
			return true
	return false

## Configures the selected world with the field catalog over [param region] without generating.
func prepare(region: Rect2i) -> void:
	if _world == null:
		_status("Select the WorldRoot node first.")
		return
	_world.configure(_world_gen.build_field_catalog(), _world_gen.build_field_modifiers(), region)
	_status("Prepared blank %dx%d map." % [region.size.x, region.size.y])

## Configures and procedurally generates a field map into the selected world.
func generate(region: Rect2i, gen_seed: int, water_count: int, path_count: int) -> void:
	if _world == null:
		_status("Select the WorldRoot node first.")
		return
	_world.configure(_world_gen.build_field_catalog(), _world_gen.build_field_modifiers(), region)
	var request := _world_gen.build_field_request(region, gen_seed)
	request.water_body_count = water_count
	request.path_count = path_count
	var report := _world_gen.generate(request, _world)
	_status("Generated seed=%d walkable=%s." % [gen_seed, report.get("walkable", 0)])

## Saves a reusable generation preset (.tres) at [param path].
func save_preset(path: String, region: Rect2i, gen_seed: int, water_count: int, path_count: int) -> void:
	var request := _world_gen.build_field_request(region, gen_seed)
	request.biome = _world_gen.build_field_biome()
	request.water_body_count = water_count
	request.path_count = path_count
	var err := ResourceSaver.save(request, path)
	_status("Preset saved: %s" % path if err == OK else "Preset save failed (%d)." % err)

## Loads a generation preset (.tres) and returns it, or null on failure.
func load_preset(path: String) -> WorldGenRequest:
	if not ResourceLoader.exists(path):
		_status("Preset not found: %s" % path)
		return null
	_status("Preset loaded: %s" % path)
	return load(path) as WorldGenRequest

## Saves the current height field and the edited scene as reusable assets.
func save_map(map_name: String) -> void:
	if _world == null or _world.height_field == null:
		_status("Nothing to save: prepare or generate first.")
		return
	var height_path := "res://assets/world/%s_height.tres" % map_name
	DirAccess.make_dir_recursive_absolute("res://assets/world")
	var err := ResourceSaver.save(_world.height_field, height_path)
	EditorInterface.save_scene()
	_status("Saved %s and scene." % height_path if err == OK else "Height save failed (%d)." % err)

func _paint_at_mouse() -> void:
	var cell := _world.world_to_cell(_world.get_global_mouse_position())
	_world.set_tile(selected_layer, cell, selected_tile)

func _edit_height_at_mouse(delta: int) -> void:
	if _world.height_field == null:
		return
	var cell := _world.world_to_cell(_world.get_global_mouse_position())
	_world.height_field.add_height(cell, delta)
	_status("Height at %s = %d" % [cell, _world.height_field.get_height(cell)])

func _status(text: String) -> void:
	if _dock != null and _dock.has_method("set_status"):
		_dock.set_status(text)
