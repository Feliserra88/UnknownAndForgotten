extends Node
## Starts the session: loads the initial map (baked or procedural), spawns the player once,
## and repositions the player when GameSession.change_map is called.

const _LOG := "GSN"
const _MAIN_CHARACTER_PATH := "res://assets/data/archetypes/main_character.tres"

@export_file("*.tscn") var start_map_path: String = ""
@export var procedural_if_missing: bool = true
@export var map_size: Vector2i = Vector2i(28, 28)
@export var main_character: NpcArchetype

var _session: Node
var _world: WorldModule
var _world_gen: WorldGenModule
var _player: NpcBody
var _npc: NpcModule

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_session = get_parent()
	if _session == null or not _session.has_method(&"get_world"):
		Log.err(_LOG, "bootstrap: parent is not GameSession")
		return
	_world = _session.call(&"get_world") as WorldModule
	if _world == null:
		Log.err(_LOG, "bootstrap: missing WorldHost")
		return
	_world_gen = WorldGenModule.new()
	add_child(_world_gen)
	var spawn_cell := _load_initial_map()
	if spawn_cell == Vector2i(-999999, -999999):
		Log.err(_LOG, "bootstrap: no map loaded")
		return
	call_deferred("_finish_setup", spawn_cell)

func on_map_loaded(spawn_cell: Vector2i) -> void:
	_sync_runtime_catalogs()
	if _world.ground_layer != null:
		_world.ground_layer.update_internals()
	var cell := spawn_cell
	if cell == Vector2i(-999999, -999999):
		cell = _default_spawn_cell()
	_place_player(cell)
	_frame_camera(cell)

func _load_initial_map() -> Vector2i:
	var map_path := _resolve_start_map_path()
	if not map_path.is_empty() and _world.load_baked_map(map_path):
		_sync_runtime_catalogs()
		return _default_spawn_cell()
	if not procedural_if_missing:
		return Vector2i(-999999, -999999)
	_generate_procedural_map()
	return _find_walkable(Rect2i(Vector2i.ZERO, map_size))

func _finish_setup(spawn_cell: Vector2i) -> void:
	_ensure_player(spawn_cell)
	_frame_camera(spawn_cell)

func _generate_procedural_map() -> void:
	var catalog := _world_gen.build_field_catalog()
	var modifiers := _world_gen.build_field_modifiers()
	var sprites := _world_gen.build_field_sprite_catalog()
	var terrains := _world_gen.build_field_terrain_sets()
	var structures := _world_gen.build_dark_medieval_wood_catalog()
	var region := Rect2i(Vector2i.ZERO, map_size)
	_world.configure(catalog, modifiers, region, null, {}, sprites, terrains, structures)
	var gen_seed := Config.get_int("WORLD_GEN_DEFAULT_SEED", 1337)
	var request := _world_gen.build_field_request(region, gen_seed)
	_world_gen.generate(request, _world)
	if _world.ground_layer != null:
		_world.ground_layer.update_internals()

func _sync_runtime_catalogs() -> void:
	if _world_gen == null:
		return
	_world.tile_catalog = _world_gen.build_field_catalog()
	_world.register_structure_catalog(_world_gen.build_dark_medieval_wood_catalog())
	_world.refresh_tilesets(_world.tile_catalog, _world_gen.build_field_modifiers())

func _resolve_start_map_path() -> String:
	if not start_map_path.is_empty() and ResourceLoader.exists(start_map_path):
		return start_map_path
	var configured := Config.get_string("GAME_START_MAP_PATH", "")
	if not configured.is_empty() and ResourceLoader.exists(configured):
		return configured
	for path in WorldModule.list_baked_map_paths():
		if path.begins_with(WorldModule.LOCAL_MAPS_DIR):
			return path
	for path in WorldModule.list_baked_map_paths():
		if path.begins_with(WorldModule.ASSETS_MAPS_DIR):
			return path
	return ""

func _ensure_player(cell: Vector2i) -> void:
	if _player != null and is_instance_valid(_player):
		_place_player(cell)
		return
	if _npc == null:
		_npc = NpcModule.new()
		add_child(_npc)
	var archetype := _resolve_main_character()
	if archetype == null:
		return
	var body := _npc.spawn(archetype, _world.cell3(cell), _world)
	if body == null or not (body is NpcBody):
		return
	_player = body as NpcBody
	_attach_player_controller(_player)
	_place_player(cell)
	Log.info(_LOG, "spawn_player", "cell=%s" % cell)

func _place_player(cell: Vector2i) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var actors := _world.get_actor_parent()
	if _player.get_parent() != actors:
		if _player.get_parent() != null:
			_player.get_parent().remove_child(_player)
		actors.add_child(_player)
	_world.apply_actor_y_sort(_player)
	if _player.instance != null:
		_player.instance.grid_cell = _world.cell3(cell)
	_player.global_position = _world.grid_to_world(_world.cell3(cell))
	_world.sync_actor_display_rotations()

func _attach_player_controller(body: NpcBody) -> void:
	body.add_to_group(&"player")
	if body.get_node_or_null("PlayerController") != null:
		return
	var ctrl: Node = load("res://scenes/game/player_controller.gd").new()
	ctrl.name = "PlayerController"
	body.add_child(ctrl)
	if body.instance != null:
		body.instance.orientation = &"front"
	var appearance := body.get_node_or_null("MotionPivot/Appearance") as NpcAppearanceController
	if appearance != null:
		appearance.set_orientation(&"front")

func _resolve_main_character() -> NpcArchetype:
	var archetype: NpcArchetype = null
	if main_character != null:
		archetype = main_character
	elif ResourceLoader.exists(_MAIN_CHARACTER_PATH):
		archetype = load(_MAIN_CHARACTER_PATH)
	else:
		archetype = _npc.build_random_character(Config.get_int("WORLD_GEN_DEFAULT_SEED", 1337))
	return _npc.ensure_walk_sprite(archetype)

func _frame_camera(cell: Vector2i) -> void:
	var cam := _world.get_node_or_null("CameraRig") as CameraRig
	if cam != null:
		cam.focus_on(_world.grid_to_world(_world.cell3(cell)))

func _default_spawn_cell() -> Vector2i:
	if _world.height_field != null:
		return _find_walkable(_world.height_field.region)
	return _find_walkable(Rect2i(Vector2i.ZERO, map_size))

func _find_walkable(region: Rect2i) -> Vector2i:
	var center := region.get_center()
	for radius in range(0, maxi(region.size.x, region.size.y)):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var c := center + Vector2i(x, y)
				if not region.has_point(c):
					continue
				var def := _world.get_tile_def_at(c)
				if def != null and def.has_tag(TileTags.Tag.WALKABLE):
					return c
	return center
