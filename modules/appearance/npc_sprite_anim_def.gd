@tool
class_name NpcSpriteAnimDef
extends Resource
## Full-body sprite set for an NPC: idle 8-way sheet plus walk sheets per facing.
## All frames share [member frame_size] (reference 64×64). Saveable as a .tres asset.

## Reference frame size in pixels (width × height). Every sheet in this set uses the same cell size.
@export var frame_size: Vector2i = Vector2i(64, 64)

@export_group("Idle (8 orientations in one row)")
## Single-row sheet: S, SE, E, NE, N, NW, W, SW — one 64×64 cell each.
@export var idle_texture: Texture2D
@export var idle_hframes: int = 8

@export_group("Walk — cardinals")
@export var walk_right_texture: Texture2D
@export var walk_right_hframes: int = 5
@export var walk_left_texture: Texture2D
@export var walk_left_hframes: int = 5

@export_group("Walk — diagonals")
@export var walk_front_right_texture: Texture2D
@export var walk_front_right_hframes: int = 5
@export var walk_back_right_texture: Texture2D
@export var walk_back_right_hframes: int = 5
@export var walk_back_left_texture: Texture2D
@export var walk_back_left_hframes: int = 5
@export var walk_front_left_texture: Texture2D
@export var walk_front_left_hframes: int = 5
@export var walk_fps: float = 8.0

@export_group("Placement")
## Normalized foot contact in each frame (0–1). Default y=0.8 → feet sit in the lower 20% of the sprite.
@export var feet_anchor: Vector2 = Vector2(0.5, 0.8)
## Extra pixel offset after [member feet_anchor] (fine-tune per archetype).
@export var sprite_offset: Vector2 = Vector2.ZERO

## Pixel offset so [member feet_anchor] aligns with the NPC root (tile foot point).
func compute_placement_offset() -> Vector2:
	var fw := float(frame_size.x)
	var fh := float(frame_size.y)
	var anchor_px := Vector2(feet_anchor.x * fw, feet_anchor.y * fh)
	var center_px := Vector2(fw * 0.5, fh * 0.5)
	return center_px - anchor_px + sprite_offset

## Maps game orientation id → idle sheet column (0–7). Default matches Pixelorama 8-way export:
## S, SE, E, NE, N, NW, W, SW.
@export var idle_frame_by_orientation: Dictionary = {
	&"front": 0,
	&"front_right": 1,
	&"side_right": 2,
	&"back_right": 3,
	&"back": 4,
	&"back_left": 5,
	&"side_left": 6,
	&"front_left": 7,
}

## Builds SpriteFrames: idle_<orientation> (1 frame) + walk loops per facing.
func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var fw := frame_size.x
	var fh := frame_size.y
	if idle_texture != null:
		for orientation in idle_frame_by_orientation:
			var col: int = idle_frame_by_orientation[orientation]
			var anim := StringName("idle_%s" % orientation)
			sf.add_animation(anim)
			sf.set_animation_speed(anim, 1.0)
			sf.set_animation_loop(anim, true)
			sf.add_frame(anim, _atlas(idle_texture, col, fw, fh), 1.0)
	_add_walk_loop(sf, &"walk_right", walk_right_texture, walk_right_hframes, fw, fh)
	_add_walk_loop(sf, &"walk_left", walk_left_texture, walk_left_hframes, fw, fh)
	_add_walk_loop(sf, &"walk_front_right", walk_front_right_texture, walk_front_right_hframes, fw, fh)
	_add_walk_loop(sf, &"walk_back_right", walk_back_right_texture, walk_back_right_hframes, fw, fh)
	_add_walk_loop(sf, &"walk_back_left", walk_back_left_texture, walk_back_left_hframes, fw, fh)
	_add_walk_loop(sf, &"walk_front_left", walk_front_left_texture, walk_front_left_hframes, fw, fh)
	return sf

func _add_walk_loop(sf: SpriteFrames, anim: StringName, texture: Texture2D, cols: int, fw: int, fh: int) -> void:
	if texture == null or cols <= 0:
		return
	sf.add_animation(anim)
	sf.set_animation_speed(anim, walk_fps)
	sf.set_animation_loop(anim, true)
	for i in cols:
		sf.add_frame(anim, _atlas(texture, i, fw, fh), 1.0)

func _atlas(texture: Texture2D, column: int, fw: int, fh: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(column * fw, 0, fw, fh)
	return atlas

## Returns the idle SpriteFrames animation name for [param orientation].
func idle_animation(orientation: StringName) -> StringName:
	return StringName("idle_%s" % orientation)

## Returns the walk SpriteFrames animation for [param orientation], or [code]&""[/code] when none.
func walk_animation(orientation: StringName) -> StringName:
	match orientation:
		&"side_right":
			return &"walk_right" if walk_right_texture != null else &""
		&"side_left":
			return &"walk_left" if walk_left_texture != null else &""
		&"front_right":
			return &"walk_front_right" if walk_front_right_texture != null else &""
		&"back_right":
			return &"walk_back_right" if walk_back_right_texture != null else &""
		&"back_left":
			return &"walk_back_left" if walk_back_left_texture != null else &""
		&"front_left":
			return &"walk_front_left" if walk_front_left_texture != null else &""
		_:
			return &""
