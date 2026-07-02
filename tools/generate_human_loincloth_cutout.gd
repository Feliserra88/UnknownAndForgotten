extends SceneTree
## Generates prototype loincloth cutout PNGs for the male humanoid rig (idle + walk strips).
## Run: godot --headless --path . --script res://tools/generate_human_loincloth_cutout.gd
## Replace with PixelLab exports under the same paths when ready.

const _ROOT := "res://assets/visuals/parts/human/male/loincloth"
const _WALK_HFRAMES := 5
const _VIEWS := ["front", "back", "side_right"]

const _PARTS := {
	"body": {"size": Vector2i(24, 28), "color": Color(0.55, 0.42, 0.34), "accent": Color(0.35, 0.28, 0.22)},
	"head": {"size": Vector2i(18, 18), "color": Color(0.86, 0.70, 0.56), "accent": Color(0.35, 0.25, 0.18)},
	"arm_left": {"size": Vector2i(8, 20), "color": Color(0.86, 0.70, 0.56), "accent": Color(0.45, 0.35, 0.28)},
	"arm_right": {"size": Vector2i(8, 20), "color": Color(0.86, 0.70, 0.56), "accent": Color(0.45, 0.35, 0.28)},
	"leg_left": {"size": Vector2i(9, 20), "color": Color(0.86, 0.70, 0.56), "accent": Color(0.35, 0.28, 0.22)},
	"leg_right": {"size": Vector2i(9, 20), "color": Color(0.86, 0.70, 0.56), "accent": Color(0.35, 0.28, 0.22)},
}

func _initialize() -> void:
	for part_id in _PARTS:
		_generate_part(part_id)
	print("generate_human_loincloth_cutout: done -> %s" % _ROOT)
	quit(0)

func _generate_part(part_id: String) -> void:
	var spec: Dictionary = _PARTS[part_id]
	var size: Vector2i = spec["size"]
	var base_color: Color = spec["color"]
	var accent: Color = spec["accent"]
	var dir := _ROOT.path_join(part_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for view in _VIEWS:
		var idle := _draw_part(size, base_color, accent, part_id, view, 0.0)
		var idle_path := dir.path_join("%s_idle.png" % view)
		idle.save_png(ProjectSettings.globalize_path(idle_path))
		var walk := Image.create(size.x * _WALK_HFRAMES, size.y, false, Image.FORMAT_RGBA8)
		walk.fill(Color(0, 0, 0, 0))
		for frame in _WALK_HFRAMES:
			var phase := float(frame) / float(_WALK_HFRAMES)
			var frame_img := _draw_part(size, base_color, accent, part_id, view, phase)
			walk.blit_rect(frame_img, Rect2i(0, 0, size.x, size.y), Vector2i(frame * size.x, 0))
		var walk_path := dir.path_join("%s_walk.png" % view)
		walk.save_png(ProjectSettings.globalize_path(walk_path))

func _draw_part(size: Vector2i, base_color: Color, accent: Color, part_id: String, view: String, phase: float) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bob := int(sin(phase * TAU) * 1.0)
	match part_id:
		"body":
			_fill_rect(img, Rect2i(2, 2 + bob, size.x - 4, size.y - 6), base_color)
			if view != "back":
				_fill_rect(img, Rect2i(4, size.y - 8 + bob, size.x - 8, 5), accent)
		"head":
			_fill_ellipse(img, Vector2i(size.x / 2, 6 + bob), Vector2i(size.x / 2 - 2, 6), base_color)
			if view != "back":
				_fill_rect(img, Rect2i(5, 8 + bob, 2, 2), Color(0.15, 0.12, 0.1))
				_fill_rect(img, Rect2i(size.x - 7, 8 + bob, 2, 2), Color(0.15, 0.12, 0.1))
		"arm_left", "arm_right":
			var swing := int(sin(phase * TAU) * 2.0)
			_fill_rect(img, Rect2i(2, 2 + bob + swing, size.x - 4, size.y - 4), base_color)
		"leg_left", "leg_right":
			var step := int(sin(phase * TAU) * 2.0) if part_id == "leg_left" else int(-sin(phase * TAU) * 2.0)
			_fill_rect(img, Rect2i(2, 2 + bob, size.x - 4, size.y - 6 + step), base_color)
			_fill_rect(img, Rect2i(1, size.y - 5 + bob + step, size.x - 2, 4), accent)
	return img

func _fill_rect(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)

func _fill_ellipse(img: Image, center: Vector2i, radius: Vector2i, color: Color) -> void:
	for y in range(center.y - radius.y, center.y + radius.y):
		for x in range(center.x - radius.x, center.x + radius.x):
			var dx := float(x - center.x) / float(maxi(radius.x, 1))
			var dy := float(y - center.y) / float(maxi(radius.y, 1))
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)
