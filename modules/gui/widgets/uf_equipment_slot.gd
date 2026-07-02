@tool
@icon("res://ui/widgets/icons/equipment_slot.svg")
class_name UfEquipmentSlot
extends UfItemSlot
## Square slot for equipment inspection (see docs/GAME_DESIGN.md section 10.6). Same as
## [class UfItemSlot] but uses payload [code]uf_equipment_item[/code] for equip-only drag sources.
##
## Layout is authored in [code]ui/templates/uf_panel_ingame_inspection.tscn[/code] (reference) and
## overridden per creature in [code]ui/panels/inspection/[/code]. Script defaults are fallbacks only.

## Drag payload type shared with the compatible-items list drag source.
const PAYLOAD_TYPE := "uf_equipment_item"

## Default square slot size; mirrored in [code]uf_equipment_slot.tscn[/code].
const DEFAULT_FIXED_SIZE := Vector2(40, 40)

@export_group("Layout (UfLayoutRegion)")
## Enabled in [code]uf_equipment_slot.tscn[/code] and inspection template; script default is off.
@export var layout_center_anchored: bool = false:
	set(value):
		layout_center_anchored = value
		_request_parent_layout()

## Offset from region center (fraction of region width/height). Author in template / panel scene.
@export var layout_center_norm: Vector2 = Vector2.ZERO:
	set(value):
		layout_center_norm = value
		if not _suppress_layout_request:
			_request_parent_layout()

## Fixed pixel size; prefab + template set [constant DEFAULT_FIXED_SIZE].
@export var layout_fixed_size: Vector2 = DEFAULT_FIXED_SIZE:
	set(value):
		layout_fixed_size = value.max(Vector2(8, 8))
		if not _suppress_layout_request:
			_request_parent_layout()

var _layout_apply_depth: int = 0
var _suppress_layout_request: bool = false
var _editor_sync_scheduled: bool = false

const _EDITOR_LAYOUT_PROPS: Array[StringName] = [
	&"position",
	&"offset_left",
	&"offset_top",
	&"offset_right",
	&"offset_bottom",
	&"size",
]

func _get_layout_region() -> UfLayoutRegion:
	var node: Node = self
	while node != null:
		if node is UfLayoutRegion:
			return node as UfLayoutRegion
		node = node.get_parent()
	return null

func _set(property: StringName, _value: Variant) -> bool:
	if Engine.is_editor_hint() and property in _EDITOR_LAYOUT_PROPS:
		_queue_editor_layout_sync(&"_set", property)
	return false

func _queue_editor_layout_sync(_source: StringName, _detail: StringName = &"") -> void:
	var region := _get_layout_region()
	if region != null:
		region.mark_editor_slot_user_edit(self)
	if _editor_sync_scheduled:
		return
	_editor_sync_scheduled = true
	call_deferred("_run_deferred_editor_sync")

func _run_deferred_editor_sync() -> void:
	_editor_sync_scheduled = false
	_sync_layout_from_editor_if_allowed()

func flush_pending_editor_sync() -> void:
	_sync_layout_from_editor()

func _sync_layout_from_editor_if_allowed() -> void:
	var region := _get_layout_region()
	if _is_layout_applying():
		if region != null:
			region.register_pending_slot_sync(self)
		return
	if region != null and region.should_suppress_editor_sync():
		region.register_pending_slot_sync(self)
		return
	_sync_layout_from_editor()

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		if not resized.is_connected(_on_editor_layout_changed):
			resized.connect(_on_editor_layout_changed)
		call_deferred("_editor_ensure_anchored_from_scene")

func enable_center_anchor_from_scene_norm() -> void:
	if layout_center_anchored:
		return
	_suppress_layout_request = true
	layout_center_anchored = true
	_suppress_layout_request = false

func _editor_ensure_anchored_from_scene() -> void:
	if not Engine.is_editor_hint() or _is_layout_applying():
		return
	var region := _get_layout_region()
	if region == null:
		return
	if not layout_center_norm.is_zero_approx():
		enable_center_anchor_from_scene_norm()
		return
	if layout_center_anchored:
		return
	var width := offset_right - offset_left
	var height := offset_bottom - offset_top
	if width < 8.0 or height < 8.0:
		return
	layout_center_anchored = true
	_sync_layout_from_editor()

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_TRANSFORM_CHANGED and not _is_layout_applying():
		_queue_editor_layout_sync(&"transform_changed")

func begin_layout_apply() -> void:
	_layout_apply_depth += 1

func end_layout_apply() -> void:
	_layout_apply_depth = maxi(_layout_apply_depth - 1, 0)

func _is_layout_applying() -> bool:
	return _layout_apply_depth > 0

func _on_editor_layout_changed() -> void:
	if not _is_layout_applying():
		_queue_editor_layout_sync(&"resized")

func _sync_layout_from_editor() -> void:
	if not Engine.is_editor_hint() or _is_layout_applying():
		return
	var region := _get_layout_region()
	if region != null and region.should_suppress_editor_sync():
		region.register_pending_slot_sync(self)
		return
	if not layout_center_anchored:
		return
	if region == null:
		return
	var region_size := region.size
	if region_size.x < 16.0 or region_size.y < 16.0:
		region_size = region.resolved_reference_size()
	var rect := get_rect()
	var slot_size := rect.size
	if slot_size.x < 8.0 or slot_size.y < 8.0:
		slot_size = layout_fixed_size
		rect.size = slot_size
	var slot_parent := get_parent() as Control
	var center := rect.position + slot_size * 0.5
	if slot_parent != null and slot_parent != region:
		center += slot_parent.position
	if not slot_size.is_equal_approx(layout_fixed_size):
		_set_layout_fixed_size_silent(slot_size)
	var norm := UfLayoutRegion.pixel_center_to_norm(center, region_size)
	if layout_center_norm.is_equal_approx(norm):
		region.unregister_pending_slot_sync(self)
		return
	_set_layout_center_norm_silent(norm)
	region.unregister_pending_slot_sync(self)

func _set_layout_center_norm_silent(value: Vector2) -> void:
	_suppress_layout_request = true
	layout_center_norm = value
	_suppress_layout_request = false
	notify_property_list_changed()
	_mark_editor_scene_dirty()

func _set_layout_fixed_size_silent(value: Vector2) -> void:
	_suppress_layout_request = true
	layout_fixed_size = value
	_suppress_layout_request = false
	_mark_editor_scene_dirty()

func _mark_editor_scene_dirty() -> void:
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()

func get_payload_type() -> StringName:
	return &"uf_equipment_item"

func _request_parent_layout() -> void:
	if _suppress_layout_request or _is_layout_applying():
		return
	var region := _get_layout_region()
	if region != null:
		region._layout_center_anchored_children()
