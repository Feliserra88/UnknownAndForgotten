class_name NpcAppearanceController
extends Node2D
## Builds and updates the modular NPC rig: one Slot_<part> per body part, each with
## Base/Equipment/Injury layers (see docs/GAME_DESIGN.md section 5.5). Placeholder build uses
## flat colour rectangles; the API matches the eventual textured rig.

const _LOG := "APP"

var _slots: Dictionary = {}

## Rebuilds every slot from [param archetype]'s body part map and part visuals.
func build_from(archetype: NpcArchetype) -> void:
	for child in get_children():
		child.queue_free()
	_slots.clear()
	var map := archetype.resolve_body_part_map()
	if map == null:
		Log.warn(_LOG, "build_from: archetype %s has no body part map" % archetype.id)
		return
	var visuals := {}
	for v in archetype.resolve_part_visuals():
		visuals[v.part_id] = v
	for part in map.parts:
		_build_slot(part, visuals.get(part, null))

## Refreshes layers from runtime [param _instance] state (orientation, injuries).
func sync_from_instance(_instance: NpcInstanceData) -> void:
	# Placeholder rig is orientation-agnostic; textured rigs swap layer textures here.
	pass

## Shows the equipment layer of [param part] using [param visual] (an EquipmentVisualDef-like
## object exposing base_coverage and get_texture) for [param orientation].
func apply_equipment(part: StringName, visual, orientation: StringName) -> void:
	if not _slots.has(part) or visual == null:
		return
	var slot: Dictionary = _slots[part]
	slot.base.visible = visual.base_coverage != &"full"
	var tex: Texture2D = visual.get_texture(orientation)
	slot.equipment.texture = tex
	slot.equipment.visible = tex != null

## Hides the equipment layer of [param part] and restores its base layer.
func clear_equipment(part: StringName) -> void:
	if not _slots.has(part):
		return
	var slot: Dictionary = _slots[part]
	slot.equipment.visible = false
	slot.base.visible = true

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

func _placeholder_texture(visual: PartVisualDef) -> ImageTexture:
	var color := visual.placeholder_color if visual != null else Color.GRAY
	var size := visual.size if visual != null else Vector2i(16, 16)
	var img := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
