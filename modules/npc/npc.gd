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

## Ensures [param archetype] has a walk sprite sheet when missing (prototype fallback).
func ensure_walk_sprite(archetype: NpcArchetype) -> NpcArchetype:
	if archetype == null:
		return null
	if archetype.resolve_sprite_anim() == null:
		archetype.sprite_anim = _Human.build_male_sprite_anim()
	var def := archetype.resolve_sprite_anim()
	if def != null and _sprite_has_textures(def):
		# Cutout overrides would show through if the sheet fails to load.
		archetype.part_visuals.clear()
	return archetype

static func _sprite_has_textures(def: Resource) -> bool:
	return (
		def.get("idle_texture") != null
		or def.get("walk_right_texture") != null
		or def.get("walk_left_texture") != null
	)

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
