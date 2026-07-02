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

@export var region_min_size: Vector2 = Vector2(240, 160):
	set(value):
		region_min_size = value.max(Vector2(16, 16))
		_sync_min_size()

## Pixel reference used when authoring [member UfEquipmentSlot.layout_center_norm].
@export var layout_reference_size: Vector2 = Vector2(240, 300):
	set(value):
		layout_reference_size = value.max(Vector2(16, 16))
		_request_layout()

var _layout_pending: bool = false

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
	_request_layout()
	call_deferred("_request_layout_after_frame")

func _request_layout_after_frame() -> void:
	_layout_pending = false
	_request_layout()

func _on_child_entered_tree(node: Node) -> void:
	if node is UfEquipmentSlot and (node as UfEquipmentSlot).layout_center_anchored:
		_request_layout()

func _request_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	call_deferred("_deferred_layout_center_anchored_children")

func _deferred_layout_center_anchored_children() -> void:
	_layout_pending = false
	if not is_inside_tree() or size.x < 1.0 or size.y < 1.0:
		return
	for child in get_children():
		_layout_center_anchored_child(child)

func _layout_center_anchored_children() -> void:
	_request_layout()

func _layout_center_anchored_child(child: Node) -> void:
	if not child is UfEquipmentSlot:
		return
	var slot := child as UfEquipmentSlot
	if not slot.layout_center_anchored:
		_bootstrap_slot_center_anchor(slot)
	if not slot.layout_center_anchored:
		return
	var half := slot.layout_fixed_size * 0.5
	var region_center := size * 0.5
	var offset := Vector2(
		slot.layout_center_norm.x * size.x,
		slot.layout_center_norm.y * size.y,
	)
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
	slot.position = region_center + offset - half
	slot.size = slot.layout_fixed_size
	slot.custom_minimum_size = slot.layout_fixed_size

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
	var norm := pixel_center_to_norm(center, layout_reference_size)
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
