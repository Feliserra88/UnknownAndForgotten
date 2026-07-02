@tool
extends PanelContainer
## Tag-filter block + scrollable item list for editor tools (NPC editor, item browser, …).

signal filter_changed(active_tags: Array[StringName])

const _TAG_FLOW := preload("res://addons/uf_item_editor/tag_flow.gd")
const _TAG_CHIP := preload("res://addons/uf_item_editor/tag_chip.gd")
const _BLOCK := preload("res://addons/uf_item_editor/editor_block.gd")
const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")
const _TITLE_KEY := "item_editor.block.items"

var _items: ItemsModule
var _tag_flow: _TAG_FLOW
var _scroll: ScrollContainer
var _list_box: VBoxContainer

var _tag_category_id: StringName = &""
var _filter_category_id: StringName = &""
var _archetype_tags: Array = []
var _exclude_placeholders: bool = true
var _equippable_only: bool = false
var _row_builder: Callable = Callable()
var _empty_message: String = ""

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _BLOCK.make_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(inner)

	_I18N.ensure_loaded()
	var header := Label.new()
	header.text = _I18N.translate_key(_TITLE_KEY)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0))
	header.custom_minimum_size = Vector2(0, 18)
	inner.add_child(header)

	_tag_flow = _TAG_FLOW.new()
	_tag_flow.filter_changed.connect(_on_tag_filter_changed)
	inner.add_child(_tag_flow)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inner.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list_box)

## Binds [param items] and configures the tag chip palette ([param tag_category_id] empty = all tags).
func setup(items: ItemsModule, tag_category_id: StringName = &"", list_min_height: int = 160) -> void:
	_items = items
	_tag_category_id = tag_category_id
	_scroll.custom_minimum_size = Vector2(0, list_min_height)
	_tag_flow.configure(_TAG_CHIP.Mode.FILTER, items, tag_category_id)

## Sets list query options: [code]archetype_tags[/code], [code]category_id[/code], [code]row_builder[/code], …
func configure_query(options: Dictionary) -> void:
	_filter_category_id = options.get("category_id", &"")
	_archetype_tags = options.get("archetype_tags", [])
	_exclude_placeholders = options.get("exclude_placeholders", true)
	_equippable_only = options.get("equippable_only", false)
	_row_builder = options.get("row_builder", Callable())
	_empty_message = options.get("empty_message", "")

func set_archetype_tags(tags: Array) -> void:
	_archetype_tags = tags

func get_scroll() -> ScrollContainer:
	return _scroll

func count_matching() -> int:
	return _query_defs().size()

func refresh() -> void:
	_clear_list()
	if _items == null:
		return
	var defs := _query_defs()
	if defs.is_empty():
		_add_empty_row()
		return
	if not _row_builder.is_valid():
		return
	for def in defs:
		var row: Control = _row_builder.call(def) as Control
		if row != null:
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_list_box.add_child(row)

func refresh_tag_picker() -> void:
	if _tag_flow != null and _items != null:
		_tag_flow.refresh(_tag_category_id)

func _query_defs() -> Array[ItemDef]:
	var filter: Dictionary = {"exclude_placeholders": _exclude_placeholders}
	if not String(_filter_category_id).is_empty():
		filter["category_id"] = _filter_category_id
	var tag_filter := _tag_flow.get_active_filter_tags() if _tag_flow != null else []
	if not tag_filter.is_empty():
		filter["tags_any"] = tag_filter
	var defs := _items.list_defs(filter)
	var out: Array[ItemDef] = []
	for item in defs:
		if _equippable_only and String(item.get_equip_slot()).is_empty():
			continue
		if not _archetype_tags.is_empty() and not item.allows_archetype(_archetype_tags):
			continue
		out.append(item)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		return String(a.id) < String(b.id)
	)
	return out

func _clear_list() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.free()

func _add_empty_row() -> void:
	var label := Label.new()
	label.text = _empty_message if not _empty_message.is_empty() else "—"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	_list_box.add_child(label)

func _on_tag_filter_changed(active_tags: Array[StringName]) -> void:
	refresh()
	filter_changed.emit(active_tags)
