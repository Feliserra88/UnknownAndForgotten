@tool
extends PanelContainer
## Drop target showing assigned item tags; right-click a chip to remove.

signal tags_changed(tags: Array[StringName])

const _CHIP := preload("res://addons/uf_item_editor/tag_chip.gd")
const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")
const _DROP_BG := Color(0.1, 0.11, 0.13, 0.6)
const _DROP_BORDER := Color(0.28, 0.34, 0.42, 1.0)
const _DROP_HOVER := Color(0.16, 0.22, 0.3, 0.85)
const _EMPTY_H := 40

var _items: ItemsModule
var _tags: Array[StringName] = []
var _flow: FlowContainer
var _hover_drop: bool = false
var _pending_rebuild: bool = false

func _init() -> void:
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_drop_style(false)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(margin)
	_flow = FlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 6)
	_flow.add_theme_constant_override("v_separation", 6)
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_flow.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(_flow)
	if _pending_rebuild:
		_pending_rebuild = false
		_rebuild_chips()

func setup(items: ItemsModule) -> void:
	_items = items

func get_tags() -> Array[StringName]:
	return _tags.duplicate()

func set_tags(tags: Array[StringName]) -> void:
	_tags = _items.normalize_tags(tags, &"") if _items != null else []
	if _flow == null:
		_pending_rebuild = true
		return
	_rebuild_chips()

func _rebuild_chips() -> void:
	if _flow == null:
		_pending_rebuild = true
		return
	_pending_rebuild = false
	for child in _flow.get_children():
		child.queue_free()
	if _tags.is_empty():
		custom_minimum_size = Vector2(0, _EMPTY_H)
		var hint := Label.new()
		hint.text = _I18N.translate_key("item_editor.tags.drop_hint")
		hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.66))
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_flow.add_child(hint)
		return
	custom_minimum_size = Vector2(0, 0)
	for tid in _tags:
		var def := _items.load_tag_def(tid) if _items != null else null
		var color := def.chip_color if def != null else Color(0.32, 0.46, 0.62)
		var label := _tag_label(def, tid)
		var chip := _CHIP.new()
		chip.setup(tid, label, _CHIP.Mode.ASSIGNED, color)
		chip.remove_requested.connect(_on_remove_tag)
		_flow.add_child(chip)

func _on_remove_tag(tag_id: StringName) -> void:
	_tags.erase(tag_id)
	_rebuild_chips()
	tags_changed.emit(_tags.duplicate())

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok := _is_tag_payload(data)
	_set_hover_drop(ok)
	return ok

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_hover_drop(false)
	if not _is_tag_payload(data):
		return
	var tid: StringName = data.get("tag_id", &"")
	if String(tid).is_empty() or _tags.has(tid):
		return
	_tags.append(tid)
	_rebuild_chips()
	tags_changed.emit(_tags.duplicate())

func _is_tag_payload(data: Variant) -> bool:
	return data is Dictionary and data.get("type", &"") == _CHIP.PAYLOAD_TYPE

func _set_hover_drop(hover: bool) -> void:
	if _hover_drop == hover:
		return
	_hover_drop = hover
	_apply_drop_style(hover)

func _apply_drop_style(hover: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = _DROP_HOVER if hover else _DROP_BORDER
	style.bg_color = _DROP_HOVER if hover else _DROP_BG
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", style)

func _tag_label(def: ItemTagDef, tag_id: StringName) -> String:
	if def != null and not def.display_name_key.is_empty():
		return _I18N.translate_key(def.display_name_key)
	return String(tag_id)
