@tool
@icon("res://ui/widgets/icons/layout_region.svg")
class_name UfLayoutRegion
extends Control
## Free-layout zone inside a flow-based ContentSlot (VBoxContainer). Place as a child of ContentSlot
## when you need anchor-based positioning: widgets dropped inside use the 2D editor to move and resize
## with the mouse. Moving this region (or its parent panel) keeps child offsets relative to the region.
##
## [UfEquipmentSlot] children with [member UfEquipmentSlot.layout_center_anchored] keep a fixed pixel
## size and reposition from the region center when the region is resized.
##
## Scene inheritance: open a child panel (e.g. [code]uf_inspection_quadruped.tscn[/code]), select a slot
## under this region, move it in the 2D editor or edit [member UfEquipmentSlot.layout_center_norm] in the
## Inspector. Saving stores only that override; anchor mode and other slot settings stay inherited.
##
## Region size and [member layout_reference_size] are authored in
## [code]ui/templates/uf_panel_ingame_inspection.tscn[/code]; script defaults are minimal fallbacks.

const _MIN_AXIS := 16.0

@export var region_min_size: Vector2 = Vector2(_MIN_AXIS, _MIN_AXIS):
	set(value):
		region_min_size = value.max(Vector2(_MIN_AXIS, _MIN_AXIS))
		_sync_min_size()

## Authoring reference for [member UfEquipmentSlot.layout_center_norm]. Set in inspection template;
## when zero, [method resolved_reference_size] uses the region's current size.
@export var layout_reference_size: Vector2 = Vector2.ZERO:
	set(value):
		layout_reference_size = value
		if layout_reference_size.x > 0.0 and layout_reference_size.y > 0.0:
			layout_reference_size = layout_reference_size.max(Vector2(_MIN_AXIS, _MIN_AXIS))
		_request_layout()

var _layout_pending: bool = false
var _suppress_child_sync: bool = false
var _pending_sync_slots: Dictionary = {}

func should_suppress_editor_sync() -> bool:
	return _suppress_child_sync

func register_pending_slot_sync(slot: UfEquipmentSlot) -> void:
	if slot == null:
		return
	_pending_sync_slots[slot.get_instance_id()] = slot

func unregister_pending_slot_sync(slot: UfEquipmentSlot) -> void:
	if slot == null:
		return
	_pending_sync_slots.erase(slot.get_instance_id())

func mark_editor_slot_user_edit(slot: UfEquipmentSlot) -> void:
	register_pending_slot_sync(slot)

func resolved_reference_size() -> Vector2:
	if size.x >= _MIN_AXIS and size.y >= _MIN_AXIS:
		return size
	if layout_reference_size.x >= _MIN_AXIS and layout_reference_size.y >= _MIN_AXIS:
		return layout_reference_size
	return Vector2(_MIN_AXIS, _MIN_AXIS)

func _enter_tree() -> void:
	_sync_min_size()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
	_connect_ancestor_resize_signals()
	_request_layout()

func _ready() -> void:
	_request_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_request_layout()

func _sync_min_size() -> void:
	custom_minimum_size = region_min_size

func _connect_ancestor_resize_signals() -> void:
	var node := get_parent()
	while node is Control:
		var control := node as Control
		if not control.resized.is_connected(_on_ancestor_resized):
			control.resized.connect(_on_ancestor_resized)
		node = control.get_parent()

func _on_resized() -> void:
	_request_layout()
	queue_redraw()

func _on_ancestor_resized() -> void:
	_suppress_child_sync = true
	_layout_pending = false
	call_deferred("_request_layout_after_resize_settle")

func _request_layout_after_resize_settle() -> void:
	call_deferred("_request_layout")
	call_deferred("_release_child_sync_suppress")

func _release_child_sync_suppress() -> void:
	call_deferred("_release_child_sync_suppress_deferred")

func _release_child_sync_suppress_deferred() -> void:
	_suppress_child_sync = false
	if Engine.is_editor_hint() and not _pending_sync_slots.is_empty():
		var pending: Array = _pending_sync_slots.values()
		_pending_sync_slots.clear()
		for slot in pending:
			if is_instance_valid(slot) and slot is UfEquipmentSlot:
				(slot as UfEquipmentSlot).flush_pending_editor_sync()

func _on_child_entered_tree(node: Node) -> void:
	if Engine.is_editor_hint():
		return
	if node is UfEquipmentSlot or _contains_equipment_slot(node):
		_request_layout()

func _contains_equipment_slot(node: Node) -> bool:
	if node is UfEquipmentSlot:
		return true
	for child in node.get_children():
		if _contains_equipment_slot(child):
			return true
	return false

func _for_each_equipment_slot(callback: Callable) -> void:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is UfEquipmentSlot:
				callback.call(child)
			elif child.get_child_count() > 0:
				stack.append(child)

func _request_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	call_deferred("_deferred_layout_center_anchored_children")

func _deferred_layout_center_anchored_children() -> void:
	_layout_pending = false
	if not is_inside_tree() or size.x < 1.0 or size.y < 1.0:
		return
	_suppress_child_sync = true
	_for_each_equipment_slot(_layout_center_anchored_child)
	call_deferred("_release_child_sync_suppress")

func _layout_center_anchored_children() -> void:
	_request_layout()

func _layout_center_anchored_child(child: Node) -> void:
	if not child is UfEquipmentSlot:
		return
	var slot := child as UfEquipmentSlot
	if not slot.layout_center_anchored:
		if slot.layout_center_norm.is_zero_approx():
			_bootstrap_slot_center_anchor(slot)
		else:
			slot.enable_center_anchor_from_scene_norm()
	if not slot.layout_center_anchored:
		return
	if Engine.is_editor_hint() and _pending_sync_slots.has(slot.get_instance_id()):
		return
	slot.begin_layout_apply()
	slot.top_level = false
	var half := slot.layout_fixed_size * 0.5
	var region_center := size * 0.5
	var offset := Vector2(
		slot.layout_center_norm.x * size.x,
		slot.layout_center_norm.y * size.y,
	)
	var region_pos := region_center + offset - half
	var new_pos := region_pos
	var slot_parent := slot.get_parent() as Control
	if slot_parent != null and slot_parent != self:
		new_pos = region_pos - slot_parent.position
	slot.layout_mode = 0
	slot.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	slot.anchor_left = 0.0
	slot.anchor_top = 0.0
	slot.anchor_right = 0.0
	slot.anchor_bottom = 0.0
	slot.offset_left = 0.0
	slot.offset_top = 0.0
	slot.offset_right = 0.0
	slot.offset_bottom = 0.0
	slot.position = new_pos
	slot.size = slot.layout_fixed_size
	slot.custom_minimum_size = slot.layout_fixed_size
	slot.end_layout_apply()

func _bootstrap_slot_center_anchor(slot: UfEquipmentSlot) -> void:
	var width := slot.offset_right - slot.offset_left
	var height := slot.offset_bottom - slot.offset_top
	var has_offsets := width >= 8.0 and height >= 8.0
	var fixed_size := slot.layout_fixed_size
	if has_offsets:
		fixed_size = Vector2(width, height)
	var center := Vector2.ZERO
	if has_offsets:
		center = Vector2(
			(slot.offset_left + slot.offset_right) * 0.5,
			(slot.offset_top + slot.offset_bottom) * 0.5,
		)
	elif slot.size.x >= 8.0 and slot.size.y >= 8.0:
		center = slot.position + slot.size * 0.5
	else:
		return
	var ref_size := resolved_reference_size()
	var norm := pixel_center_to_norm(center, ref_size)
	apply_center_anchored_slot(slot, norm, fixed_size)

## Offset of a normalized top-left rect center from region center (0..1 space).
static func norm_rect_center_offset(norm_rect: Rect2) -> Vector2:
	var center := norm_rect.position + norm_rect.size * 0.5
	return Vector2(center.x - 0.5, center.y - 0.5)

## Offset from region center for a pixel center authored on [param reference_size].
static func pixel_center_to_norm(pixel_center: Vector2, reference_size: Vector2) -> Vector2:
	if reference_size.x <= 0.0 or reference_size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		(pixel_center.x - reference_size.x * 0.5) / reference_size.x,
		(pixel_center.y - reference_size.y * 0.5) / reference_size.y,
	)

static func apply_center_anchored_slot(
	slot: UfEquipmentSlot,
	center_norm: Vector2,
	fixed_size: Vector2 = Vector2(40, 40),
) -> void:
	slot.layout_center_anchored = true
	slot.layout_center_norm = center_norm
	slot.layout_fixed_size = fixed_size

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(Vector2.ONE, size - Vector2(2, 2))
	draw_rect(rect, Color(0.35, 0.55, 0.85, 0.12), true)
	draw_rect(rect, Color(0.45, 0.65, 0.95, 0.55), false, 1.0)
	var center := size * 0.5
	draw_line(Vector2(center.x, 0.0), Vector2(center.x, size.y), Color(0.45, 0.65, 0.95, 0.35), 1.0)
	draw_line(Vector2(0.0, center.y), Vector2(size.x, center.y), Color(0.45, 0.65, 0.95, 0.35), 1.0)
