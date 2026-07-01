extends SceneTree
## Converts PixelLab Wang tileset metadata JSON + PNG sheets into a Godot TileSet with terrains.
## Usage:
##   godot --headless -s res://tools/pixellab_wang_converter.gd -- \
##     assets/world/terrains/wang/grass_water_metadata.json assets/world/terrains/wang/grass_water_image.png \
##     assets/world/terrains/wang/grass_path_metadata.json assets/world/terrains/wang/grass_path_image.png \
##     --output assets/world/terrains/field_combined.tres

const _CORNER_LAYOUT := [
	"ss/sw", "ss/ww", "ss/ws", "ww/ws", "ww/sw",
	"sw/sw", "ww/ww", "ws/ws", "ws/ww", "sw/ww",
	"sw/ss", "ww/ss", "ws/ss", "ws/sw", "sw/ws",
	"ww/ww", "ss/ss", "", "", "",
]

var _output_path := "res://assets/world/terrains/field_combined.tres"
var _tile_size := 0
var _terrains: Dictionary = {}
var _tiles: Array = []


func _init() -> void:
	var pairs := _parse_pairs()
	if pairs.is_empty():
		push_error("No metadata/png pairs found. Pass *_metadata.json and *_image.png paths.")
		quit(1)
		return
	for pair in pairs:
		_load_pair(pair.json, pair.png)
	if _tiles.is_empty():
		push_error("No tiles loaded")
		quit(1)
		return
	_build_tileset()
	print("Created %s with terrains: %s" % [_output_path, ", ".join(_terrains.values())])
	quit()


func _parse_pairs() -> Array:
	var pairs: Array = []
	var args := OS.get_cmdline_user_args()
	var output_next := false
	for arg in args:
		if arg == "--output" or arg == "-o":
			output_next = true
			continue
		if output_next:
			_output_path = arg
			output_next = false
			continue
		if arg.ends_with("_metadata.json"):
			var png := arg.replace("_metadata.json", "_image.png")
			if FileAccess.file_exists(png):
				pairs.append({"json": arg, "png": png})
	return pairs


func _load_pair(json_path: String, png_path: String) -> void:
	if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(png_path):
		push_warning("Missing pair %s / %s" % [json_path, png_path])
		return
	var file := FileAccess.open(json_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON %s" % json_path)
		return
	var metadata: Dictionary = parsed
	var sheet := Image.new()
	if sheet.load(png_path) != OK:
		push_warning("Could not load %s" % png_path)
		return
	if _tile_size == 0:
		var size: Dictionary = metadata.get("tileset_data", {}).get("tile_size", {})
		_tile_size = int(size.get("width", 32))
	var prompts: Dictionary = metadata.get("metadata", {}).get("terrain_prompts", {})
	var lower_name: String = str(prompts.get("lower", "lower"))
	var upper_name: String = str(prompts.get("upper", "upper"))
	var lower_id := _terrain_id(lower_name)
	var upper_id := _terrain_id(upper_name)
	var wang_tiles := {}
	for tile in metadata.get("tileset_data", {}).get("tiles", []):
		var corners: Dictionary = tile.get("corners", {})
		var bbox: Dictionary = tile.get("bounding_box", {})
		var tile_image := Image.create(int(bbox.width), int(bbox.height), false, Image.FORMAT_RGBA8)
		tile_image.blit_rect(sheet, Rect2i(int(bbox.x), int(bbox.y), int(bbox.width), int(bbox.height)), Vector2i.ZERO)
		var nw := 1 if str(corners.get("NW", "")) == "upper" else 0
		var ne := 1 if str(corners.get("NE", "")) == "upper" else 0
		var sw := 1 if str(corners.get("SW", "")) == "upper" else 0
		var se := 1 if str(corners.get("SE", "")) == "upper" else 0
		var wang_idx := nw * 8 + ne * 4 + sw * 2 + se
		wang_tiles[wang_idx] = {
			"image": tile_image,
			"corners": [
				upper_id if nw == 1 else lower_id,
				upper_id if ne == 1 else lower_id,
				upper_id if sw == 1 else lower_id,
				upper_id if se == 1 else lower_id,
			],
		}
	for pattern in _CORNER_LAYOUT:
		if pattern == "":
			_tiles.append(null)
			continue
		var parts: PackedStringArray = pattern.split("/")
		var top := parts[0]
		var bottom := parts[1]
		var nw := 1 if top[0] == "s" else 0
		var ne := 1 if top[1] == "s" else 0
		var sw := 1 if bottom[0] == "s" else 0
		var se := 1 if bottom[1] == "s" else 0
		var wang_idx := nw * 8 + ne * 4 + sw * 2 + se
		_tiles.append(wang_tiles.get(wang_idx))


func _terrain_id(name: String) -> int:
	for id in _terrains:
		if _terrains[id] == name:
			return id
	var id := _terrains.size()
	_terrains[id] = name
	return id


func _build_tileset() -> void:
	var cols := 5
	var rows := int(ceil(float(_tiles.size()) / float(cols)))
	var atlas := Image.create(cols * _tile_size, rows * _tile_size, false, Image.FORMAT_RGBA8)
	for i in _tiles.size():
		if _tiles[i] == null:
			continue
		var img: Image = _tiles[i].image
		var x := (i % cols) * _tile_size
		var y := int(i / cols) * _tile_size
		atlas.blit_rect(img, Rect2i(0, 0, _tile_size, _tile_size), Vector2i(x, y))
	var atlas_tex := ImageTexture.create_from_image(atlas)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(_tile_size, _tile_size)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for id in _terrains:
		ts.add_terrain(0)
		ts.set_terrain_name(0, id, _terrains[id])
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(_tile_size, _tile_size)
	var source_id := ts.add_source(source)
	for i in _tiles.size():
		if _tiles[i] == null:
			continue
		var coords := Vector2i(i % cols, int(i / cols))
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		var corners: Array = _tiles[i].corners
		data.terrain_set = 0
		data.terrain = corners[0]
		data.set_terrain_peering_bit(TileSet.TERRAIN_PEERING_TOP_LEFT, corners[0])
		data.set_terrain_peering_bit(TileSet.TERRAIN_PEERING_TOP_RIGHT, corners[1])
		data.set_terrain_peering_bit(TileSet.TERRAIN_PEERING_BOTTOM_LEFT, corners[2])
		data.set_terrain_peering_bit(TileSet.TERRAIN_PEERING_BOTTOM_RIGHT, corners[3])
	var err := ResourceSaver.save(ts, _output_path)
	if err != OK:
		push_error("Failed to save %s err=%s" % [_output_path, err])
