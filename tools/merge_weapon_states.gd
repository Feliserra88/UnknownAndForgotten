extends SceneTree
## Packs five quality-tier PNGs into one horizontal strip and flattens the type folder.
##
## Input folder must contain: pristine.png, good.png, worn.png, rusty.png, battered.png
## Output: <weapon_dir>/<typeNN>.png (320×64, columns 0..4 = best → worst)
## Then deletes the <typeNN>/ folder and all files inside (including .import).
##
## Usage:
##   godot --headless -s res://tools/merge_weapon_states.gd -- \
##     assets/visuals/equipment/weapons/long_sword type02
##   godot --headless -s res://tools/merge_weapon_states.gd -- \
##     assets/visuals/equipment/weapons/long_sword type01 type02 type03

const TIERS: Array[String] = ["pristine", "good", "worn", "rusty", "battered"]
const CELL := 64


func _init() -> void:
	var args := _user_args()
	if args.size() < 2:
		_print_usage()
		quit(1)
		return

	var weapon_dir := _as_res_path(args[0])
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(weapon_dir)):
		push_error("Weapon directory not found: %s" % weapon_dir)
		quit(1)
		return

	var failed := false
	for i in range(1, args.size()):
		if not _merge_type(weapon_dir, args[i]):
			failed = true

	quit(1 if failed else 0)


func _user_args() -> PackedStringArray:
	var user := OS.get_cmdline_user_args()
	if not user.is_empty():
		return user
	var all := OS.get_cmdline_args()
	for i in all.size():
		if all[i] == "--" and i + 1 < all.size():
			return all.slice(i + 1)
		if all[i].ends_with("merge_weapon_states.gd") and i + 1 < all.size():
			return all.slice(i + 1)
	return PackedStringArray()


func _print_usage() -> void:
	push_error(
		"Usage: godot --headless -s res://tools/merge_weapon_states.gd -- "
		+ "<weapon_dir> <typeNN> [typeNN ...]"
	)


func _as_res_path(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/")
	if p.begins_with("res://"):
		return p
	if p.begins_with("/"):
		return "res:/%s" % p
	return "res://%s" % p.trim_prefix("./")


func _merge_type(weapon_dir: String, type_name: String) -> bool:
	var type_dir := "%s/%s" % [weapon_dir, type_name]
	var type_abs := ProjectSettings.globalize_path(type_dir)
	if not DirAccess.dir_exists_absolute(type_abs):
		push_error("[%s] Folder not found: %s" % [type_name, type_dir])
		return false

	var tier_images: Array[Image] = []
	for tier in TIERS:
		var tier_path := "%s/%s.png" % [type_dir, tier]
		var tier_abs := ProjectSettings.globalize_path(tier_path)
		if not FileAccess.file_exists(tier_abs):
			push_error("[%s] Missing tier file: %s" % [type_name, tier_path])
			return false
		var img := Image.load_from_file(tier_abs)
		if img == null:
			push_error("[%s] Failed to load: %s" % [type_name, tier_path])
			return false
		if img.get_width() != CELL or img.get_height() != CELL:
			push_error(
				"[%s] Expected %d×%d for %s, got %d×%d"
				% [type_name, CELL, CELL, tier, img.get_width(), img.get_height()]
			)
			return false
		tier_images.append(img)

	var out := Image.create(CELL * TIERS.size(), CELL, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for i in tier_images.size():
		out.blit_rect(tier_images[i], Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))

	var out_res := "%s/%s.png" % [weapon_dir, type_name]
	var out_abs := ProjectSettings.globalize_path(out_res)
	var err := out.save_png(out_abs)
	if err != OK:
		push_error("[%s] Failed to save %s (error %d)" % [type_name, out_res, err])
		return false

	if not _remove_dir_recursive(type_abs):
		push_error("[%s] Merged to %s but failed to remove %s" % [type_name, out_res, type_dir])
		return false

	print("[%s] OK → %s (%d×%d)" % [type_name, out_res, CELL * TIERS.size(), CELL])
	return true


func _remove_dir_recursive(abs_path: String) -> bool:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := "%s/%s" % [abs_path, entry]
			if dir.current_is_dir():
				if not _remove_dir_recursive(child):
					return false
			else:
				if DirAccess.remove_absolute(child) != OK:
					return false
		entry = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(abs_path) == OK
