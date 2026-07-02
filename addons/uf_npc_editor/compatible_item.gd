@tool
extends "res://addons/uf_item_editor/item_list_row.gd"
## Compatible-items row in the NPC editor: same layout as the item editor list, draggable onto inspection slots.

var _item_id: StringName = &""

## Fills the row from [param row_data] ([method ItemsModule.resolve_list_row]) and enables drag-drop.
func setup_compatible(row_data: Dictionary) -> void:
	_item_id = row_data.get("id", &"")
	setup(row_data, false)
	tooltip_text = String(_item_id)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if String(_item_id).is_empty():
		return null
	var preview := Label.new()
	var key: String = _meta.get("display_name_key", "")
	preview.text = _I18N.translate_key(key) if not key.is_empty() else String(_item_id)
	set_drag_preview(preview)
	return {"type": UfEquipmentSlot.PAYLOAD_TYPE, "item_id": _item_id}
