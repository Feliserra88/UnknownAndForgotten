@tool
@icon("res://ui/widgets/icons/equipment_slot.svg")
class_name UfEquipmentSlot
extends UfItemSlot
## Square slot for equipment inspection (see docs/GAME_DESIGN.md section 10.6). Same as
## [class UfItemSlot] but uses payload [code]uf_equipment_item[/code] for equip-only drag sources.
##
## Inside [UfLayoutRegion], enable [member layout_center_anchored] for fixed-size slots positioned
## relative to the region center.

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
		_request_parent_layout()

## Square size in pixels; does not scale when the panel is resized.
@export var layout_fixed_size: Vector2 = Vector2(40, 40):
	set(value):
		layout_fixed_size = value.max(Vector2(8, 8))
		_request_parent_layout()

func get_payload_type() -> StringName:
	return &"uf_equipment_item"

func _request_parent_layout() -> void:
	var parent := get_parent()
	if parent is UfLayoutRegion:
		parent._layout_center_anchored_children()
