@tool
class_name PartVisualDef
extends Resource
## Visual definition of a body part's base layer (see docs/GAME_DESIGN.md section 5.5.4).
## Placeholder build uses a flat colour rectangle; real art supplies per-orientation idle/walk.
## Saveable as a .tres asset.

@export var part_id: StringName = &""
## Idle textures keyed by orientation (front/back/side_left/side_right).
@export var textures: Dictionary = {}
@export_group("Walk")
## Walk strip textures keyed by orientation (horizontal strip, [member walk_hframes] columns).
@export var walk_textures: Dictionary = {}
@export var walk_hframes: int = 8
@export var walk_fps: float = 8.0
@export_group("Placeholder")
@export var placeholder_color: Color = Color(0.8, 0.7, 0.6)
@export var size: Vector2i = Vector2i(16, 16)
## When set (both axes > 0), base layer scales so one frame matches this size (PixelLab 64–68px → rig space).
@export var display_size: Vector2i = Vector2i.ZERO
## Offset in pixels from the NPC root where this part's slot is anchored.
@export var offset: Vector2 = Vector2.ZERO
@export var z_index: int = 0

## Returns the idle texture for [param orientation], or null when none is defined.
func get_texture(orientation: StringName) -> Texture2D:
	return textures.get(orientation, null)

## Returns the walk strip for [param orientation], or null when none is defined.
func get_walk_texture(orientation: StringName) -> Texture2D:
	return walk_textures.get(orientation, null)

## True when at least one idle or walk texture is assigned.
func has_art() -> bool:
	for view in CutoutOrientation.all_views():
		if textures.get(view) != null or walk_textures.get(view) != null:
			return true
	return false

## Builds SpriteFrames with idle_<view> (1 frame) and walk_<view> loops for cutout slots.
func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for view in CutoutOrientation.all_views():
		var idle_tex: Texture2D = textures.get(view)
		if idle_tex != null:
			var idle_anim := StringName("idle_%s" % view)
			sf.add_animation(idle_anim)
			sf.set_animation_speed(idle_anim, 1.0)
			sf.set_animation_loop(idle_anim, true)
			sf.add_frame(idle_anim, idle_tex, 1.0)
		var walk_tex: Texture2D = walk_textures.get(view)
		if walk_tex != null and walk_hframes > 0:
			var walk_anim := StringName("walk_%s" % view)
			sf.add_animation(walk_anim)
			sf.set_animation_speed(walk_anim, walk_fps)
			sf.set_animation_loop(walk_anim, true)
			var fw := int(walk_tex.get_width()) / walk_hframes
			var fh := int(walk_tex.get_height())
			for i in walk_hframes:
				sf.add_frame(walk_anim, _atlas(walk_tex, i, fw, fh), 1.0)
	return sf

## Size of one idle/walk frame in texture pixels (for scaling full-canvas PixelLab parts).
func reference_frame_size() -> Vector2:
	for view in CutoutOrientation.all_views():
		var idle_tex: Texture2D = textures.get(view)
		if idle_tex != null:
			return idle_tex.get_size()
	for view in walk_textures.values():
		var walk_tex: Texture2D = view
		if walk_tex != null and walk_hframes > 0:
			return Vector2(walk_tex.get_width() / float(walk_hframes), walk_tex.get_height())
	return Vector2(size)

## Scale factor mapping [member reference_frame_size] to [member display_size].
func resolve_base_scale() -> Vector2:
	if display_size.x <= 0 or display_size.y <= 0:
		return Vector2.ONE
	var frame := reference_frame_size()
	if frame.x <= 0.0 or frame.y <= 0.0:
		return Vector2.ONE
	return Vector2(display_size) / frame

func _atlas(texture: Texture2D, column: int, fw: int, fh: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(column * fw, 0, fw, fh)
	return atlas
