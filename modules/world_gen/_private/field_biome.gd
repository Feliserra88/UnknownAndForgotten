extends RefCounted
## Factory for the placeholder "field" biome: tile catalog, modifiers and biome definition.
## Internal to world_gen; exposed through the WorldGenModule facade.

## Builds the tile catalog used by the field biome (grass, path, water, wall, bush, door).
static func build_catalog() -> TileCatalog:
	var catalog := TileCatalog.new()
	catalog.tiles = [_grass(), _dirt_path(), _pond_water(), _rock_wall(), _bush(), _open_door()]
	return catalog

## Builds the modifier definitions available in the field biome.
static func build_modifiers() -> Array[TileModifierDef]:
	return [_wet(), _snowy(), _burning()]

## Builds the field biome definition wiring tile ids and feature parameters.
static func build_biome() -> BiomeDef:
	var b := BiomeDef.new()
	b.id = &"field"
	b.display_name_key = "biome.field.name"
	b.ground_tile = &"grass"
	b.z_min = 0
	b.z_max = 2
	b.height_noise_frequency = 0.08
	b.water_tile = &"pond_water"
	b.water_body_count = 2
	b.water_noise_frequency = 0.12
	b.path_tile = &"dirt_path"
	b.path_count = 1
	b.scatter_tiles = [&"bush", &"rock_wall"]
	b.scatter_chance = 0.04
	return b

static func _grass() -> TileDef:
	var t := TileDef.new()
	t.id = &"grass"
	t.display_name_key = "tile.grass.name"
	t.tags = TileTags.Tag.GROUND | TileTags.Tag.WALKABLE
	t.placeholder_color = Color(0.45, 0.72, 0.36)
	return t

static func _dirt_path() -> TileDef:
	var t := TileDef.new()
	t.id = &"dirt_path"
	t.display_name_key = "tile.dirt_path.name"
	t.tags = TileTags.Tag.GROUND | TileTags.Tag.WALKABLE
	t.placeholder_color = Color(0.62, 0.47, 0.30)
	var rule := TilePlacementRule.new()
	rule.is_linear = true
	rule.min_collinear_neighbors = 2
	t.placement_rule = rule
	return t

static func _pond_water() -> TileDef:
	var t := TileDef.new()
	t.id = &"pond_water"
	t.display_name_key = "tile.pond_water.name"
	t.tags = TileTags.Tag.WATER
	t.placeholder_color = Color(0.27, 0.49, 0.78)
	var rule := TilePlacementRule.new()
	rule.forbid_isolated = true
	rule.min_cluster_size = 6
	rule.max_cluster_size = 24
	rule.roundness_min = 0.55
	t.placement_rule = rule
	return t

static func _rock_wall() -> TileDef:
	var t := TileDef.new()
	t.id = &"rock_wall"
	t.display_name_key = "tile.rock_wall.name"
	t.tags = TileTags.Tag.WALL | TileTags.Tag.VISION_BLOCKER
	t.placeholder_color = Color(0.55, 0.55, 0.58)
	return t

static func _bush() -> TileDef:
	var t := TileDef.new()
	t.id = &"bush"
	t.display_name_key = "tile.bush.name"
	t.tags = TileTags.Tag.WALKABLE | TileTags.Tag.COVER | TileTags.Tag.VISION_BLOCKER
	t.placeholder_color = Color(0.24, 0.45, 0.25)
	return t

static func _open_door() -> TileDef:
	var t := TileDef.new()
	t.id = &"open_door"
	t.display_name_key = "tile.open_door.name"
	t.tags = TileTags.Tag.WALKABLE | TileTags.Tag.INTERACTABLE
	var rules := TileSideRules.new()
	# Passable north/south, blocked (and vision-blocking) east/west.
	rules.passable = [true, false, true, false]
	rules.blocks_vision = [false, true, false, true]
	t.side_rules = rules
	t.placeholder_color = Color(0.78, 0.66, 0.42)
	return t

static func _wet() -> TileModifierDef:
	var m := TileModifierDef.new()
	m.id = &"wet"
	m.display_name_key = "modifier.wet.name"
	m.overlay_color = Color(0.30, 0.55, 0.95, 0.40)
	m.movement_cost_mult = 1.2
	return m

static func _snowy() -> TileModifierDef:
	var m := TileModifierDef.new()
	m.id = &"snowy"
	m.display_name_key = "modifier.snowy.name"
	m.overlay_color = Color(0.95, 0.97, 1.0, 0.55)
	m.movement_cost_mult = 1.5
	return m

static func _burning() -> TileModifierDef:
	var m := TileModifierDef.new()
	m.id = &"burning"
	m.display_name_key = "modifier.burning.name"
	m.overlay_color = Color(0.95, 0.40, 0.15, 0.55)
	m.adds_tags = TileTags.Tag.HAZARD
	m.permanent = false
	return m
