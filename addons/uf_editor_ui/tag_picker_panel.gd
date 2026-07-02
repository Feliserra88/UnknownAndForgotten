@tool
extends PanelContainer
## Tabbed tag picker for the item editor (toggle selection + list filtering).

signal tags_changed(tags: Array[StringName])

const _BLOCK := preload("res://addons/uf_editor_ui/editor_block.gd")
const _TAG_FLOW := preload("res://addons/uf_editor_ui/tag_flow.gd")
const _I18N := preload("res://addons/uf_editor_ui/editor_i18n.gd")
const _TITLE_KEY := "item_editor.block.tags"
const _PALETTE_MIN_H := 88

var _items: ItemsModule
var _item_category_id: StringName = &""
var _selected_tags: Array[StringName] = []
var _header_label: Label
var _tab_bar: TabBar
var _palette_scroll: ScrollContainer
var _palette_flow: _TAG_FLOW
var _tab_groups: Array[StringName] = []
var _suppress_signals: bool = false
var _embedded: bool = false
var _built: bool = false
var _pending_items: ItemsModule = null

func set_embedded(value: bool) -> void:
	_embedded = value

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _ready() -> void:
	_ensure_built()
	if _pending_items != null:
		setup(_pending_items)

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	if not _embedded:
		add_theme_stylebox_override("panel", _BLOCK.make_panel_style())

	var margin := MarginContainer.new()
	var pad := 0 if _embedded else 8
	margin.add_theme_constant_override("margin_left", pad)
	margin.add_theme_constant_override("margin_right", pad)
	margin.add_theme_constant_override("margin_top", pad)
	margin.add_theme_constant_override("margin_bottom", pad)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(inner)

	if not _embedded:
		_header_label = Label.new()
		_BLOCK.style_block_header(_header_label)
		inner.add_child(_header_label)

	_tab_bar = TabBar.new()
	_tab_bar.tab_alignment = TabBar.AlignmentMode.ALIGNMENT_LEFT
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tab_bar.tab_changed.connect(_on_tab_changed)
	inner.add_child(_tab_bar)

	_palette_scroll = ScrollContainer.new()
	_palette_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_palette_scroll.custom_minimum_size = Vector2(0, _PALETTE_MIN_H)
	_palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_palette_scroll.clip_contents = true
	inner.add_child(_palette_scroll)

	_palette_flow = _TAG_FLOW.new()
	_palette_flow.filter_changed.connect(_on_filter_changed)
	_palette_scroll.add_child(_palette_flow)

	if not _embedded:
		_refresh_header_label()

func setup(items: ItemsModule) -> void:
	_pending_items = items
	if not _built:
		return
	_items = items
	_build_tabs()
	_select_tab_for_category(_item_category_id)
	_refresh_palette()
	_update_tab_labels()

func set_item_category(category_id: StringName) -> void:
	_item_category_id = category_id
	if _tab_bar != null and _tab_bar.tab_count > 0:
		_select_tab_for_category(category_id)

func get_tags() -> Array[StringName]:
	return _selected_tags.duplicate()

func set_tags(tags: Array[StringName], emit: bool = false) -> void:
	var normalized := tags
	if _items != null:
		normalized = _items.normalize_tags(tags, &"")
	_selected_tags = normalized.duplicate()
	if _built:
		_refresh_palette()
		_update_tab_labels()
	if emit:
		tags_changed.emit(_selected_tags.duplicate())

func refresh() -> void:
	if not _built:
		return
	_refresh_palette()
	_update_tab_labels()

func refresh_localized_controls() -> void:
	if not _embedded:
		_refresh_header_label()
	_update_tab_labels()

func _refresh_header_label() -> void:
	if _header_label == null:
		return
	_I18N.ensure_loaded()
	_header_label.text = _I18N.translate_key(_TITLE_KEY)

func _build_tabs() -> void:
	if _tab_bar == null or _items == null:
		return
	_tab_bar.clear_tabs()
	_tab_groups.clear()
	for group_id in _items.TAG_PICKER_GROUPS:
		_tab_groups.append(group_id)
		_tab_bar.add_tab(_tab_label(group_id))
		_tab_bar.set_tab_metadata(_tab_bar.tab_count - 1, group_id)

func _select_tab_for_category(category_id: StringName) -> void:
	if _tab_bar == null or _tab_bar.tab_count == 0:
		return
	if not String(category_id).is_empty():
		for i in _tab_bar.tab_count:
			if _group_id_for_tab(i) == category_id:
				_tab_bar.current_tab = i
				_refresh_palette()
				return
	_tab_bar.current_tab = 0
	_refresh_palette()

func _current_group_id() -> StringName:
	if _tab_bar == null or _tab_bar.tab_count == 0:
		return &""
	var idx := _tab_bar.current_tab
	if idx >= 0 and idx < _tab_groups.size():
		return _tab_groups[idx]
	return _tab_bar.get_tab_metadata(idx)

func _refresh_palette() -> void:
	if _palette_flow == null or _items == null:
		return
	_suppress_signals = true
	var group_id := _current_group_id()
	var defs := _items.list_tag_defs_for_group(group_id) if not String(group_id).is_empty() else []
	_palette_flow.show_filter_defs(defs, _selected_tags_for_group(group_id))
	_suppress_signals = false

func _selected_tags_for_group(group_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for tid in _selected_tags:
		if _tag_belongs_to_group(tid, group_id):
			out.append(tid)
	return out

func _tag_belongs_to_group(tag_id: StringName, group_id: StringName) -> bool:
	var def := _items.load_tag_def(tag_id) if _items != null else null
	if def == null:
		return false
	if group_id == &"general":
		return def.categories.is_empty()
	return def.categories.has(group_id)

func _on_tab_changed(_idx: int) -> void:
	_refresh_palette()

func _on_filter_changed(tab_active: Array[StringName]) -> void:
	if _suppress_signals:
		return
	_merge_tab_selection(tab_active)
	_update_tab_labels()
	tags_changed.emit(_selected_tags.duplicate())

func _merge_tab_selection(tab_active: Array[StringName]) -> void:
	var group_id := _current_group_id()
	var tab_ids: Array[StringName] = []
	for def in _items.list_tag_defs_for_group(group_id):
		tab_ids.append(def.id)
	var next: Array[StringName] = []
	for tid in _selected_tags:
		if not tab_ids.has(tid):
			next.append(tid)
	for tid in tab_active:
		if not next.has(tid):
			next.append(tid)
	_selected_tags = _items.normalize_tags(next, &"") if _items != null else next

func _group_id_for_tab(tab_index: int) -> StringName:
	if tab_index >= 0 and tab_index < _tab_groups.size():
		return _tab_groups[tab_index]
	if _tab_bar != null and tab_index >= 0 and tab_index < _tab_bar.tab_count:
		return _tab_bar.get_tab_metadata(tab_index)
	return &""

func _update_tab_labels() -> void:
	if _tab_bar == null:
		return
	for i in _tab_bar.tab_count:
		var group_id := _group_id_for_tab(i)
		var base := _tab_label(group_id)
		var count := _count_selected_in_group(group_id)
		_tab_bar.set_tab_title(i, "%s (%d)" % [base, count] if count > 0 else base)

func _count_selected_in_group(group_id: StringName) -> int:
	var count := 0
	for tid in _selected_tags:
		if _tag_belongs_to_group(tid, group_id):
			count += 1
	return count

func _tab_label(group_id: StringName) -> String:
	var key := "item_editor.tag_tab.%s" % group_id
	var label := _I18N.translate_key(key)
	if label == key:
		return String(group_id)
	return label
