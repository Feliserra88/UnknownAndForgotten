@tool
extends VBoxContainer
## Flow of tag chips for list filtering (toggle) or palette (drag source).

signal filter_changed(active_tags: Array[StringName])
signal palette_tag_selected(tag_id: StringName)

const _CHIP := preload("res://addons/uf_item_editor/tag_chip.gd")
const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")

var _mode: int = _CHIP.Mode.FILTER
var _items: ItemsModule
var _flow: FlowContainer
var _active: Dictionary = {}

func _init() -> void:
	_flow = FlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 6)
	_flow.add_theme_constant_override("v_separation", 6)
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_flow)

func configure(mode: int, items: ItemsModule, category_id: StringName) -> void:
	_mode = mode
	_items = items
	_active.clear()
	_rebuild(items.list_tag_defs(category_id))

func refresh(category_id: StringName) -> void:
	if _items == null:
		return
	_rebuild(_items.list_tag_defs(category_id))

func get_active_filter_tags() -> Array[StringName]:
	var out: Array[StringName] = []
	for key in _active.keys():
		if _active[key]:
			out.append(StringName(key))
	return out

func clear_filter() -> void:
	_active.clear()
	for child in _flow.get_children():
		if child is _CHIP:
			(child as _CHIP).set_filter_active(false)

func _rebuild(defs: Array[ItemTagDef]) -> void:
	for child in _flow.get_children():
		child.queue_free()
	for def in defs:
		if def == null:
			continue
		var chip := _CHIP.new()
		chip.setup(def.id, _tag_label(def), _mode, def.chip_color)
		if _mode == _CHIP.Mode.FILTER:
			var key := String(def.id)
			chip.set_filter_active(_active.get(key, false))
			chip.activated.connect(_on_filter_chip.bind(def.id))
		elif _mode == _CHIP.Mode.PALETTE:
			chip.activated.connect(_on_palette_chip.bind(def.id))
		_flow.add_child(chip)

func _on_palette_chip(tag_id: StringName) -> void:
	palette_tag_selected.emit(tag_id)

func _on_filter_chip(tag_id: StringName) -> void:
	var key := String(tag_id)
	_active[key] = not _active.get(key, false)
	for child in _flow.get_children():
		if child is _CHIP and (child as _CHIP).get_tag_id() == tag_id:
			(child as _CHIP).set_filter_active(_active[key])
			break
	filter_changed.emit(get_active_filter_tags())

func _tag_label(def: ItemTagDef) -> String:
	if def.display_name_key.is_empty():
		return String(def.id)
	return _I18N.translate_key(def.display_name_key)
