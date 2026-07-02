extends SceneTree
## Builds PartVisualDef .tres assets from loincloth PNG folders.
## Run: godot --headless --path . --script res://tools/build_loincloth_part_defs.gd

const _ART_ROOT := "res://assets/visuals/parts/human/male/loincloth"
const _DEF_ROOT := "res://assets/visuals/parts/human/male/defs"
const _WALK_HFRAMES := 5
const _WALK_FPS := 8.0

const _PART_OFFSETS := {
	&"body": {"offset": Vector2.ZERO, "z_index": 0},
	&"head": {"offset": Vector2(0, -22), "z_index": 2},
	&"arm_left": {"offset": Vector2(-13, -2), "z_index": 1},
	&"arm_right": {"offset": Vector2(13, -2), "z_index": 1},
	&"leg_left": {"offset": Vector2(-6, 22), "z_index": 0},
	&"leg_right": {"offset": Vector2(6, 22), "z_index": 0},
}

const _VIEWS := [&"front", &"back", &"side_right"]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_DEF_ROOT))
	for part_id in _PART_OFFSETS:
		_build_def(part_id)
	print("build_loincloth_part_defs: done -> %s" % _DEF_ROOT)
	quit(0)

func _build_def(part_id: StringName) -> void:
	var def := PartVisualDef.new()
	def.part_id = part_id
	var meta: Dictionary = _PART_OFFSETS[part_id]
	def.offset = meta["offset"]
	def.z_index = meta["z_index"]
	def.walk_hframes = _WALK_HFRAMES
	def.walk_fps = _WALK_FPS
	var part_dir := "%s/%s" % [_ART_ROOT, part_id]
	for view in _VIEWS:
		var idle_path := "%s/%s_idle.png" % [part_dir, view]
		if ResourceLoader.exists(idle_path):
			def.textures[view] = load(idle_path)
		var walk_path := "%s/%s_walk.png" % [part_dir, view]
		if ResourceLoader.exists(walk_path):
			def.walk_textures[view] = load(walk_path)
	var out_path := "%s/loincloth_%s.tres" % [_DEF_ROOT, part_id]
	var err := ResourceSaver.save(def, out_path)
	if err != OK:
		push_error("Failed to save %s: %s" % [out_path, error_string(err)])
