extends RefCounted
## Builds the placeholder NPC archetype chain (npc -> humanoid -> human) and a randomized
## main-character archetype. Internal to the npc module; exposed via the NpcModule facade.

const _NPC_SCENE := preload("res://scenes/npc/npc_base.tscn")

## Builds the archetype chain and returns the leaf "human" archetype (parents wired in).
static func build_chain() -> NpcArchetype:
	var root := NpcArchetype.new()
	root.id = &"npc"
	root.display_name_key = "archetype.npc.name"

	var humanoid := NpcArchetype.new()
	humanoid.id = &"humanoid"
	humanoid.parent = root
	humanoid.display_name_key = "archetype.humanoid.name"
	humanoid.scene = _NPC_SCENE
	humanoid.body_part_map = BodyPartMap.humanoid()
	humanoid.base_attributes = AttributeSet.new()
	humanoid.base_vitals = VitalsTemplate.new()
	humanoid.part_visuals = _default_visuals()

	var human := NpcArchetype.new()
	human.id = &"human"
	human.parent = humanoid
	human.display_name_key = "archetype.human.name"
	return human

## Builds a randomized main-character archetype derived from "human" using [param gen_seed].
static func build_random_main_character(gen_seed: int) -> NpcArchetype:
	var rng := RandomNumberGenerator.new()
	rng.seed = gen_seed
	var main := NpcArchetype.new()
	main.id = &"main_character"
	main.parent = build_chain()
	main.display_name_key = "npc.main_character.name"
	main.base_attributes = _random_attributes(rng)
	main.part_visuals = _random_visuals(rng)
	return main

static func _default_visuals() -> Array[PartVisualDef]:
	return [
		_visual(&"body", Color(0.40, 0.45, 0.65), Vector2i(20, 28), Vector2(0, 0), 0),
		_visual(&"head", Color(0.86, 0.70, 0.56), Vector2i(16, 16), Vector2(0, -22), 2),
		_visual(&"arm_left", Color(0.40, 0.45, 0.65), Vector2i(6, 20), Vector2(-13, -2), 1),
		_visual(&"arm_right", Color(0.40, 0.45, 0.65), Vector2i(6, 20), Vector2(13, -2), 1),
		_visual(&"leg_left", Color(0.28, 0.28, 0.34), Vector2i(7, 18), Vector2(-6, 22), 0),
		_visual(&"leg_right", Color(0.28, 0.28, 0.34), Vector2i(7, 18), Vector2(6, 22), 0),
	]

static func _random_visuals(rng: RandomNumberGenerator) -> Array[PartVisualDef]:
	var skin := _random_skin(rng)
	var shirt := _random_color(rng, 0.3, 0.8)
	var pants := _random_color(rng, 0.15, 0.5)
	return [
		_visual(&"body", shirt, Vector2i(20, 28), Vector2(0, 0), 0),
		_visual(&"head", skin, Vector2i(16, 16), Vector2(0, -22), 2),
		_visual(&"arm_left", shirt, Vector2i(6, 20), Vector2(-13, -2), 1),
		_visual(&"arm_right", shirt, Vector2i(6, 20), Vector2(13, -2), 1),
		_visual(&"leg_left", pants, Vector2i(7, 18), Vector2(-6, 22), 0),
		_visual(&"leg_right", pants, Vector2i(7, 18), Vector2(6, 22), 0),
	]

static func _random_attributes(rng: RandomNumberGenerator) -> AttributeSet:
	var a := AttributeSet.new()
	a.strength = rng.randi_range(3, 9)
	a.agility = rng.randi_range(3, 9)
	a.willpower = rng.randi_range(3, 9)
	a.vitality = rng.randi_range(3, 9)
	a.perception = rng.randi_range(3, 9)
	a.charisma = rng.randi_range(3, 9)
	return a

static func _visual(part: StringName, color: Color, size: Vector2i, offset: Vector2, z: int) -> PartVisualDef:
	var v := PartVisualDef.new()
	v.part_id = part
	v.placeholder_color = color
	v.size = size
	v.offset = offset
	v.z_index = z
	return v

static func _random_skin(rng: RandomNumberGenerator) -> Color:
	var tones := [Color(0.96, 0.80, 0.66), Color(0.86, 0.66, 0.50), Color(0.66, 0.48, 0.34), Color(0.45, 0.32, 0.24)]
	return tones[rng.randi_range(0, tones.size() - 1)]

static func _random_color(rng: RandomNumberGenerator, lo: float, hi: float) -> Color:
	return Color(rng.randf_range(lo, hi), rng.randf_range(lo, hi), rng.randf_range(lo, hi))
