class_name NpcModule
extends Node
## Public facade for NPC creation (see docs/GAME_DESIGN.md section 5.6). Resolves the archetype
## scene, builds runtime instance data and returns a ready-to-add NpcBody node.

const _LOG := "NPC"
const _DEFAULT_SCENE := preload("res://scenes/npc/npc_base.tscn")
const _Human := preload("res://modules/npc/_private/human_factory.gd")

## Builds the placeholder archetype chain and returns the "human" leaf archetype.
func build_human_archetype() -> NpcArchetype:
	return _Human.build_chain()

## Builds a randomized main-character archetype derived from "human" using [param gen_seed].
func build_random_character(gen_seed: int) -> NpcArchetype:
	return _Human.build_random_main_character(gen_seed)

## Spawns an NPC from [param archetype] at logical [param cell]. Returns the body node (not yet
## added to the tree) or null on failure. [param _world] is reserved for placement helpers.
func spawn(archetype: NpcArchetype, cell: Vector3i, _world: WorldModule = null) -> Node2D:
	if archetype == null:
		Log.warn(_LOG, "spawn: null archetype")
		return null
	var scene := archetype.resolve_scene()
	if scene == null:
		scene = _DEFAULT_SCENE
	var body := scene.instantiate()
	var instance := NpcInstanceData.new()
	instance.apply_archetype(archetype)
	instance.grid_cell = cell
	if body.has_method("initialize"):
		body.initialize(instance, archetype)
	body.add_to_group(&"npc")
	for fid in instance.faction_ids:
		body.add_to_group(StringName("faction_%s" % fid))
	return body
