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
	return main

static func _random_attributes(rng: RandomNumberGenerator) -> AttributeSet:
	var a := AttributeSet.new()
	var lo := AttributesModule.ATTR_DEFAULT - 2
	var hi := AttributesModule.ATTR_DEFAULT + 2
	for attr_name in AttributesModule.ATTR_NAMES:
		a.set(attr_name, rng.randi_range(lo, hi))
	return AttributesModule.clamp_attributes(a)
