extends RefCounted
## Spawns and clears free Sprite2D props and decor on map layers. Internal to world.

static func clear_layer(layer: Node2D) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	for child in layer.get_children():
		child.queue_free()

static func spawn_prop(
	parent: Node2D,
	ground_layer: TileMapLayer,
	cell: Vector2i,
	prop: MapPropDef,
	local_offset: Vector2,
) -> Sprite2D:
	if parent == null or prop == null or ground_layer == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = "Prop_%s_%d_%d" % [prop.id, cell.x, cell.y]
	sprite.texture = prop.sprite_texture
	sprite.centered = true
	sprite.y_sort_enabled = true
	if prop.sprite_texture != null:
		sprite.offset = Vector2(0.0, -prop.sprite_texture.get_height() * 0.5 + float(prop.y_sort_origin))
	else:
		sprite.modulate = Color(prop.id.hash() % 255, 100, 150, 0.9)
		sprite.scale = Vector2(0.5, 0.75)
	var pos := ground_layer.map_to_local(cell) + local_offset
	sprite.position = pos
	sprite.set_meta(&"uf_cell", cell)
	sprite.set_meta(&"uf_prop_id", prop.id)
	parent.add_child(sprite)
	return sprite

static func spawn_decor(
	parent: Node2D,
	ground_layer: TileMapLayer,
	cell: Vector2i,
	decor: MapDecorDef,
	local_offset: Vector2,
	scale_factor: float,
) -> Sprite2D:
	if parent == null or decor == null or ground_layer == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = "Decor_%s_%d_%d" % [decor.id, cell.x, cell.y]
	sprite.texture = decor.sprite_texture
	sprite.centered = true
	sprite.y_sort_enabled = true
	sprite.scale = Vector2.ONE * scale_factor
	if decor.sprite_texture == null:
		sprite.modulate = Color(0.7, 0.65, 0.55, 0.8)
		sprite.scale *= Vector2(0.25, 0.25)
	var pos := ground_layer.map_to_local(cell) + local_offset
	sprite.position = pos
	sprite.set_meta(&"uf_cell", cell)
	sprite.set_meta(&"uf_decor_id", decor.id)
	parent.add_child(sprite)
	return sprite

static func random_offset(rng: RandomNumberGenerator, spread: Vector2) -> Vector2:
	if spread == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y, spread.y))

static func random_scale(rng: RandomNumberGenerator, scale_range: Vector2) -> float:
	if scale_range == Vector2.ZERO:
		return 1.0
	return rng.randf_range(scale_range.x, scale_range.y)
