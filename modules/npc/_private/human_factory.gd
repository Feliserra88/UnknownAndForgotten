extends RefCounted
## Builds the placeholder NPC archetype chain (npc -> humanoid -> human) and a randomized
## main-character archetype. Internal to the npc module; exposed via the NpcModule facade.

const _NPC_SCENE := preload("res://scenes/npc/npc_base.tscn")
const _MALE_SPRITE_ANIM := preload("res://assets/visuals/characters/human/male/human_male_sprite_anim.tres")

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
	main.sprite_anim = build_male_sprite_anim()
	return main

## Builds the male human sprite set (idle 8-way + walk sheets at 64×64).
static func build_male_sprite_anim() -> Resource:
	var def: Resource = _MALE_SPRITE_ANIM.duplicate(true)
	def.walk_fps = float(Config.get_int("NPC_WALK_FPS", 8))
	def.feet_anchor = Vector2(0.5, Config.get_float("NPC_FEET_ANCHOR_Y", 0.8))
	var frame := Config.get_int("NPC_SPRITE_FRAME_SIZE", 64)
	def.frame_size = Vector2i(frame, frame)
	return def

static func _default_visuals() -> Array[PartVisualDef]:
	return [
		_visual(&"body", Color(0.40, 0.45, 0.65), Vector2i(20, 28), Vector2(0, 0), 0),
		_visual(&"head", Color(0.86, 0.70, 0.56), Vector2i(16, 16), Vector2(0, -22), 2),
		_visual(&"arm_left", Color(0.40, 0.45, 0.65), Vector2i(6, 20), Vector2(-13, -2), 1),
		_visual(&"arm_right", Color(0.40, 0.45, 0.65), Vector2i(6, 20), Vector2(13, -2), 1),
		_visual(&"leg_left", Color(0.28, 0.28, 0.34), Vector2i(7, 18), Vector2(-6, 22), 0),
		_visual(&"leg_right", Color(0.28, 0.28, 0.34), Vector2i(7, 18), Vector2(6, 22), 0),
	]

static func _random_attributes(rng: RandomNumberGenerator) -> AttributeSet:
	var a := AttributeSet.new()
	var lo := AttributesModule.ATTR_DEFAULT - 2
	var hi := AttributesModule.ATTR_DEFAULT + 2
	for attr_name in AttributesModule.ATTR_NAMES:
		a.set(attr_name, rng.randi_range(lo, hi))
	return AttributesModule.clamp_attributes(a)

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
