extends RefCounted
## Factory for the "field" biome: tile catalog, modifiers and biome definition.
## Internal to world_gen; exposed through the WorldGenModule facade.

const _CATALOG_PATH := "res://assets/world/field_catalog.tres"

## Loads the field tile catalog from assets (grass, path, water, wall, bush, door, …).
static func build_catalog() -> TileCatalog:
	var catalog: TileCatalog = load(_CATALOG_PATH)
	if catalog == null:
		push_error("field_biome: missing catalog at %s" % _CATALOG_PATH)
		return TileCatalog.new()
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
