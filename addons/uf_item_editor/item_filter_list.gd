@tool
extends PanelContainer
## Tag-filter block + scrollable item list for editor tools (NPC editor, item browser, …).

signal filter_changed(active_tags: Array[StringName])
signal item_selected(meta: Dictionary)

const _TAG_FLOW := preload("res://addons/uf_item_editor/tag_flow.gd")
const _TAG_CHIP := preload("res://addons/uf_item_editor/tag_chip.gd")
const _BLOCK := preload("res://addons/uf_item_editor/editor_block.gd")
const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")
const _TITLE_KEY := "item_editor.block.items"

var _items: ItemsModule
var _header_label: Label
var _title_key: String = _TITLE_KEY
var _tag_flow: _TAG_FLOW
var _scroll: ScrollContainer
var _list_box: VBoxContainer
var _built: bool = false
var _pending_setup: Dictionary = {}

var _tag_category_id: StringName = &""
var _filter_category_id: StringName = &""
var _archetype_tags: Array = []
var _exclude_placeholders: bool = true
var _equippable_only: bool = false
var _row_builder: Callable = Callable()
var _list_populator: Callable = Callable()
var _empty_message: String = ""
var _selected_key: String = ""
var _selection_key_fn: Callable = Callable()

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	_ensure_built()
	_refresh_header_label()

func _ensure_built() -> void:
	if _built:
		return
	_built = true
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

	_header_label = Label.new()
	_BLOCK.style_block_header(_header_label)
	inner.add_child(_header_label)

	_tag_flow = _TAG_FLOW.new()
	_tag_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tag_flow.filter_changed.connect(_on_tag_filter_changed)
	inner.add_child(_tag_flow)

	_scroll = ScrollContainer.new()
	_scroll.name = "ItemListScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = 1.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.clip_contents = true
	inner.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.name = "ItemListBox"
	_list_box.add_theme_constant_override("separation", 6)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(_list_box)

	if not _pending_setup.is_empty():
		_apply_setup(_pending_setup)

## Binds [param items] and configures the tag chip palette ([param tag_category_id] empty = all tags).
func setup(items: ItemsModule, tag_category_id: StringName = &"", list_min_height: int = 160) -> void:
	_pending_setup = {
		"items": items,
		"tag_category_id": tag_category_id,
		"list_min_height": list_min_height,
	}
	if _built:
		_apply_setup(_pending_setup)

func _apply_setup(options: Dictionary) -> void:
	_items = options.get("items") as ItemsModule
	_tag_category_id = options.get("tag_category_id", &"")
	var list_min_height: int = int(options.get("list_min_height", 160))
	if _scroll != null:
		_scroll.custom_minimum_size = Vector2(0, list_min_height)
	if _tag_flow != null and _items != null:
		_tag_flow.configure(_TAG_CHIP.Mode.FILTER, _items, _tag_category_id)

## Sets list query options: [code]archetype_tags[/code], [code]category_id[/code], [code]row_builder[/code], …
func configure_query(options: Dictionary) -> void:
	_filter_category_id = options.get("category_id", &"")
	_archetype_tags = options.get("archetype_tags", [])
	_exclude_placeholders = options.get("exclude_placeholders", true)
	_equippable_only = options.get("equippable_only", false)
	_row_builder = options.get("row_builder", Callable())
	_empty_message = options.get("empty_message", "")

func set_title_key(key: String) -> void:
	_title_key = key
	_refresh_header_label()

func refresh_localized_controls() -> void:
	if not is_inside_tree():
		call_deferred("refresh_localized_controls")
		return
	_ensure_built()
	_refresh_header_label()

func _refresh_header_label() -> void:
	if _header_label == null:
		return
	_I18N.ensure_loaded()
	_header_label.text = _I18N.translate_key(_title_key)

func set_archetype_tags(tags: Array) -> void:
	_archetype_tags = tags

func set_list_populator(callable: Callable) -> void:
	_list_populator = callable

func set_tag_category(category_id: StringName) -> void:
	_tag_category_id = category_id
	if _items != null and _tag_flow != null:
		_tag_flow.configure(_TAG_CHIP.Mode.FILTER, _items, category_id)

func set_selection_key_fn(callable: Callable) -> void:
	_selection_key_fn = callable

func get_selection_key() -> String:
	return _selected_key

func set_selection_key(key: String) -> void:
	_selected_key = key
	_apply_row_selection()

func clear_selection() -> void:
	set_selection_key("")

func update_row_selection(is_selected: Callable) -> void:
	if _list_box == null:
		return
	for child in _list_box.get_children():
		if child.has_method("set_selected") and child.has_method("get_meta_data"):
			var meta: Dictionary = child.get_meta_data()
			child.set_selected(is_selected.call(meta))

func get_scroll() -> ScrollContainer:
	_ensure_built()
	return _scroll

func count_matching() -> int:
	_ensure_built()
	return _query_defs().size()

func refresh() -> void:
	_ensure_built()
	_clear_list()
	if _items == null:
		return
	if _list_populator.is_valid():
		var tag_filter := _tag_flow.get_active_filter_tags() if _tag_flow != null else []
		var rows: Array = _list_populator.call(tag_filter)
		if rows.is_empty():
			_add_empty_row()
		else:
			for row in rows:
				if row is Control:
					_add_list_row(row as Control)
		_finish_refresh()
		return
	var defs := _query_defs()
	if defs.is_empty():
		_add_empty_row()
		_finish_refresh()
		return
	if not _row_builder.is_valid():
		_finish_refresh()
		return
	for def in defs:
		var row: Control = _row_builder.call(def) as Control
		if row != null:
			_add_list_row(row)
	_finish_refresh()

func _add_list_row(row: Control) -> void:
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_child(row)
	_wire_row(row)

func _wire_row(row: Control) -> void:
	if row.has_signal("row_selected") and not row.row_selected.is_connected(_on_row_selected):
		row.row_selected.connect(_on_row_selected)

func _on_row_selected(meta: Dictionary) -> void:
	_selected_key = _meta_selection_key(meta)
	_apply_row_selection()
	item_selected.emit(meta)

func _meta_selection_key(meta: Dictionary) -> String:
	if _selection_key_fn.is_valid():
		return String(_selection_key_fn.call(meta))
	return String(meta.get("id", ""))

func _apply_row_selection() -> void:
	update_row_selection(func(meta: Dictionary) -> bool:
		return _meta_selection_key(meta) == _selected_key and not _selected_key.is_empty()
	)

func _finish_refresh() -> void:
	_sync_scroll_area()
	_apply_row_selection()

func refresh_tag_picker() -> void:
	_ensure_built()
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
	if _list_box == null:
		return
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.free()

func _add_empty_row() -> void:
	var label := Label.new()
	label.text = _empty_message if not _empty_message.is_empty() else "—"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	_list_box.add_child(label)
	_sync_scroll_area()

func _sync_scroll_area() -> void:
	if _list_box != null:
		_list_box.queue_sort()
	if _scroll != null:
		call_deferred("_deferred_sync_scroll_area")

func _deferred_sync_scroll_area() -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	_scroll.update_minimum_size()
	_scroll.queue_sort()

func _on_tag_filter_changed(active_tags: Array[StringName]) -> void:
	refresh()
	filter_changed.emit(active_tags)
