extends Node
## Runtime test driver: generates a field map into the parent WorldModule and frames the camera.
## Skipped in the editor so the uf_map_editor controls the map instead.

const _LOG := "WGN"
const _MAIN_CHARACTER_PATH := "res://assets/data/archetypes/main_character.tres"

@export var map_size: Vector2i = Vector2i(28, 28)
## When set, spawns this archetype as the main character on a walkable cell. When left empty the
## demo loads the saved main_character.tres asset, or builds a random one as a fallback.
@export var main_character: NpcArchetype

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var world := get_parent() as WorldModule
	if world == null:
		Log.err(_LOG, "world_demo: parent is not a WorldModule")
		return
	var world_gen := WorldGenModule.new()
	add_child(world_gen)
	var catalog := world_gen.build_field_catalog()
	var modifiers := world_gen.build_field_modifiers()
	var sprites := world_gen.build_field_sprite_catalog()
	var terrains := world_gen.build_field_terrain_sets()
	var region := Rect2i(Vector2i.ZERO, map_size)
	world.configure(catalog, modifiers, region, null, {}, sprites, terrains)
	var gen_seed := Config.get_int("WORLD_GEN_DEFAULT_SEED", 1337)
	var request := world_gen.build_field_request(region, gen_seed)
	world_gen.generate(request, world)
	if world.ground_layer != null:
		world.ground_layer.update_internals()
	var spawn_cell := _find_walkable(world, region)
	call_deferred("_finish_demo_setup", world, spawn_cell)

func _finish_demo_setup(world: WorldModule, spawn_cell: Vector2i) -> void:
	_frame_camera(world, spawn_cell)
	_spawn_main_character(world, spawn_cell)

func _spawn_main_character(world: WorldModule, cell: Vector2i) -> void:
	var npc := NpcModule.new()
	add_child(npc)
	var archetype := _resolve_main_character(npc)
	if archetype == null:
		return
	var body := npc.spawn(archetype, world.cell3(cell), world)
	if body != null:
		var actor_parent := world.get_actor_parent()
		actor_parent.add_child(body)
		world.apply_actor_y_sort(body)
		body.global_position = world.grid_to_world(world.cell3(cell))
		_attach_player_controller(body)
		world.sync_actor_display_rotations()
		Log.info(_LOG, "spawn_player", "cell=%s pos=%s" % [cell, body.global_position])

func _attach_player_controller(body: Node2D) -> void:
	body.add_to_group(&"player")
	var ctrl: Node = load("res://scenes/world/main_character_controller.gd").new()
	body.add_child(ctrl)
	if body is NpcBody:
		var npc_body := body as NpcBody
		if npc_body.instance != null:
			npc_body.instance.orientation = &"front"
		var appearance := body.get_node_or_null("MotionPivot/Appearance") as NpcAppearanceController
		if appearance != null:
			appearance.set_orientation(&"front")

func _resolve_main_character(npc: NpcModule) -> NpcArchetype:
	var archetype: NpcArchetype = null
	if main_character != null:
		archetype = main_character
	elif ResourceLoader.exists(_MAIN_CHARACTER_PATH):
		archetype = load(_MAIN_CHARACTER_PATH)
	else:
		archetype = npc.build_random_character(Config.get_int("WORLD_GEN_DEFAULT_SEED", 1337))
	return npc.ensure_walk_sprite(archetype)

func _frame_camera(world: WorldModule, cell: Vector2i) -> void:
	var cam := world.get_node_or_null("CameraRig") as CameraRig
	if cam != null:
		cam.focus_on(world.grid_to_world(world.cell3(cell)))

func _find_walkable(world: WorldModule, region: Rect2i) -> Vector2i:
	var center := region.get_center()
	for radius in range(0, maxi(region.size.x, region.size.y)):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var c := center + Vector2i(x, y)
				var def := world.get_tile_def_at(c)
				if def != null and def.has_tag(TileTags.Tag.WALKABLE):
					return c
	return center
