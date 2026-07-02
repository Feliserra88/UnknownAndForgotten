extends SceneTree
## Imports PixelLab 8-direction cutout objects into human male part folders.
## Idle manifest JSON:
##   { "set": "naked", "part_id": "body", "rotations": { "south": "https://...", ... } }
## Walk manifest JSON:
##   { "set": "naked", "part_id": "body", "animation": "walk", "walk_hframes": 8,
##     "directions": { "south": ["https://frame0", ...], "north": [...], "east": [...] } }
## Run: godot --headless --path . --script res://tools/import_pixellab_cutout.gd -- manifest.json

const _ART_BASE := "res://assets/visuals/parts/human/male"
const _PIXEL_TO_VIEW := {
	"south": "front",
	"north": "back",
	"east": "side_right",
}

func _initialize() -> void:
	var json_path := _cmdline_manifest_path()
	if json_path.is_empty():
		push_error("Usage: ... -- manifest.json")
		quit(1)
		return
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Cannot read %s" % json_path)
		quit(1)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid JSON manifest")
		quit(1)
		return
	var set_name: String = data.get("set", "naked")
	var part_id: String = data.get("part_id", "")
	if part_id.is_empty():
		push_error("Manifest needs set and part_id")
		quit(1)
		return
	var art_root := "%s/%s/%s" % [_ART_BASE, set_name, part_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(art_root))
	if data.has("animation") and data.get("animation") == "walk":
		_import_walk(data, art_root)
	else:
		_import_idle(data, art_root)
	print("import_pixellab_cutout: done set=%s part=%s" % [set_name, part_id])
	quit(0)

func _import_idle(data: Dictionary, art_root: String) -> void:
	var rotations: Dictionary = data.get("rotations", {})
	if rotations.is_empty():
		push_error("Idle manifest needs rotations map")
		return
	for pix_dir in rotations:
		var view: String = _PIXEL_TO_VIEW.get(pix_dir, "")
		if view.is_empty():
			continue
		var url: String = rotations[pix_dir]
		var img := _download_image_sync(url)
		if img == null:
			push_warning("Skip idle %s (%s)" % [pix_dir, url])
			continue
		var out := art_root.path_join("%s_idle.png" % view)
		img.save_png(ProjectSettings.globalize_path(out))
		print("Saved %s" % out)

func _import_walk(data: Dictionary, art_root: String) -> void:
	var directions: Dictionary = data.get("directions", {})
	var hframes: int = int(data.get("walk_hframes", 8))
	if directions.is_empty():
		push_error("Walk manifest needs directions map of frame URL arrays")
		return
	for pix_dir in directions:
		var view: String = _PIXEL_TO_VIEW.get(pix_dir, "")
		if view.is_empty():
			continue
		var urls: Variant = directions[pix_dir]
		if typeof(urls) != TYPE_ARRAY:
			continue
		var frames: Array = urls
		if frames.size() > hframes:
			frames = frames.slice(frames.size() - hframes, frames.size())
		elif frames.size() < hframes:
			push_warning("Walk %s has %d frames, expected %d" % [pix_dir, frames.size(), hframes])
		var first := _download_image_sync(frames[0])
		if first == null:
			continue
		var fw := first.get_width()
		var fh := first.get_height()
		var strip := Image.create(fw * frames.size(), fh, false, first.get_format())
		for i in frames.size():
			var frame_img := _download_image_sync(frames[i])
			if frame_img == null:
				continue
			strip.blit_rect(frame_img, Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
		var out := art_root.path_join("%s_walk.png" % view)
		strip.save_png(ProjectSettings.globalize_path(out))
		print("Saved walk strip %s (%d frames)" % [out, frames.size()])

func _cmdline_manifest_path() -> String:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--" and i + 1 < args.size():
			return args[i + 1]
	return ""

func _download_image_sync(url: String) -> Image:
	var http := HTTPClient.new()
	var err := http.connect_to_host(_host_from_url(url), _port_from_url(url), _use_tls(url))
	if err != OK:
		return null
	_poll_http(http, [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING])
	var path := _path_from_url(url)
	err = http.request(HTTPClient.METHOD_GET, path)
	if err != OK:
		return null
	_poll_http(http, [HTTPClient.STATUS_REQUESTING])
	if http.get_status() != HTTPClient.STATUS_BODY or http.get_response_code() != 200:
		return null
	var body := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(5)
		else:
			body.append_array(chunk)
	var img := Image.new()
	if img.load_png_from_buffer(body) != OK and img.load_jpg_from_buffer(body) != OK:
		return null
	return img

func _poll_http(http: HTTPClient, statuses: Array) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while statuses.has(http.get_status()):
		if Time.get_ticks_msec() > deadline:
			return
		http.poll()
		OS.delay_msec(5)

func _use_tls(url: String) -> bool:
	return url.begins_with("https://")

func _host_from_url(url: String) -> String:
	var stripped := url.replace("https://", "").replace("http://", "")
	return stripped.split("/")[0]

func _port_from_url(url: String) -> int:
	return 443 if _use_tls(url) else 80

func _path_from_url(url: String) -> String:
	var stripped := url.replace("https://", "").replace("http://", "")
	var parts := stripped.split("/")
	parts.remove_at(0)
	return "/" + "/".join(parts)
