@tool
@icon("res://ui/widgets/icons/equipment_slot.svg")
class_name UfEquipmentSlot
extends Panel
## Square slot cell for an inspection panel (see docs/GAME_DESIGN.md section 10.6). Presentational
## only: it displays an icon and carries an opaque payload while dragging; it never imports domain
## types (ItemDef, EquipmentState). The owner interprets payloads and wires domain logic.

## Drag payload type shared with the compatible-items list drag source.
const PAYLOAD_TYPE := "uf_equipment_item"

signal item_dropped(slot_id: StringName, payload: Dictionary)
signal item_removed(slot_id: StringName)
signal slot_activated(slot_id: StringName)

@export var slot_id: StringName = &"":
	set(value):
		slot_id = value
		tooltip_text = String(value)

var _icon: TextureRect
var _item_id: StringName = &""

func _ready() -> void:
	if _icon == null:
		_icon = TextureRect.new()
		_icon.name = "Icon"
		_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
	mouse_filter = Control.MOUSE_FILTER_STOP

## Displays [param item_id] with [param tex] as its icon (empty id clears the slot).
func set_item(item_id: StringName, tex: Texture2D) -> void:
	_item_id = item_id
	if _icon != null:
		_icon.texture = tex

## Clears any item shown in this slot.
func clear_item() -> void:
	_item_id = &""
	if _icon != null:
		_icon.texture = null

## Returns the item id currently shown, or &"" when empty.
func item_id() -> StringName:
	return _item_id

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			slot_activated.emit(slot_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not String(_item_id).is_empty():
			clear_item()
			item_removed.emit(slot_id)
			accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if String(_item_id).is_empty():
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture if _icon != null else null
	preview.custom_minimum_size = size
	preview.size = size
	set_drag_preview(preview)
	return {"type": PAYLOAD_TYPE, "item_id": _item_id, "from_slot": slot_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == PAYLOAD_TYPE

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	item_dropped.emit(slot_id, data)
