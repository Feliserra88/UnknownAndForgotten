extends SceneTree
## Generates dummy helmet equipment visuals (4 views) for cutout smoke test.
## Run: godot --headless --path . --script res://tools/generate_dummy_helmet_visual.gd

const _ROOT := "res://assets/visuals/equipment/armor/dummy_helmet"
const _VIEWS := ["front", "back", "side_right"]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_ROOT))
	var visual := EquipmentVisualDef.new()
	visual.slot = &"head"
	visual.base_coverage = EquipmentVisualDef.Coverage.PARTIAL
	for view in _VIEWS:
		var img := _draw_helmet(view)
		var path := _ROOT.path_join("%s.png" % view)
		img.save_png(ProjectSettings.globalize_path(path))
		visual.textures[StringName(view)] = ImageTexture.create_from_image(img)
	ResourceSaver.save(visual, "res://assets/visuals/equipment/armor/dummy_helmet_visual.tres")
	print("generate_dummy_helmet_visual: done")
	quit(0)

func _draw_helmet(view: String) -> Image:
	var img := Image.create(20, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var metal := Color(0.55, 0.58, 0.62)
	var dark := Color(0.28, 0.30, 0.34)
	for y in range(2, 12):
		for x in range(2, 18):
			img.set_pixel(x, y, metal)
	for y in range(0, 4):
		for x in range(4, 16):
			img.set_pixel(x, y, dark)
	if view != "back":
		_fill_rect(img, Rect2i(7, 6, 3, 2), Color(0.12, 0.12, 0.14))
		_fill_rect(img, Rect2i(11, 6, 3, 2), Color(0.12, 0.12, 0.14))
	return img

func _fill_rect(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)
