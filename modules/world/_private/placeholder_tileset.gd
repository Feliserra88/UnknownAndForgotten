class_name PlaceholderTileSet
extends RefCounted
## Builds placeholder isometric TileSets (colored diamonds) for tiles and modifier overlays.
## Placeholder visuals only; real art replaces these atlases later. Internal to the world module.

## Builds a TileSet with one diamond tile per [param tile_defs] entry and assigns each
## def its source_id/atlas_coords. The custom data layer "tile_def_id" stores the tile id.
static func build_tiles(tile_defs: Array, tile_size: Vector2i) -> TileSet:
	var ts := _new_isometric_tileset(tile_size, "tile_def_id")
	var source := TileSetAtlasSource.new()
	source.texture = _build_atlas(tile_defs, tile_size, false)
	source.texture_region_size = tile_size
	var source_id := ts.add_source(source)
	for i in tile_defs.size():
		var def: TileDef = tile_defs[i]
		var coords := Vector2i(i, 0)
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		data.set_custom_data("tile_def_id", def.id)
		def.source_id = source_id
		def.atlas_coords = coords
	return ts

## Builds a TileSet of semi-transparent overlays for [param modifier_defs] and assigns
## each one a stable atlas coordinate (index order). The data layer "modifier_id" stores its id.
static func build_modifier_overlays(modifier_defs: Array, tile_size: Vector2i) -> Dictionary:
	var ts := _new_isometric_tileset(tile_size, "modifier_id")
	var source := TileSetAtlasSource.new()
	source.texture = _build_atlas(modifier_defs, tile_size, true)
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

static func _build_atlas(defs: Array, tile_size: Vector2i, overlay: bool) -> ImageTexture:
	var count: int = max(defs.size(), 1)
	var img := Image.create(count * tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in defs.size():
		var color: Color = defs[i].overlay_color if overlay else defs[i].placeholder_color
		_draw_diamond(img, Vector2i(i * tile_size.x, 0), tile_size, color, not overlay)
	return ImageTexture.create_from_image(img)

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
