@tool
@icon("res://ui/widgets/icons/item_slot.svg")
class_name UfItemSlot
extends Panel
## Square slot cell for loot, inventory and other generic item grids (see docs/GAME_DESIGN.md
## section 10.6). Presentational only: icon + opaque drag payload; no domain types.

signal item_dropped(slot_id: StringName, payload: Dictionary)
signal item_removed(slot_id: StringName)
signal slot_activated(slot_id: StringName)

@export var slot_id: StringName = &"":
	set(value):
		slot_id = value
		tooltip_text = String(value)

var _icon: TextureRect
var _item_id: StringName = &""

## Drag payload type for generic items (loot, inventory, …).
func get_payload_type() -> StringName:
	return &"uf_item"

func _ready() -> void:
	_ensure_icon()
	mouse_filter = Control.MOUSE_FILTER_STOP

## Displays [param item_id] with [param tex] as its icon (empty id clears the slot).
func set_item(item_id: StringName, tex: Texture2D) -> void:
	_item_id = item_id
	_ensure_icon()
	_icon.texture = tex

## Clears any item shown in this slot.
func clear_item() -> void:
	_item_id = &""
	if _icon != null:
		_icon.texture = null

## Returns the item id currently shown, or &"" when empty.
func item_id() -> StringName:
	return _item_id

## Returns the icon texture currently shown, or null when empty.
func item_texture() -> Texture2D:
	return _icon.texture if _icon != null else null

func _ensure_icon() -> void:
	if _icon != null:
		return
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

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
	preview.texture = item_texture()
	preview.custom_minimum_size = size
	preview.size = size
	set_drag_preview(preview)
	return {"type": String(get_payload_type()), "item_id": _item_id, "from_slot": slot_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == String(get_payload_type())

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	item_dropped.emit(slot_id, data)
