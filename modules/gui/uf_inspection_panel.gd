@tool
@icon("res://ui/templates/icons/panel_ingame_inspection.svg")
class_name UfInspectionPanel
extends UfPanelIngame
## Reusable NPC inspection panel (see docs/GAME_DESIGN.md section 5.5.5): artist-authored scene under
## [code]ui/panels/equipment/[/code] with [UfEquipmentSlot] nodes. Used in-game and by uf_npc_editor.
## Presentational only; it relays slot signals and never touches domain modules.

const _LabelScript := preload("res://modules/gui/widgets/uf_label.gd")
## Minimum panel footprint (matches ui/templates/uf_panel_ingame_equipment.tscn). Editors must reserve this space.
const PANEL_MIN_SIZE := Vector2(400, 600)
const _PLACEHOLDER_DETAIL_COLOR := Color(1, 0.45, 0.45)
## Maps legacy uf_gui_tools slot node names to equipment slot_id when the saved scene omits slot_id.
const _LEGACY_SLOT_NODE_MAP := {
	&"UfEquipmentHead": &"head",
	&"UfEquipmentLeftHand": &"arm_left",
	&"UfEquipmentRightHand": &"arm_right",
	&"UfEquipmentLegs": &"feet",
	&"UfEquipmentBody": &"body",
	&"UfEquipmentWaist": &"belt",
}

signal item_dropped(slot_id: StringName, payload: Dictionary)
signal item_removed(slot_id: StringName)
signal slot_activated(slot_id: StringName)

var _slots: Dictionary = {}

## Shows an obvious placeholder when the artist panel asset is missing (GAME_DESIGN §5.5.5).
func show_asset_missing_placeholder(failed_path: String = "") -> void:
	_slots.clear()
	var content := get_content_slot()
	if content == null:
		return
	for child in content.get_children():
		child.queue_free()

	var region := UfLayoutRegion.new()
	region.name = "MissingPanelPlaceholder"
	region.region_min_size = PANEL_MIN_SIZE
	content.add_child(region)

	var frame := Panel.new()
	frame.name = "PlaceholderFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.05, 0.05, 0.92)
	style.border_color = Color(1, 0.2, 0.2)
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	frame.add_theme_stylebox_override("panel", style)
	region.add_child(frame)

	var body := VBoxContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(body)

	var label := _LabelScript.new() as UfLabel
	label.name = "MissingPanelLabel"
	label.label_key = "gui.inspection.missing_panel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)

	if not failed_path.is_empty():
		var path_label := Label.new()
		path_label.name = "MissingPanelPath"
		path_label.text = failed_path
		path_label.modulate = _PLACEHOLDER_DETAIL_COLOR
		path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(path_label)

## Indexes UfEquipmentSlot nodes from a saved panel scene and wires slot_id + signals.
## Call after instantiating a scene from InspectionLayoutDef.panel_path.
func bind_scene_slots() -> void:
	_slots.clear()
	var content := get_content_slot()
	if content == null:
		return
	_bind_slots_recursive(content)
	_request_region_layout(content)

func _request_region_layout(node: Node) -> void:
	for child in node.get_children():
		if child is UfLayoutRegion:
			(child as UfLayoutRegion)._layout_center_anchored_children()
		_request_region_layout(child)

func _bind_slots_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is UfEquipmentSlot:
			_register_slot(child as UfEquipmentSlot)
		_bind_slots_recursive(child)

func _register_slot(slot: UfEquipmentSlot) -> void:
	var slot_id := slot.slot_id
	if String(slot_id).is_empty():
		slot_id = _LEGACY_SLOT_NODE_MAP.get(StringName(slot.name), &"")
	if String(slot_id).is_empty():
		return
	slot.slot_id = slot_id
	_slots[slot_id] = slot
	if not slot.item_dropped.is_connected(_on_slot_item_dropped):
		slot.item_dropped.connect(_on_slot_item_dropped)
	if not slot.item_removed.is_connected(_on_slot_item_removed):
		slot.item_removed.connect(_on_slot_item_removed)
	if not slot.slot_activated.is_connected(_on_slot_activated):
		slot.slot_activated.connect(_on_slot_activated)

## Sets [param item_id] with [param tex] on the slot [param slot_id], if present.
func set_slot_item(slot_id: StringName, item_id: StringName, tex: Texture2D) -> void:
	var slot := _slots.get(slot_id, null) as UfEquipmentSlot
	if slot != null:
		slot.set_item(item_id, tex)

## Clears the item shown in slot [param slot_id], if present.
func clear_slot(slot_id: StringName) -> void:
	var slot := _slots.get(slot_id, null) as UfEquipmentSlot
	if slot != null:
		slot.clear_item()

## Returns the slot ids currently built by this panel.
func slot_ids() -> Array:
	return _slots.keys()

func _on_slot_item_dropped(slot_id: StringName, payload: Dictionary) -> void:
	item_dropped.emit(slot_id, payload)

func _on_slot_item_removed(slot_id: StringName) -> void:
	item_removed.emit(slot_id)

func _on_slot_activated(slot_id: StringName) -> void:
	slot_activated.emit(slot_id)
