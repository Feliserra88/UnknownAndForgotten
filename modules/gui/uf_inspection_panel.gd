@tool
@icon("res://ui/templates/icons/inspection.svg")
class_name UfInspectionPanel
extends UfInfoPanel
## Reusable NPC inspection panel (see docs/GAME_DESIGN.md section 10.6): a background silhouette with
## anchored square slots, built from an InspectionLayoutDef. Used both in-game (inspect an NPC) and by
## the uf_npc_editor. Presentational only; it relays slot signals and never touches domain modules.

const _SlotScript := preload("res://modules/gui/widgets/uf_equipment_slot.gd")

signal item_dropped(slot_id: StringName, payload: Dictionary)
signal item_removed(slot_id: StringName)
signal slot_activated(slot_id: StringName)

var _slots: Dictionary = {}
var _region: UfLayoutRegion

## Rebuilds the panel from [param layout]: background TextureRect + one square slot per layout entry.
func build_from_layout(layout: InspectionLayoutDef) -> void:
	_slots.clear()
	var content := get_content_slot()
	if content == null or layout == null:
		return
	for child in content.get_children():
		child.queue_free()
	_region = UfLayoutRegion.new()
	_region.name = "InspectionArea"
	var region_size := layout.background_size
	if region_size.x < 16.0 or region_size.y < 16.0:
		region_size = Vector2(220, 320)
	_region.region_min_size = region_size
	content.add_child(_region)

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = layout.background_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_region.add_child(background)

	for entry in layout.slots:
		var slot_id := StringName(entry.get("slot_id", &""))
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.size == Vector2.ZERO:
			continue
		_add_slot(slot_id, rect)

## Sets [param item_id] with [param tex] on the slot [param slot_id], if present.
func set_slot_item(slot_id: StringName, item_id: StringName, tex: Texture2D) -> void:
	var slot := _slots.get(slot_id, null) as UfEquipmentSlot
	if slot != null:
		slot.set_item(item_id, tex)

## Clears the item shown in slot [param slot_id], if present.
func clear_slot(slot_id: StringName) -> void:
	var slot := _slots.get(slot_id, null) as UfEquipmentSlot
	if slot != null:
		slot.clear_item()

## Returns the slot ids currently built by this panel.
func slot_ids() -> Array:
	return _slots.keys()

func _add_slot(slot_id: StringName, rect: Rect2) -> void:
	var slot := _SlotScript.new() as UfEquipmentSlot
	slot.slot_id = slot_id
	slot.name = "Slot_%s" % slot_id
	slot.custom_minimum_size = Vector2(28, 28)
	slot.set_anchor(SIDE_LEFT, rect.position.x)
	slot.set_anchor(SIDE_TOP, rect.position.y)
	slot.set_anchor(SIDE_RIGHT, rect.position.x + rect.size.x)
	slot.set_anchor(SIDE_BOTTOM, rect.position.y + rect.size.y)
	slot.offset_left = 0.0
	slot.offset_top = 0.0
	slot.offset_right = 0.0
	slot.offset_bottom = 0.0
	_region.add_child(slot)
	_slots[slot_id] = slot
	slot.item_dropped.connect(_on_slot_item_dropped)
	slot.item_removed.connect(_on_slot_item_removed)
	slot.slot_activated.connect(_on_slot_activated)

func _on_slot_item_dropped(slot_id: StringName, payload: Dictionary) -> void:
	item_dropped.emit(slot_id, payload)

func _on_slot_item_removed(slot_id: StringName) -> void:
	item_removed.emit(slot_id)

func _on_slot_activated(slot_id: StringName) -> void:
	slot_activated.emit(slot_id)
