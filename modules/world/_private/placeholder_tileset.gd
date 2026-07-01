class_name PlaceholderTileSet
extends RefCounted
## Builds isometric TileSets from TileDef art textures or coloured placeholder diamonds.
## Internal to the world module.

const _ART_REGION := Vector2i(64, 64)

## Builds a TileSet with one tile per [param tile_defs] entry and assigns each
## def its source_id/atlas_coords. The custom data layer "tile_def_id" stores the tile id.
static func build_tiles(tile_defs: Array, tile_size: Vector2i) -> TileSet:
	var region_size := _resolve_region_size(tile_defs, tile_size)
	var ts := _new_isometric_tileset(tile_size, "tile_def_id")
	var source := TileSetAtlasSource.new()
	source.texture = _build_tile_atlas(tile_defs, tile_size, region_size)
	source.texture_region_size = region_size
	var texture_origin := _texture_origin_for(region_size, tile_size)
	var source_id := ts.add_source(source)
	for i in tile_defs.size():
		var def: TileDef = tile_defs[i]
		var coords := Vector2i(i, 0)
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		data.set_custom_data("tile_def_id", def.id)
		if region_size != tile_size:
			data.texture_origin = texture_origin
		def.source_id = source_id
		def.atlas_coords = coords
	return ts

## Writes source_id and atlas_coords on [param tile_defs] to match [param tileset] layout.
## Required when reusing a cached TileSet (uf_map_editor) so set_cell uses valid coordinates.
static func assign_tile_mapping(tile_defs: Array, tileset: TileSet) -> void:
	if tile_defs.is_empty() or tileset == null or tileset.get_source_count() == 0:
		return
	var source_id := tileset.get_source_id(0)
	for i in tile_defs.size():
		var def: TileDef = tile_defs[i]
		if def == null:
			continue
		def.source_id = source_id
		def.atlas_coords = Vector2i(i, 0)

## Builds a TileSet of semi-transparent overlays for [param modifier_defs] and assigns
## each one a stable atlas coordinate (index order). The data layer "modifier_id" stores its id.
static func build_modifier_overlays(modifier_defs: Array, tile_size: Vector2i) -> Dictionary:
	var ts := _new_isometric_tileset(tile_size, "modifier_id")
	var source := TileSetAtlasSource.new()
	source.texture = _build_atlas(modifier_defs, tile_size, tile_size, true)
	source.texture_region_size = tile_size
	var source_id := ts.add_source(source)
	var coords_by_id := {}
	for i in modifier_defs.size():
		var def: TileModifierDef = modifier_defs[i]
		var coords := Vector2i(i, 0)
		source.create_tile(coords)
		source.get_tile_data(coords, 0).set_custom_data("modifier_id", def.id)
		coords_by_id[def.id] = coords
	return {"tileset": ts, "source_id": source_id, "coords": coords_by_id}

static func _new_isometric_tileset(tile_size: Vector2i, data_layer_name: String) -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = tile_size
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, data_layer_name)
	ts.set_custom_data_layer_type(0, TYPE_STRING_NAME)
	return ts

static func _resolve_region_size(tile_defs: Array, tile_size: Vector2i) -> Vector2i:
	for def in tile_defs:
		if def is TileDef and def.art_texture != null:
			return _ART_REGION
	return tile_size

static func _build_tile_atlas(tile_defs: Array, tile_size: Vector2i, region_size: Vector2i) -> ImageTexture:
	var count: int = maxi(tile_defs.size(), 1)
	var img := Image.create(count * region_size.x, region_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in tile_defs.size():
		var def: TileDef = tile_defs[i]
		var origin := Vector2i(i * region_size.x, 0)
		if def.art_texture != null:
			_blit_texture(img, origin, region_size, def.art_texture)
		else:
			_draw_diamond(img, origin, tile_size, def.placeholder_color, true)
	return ImageTexture.create_from_image(img)

static func _build_atlas(defs: Array, tile_size: Vector2i, region_size: Vector2i, overlay: bool) -> ImageTexture:
	var count: int = maxi(defs.size(), 1)
	var img := Image.create(count * region_size.x, region_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in defs.size():
		var color: Color = defs[i].overlay_color if overlay else defs[i].placeholder_color
		_draw_diamond(img, Vector2i(i * region_size.x, 0), tile_size, color, not overlay)
	return ImageTexture.create_from_image(img)

static func _blit_texture(img: Image, origin: Vector2i, region_size: Vector2i, texture: Texture2D) -> void:
	var src := _load_texture_image(texture)
	if src == null or src.is_empty():
		push_warning("PlaceholderTileSet: could not read art texture %s" % texture.resource_path)
		return
	if src.get_format() != Image.FORMAT_RGBA8:
		src = src.duplicate()
		src.convert(Image.FORMAT_RGBA8)
	else:
		src = src.duplicate()
	if src.get_size() != region_size:
		src.resize(region_size.x, region_size.y, Image.INTERPOLATE_NEAREST)
	for px in region_size.x:
		for py in region_size.y:
			var c := src.get_pixel(px, py)
			if c.a > 0.0:
				img.set_pixel(origin.x + px, origin.y + py, c)

static func _load_texture_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var img := texture.get_image()
	if img != null and not img.is_empty():
		return img
	var path := texture.resource_path
	if path.is_empty():
		return null
	var file_img := Image.new()
	if file_img.load(path) != OK:
		return null
	return file_img

static func _texture_origin_for(region_size: Vector2i, tile_size: Vector2i) -> Vector2i:
	return Vector2i(0, int((tile_size.y - region_size.y) / 2.0))

static func _draw_diamond(img: Image, origin: Vector2i, size: Vector2i, color: Color, outline: bool) -> void:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var edge := color.darkened(0.35)
	for px in size.x:
		for py in size.y:
			var nx: float = absf(px + 0.5 - hw) / hw
			var ny: float = absf(py + 0.5 - hh) / hh
			var d := nx + ny
			if d <= 1.0:
				var c := color
				if outline and d >= 0.82:
					c = edge
				img.set_pixel(origin.x + px, origin.y + py, c)
