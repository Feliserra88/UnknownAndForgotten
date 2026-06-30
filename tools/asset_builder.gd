extends Node
## One-shot builder that materializes the reusable placeholder assets as .tres files so designers
## can reuse and fine-tune them. Run via the editor/MCP (run_project scene=res://tools/asset_builder.tscn).

const _LOG := "WGN"

const _DIRS := [
	"res://assets/world/tiles",
	"res://assets/world/modifiers",
	"res://assets/world/biomes",
	"res://assets/world/presets",
	"res://assets/data/archetypes",
	"res://assets/visuals/parts",
	"res://assets/visuals/characters/human/male",
]

func _ready() -> void:
	for dir in _DIRS:
		DirAccess.make_dir_recursive_absolute(dir)
	_build_world_assets()
	_build_npc_assets()
	print("ASSET_BUILDER_DONE")
	get_tree().quit()

func _build_world_assets() -> void:
	var world_gen := WorldGenModule.new()
	var catalog := world_gen.build_field_catalog()
	for tile in catalog.tiles:
		_save(tile, "res://assets/world/tiles/%s.tres" % tile.id)
	_save(catalog, "res://assets/world/field_catalog.tres")
	var modifiers := world_gen.build_field_modifiers()
	for m in modifiers:
		_save(m, "res://assets/world/modifiers/%s.tres" % m.id)
	var biome := world_gen.build_field_biome()
	_save(biome, "res://assets/world/biomes/field.tres")
	var request := world_gen.build_field_request(Rect2i(0, 0, 28, 28), Config.get_int("WORLD_GEN_DEFAULT_SEED", 1337))
	request.biome = biome
	_save(request, "res://assets/world/presets/field_default.tres")
	world_gen.free()

func _build_npc_assets() -> void:
	var npc := NpcModule.new()
	var main := npc.build_random_character(Config.get_int("WORLD_GEN_DEFAULT_SEED", 1337))
	var human: NpcArchetype = main.parent
	var humanoid: NpcArchetype = human.parent
	var root: NpcArchetype = humanoid.parent
	_save(root, "res://assets/data/archetypes/npc_root.tres")
	_save(humanoid, "res://assets/data/archetypes/humanoid.tres")
	_save(human, "res://assets/data/archetypes/human.tres")
	var i := 0
	for visual in main.part_visuals:
		_save(visual, "res://assets/visuals/parts/main_%s.tres" % visual.part_id)
		i += 1
	if main.sprite_anim != null:
		_save(main.sprite_anim, "res://assets/visuals/characters/human/male/human_male_sprite_anim.tres")
		main.sprite_anim = load("res://assets/visuals/characters/human/male/human_male_sprite_anim.tres")
	main.part_visuals.clear()
	_save(main, "res://assets/data/archetypes/main_character.tres")
	npc.free()

func _save(resource: Resource, path: String) -> void:
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		Log.warn(_LOG, "failed saving %s err=%d" % [path, err])
		return
	# Adopt the path so later saves reference this resource externally instead of embedding it.
	resource.take_over_path(path)
	Log.info(_LOG, "save", path)
