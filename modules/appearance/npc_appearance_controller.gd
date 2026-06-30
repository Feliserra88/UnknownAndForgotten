class_name NpcAppearanceController
extends Node2D
## Builds and updates the NPC visual rig: cutout slots or a full-body AnimatedSprite2D
## driven by an NpcSpriteAnimDef (idle 8-way sheet + walk left/right sheets).

const _LOG := "APP"

var _slots: Dictionary = {}
var _animated_sprite: AnimatedSprite2D
var _sprite_def: Resource
var _orientation: StringName = &"front"
var _is_moving: bool = false

## Rebuilds the rig from [param archetype]: sprite sheet mode when sprite_anim is set, else cutout.
func build_from(archetype: NpcArchetype) -> void:
	_clear_children()
	_slots.clear()
	_animated_sprite = null
	_sprite_def = archetype.resolve_sprite_anim()
	if _sprite_def != null and _has_any_texture(_sprite_def):
		_build_sprite_rig(_sprite_def)
		return
	if _sprite_def != null:
		Log.warn(_LOG, "sprite_anim has no textures on archetype %s" % archetype.id)
	var map := archetype.resolve_body_part_map()
	if map == null:
		Log.warn(_LOG, "build_from: archetype %s has no body part map or sprite_anim" % archetype.id)
		return
	var visuals := {}
	for v in archetype.resolve_part_visuals():
		visuals[v.part_id] = v
	for part in map.parts:
		_build_slot(part, visuals.get(part, null))

## Refreshes layers from runtime [param instance] state (orientation, injuries).
func sync_from_instance(instance: NpcInstanceData) -> void:
	if _animated_sprite != null:
		set_orientation(instance.orientation)

## Sets facing direction and refreshes the active idle or walk animation.
func set_orientation(orientation: StringName) -> void:
	_orientation = orientation
	if _animated_sprite == null or _sprite_def == null:
		return
	_animated_sprite.flip_h = false
	_refresh_animation()

## Switches between walk loops (E/W) and idle poses (all directions).
func set_moving(moving: bool) -> void:
	_is_moving = moving
	if _animated_sprite == null:
		return
	_refresh_animation()

func _refresh_animation() -> void:
	if _animated_sprite == null or _sprite_def == null:
		return
	var anim := StringName()
	if _is_moving:
		anim = _sprite_def.walk_animation(_orientation)
	if anim.is_empty() or not _animated_sprite.sprite_frames.has_animation(anim):
		anim = _sprite_def.idle_animation(_orientation)
	if not _animated_sprite.sprite_frames.has_animation(anim):
		anim = &"idle_front"
	if _animated_sprite.animation != anim:
		_animated_sprite.play(anim)

func _has_any_texture(def: Resource) -> bool:
	return def.get("idle_texture") != null or def.get("walk_right_texture") != null or def.get("walk_left_texture") != null

func _build_sprite_rig(def: Resource) -> void:
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "BodySprite"
	_animated_sprite.sprite_frames = def.build_sprite_frames()
	_animated_sprite.position = def.compute_placement_offset()
	_animated_sprite.y_sort_enabled = true
	add_child(_animated_sprite)
	_refresh_animation()
	Log.info(_LOG, "rig", "frame=%s idle=%d walk_r=%d walk_l=%d fps=%.1f" % [
		def.frame_size, def.idle_hframes, def.walk_right_hframes, def.walk_left_hframes, def.walk_fps
	])

func _build_slot(part: StringName, visual: PartVisualDef) -> void:
	var slot := Node2D.new()
	slot.name = "Slot_%s" % part
	add_child(slot)
	if visual != null:
		slot.position = visual.offset
		slot.z_index = visual.z_index
	var base := Sprite2D.new()
	base.name = "BaseLayer"
	base.texture = _placeholder_texture(visual)
	slot.add_child(base)
	var equipment := Sprite2D.new()
	equipment.name = "EquipmentLayer"
	equipment.visible = false
	slot.add_child(equipment)
	var injury := Sprite2D.new()
	injury.name = "InjuryLayer"
	injury.visible = false
	slot.add_child(injury)
	_slots[part] = {"node": slot, "base": base, "equipment": equipment, "injury": injury}

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

func _placeholder_texture(visual: PartVisualDef) -> ImageTexture:
	var color := visual.placeholder_color if visual != null else Color.GRAY
	var size := visual.size if visual != null else Vector2i(16, 16)
	var img := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
