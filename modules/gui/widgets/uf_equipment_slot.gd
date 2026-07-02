@tool
@icon("res://ui/widgets/icons/equipment_slot.svg")
class_name UfEquipmentSlot
extends UfItemSlot
## Square slot for equipment inspection (see docs/GAME_DESIGN.md section 10.6). Same as
## [class UfItemSlot] but uses payload [code]uf_equipment_item[/code] for equip-only drag sources.
##
## Inside [UfLayoutRegion], enable [member layout_center_anchored] for fixed-size slots positioned
## relative to the region center. In inherited panel scenes, move the slot in the 2D editor (or edit
## [member layout_center_norm]) to override only position; other settings stay from the template.

## Drag payload type shared with the compatible-items list drag source.
const PAYLOAD_TYPE := "uf_equipment_item"

## Keep [member layout_fixed_size] and position from parent [UfLayoutRegion] center.
@export var layout_center_anchored: bool = false:
	set(value):
		layout_center_anchored = value
		_request_parent_layout()

## Offset from region center in units of region width/height (e.g. 0.1 = 10% right of center).
@export var layout_center_norm: Vector2 = Vector2.ZERO:
	set(value):
		layout_center_norm = value
		if not _suppress_layout_request:
			_request_parent_layout()

## Square size in pixels; does not scale when the panel is resized.
@export var layout_fixed_size: Vector2 = Vector2(40, 40):
	set(value):
		layout_fixed_size = value.max(Vector2(8, 8))
		if not _suppress_layout_request:
			_request_parent_layout()

var _layout_apply_depth: int = 0
var _suppress_layout_request: bool = false

const _EDITOR_LAYOUT_PROPS: Array[StringName] = [
	&"position",
	&"offset_left",
	&"offset_top",
	&"offset_right",
	&"offset_bottom",
	&"size",
]

func _set(property: StringName, value: Variant) -> bool:
	if Engine.is_editor_hint() and property in _EDITOR_LAYOUT_PROPS:
		call_deferred("_sync_layout_from_editor")
	return false

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		if not resized.is_connected(_on_editor_layout_changed):
			resized.connect(_on_editor_layout_changed)

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		call_deferred("_sync_layout_from_editor")

func begin_layout_apply() -> void:
	_layout_apply_depth += 1

func end_layout_apply() -> void:
	_layout_apply_depth = maxi(_layout_apply_depth - 1, 0)

func _is_layout_applying() -> bool:
	return _layout_apply_depth > 0

func _on_editor_layout_changed() -> void:
	call_deferred("_sync_layout_from_editor")

func _sync_layout_from_editor() -> void:
	if not Engine.is_editor_hint() or _is_layout_applying():
		return
	if not layout_center_anchored:
		return
	var region := get_parent() as UfLayoutRegion
	if region == null:
		return
	var region_size := region.size
	if region_size.x < 1.0 or region_size.y < 1.0:
		region_size = region.layout_reference_size
	var rect := get_rect()
	var slot_size := rect.size
	if slot_size.x < 8.0 or slot_size.y < 8.0:
		slot_size = layout_fixed_size
		rect.size = slot_size
	if not slot_size.is_equal_approx(layout_fixed_size):
		_set_layout_fixed_size_silent(slot_size)
	var center := rect.position + slot_size * 0.5
	var norm := UfLayoutRegion.pixel_center_to_norm(center, region_size)
	if layout_center_norm.is_equal_approx(norm):
		return
	_set_layout_center_norm_silent(norm)

func _set_layout_center_norm_silent(value: Vector2) -> void:
	_suppress_layout_request = true
	layout_center_norm = value
	_suppress_layout_request = false
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
	var parent := get_parent()
	if parent is UfLayoutRegion:
		parent._layout_center_anchored_children()
