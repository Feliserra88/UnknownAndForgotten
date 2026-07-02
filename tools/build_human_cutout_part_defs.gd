extends SceneTree
## Builds PartVisualDef .tres assets from human male cutout PNG folders.
## Run: godot --headless --path . --script res://tools/build_human_cutout_part_defs.gd -- naked
## Sets: naked (production), _dummy (dev placeholder only)

const _ART_BASE := "res://assets/visuals/parts/human/male"
const _DEF_ROOT := "res://assets/visuals/parts/human/male/defs"
const _WALK_HFRAMES := 8
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
	var set_name := _cmdline_set_name()
	if set_name.is_empty():
		push_error("Usage: ... -- <set_name>   e.g. naked or _dummy")
		quit(1)
		return
	var art_root := "%s/%s" % [_ART_BASE, set_name]
	var def_prefix := set_name if set_name != "_dummy" else "dummy"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_DEF_ROOT))
	for part_id in _PART_OFFSETS:
		_build_def(part_id, art_root, def_prefix)
	print("build_human_cutout_part_defs: done set=%s -> %s" % [set_name, _DEF_ROOT])
	quit(0)

func _build_def(part_id: StringName, art_root: String, def_prefix: String) -> void:
	var def := PartVisualDef.new()
	def.part_id = part_id
	var meta: Dictionary = _PART_OFFSETS[part_id]
	def.offset = meta["offset"]
	def.z_index = meta["z_index"]
	def.walk_hframes = _WALK_HFRAMES
	def.walk_fps = _WALK_FPS
	var part_dir := "%s/%s" % [art_root, part_id]
	for view in _VIEWS:
		var idle_path := "%s/%s_idle.png" % [part_dir, view]
		if ResourceLoader.exists(idle_path):
			def.textures[view] = load(idle_path)
		var walk_path := "%s/%s_walk.png" % [part_dir, view]
		if ResourceLoader.exists(walk_path):
			def.walk_textures[view] = load(walk_path)
	var out_path := "%s/%s_%s.tres" % [_DEF_ROOT, def_prefix, part_id]
	var err := ResourceSaver.save(def, out_path)
	if err != OK:
		push_error("Failed to save %s: %s" % [out_path, error_string(err)])

func _cmdline_set_name() -> String:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--" and i + 1 < args.size():
			return args[i + 1]
	return ""
