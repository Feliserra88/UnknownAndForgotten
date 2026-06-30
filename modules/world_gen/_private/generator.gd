extends RefCounted
## Procedural generator for the field biome. Internal to world_gen; call via the facade.
## Writes only through the WorldModule public API and validates placement constraints.

const _LOG := "WGN"

## Generates the map described by [param request] into [param world]; returns a report dict.
static func generate(request: WorldGenRequest, world: WorldModule) -> Dictionary:
	var biome := request.biome
	var region := request.area
	var rng := RandomNumberGenerator.new()
	rng.seed = request.gen_seed
	_generate_height(biome, world, region)
	_fill_ground(biome, world, region)
	var water_cells := _place_water(biome, world, region, request, rng)
	var path_cells := _place_paths(biome, world, region, request, rng)
	_scatter(biome, world, region, rng, water_cells, path_cells)
	_apply_modifiers(world, region, water_cells, rng)
	_validate_water(world, biome, water_cells)
	_validate_paths(world, biome, path_cells)
	var walkable := _count_walkable(world, region)
	Log.info(_LOG, "gen", "seed=%d water=%d path=%d walkable=%d" % [request.gen_seed, water_cells.size(), path_cells.size(), walkable])
	return {"water": water_cells, "paths": path_cells, "walkable": walkable}

static func _generate_height(biome: BiomeDef, world: WorldModule, region: Rect2i) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = biome.id.hash()
	noise.frequency = biome.height_noise_frequency
	var span := maxi(biome.z_max - biome.z_min, 0)
	for x in region.size.x:
		for y in region.size.y:
			var cell := region.position + Vector2i(x, y)
			var n := (noise.get_noise_2d(cell.x, cell.y) + 1.0) * 0.5
			world.set_height(cell, biome.z_min + int(round(n * span)))

static func _fill_ground(biome: BiomeDef, world: WorldModule, region: Rect2i) -> void:
	for x in region.size.x:
		for y in region.size.y:
			world.set_tile(WorldModule.Layer.GROUND, region.position + Vector2i(x, y), biome.ground_tile)

static func _place_water(biome: BiomeDef, world: WorldModule, region: Rect2i, request: WorldGenRequest, rng: RandomNumberGenerator) -> Array:
	var placed: Array[Vector2i] = []
	var tile := world.tile_catalog.get_tile(biome.water_tile)
	if tile == null:
		return placed
	var rule := tile.placement_rule
	var min_size := rule.min_cluster_size if rule != null else 1
	var max_size := rule.max_cluster_size if rule != null and rule.max_cluster_size > 0 else min_size + 8
	for i in request.effective_water_body_count():
		var target := rng.randi_range(maxi(min_size, 1), maxi(max_size, min_size + 1))
		var body := _grow_round_blob(region, target, rng)
		if body.size() < min_size:
			continue
		for c in body:
			world.set_tile(WorldModule.Layer.TERRAIN, c, biome.water_tile)
			placed.append(c)
	return placed

## Grows a rounded, contiguous blob of about [param target] cells centred randomly in [param region].
static func _grow_round_blob(region: Rect2i, target: int, rng: RandomNumberGenerator) -> Array:
	var margin := 2
	var cx := rng.randi_range(region.position.x + margin, region.position.x + region.size.x - 1 - margin)
	var cy := rng.randi_range(region.position.y + margin, region.position.y + region.size.y - 1 - margin)
	var center := Vector2(cx, cy)
	var radius := sqrt(float(target) / PI) + 1.0
	var reach := int(ceil(radius)) + 1
	var cells: Array[Vector2i] = []
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var c := Vector2i(cx + dx, cy + dy)
			if region.has_point(c) and Vector2(c).distance_to(center) <= radius:
				cells.append(c)
	cells.sort_custom(func(a, b): return Vector2(a).distance_to(center) < Vector2(b).distance_to(center))
	return cells.slice(0, mini(target, cells.size()))

static func _place_paths(biome: BiomeDef, world: WorldModule, region: Rect2i, request: WorldGenRequest, rng: RandomNumberGenerator) -> Array:
	var placed: Array[Vector2i] = []
	var tile := world.tile_catalog.get_tile(biome.path_tile)
	if tile == null:
		return placed
	for i in request.effective_path_count():
		var cy := rng.randi_range(region.position.y + 2, region.position.y + region.size.y - 3)
		var path: Array[Vector2i] = []
		for x in region.size.x:
			var cx := region.position.x + x
			path.append(Vector2i(cx, cy))
			if rng.randf() < 0.2:
				var ny := clampi(cy + (1 if rng.randf() < 0.5 else -1), region.position.y + 1, region.position.y + region.size.y - 2)
				if ny != cy:
					# vertical connector at the same column keeps the line continuous
					path.append(Vector2i(cx, ny))
					cy = ny
		for c in path:
			world.set_tile(WorldModule.Layer.TERRAIN, c, biome.path_tile)
			placed.append(c)
	return placed

static func _scatter(biome: BiomeDef, world: WorldModule, region: Rect2i, rng: RandomNumberGenerator, water_cells: Array, path_cells: Array) -> void:
	if biome.scatter_tiles.is_empty():
		return
	var occupied := {}
	for c in water_cells:
		occupied[c] = true
	for c in path_cells:
		occupied[c] = true
	for x in region.size.x:
		for y in region.size.y:
			var c := region.position + Vector2i(x, y)
			if occupied.has(c):
				continue
			if rng.randf() < biome.scatter_chance:
				var id: StringName = biome.scatter_tiles[rng.randi_range(0, biome.scatter_tiles.size() - 1)]
				world.set_tile(WorldModule.Layer.OBJECTS, c, id)

static func _apply_modifiers(world: WorldModule, region: Rect2i, water_cells: Array, rng: RandomNumberGenerator) -> void:
	var wet := world.get_modifier_def(&"wet")
	var burning := world.get_modifier_def(&"burning")
	if wet != null:
		var water_set := {}
		for c in water_cells:
			water_set[c] = true
		for c in water_cells:
			for dir in Direction.all():
				var n: Vector2i = c + Direction.to_vector(dir)
				if region.has_point(n) and not water_set.has(n):
					world.add_modifier(n, wet)
	if burning != null and rng.randf() < 0.6:
		var bc := region.position + Vector2i(rng.randi_range(1, region.size.x - 2), rng.randi_range(1, region.size.y - 2))
		world.add_modifier(bc, burning)

## Flood-fills water clusters and warns when any breaks its placement rule (size/roundness/isolation).
static func _validate_water(world: WorldModule, biome: BiomeDef, water_cells: Array) -> void:
	var tile := world.tile_catalog.get_tile(biome.water_tile)
	if tile == null or tile.placement_rule == null or water_cells.is_empty():
		return
	var rule := tile.placement_rule
	var remaining := {}
	for c in water_cells:
		remaining[c] = true
	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		var cluster := _flood(remaining, start)
		var size := cluster.size()
		if rule.forbid_isolated and size <= 1:
			Log.warn(_LOG, "water cluster isolated at %s" % start)
		if size < rule.min_cluster_size:
			Log.warn(_LOG, "water cluster size=%d below min=%d" % [size, rule.min_cluster_size])
		if rule.max_cluster_size > 0 and size > rule.max_cluster_size:
			Log.warn(_LOG, "water cluster size=%d above max=%d" % [size, rule.max_cluster_size])
		if rule.roundness_min > 0.0 and _roundness(cluster) < rule.roundness_min:
			Log.warn(_LOG, "water cluster roundness below %.2f" % rule.roundness_min)

## Warns about path cells that fail the minimum collinear-neighbour rule (dangling stubs).
static func _validate_paths(world: WorldModule, biome: BiomeDef, path_cells: Array) -> void:
	var tile := world.tile_catalog.get_tile(biome.path_tile)
	if tile == null or tile.placement_rule == null or not tile.placement_rule.is_linear:
		return
	var need := tile.placement_rule.min_collinear_neighbors
	var path_set := {}
	for c in path_cells:
		path_set[c] = true
	var endpoints := 0
	var stubs := 0
	for c in path_set:
		var neighbors := 0
		for dir in Direction.all():
			if path_set.has(c + Direction.to_vector(dir)):
				neighbors += 1
		if neighbors <= 1:
			endpoints += 1
		elif neighbors < need:
			stubs += 1
	if stubs > 0:
		Log.warn(_LOG, "path has %d under-connected cells (need %d neighbours)" % [stubs, need])
	Log.detail(_LOG, "path", "endpoints=%d cells=%d" % [endpoints, path_set.size()])

static func _flood(remaining: Dictionary, start: Vector2i) -> Array:
	var cluster: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	remaining.erase(start)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		cluster.append(c)
		for dir in Direction.all():
			var n: Vector2i = c + Direction.to_vector(dir)
			if remaining.has(n):
				remaining.erase(n)
				queue.append(n)
	return cluster

## Returns a 0..1 compactness estimate: cluster area over the area of its bounding circle.
static func _roundness(cluster: Array) -> float:
	if cluster.size() <= 1:
		return 1.0
	var centroid := Vector2.ZERO
	for c in cluster:
		centroid += Vector2(c)
	centroid /= cluster.size()
	var max_dist := 0.0
	for c in cluster:
		max_dist = maxf(max_dist, Vector2(c).distance_to(centroid))
	if max_dist <= 0.0:
		return 1.0
	return clampf(cluster.size() / (PI * max_dist * max_dist), 0.0, 1.0)

static func _count_walkable(world: WorldModule, region: Rect2i) -> int:
	var count := 0
	for x in region.size.x:
		for y in region.size.y:
			var def := world.get_tile_def_at(region.position + Vector2i(x, y))
			if def != null and def.has_tag(TileTags.Tag.WALKABLE):
				count += 1
	return count
