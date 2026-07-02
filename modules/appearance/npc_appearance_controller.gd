@tool
class_name NpcAppearanceController
extends Node2D
## Builds and updates the NPC visual rig: cutout slots or a full-body AnimatedSprite2D
## driven by an NpcSpriteAnimDef (idle 8-way sheet + walk sheets per facing).

const _LOG := "APP"

var _slots: Dictionary = {}
var _equipment_visuals: Dictionary = {}
var _animated_sprite: AnimatedSprite2D
var _sprite_def: Resource
var _orientation: StringName = &"front"
var _is_moving: bool = false

## Rebuilds the rig from [param archetype]: sprite sheet mode when sprite_anim is set, else cutout.
func build_from(archetype: NpcArchetype) -> void:
	_clear_children()
	_slots.clear()
	_equipment_visuals.clear()
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
	_refresh_cutout_layers()

## Refreshes layers from runtime [param instance] state (orientation, equipment).
func sync_from_instance(instance: NpcInstanceData, equipment: EquipmentModule = null) -> void:
	if instance == null:
		return
	set_orientation(instance.orientation)
	if _animated_sprite != null or _slots.is_empty() or equipment == null:
		return
	for slot_id in instance.equipment.occupied_slots():
		var inst := instance.equipment.get_instance(slot_id)
		if inst == null:
			continue
		var visual := equipment.resolve_visual(inst.def_id)
		if visual != null:
			apply_equipment(slot_id, visual)
		else:
			clear_equipment(slot_id)

## Applies [param visual] on the anatomical slot (cutout rig only).
func apply_equipment(equip_slot: StringName, visual: EquipmentVisualDef) -> void:
	if visual == null:
		clear_equipment(equip_slot)
		return
	var part_id := visual.slot if not visual.slot.is_empty() else equip_slot
	_equipment_visuals[part_id] = visual
	_refresh_cutout_layers()

## Clears equipment visuals on [param equip_slot]'s anatomical part.
func clear_equipment(equip_slot: StringName) -> void:
	var part_id := equip_slot
	for pid in _equipment_visuals.keys():
		var visual: EquipmentVisualDef = _equipment_visuals[pid]
		if visual != null and (visual.slot == equip_slot or pid == equip_slot):
			part_id = pid
			break
	_equipment_visuals.erase(part_id)
	var slot: Dictionary = _slots.get(part_id, {})
	var layer := slot.get("equipment", null) as CanvasItem
	if layer != null:
		layer.visible = false
		if layer is Sprite2D:
			(layer as Sprite2D).texture = null
	_apply_cutout_base(slot, _resolved_view(), _resolved_flip_h())

## Shows [param tex] on the EquipmentLayer of [param part_id]'s slot (cutout rig only).
## Fallback when no EquipmentVisualDef exists. No-op in sprite-sheet mode.
func set_equipment_texture(part_id: StringName, tex: Texture2D) -> void:
	var slot: Dictionary = _slots.get(part_id, {})
	var layer := slot.get("equipment", null) as Sprite2D
	if layer == null:
		return
	layer.texture = tex
	layer.visible = tex != null
	layer.flip_h = false
	if tex != null:
		var ref_size := _reference_sprite_size(slot)
		var tex_size := tex.get_size()
		if ref_size.x > 0.0 and ref_size.y > 0.0 and tex_size.x > 0.0 and tex_size.y > 0.0:
			layer.scale = Vector2(ref_size.x / tex_size.x, ref_size.y / tex_size.y)
		else:
			layer.scale = Vector2.ONE

## Hides and clears the EquipmentLayer of [param part_id]'s slot.
func clear_equipment_texture(part_id: StringName) -> void:
	set_equipment_texture(part_id, null)

## Returns the anatomical part ids that currently have a built slot (cutout rig).
func slot_part_ids() -> Array:
	return _slots.keys()

## Sets facing direction and refreshes the active idle or walk animation.
func set_orientation(orientation: StringName) -> void:
	_orientation = orientation
	if _animated_sprite != null and _sprite_def != null:
		_animated_sprite.flip_h = false
		_refresh_animation()
		return
	_refresh_cutout_layers()

## Switches between walk loops and idle poses for the active orientation.
func set_moving(moving: bool) -> void:
	_is_moving = moving
	if _animated_sprite != null:
		_refresh_animation()
		return
	_refresh_cutout_layers()

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

func _refresh_cutout_layers() -> void:
	if _slots.is_empty():
		return
	var view := _resolved_view()
	var flip_h := _resolved_flip_h()
	for part_id in _slots:
		var slot: Dictionary = _slots[part_id]
		_apply_cutout_base(slot, view, flip_h)
		_apply_cutout_equipment(slot, view, flip_h)
		_apply_cutout_injury(slot, view, flip_h)

func _resolved_view() -> StringName:
	return CutoutOrientation.resolve(_orientation).get("view", &"front") as StringName

func _resolved_flip_h() -> bool:
	return bool(CutoutOrientation.resolve(_orientation).get("flip_h", false))

func _apply_cutout_base(slot: Dictionary, view: StringName, flip_h: bool) -> void:
	if slot.is_empty():
		return
	var tex_key := CutoutOrientation.texture_key(view, flip_h)
	var base: Node = slot.get("base") as Node
	var visual: PartVisualDef = slot.get("visual") as PartVisualDef
	var part_id: StringName = slot.get("part_id", &"")
	var equipment_visual: EquipmentVisualDef = _equipment_visuals.get(part_id) as EquipmentVisualDef
	var hide_base := (
		equipment_visual != null
		and equipment_visual.base_coverage == EquipmentVisualDef.Coverage.FULL
	)
	if base is AnimatedSprite2D:
		var anim_sprite := base as AnimatedSprite2D
		anim_sprite.visible = not hide_base
		if hide_base:
			return
		anim_sprite.flip_h = flip_h and view == &"side_left"
		var anim := _cutout_anim_name(tex_key, visual != null and visual.get_walk_texture(tex_key) != null)
		if not anim_sprite.sprite_frames.has_animation(anim):
			anim = &"idle_front"
		anim_sprite.animation = anim
		var is_walk := _is_moving and String(anim).begins_with("walk_")
		if is_walk:
			if not anim_sprite.is_playing() or anim_sprite.animation != anim:
				anim_sprite.play(anim)
		else:
			anim_sprite.set_frame_and_progress(0, 0.0)
			anim_sprite.stop()
	elif base is Sprite2D:
		var sprite := base as Sprite2D
		sprite.visible = not hide_base
		if hide_base:
			return
		sprite.flip_h = flip_h and view == &"side_left"
		if visual != null:
			var tex := visual.get_texture(tex_key)
			if tex != null:
				sprite.texture = tex

func _apply_cutout_equipment(slot: Dictionary, view: StringName, flip_h: bool) -> void:
	var layer := slot.get("equipment", null) as Sprite2D
	if layer == null:
		return
	var part_id: StringName = slot.get("part_id", &"")
	var visual: EquipmentVisualDef = _equipment_visuals.get(part_id) as EquipmentVisualDef
	if visual == null:
		return
	var tex_key := CutoutOrientation.texture_key(view, flip_h)
	var tex := visual.get_texture(tex_key)
	layer.texture = tex
	layer.visible = tex != null
	layer.flip_h = flip_h and view == &"side_left"
	layer.scale = Vector2.ONE
	if tex != null and visual.z_offset != 0:
		layer.z_index = visual.z_offset

func _apply_cutout_injury(_slot: Dictionary, _view: StringName, _flip_h: bool) -> void:
	pass

func _cutout_anim_name(tex_key: StringName, has_walk: bool) -> StringName:
	if _is_moving and has_walk:
		return StringName("walk_%s" % tex_key)
	return StringName("idle_%s" % tex_key)

func _reference_sprite_size(slot: Dictionary) -> Vector2:
	var base: Node = slot.get("base") as Node
	if base is AnimatedSprite2D:
		var anim := base as AnimatedSprite2D
		if anim.sprite_frames != null and not anim.animation.is_empty():
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				return tex.get_size()
	if base is Sprite2D:
		var tex := (base as Sprite2D).texture
		if tex != null:
			return tex.get_size()
	var visual: PartVisualDef = slot.get("visual") as PartVisualDef
	if visual != null:
		return Vector2(visual.size)
	return Vector2(16, 16)

func _has_any_texture(def: Resource) -> bool:
	return (
		def.get("idle_texture") != null
		or def.get("walk_right_texture") != null
		or def.get("walk_left_texture") != null
		or def.get("walk_front_right_texture") != null
		or def.get("walk_back_right_texture") != null
		or def.get("walk_back_left_texture") != null
		or def.get("walk_front_left_texture") != null
	)

func _build_sprite_rig(def: Resource) -> void:
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "BodySprite"
	_animated_sprite.sprite_frames = def.build_sprite_frames()
	_animated_sprite.position = def.compute_placement_offset()
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
	var base: Node2D
	if visual != null and visual.has_art():
		var anim := AnimatedSprite2D.new()
		anim.name = "BaseLayer"
		anim.sprite_frames = visual.build_sprite_frames()
		base = anim
	else:
		var sprite := Sprite2D.new()
		sprite.name = "BaseLayer"
		sprite.texture = _placeholder_texture(visual)
		base = sprite
	slot.add_child(base)
	var equipment := Sprite2D.new()
	equipment.name = "EquipmentLayer"
	equipment.visible = false
	slot.add_child(equipment)
	var injury := Sprite2D.new()
	injury.name = "InjuryLayer"
	injury.visible = false
	slot.add_child(injury)
	_slots[part] = {
		"node": slot,
		"base": base,
		"equipment": equipment,
		"injury": injury,
		"visual": visual,
		"part_id": part,
	}

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

func _placeholder_texture(visual: PartVisualDef) -> ImageTexture:
	var color := visual.placeholder_color if visual != null else Color.GRAY
	var size := visual.size if visual != null else Vector2i(16, 16)
	var img := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
