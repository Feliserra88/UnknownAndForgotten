extends RefCounted
## Factory for the "field" biome: tile catalog, modifiers and biome definition.
## Internal to world_gen; exposed through the WorldGenModule facade.

const _CATALOG_PATH := "res://assets/world/field_catalog.tres"
const _SPRITE_CATALOG_PATH := "res://assets/world/field_sprite_catalog.tres"
const _TERRAIN_SET_PATH := "res://assets/world/terrains/field_terrain_set.tres"
const _STRUCTURE_CATALOGS := {
	&"dark_medieval_wood": "res://assets/world/structures/dark_medieval_wood/dark_medieval_wood_catalog.tres",
}

static func build_catalog() -> TileCatalog:
	var catalog: TileCatalog = load(_CATALOG_PATH)
	if catalog == null:
		push_error("field_biome: missing catalog at %s" % _CATALOG_PATH)
		return TileCatalog.new()
	return catalog

static func build_sprite_catalog() -> MapSpriteCatalog:
	var catalog: MapSpriteCatalog = load(_SPRITE_CATALOG_PATH)
	if catalog == null:
		push_error("field_biome: missing sprite catalog at %s" % _SPRITE_CATALOG_PATH)
		return MapSpriteCatalog.new()
	return catalog

static func build_terrain_sets() -> Array:
	var terrain_set: TerrainSetDef = load(_TERRAIN_SET_PATH)
	if terrain_set == null:
		return []
	return [terrain_set]

static func build_structure_catalog(kit_id: StringName) -> StructureCatalog:
	var path: String = _STRUCTURE_CATALOGS.get(kit_id, "")
	if path.is_empty():
		push_error("field_biome: unknown structure kit %s" % kit_id)
		return StructureCatalog.new()
	var catalog: StructureCatalog = load(path)
	if catalog == null:
		push_error("field_biome: missing structure catalog at %s" % path)
		return StructureCatalog.new()
	return catalog

static func build_modifiers() -> Array[TileModifierDef]:
	return [_wet(), _snowy(), _burning()]

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
	b.terrain_regions = [_water_region(), _path_region()]
	b.scatter_props = [&"oak_tree", &"large_rock", &"field_bush"]
	b.scatter_prop_chance = 0.028
	b.scatter_decor = [&"scatter_pebble", &"wildflower", &"grass_tuft"]
	b.scatter_decor_chance = 0.075
	b.scatter_tiles = [&"rock_wall"]
	b.scatter_chance = 0.015
	b.scatter_modifiers = []
	b.scatter_modifier_chance = 0.0
	return b

static func _water_region() -> TerrainRegionDef:
	var r := TerrainRegionDef.new()
	r.id = &"water"
	r.terrain_set_id = &"field"
	r.terrain_name = &"water"
	r.placement_kind = TerrainRegionDef.PlacementKind.BLOB
	r.body_count = 2
	var rule := TilePlacementRule.new()
	rule.forbid_isolated = true
	rule.min_cluster_size = 6
	rule.max_cluster_size = 24
	rule.roundness_min = 0.55
	r.placement_rule = rule
	return r

static func _path_region() -> TerrainRegionDef:
	var r := TerrainRegionDef.new()
	r.id = &"path"
	r.terrain_set_id = &"field"
	r.terrain_name = &"dirt_path"
	r.placement_kind = TerrainRegionDef.PlacementKind.PATH
	r.path_count = 1
	var rule := TilePlacementRule.new()
	rule.is_linear = true
	rule.min_collinear_neighbors = 2
	r.placement_rule = rule
	return r

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
