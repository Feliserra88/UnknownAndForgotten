@tool
@icon("res://ui/widgets/icons/equipment_slot.svg")
class_name UfEquipmentSlot
extends UfItemSlot
## Square slot for equipment inspection (see docs/GAME_DESIGN.md section 10.6). Same as
## [class UfItemSlot] but uses payload [code]uf_equipment_item[/code] for equip-only drag sources.

## Drag payload type shared with the compatible-items list drag source.
const PAYLOAD_TYPE := "uf_equipment_item"

func get_payload_type() -> StringName:
	return &"uf_equipment_item"
