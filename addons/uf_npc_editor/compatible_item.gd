@tool
extends Button
## One draggable entry in the NPC editor's compatible-items list. Emits the same drag payload the
## UfEquipmentSlot widget accepts, so items can be dropped straight onto inspection slots.

var _item_id: StringName = &""

## Configures the button label/icon and the item id carried while dragging.
func setup(item_id: StringName, label: String, icon_tex: Texture2D) -> void:
	_item_id = item_id
	text = label
	tooltip_text = String(item_id)
	if icon_tex != null:
		icon = icon_tex
		expand_icon = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT

func _get_drag_data(_at_position: Vector2) -> Variant:
	if String(_item_id).is_empty():
		return null
	var preview := Label.new()
	preview.text = text
	set_drag_preview(preview)
	return {"type": UfEquipmentSlot.PAYLOAD_TYPE, "item_id": _item_id}
