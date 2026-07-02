@tool
extends Control
## Item editor workspace: left properties, center browse list, right actions and filters.

const _ROW := preload("res://addons/uf_item_editor/item_list_row.gd")
const _BLOCK := preload("res://addons/uf_item_editor/editor_block.gd")
const _TAG_CHIP := preload("res://addons/uf_item_editor/tag_chip.gd")
const _TAG_FLOW := preload("res://addons/uf_item_editor/tag_flow.gd")
const _TAG_ZONE := preload("res://addons/uf_item_editor/tag_assign_zone.gd")
const _PREVIEW_SUMMARY := preload("res://addons/uf_item_editor/item_preview_summary.gd")
const _I18N := preload("res://addons/uf_item_editor/editor_i18n.gd")
const _LOG := "ITM"
const _MARGIN := 8
const _PANEL_SEP := 6
const _FIELD_SEP := 6
const _SECTION_SEP := 8
const _LABEL_WIDTH := 108
const _BTN_H := 26
const _BTN_MIN_W := 88
const _SPRITE_PREVIEW_FALLBACK := Vector2(64, 64)
const _COL_LEFT := 0.30
const _COL_CENTER := 0.40
const _COL_RIGHT := 0.30
const _COL_MIN_LEFT := 160
const _COL_MIN_CENTER := 200
const _COL_MIN_RIGHT := 160
const _CENTER_PREVIEW_CHROME := 52
const _CENTER_LIST_MIN := 120

var _items: ItemsModule
var _modifier: ModifierModule
var _draft: ItemDef
var _data_ready: bool = false
var _selected_meta: Dictionary = {}
var _selected_list_key: String = ""
var _browse_mode: StringName = &"saved"
var _back_to_saved_btn: Button
var _browse_hint: Label
var _preview_state: int = 0
var _preview_modifier_ids: Array[StringName] = []

var _category_option: OptionButton
var _family_option: OptionButton
var _state_option: OptionButton
var _modifier_option: OptionButton
var _status_label: Label
var _save_btn: Button
var _action_buttons: Array[Dictionary] = []
var _locale_labels: Array[Dictionary] = []
var _tag_filter_flow: _TAG_FLOW
var _tag_palette_flow: _TAG_FLOW
var _tag_assign_zone: _TAG_ZONE
var _details_box: VBoxContainer
var _list_box: VBoxContainer
var _preview_icon: TextureRect
var _preview_summary: _PREVIEW_SUMMARY
var _cols: HSplitContainer
var _center_right: HSplitContainer
var _center_split: VSplitContainer
var _id_field: LineEdit
var _name_key_field: LineEdit
var _desc_key_field: LineEdit
var _weight_field: SpinBox
var _price_field: SpinBox
var _durability_field: SpinBox
var _grid_w_field: SpinBox
var _grid_h_field: SpinBox
var _def_state_option: OptionButton
var _def_quality_option: OptionButton
var _weapon_family_field: LineEdit
var _weapon_type_field: LineEdit
var _weapon_slot_option: OptionButton
var _weapon_hands_field: SpinBox
var _weapon_modifier_field: LineEdit
var _weapon_section: VBoxContainer
var _weapon_block: PanelContainer
var _armor_section: VBoxContainer
var _armor_block: PanelContainer
var _food_section: VBoxContainer
var _food_block: PanelContainer
var _valuable_section: VBoxContainer
var _valuable_block: PanelContainer
var _armor_slot_option: OptionButton
var _armor_modifier_field: LineEdit
var _food_nutrition_field: SpinBox
var _food_spoilage_field: SpinBox
var _food_stackable: CheckBox
var _valuable_stackable: CheckBox
var _valuable_merchant_field: LineEdit
var _tier_state_box: VBoxContainer
var _tier_quality_box: VBoxContainer
var _localizing: bool = false

func setup() -> void:
	_items = ItemsModule.new()
	_modifier = ModifierModule.new()
	_build_ui()
	_refresh_localized_strings()

func ensure_ready() -> void:
	_fit_to_parent()
	if not _data_ready:
		if not is_inside_tree() or _category_option == null:
			call_deferred("ensure_ready")
			return
		_bootstrap_data()
	else:
		_refresh_localized_ui()
		_rebuild_list()
	_finalize_layout()
	call_deferred("_finalize_layout")

func sync_layout() -> void:
	_fit_to_parent()
	_finalize_layout()

func _fit_to_parent() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if parent.size.x > 8 and parent.size.y > 8:
		size = parent.size

func _bootstrap_data() -> void:
	_populate_categories()
	_populate_weapon_families()
	_populate_art_strip_states()
	_populate_item_modifiers()
	_refresh_tag_pickers(true)
	_refresh_localized_strings()
	_rebuild_list()
	_set_status(_T("item_editor.status.ready"))
	_data_ready = true
	call_deferred("_finalize_layout")

func _refresh_tag_pickers(reset_filters: bool = false) -> void:
	var cat := _current_category_id()
	if _tag_filter_flow != null:
		if reset_filters:
			_tag_filter_flow.configure(_TAG_CHIP.Mode.FILTER, _items, cat)
		else:
			_tag_filter_flow.refresh(cat)
	if _tag_palette_flow != null:
		if reset_filters:
			_tag_palette_flow.configure(_TAG_CHIP.Mode.PALETTE, _items, cat)
		else:
			_tag_palette_flow.refresh(cat)

func _finalize_layout() -> void:
	_apply_column_splits()
	_apply_center_split()

func _apply_column_splits() -> void:
	if _cols == null or _cols.size.x < 360:
		return
	var total_w := _cols.size.x
	var sep_outer := _cols.get_theme_constant("separation", "HSplitContainer")
	var left_w := int(round(total_w * _COL_LEFT))
	var center_w := int(round(total_w * _COL_CENTER))
	var right_w := maxi(int(round(total_w * _COL_RIGHT)), _COL_MIN_RIGHT)
	left_w = clampi(left_w, _COL_MIN_LEFT, total_w - center_w - right_w - sep_outer - 4)
	_cols.split_offset = left_w
	if _center_right == null:
		return
	var inner_w := maxi(total_w - left_w - sep_outer, _COL_MIN_CENTER + _COL_MIN_RIGHT)
	center_w = clampi(center_w, _COL_MIN_CENTER, inner_w - _COL_MIN_RIGHT)
	_center_right.split_offset = center_w

func _apply_center_split() -> void:
	if _center_split == null:
		return
	var avail := _center_split.size.y
	if avail < _CENTER_LIST_MIN + 72:
		return
	var sprite_h := int(_preview_icon.custom_minimum_size.y) if _preview_icon != null else int(_SPRITE_PREVIEW_FALLBACK.y)
	var top_h := maxi(_CENTER_PREVIEW_CHROME + sprite_h, 96)
	if _preview_summary != null:
		top_h = maxi(top_h, _CENTER_PREVIEW_CHROME + sprite_h + 24)
	top_h = clampi(top_h, 72, avail - _CENTER_LIST_MIN)
	_center_split.split_offset = top_h

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", _MARGIN)
	margin.add_theme_constant_override("margin_right", _MARGIN)
	margin.add_theme_constant_override("margin_top", _MARGIN)
	margin.add_theme_constant_override("margin_bottom", _MARGIN)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", _PANEL_SEP)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)
	_build_toolbar(root)
	_cols = HSplitContainer.new()
	_cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_cols)
	_build_left_column(_cols)
	_center_right = HSplitContainer.new()
	_center_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cols.add_child(_center_right)
	_build_center_column(_center_right)
	_build_right_column(_center_right)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 22)
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	root.add_child(_status_label)
	call_deferred("_bind_parent_resize")

func _bind_parent_resize() -> void:
	var parent := get_parent() as Control
	if parent != null and not parent.resized.is_connected(_on_parent_resized):
		parent.resized.connect(_on_parent_resized)

func _on_parent_resized() -> void:
	if is_visible_in_tree():
		sync_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_column_splits()
		_apply_center_split()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		call_deferred("sync_layout")
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		if _data_ready:
			_refresh_localized_ui()

func _build_toolbar(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _BLOCK.make_panel_style())
	parent.add_child(panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", _FIELD_SEP)
	panel.add_child(bar)
	bar.add_child(_tracked_label("item_editor.toolbar.category"))
	_category_option = OptionButton.new()
	_category_option.custom_minimum_size = Vector2(140, _BTN_H)
	_category_option.item_selected.connect(_on_category_changed)
	bar.add_child(_category_option)
	_save_btn = Button.new()
	_save_btn.custom_minimum_size = Vector2(_BTN_MIN_W, _BTN_H)
	_save_btn.pressed.connect(_on_save_pressed)
	_action_buttons.append({"button": _save_btn, "key": "item_editor.action.save"})
	bar.add_child(_save_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

func _build_left_column(parent: HSplitContainer) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = 0
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	var header := _section_header("item_editor.block.definition")
	column.add_child(header)
	var left := ScrollContainer.new()
	left.name = "DefinitionScroll"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(left)
	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", _PANEL_SEP)
	_details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_details_box)
	_rebuild_details_form()

func _build_center_column(parent: HSplitContainer) -> void:
	var column := VBoxContainer.new()
	column.name = "CenterColumn"
	column.custom_minimum_size.x = 0
	column.add_theme_constant_override("separation", _PANEL_SEP)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var browse_bar := HBoxContainer.new()
	browse_bar.add_theme_constant_override("separation", _FIELD_SEP)
	column.add_child(browse_bar)
	_back_to_saved_btn = Button.new()
	_back_to_saved_btn.custom_minimum_size = Vector2(_BTN_MIN_W, _BTN_H)
	_back_to_saved_btn.visible = false
	_back_to_saved_btn.pressed.connect(_on_back_to_saved_pressed)
	_action_buttons.append({"button": _back_to_saved_btn, "key": "item_editor.action.back_to_saved"})
	browse_bar.add_child(_back_to_saved_btn)
	_browse_hint = Label.new()
	_browse_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browse_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_browse_hint.add_theme_color_override("font_color", Color(0.62, 0.67, 0.72))
	browse_bar.add_child(_browse_hint)
	_set_browse_mode(&"saved", false)
	_center_split = VSplitContainer.new()
	_center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_center_split)
	var preview_pane := VBoxContainer.new()
	preview_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_pane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_center_split.add_child(preview_pane)
	var preview_body := _mount_section(preview_pane, "item_editor.block.draft_preview", false)
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 12)
	preview_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_body.add_child(preview_row)
	var preview_frame := PanelContainer.new()
	preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_frame.add_theme_stylebox_override("panel", _BLOCK.make_preview_style())
	preview_row.add_child(preview_frame)
	var preview_pad := MarginContainer.new()
	preview_pad.add_theme_constant_override("margin_left", 6)
	preview_pad.add_theme_constant_override("margin_right", 6)
	preview_pad.add_theme_constant_override("margin_top", 6)
	preview_pad.add_theme_constant_override("margin_bottom", 6)
	preview_frame.add_child(preview_pad)
	_preview_icon = TextureRect.new()
	_preview_icon.custom_minimum_size = _SPRITE_PREVIEW_FALLBACK
	_preview_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP
	preview_pad.add_child(_preview_icon)
	_preview_summary = _PREVIEW_SUMMARY.new()
	_preview_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_summary.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_row.add_child(_preview_summary)
	_preview_summary.show_empty()
	var list_pane := VBoxContainer.new()
	list_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_pane.custom_minimum_size = Vector2(0, _CENTER_LIST_MIN)
	_center_split.add_child(list_pane)
	var list_body := _mount_section(list_pane, "item_editor.block.selectable_items", true)
	var scroll := ScrollContainer.new()
	scroll.name = "BrowseListScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list_body.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

func _build_right_column(parent: HSplitContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var right := ScrollContainer.new()
	right.name = "SidebarScroll"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(right)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _PANEL_SEP)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(box)
	var actions_wrap := _BLOCK.create("item_editor.block.actions")
	_register_block_title(actions_wrap)
	box.add_child(actions_wrap.block)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_wrap.body.add_child(actions)
	for spec in [
		["item_editor.action.new", _on_new_pressed],
		["item_editor.action.new_from_art", _on_new_from_art_pressed],
		["item_editor.action.clone", _on_clone_pressed],
		["item_editor.action.edit", _on_edit_pressed],
		["item_editor.action.delete", _on_delete_pressed],
	]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(_BTN_MIN_W, _BTN_H)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn.pressed.connect(spec[1])
		_action_buttons.append({"button": btn, "key": spec[0]})
		actions.add_child(btn)
	_section_gap(box)
	var filters_wrap := _BLOCK.create("item_editor.block.preview_filters")
	_register_block_title(filters_wrap)
	box.add_child(filters_wrap.block)
	_family_option = _add_filter_row(filters_wrap.body, _T("item_editor.field.family"))
	_family_option.item_selected.connect(func(_i: int) -> void: _rebuild_list())
	_state_option = _add_filter_row(filters_wrap.body, _T("item_editor.field.strip_state"))
	_state_option.item_selected.connect(_on_art_strip_state_changed)
	_modifier_option = _add_filter_row(filters_wrap.body, _T("item_editor.field.preview_modifier"))
	_modifier_option.item_selected.connect(_on_preview_modifier_changed)
	_section_gap(box)
	var tag_filter_wrap := _BLOCK.create("item_editor.block.tag_filter")
	_register_block_title(tag_filter_wrap)
	box.add_child(tag_filter_wrap.block)
	var filter_hint := _tracked_label("item_editor.tags.filter_hint")
	filter_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_filter_wrap.body.add_child(filter_hint)
	_tag_filter_flow = _TAG_FLOW.new()
	_tag_filter_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tag_filter_flow.filter_changed.connect(_on_tag_filter_changed)
	tag_filter_wrap.body.add_child(_tag_filter_flow)

func _rebuild_details_form() -> void:
	if _details_box == null:
		return
	var saved_tags: Array[StringName] = []
	if _tag_assign_zone != null:
		saved_tags = _tag_assign_zone.get_tags()
	for child in _details_box.get_children():
		child.queue_free()
	var props_wrap := _BLOCK.create("item_editor.block.properties")
	_register_block_title(props_wrap)
	_details_box.add_child(props_wrap.block)
	_id_field = _add_line_field_to(props_wrap.body, _T("item_editor.field.id"))
	_name_key_field = _add_line_field_to(props_wrap.body, _T("item_editor.field.display_name_key"))
	_desc_key_field = _add_line_field_to(props_wrap.body, _T("item_editor.field.description_key"))
	_weight_field = _add_spin_field_to(props_wrap.body, _T("item_editor.field.weight"), 0, 9999, 0.1)
	_price_field = _add_spin_field_to(props_wrap.body, _T("item_editor.field.base_price"), 0, 999999, 1)
	_durability_field = _add_spin_field_to(props_wrap.body, _T("item_editor.field.max_durability"), 0, 9999, 1)
	_grid_w_field = _add_spin_field_to(props_wrap.body, _T("item_editor.field.grid_w"), 1, 8, 1)
	_grid_h_field = _add_spin_field_to(props_wrap.body, _T("item_editor.field.grid_h"), 1, 8, 1)
	_def_state_option = _add_option_field_to(props_wrap.body, _T("item_editor.field.state"))
	_def_state_option.item_selected.connect(_on_def_state_changed)
	_def_quality_option = _add_option_field_to(props_wrap.body, _T("item_editor.field.quality"))
	_def_quality_option.item_selected.connect(_on_def_quality_changed)
	_section_gap(_details_box)
	var tags_wrap := _BLOCK.create("item_editor.block.tags")
	_register_block_title(tags_wrap)
	_details_box.add_child(tags_wrap.block)
	var palette_hint := _tracked_label("item_editor.tags.palette_hint")
	palette_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags_wrap.body.add_child(palette_hint)
	_tag_palette_flow = _TAG_FLOW.new()
	_tag_palette_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tag_palette_flow.palette_tag_selected.connect(_on_palette_tag_selected)
	tags_wrap.body.add_child(_tag_palette_flow)
	_tag_assign_zone = _TAG_ZONE.new()
	_tag_assign_zone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tag_assign_zone.setup(_items)
	_tag_assign_zone.tags_changed.connect(_on_draft_tags_changed)
	tags_wrap.body.add_child(_tag_assign_zone)
	_section_gap(_details_box)
	var tiers_wrap := _BLOCK.create("item_editor.block.tiers")
	_register_block_title(tiers_wrap)
	_details_box.add_child(tiers_wrap.block)
	_tier_state_box = VBoxContainer.new()
	_tier_state_box.add_theme_constant_override("separation", _FIELD_SEP)
	tiers_wrap.body.add_child(_tracked_label("item_editor.block.state_tiers"))
	tiers_wrap.body.add_child(_tier_state_box)
	var reset_state := Button.new()
	reset_state.custom_minimum_size = Vector2(_BTN_MIN_W, _BTN_H)
	reset_state.pressed.connect(_on_reset_state_tiers)
	_locale_labels.append({"label": reset_state, "key": "item_editor.action.reset_state_tiers", "is_button": true})
	tiers_wrap.body.add_child(reset_state)
	_tier_quality_box = VBoxContainer.new()
	_tier_quality_box.add_theme_constant_override("separation", _FIELD_SEP)
	tiers_wrap.body.add_child(_tracked_label("item_editor.block.quality_tiers"))
	tiers_wrap.body.add_child(_tier_quality_box)
	var reset_quality := Button.new()
	reset_quality.custom_minimum_size = Vector2(_BTN_MIN_W, _BTN_H)
	reset_quality.pressed.connect(_on_reset_quality_tiers)
	_locale_labels.append({"label": reset_quality, "key": "item_editor.action.reset_quality_tiers", "is_button": true})
	tiers_wrap.body.add_child(reset_quality)
	_section_gap(_details_box)
	var weapon_wrap := _BLOCK.create("item_editor.block.weapon_payload")
	_register_block_title(weapon_wrap)
	_details_box.add_child(weapon_wrap.block)
	_weapon_block = weapon_wrap.block
	_weapon_section = weapon_wrap.body
	_weapon_family_field = _add_line_field_to(_weapon_section, _T("item_editor.field.weapon_family"))
	_weapon_type_field = _add_line_field_to(_weapon_section, _T("item_editor.field.design_type"))
	_weapon_slot_option = _add_option_field_to(_weapon_section, _T("item_editor.field.equip_slot"))
	for slot in [&"arm_right", &"arm_left", &"belt", &"back"]:
		_weapon_slot_option.add_item(String(slot), -1)
		_weapon_slot_option.set_item_metadata(_weapon_slot_option.item_count - 1, slot)
	_weapon_hands_field = _add_spin_field_to(_weapon_section, _T("item_editor.field.hands"), 1, 2, 1)
	_weapon_modifier_field = _add_line_field_to(_weapon_section, _T("item_editor.field.attribute_modifier_id"))
	_section_gap(_details_box)
	var armor_wrap := _BLOCK.create("item_editor.block.armor_payload")
	_register_block_title(armor_wrap)
	_details_box.add_child(armor_wrap.block)
	_armor_block = armor_wrap.block
	_armor_section = armor_wrap.body
	_armor_slot_option = _add_option_field_to(_armor_section, _T("item_editor.field.equip_slot"))
	for slot in [&"head", &"body", &"arm_left", &"arm_right", &"belt", &"neck", &"ring_1", &"ring_2", &"feet", &"back"]:
		_armor_slot_option.add_item(String(slot), -1)
		_armor_slot_option.set_item_metadata(_armor_slot_option.item_count - 1, slot)
	_armor_modifier_field = _add_line_field_to(_armor_section, _T("item_editor.field.attribute_modifier_id"))
	_section_gap(_details_box)
	var food_wrap := _BLOCK.create("item_editor.block.food_payload")
	_register_block_title(food_wrap)
	_details_box.add_child(food_wrap.block)
	_food_block = food_wrap.block
	_food_section = food_wrap.body
	_food_nutrition_field = _add_spin_field_to(_food_section, _T("item_editor.field.nutrition"), 0, 999, 1)
	_food_spoilage_field = _add_spin_field_to(_food_section, _T("item_editor.field.spoilage_hours"), 0, 9999, 1)
	_food_stackable = CheckBox.new()
	_food_stackable.button_pressed = true
	_locale_labels.append({"label": _food_stackable, "key": "item_editor.field.stackable", "is_button": true})
	_food_section.add_child(_food_stackable)
	_section_gap(_details_box)
	var valuable_wrap := _BLOCK.create("item_editor.block.valuable_payload")
	_register_block_title(valuable_wrap)
	_details_box.add_child(valuable_wrap.block)
	_valuable_block = valuable_wrap.block
	_valuable_section = valuable_wrap.body
	_valuable_stackable = CheckBox.new()
	_valuable_stackable.button_pressed = true
	_locale_labels.append({"label": _valuable_stackable, "key": "item_editor.field.stackable", "is_button": true})
	_valuable_section.add_child(_valuable_stackable)
	_valuable_merchant_field = _add_line_field_to(_valuable_section, _T("item_editor.field.merchant_category"))
	_refresh_tag_pickers()
	if not saved_tags.is_empty():
		_tag_assign_zone.set_tags(saved_tags)
	_update_category_sections_visibility()
	_sync_form_from_draft()

func _populate_categories() -> void:
	if _category_option == null:
		return
	var selected_id := _current_category_id() if _category_option.item_count > 0 else &"weapon"
	_category_option.clear()
	for cat in _items.list_categories():
		_category_option.add_item(_T(cat.display_name_key) if not cat.display_name_key.is_empty() else String(cat.id))
		_category_option.set_item_metadata(_category_option.item_count - 1, cat.id)
	for i in _category_option.item_count:
		if _category_option.get_item_metadata(i) == selected_id:
			_category_option.select(i)
			break

func _populate_weapon_families() -> void:
	if _family_option == null:
		return
	_family_option.clear()
	_family_option.add_item(_T("item_editor.filter.all"), -1)
	_family_option.set_item_metadata(0, &"")
	var seen: Dictionary = {}
	for entry in _items.list_sprite_templates(&"weapon"):
		var fam: StringName = entry.get("family", &"")
		if String(fam).is_empty() or seen.has(fam):
			continue
		seen[fam] = true
		_family_option.add_item(String(fam))
		_family_option.set_item_metadata(_family_option.item_count - 1, fam)

func _populate_art_strip_states() -> void:
	if _state_option == null:
		return
	_state_option.clear()
	for tier in _preview_state_tiers():
		_state_option.add_item(_T(tier.display_name_key) if not tier.display_name_key.is_empty() else String(tier.id))
	_update_art_strip_filter_visibility()

func _sync_def_tier_option_menus() -> void:
	if _def_state_option == null or _def_quality_option == null:
		return
	var state_tiers: Array[ItemStateTierDef] = []
	var quality_tiers: Array[ItemQualityTierDef] = []
	var state_idx := 0
	var quality_idx := 0
	if _draft != null:
		state_tiers = _draft.state_tiers
		quality_tiers = _draft.quality_tiers
		state_idx = _draft.default_state_index
		quality_idx = _draft.default_quality_index
	else:
		var cat := _items.load_category(_current_category_id())
		if cat != null and not cat.default_state_tiers.is_empty():
			state_tiers = cat.default_state_tiers
		else:
			state_tiers = _items.default_weapon_state_tiers()
		if cat != null and not cat.default_quality_tiers.is_empty():
			quality_tiers = cat.default_quality_tiers
		else:
			quality_tiers = _items.default_quality_tiers()
	_def_state_option.clear()
	for tier in state_tiers:
		_def_state_option.add_item(_T(tier.display_name_key) if not tier.display_name_key.is_empty() else String(tier.id))
	_def_quality_option.clear()
	for tier in quality_tiers:
		_def_quality_option.add_item(_T(tier.display_name_key) if not tier.display_name_key.is_empty() else String(tier.id))
	if _def_state_option.item_count > 0:
		_def_state_option.select(clampi(state_idx, 0, _def_state_option.item_count - 1))
	if _def_quality_option.item_count > 0:
		_def_quality_option.select(clampi(quality_idx, 0, _def_quality_option.item_count - 1))
	var editable := _draft != null
	_def_state_option.disabled = not editable
	_def_quality_option.disabled = not editable

func _update_art_strip_filter_visibility() -> void:
	if _state_option == null:
		return
	var row := _state_option.get_parent() as Control
	if row != null:
		row.visible = _browse_mode == &"art"

func _current_category_id() -> StringName:
	var idx := _category_option.selected
	if idx < 0:
		return &"weapon"
	return _category_option.get_item_metadata(idx)

func _current_family_filter() -> StringName:
	if _family_option == null or _family_option.selected < 0:
		return &""
	return _family_option.get_item_metadata(_family_option.selected)

func _set_browse_mode(mode: StringName, rebuild: bool = true) -> void:
	_browse_mode = mode
	if _back_to_saved_btn != null:
		_back_to_saved_btn.visible = mode == &"art"
	if _browse_hint != null:
		_browse_hint.text = _T("item_editor.hint.art_library") if mode == &"art" else _T("item_editor.hint.saved_items")
	if mode == &"saved" and _selected_list_key.begins_with("art:"):
		_selected_list_key = ""
		_selected_meta = {}
	if rebuild:
		_rebuild_list()
	_update_art_strip_filter_visibility()

func _on_new_from_art_pressed() -> void:
	_set_browse_mode(&"art")

func _on_back_to_saved_pressed() -> void:
	_set_browse_mode(&"saved")

func _row_selection_key(meta: Dictionary) -> String:
	if meta.get("is_sprite_template", false):
		var path := String(meta.get("library_path", ""))
		if not path.is_empty():
			return "art:%s" % path
		return "art:%s" % String(meta.get("label", ""))
	return "item:%s" % String(meta.get("id", ""))

func _draft_selection_key() -> String:
	if _draft == null or String(_draft.id).is_empty():
		return ""
	return "item:%s" % String(_draft.id)

func _active_selection_key() -> String:
	if not _selected_list_key.is_empty():
		return _selected_list_key
	return _draft_selection_key()

func _update_list_selection() -> void:
	var active := _active_selection_key()
	for child in _list_box.get_children():
		if child is _ROW:
			var row: _ROW = child
			row.set_selected(_row_selection_key(row.get_meta_data()) == active and not active.is_empty())

func _rebuild_list() -> void:
	if _list_box == null:
		return
	_clear_list_box()
	var tag_filter: Array[StringName] = []
	if _tag_filter_flow != null:
		tag_filter = _tag_filter_flow.get_active_filter_tags()
	if _browse_mode == &"art":
		_append_sprite_rows(tag_filter)
	else:
		_append_item_rows(tag_filter)
	_update_list_selection()

func _clear_list_box() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.free()

func _on_tag_filter_changed(_active_tags: Array[StringName]) -> void:
	call_deferred("_rebuild_list")

func _append_sprite_rows(active_tags: Array[StringName]) -> void:
	var family := _current_family_filter()
	var entries := _items.list_sprite_templates(_current_category_id(), family)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")) < String(b.get("label", ""))
	)
	if entries.is_empty():
		_list_box.add_child(_body_label(_T("item_editor.list.no_art")))
		return
	for entry in entries:
		if not active_tags.is_empty():
			var entry_tags := _items.infer_template_tags(entry)
			if not _items.tags_overlap_any(entry_tags, active_tags):
				continue
		var row_data := entry.duplicate()
		row_data["icon"] = _items.resolve_strip_icon(
			String(entry.get("library_path", "")),
			_preview_state,
			_preview_state_tiers(),
		)
		var row := _ROW.new()
		row.custom_minimum_size = Vector2(0, 64)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list_box.add_child(row)
		row.setup(row_data, true)
		row.row_selected.connect(_on_row_selected)

func _preview_state_tiers() -> Array[ItemStateTierDef]:
	var cat := _items.load_category(_current_category_id())
	if cat != null and not cat.default_state_tiers.is_empty():
		return cat.default_state_tiers
	return _items.default_weapon_state_tiers()

func _append_item_rows(active_tags: Array[StringName]) -> void:
	var filter := {"category_id": _current_category_id()}
	if not active_tags.is_empty():
		filter["tags_any"] = active_tags
	var defs := _items.list_defs(filter)
	defs.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		return String(a.id) < String(b.id)
	)
	if defs.is_empty():
		_list_box.add_child(_body_label(_T("item_editor.list.no_items")))
		return
	for def in defs:
		var row_data := _items.resolve_list_row(def, _preview_modifier_ids, _modifier)
		var row := _ROW.new()
		row.custom_minimum_size = Vector2(0, 80)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list_box.add_child(row)
		row.setup(row_data, false)
		row.row_selected.connect(_on_row_selected)

func _on_row_selected(meta: Dictionary) -> void:
	_selected_meta = meta
	_selected_list_key = _row_selection_key(meta)
	_update_list_selection()
	_refresh_preview_panel()

func _on_category_changed(_idx: int) -> void:
	_update_category_sections_visibility()
	_refresh_tag_pickers(true)
	_populate_art_strip_states()
	if _draft != null:
		_sync_def_tier_option_menus()
	_rebuild_list()

func _on_art_strip_state_changed(idx: int) -> void:
	_preview_state = idx
	_refresh_preview_panel()
	if _browse_mode == &"art":
		_rebuild_list()

func _on_def_state_changed(idx: int) -> void:
	if _draft == null:
		return
	_draft.default_state_index = idx
	_refresh_preview_panel()
	if _browse_mode == &"saved":
		_rebuild_list()

func _on_def_quality_changed(idx: int) -> void:
	if _draft == null:
		return
	_draft.default_quality_index = idx
	_refresh_preview_panel()
	if _browse_mode == &"saved":
		_rebuild_list()

func _on_preview_modifier_changed(idx: int) -> void:
	_preview_modifier_ids.clear()
	if idx > 0 and _modifier_option != null:
		var mid: StringName = _modifier_option.get_item_metadata(idx)
		if not String(mid).is_empty():
			_preview_modifier_ids.append(mid)
	_refresh_preview_panel()
	if _browse_mode == &"saved" and _draft != null:
		_rebuild_list()

func _populate_item_modifiers() -> void:
	if _modifier_option == null:
		return
	_modifier_option.clear()
	_modifier_option.add_item(_T("item_editor.filter.none"), -1)
	_modifier_option.set_item_metadata(0, &"")
	for def in _modifier.list_by_kind(ModifierDef.Kind.ITEM):
		_modifier_option.add_item(_T(def.display_name_key) if not def.display_name_key.is_empty() else String(def.id))
		_modifier_option.set_item_metadata(_modifier_option.item_count - 1, def.id)

func _on_reset_state_tiers() -> void:
	if _draft == null:
		return
	_draft.state_tiers = _items.default_weapon_state_tiers()
	_draft.default_state_index = clampi(_draft.default_state_index, 0, maxi(0, _draft.state_tiers.size() - 1))
	_sync_def_tier_option_menus()
	_refresh_preview_panel()
	_set_status(_T("item_editor.status.state_tiers_reset"))

func _on_reset_quality_tiers() -> void:
	if _draft == null:
		return
	_draft.quality_tiers = _items.default_quality_tiers()
	_draft.default_quality_index = clampi(_draft.default_quality_index, 0, maxi(0, _draft.quality_tiers.size() - 1))
	_sync_def_tier_option_menus()
	_refresh_preview_panel()
	_set_status(_T("item_editor.status.quality_tiers_reset"))

func _refresh_preview_panel() -> void:
	_refresh_preview_icon()
	_refresh_preview_summary()

func _refresh_preview_icon() -> void:
	if _preview_icon == null:
		return
	var tex: Texture2D = null
	if _draft != null:
		var inst := ItemInstance.new()
		inst.def_id = _draft.id
		inst.state_index = _draft.default_state_index
		inst.quality_index = _draft.default_quality_index
		inst.modifier_ids = _preview_modifier_ids.duplicate()
		tex = _items.resolve_icon(inst, _draft)
	elif _selected_meta.has("icon"):
		tex = _selected_meta.get("icon")
	elif _selected_meta.has("library_path"):
		var path: String = _selected_meta.get("library_path", "")
		tex = _items.resolve_strip_icon(path, _preview_state, _preview_state_tiers())
	_preview_icon.texture = tex
	_sync_preview_icon_size(tex)

func _sync_preview_icon_size(tex: Texture2D) -> void:
	if _preview_icon == null:
		return
	var sz := tex.get_size() if tex != null else _SPRITE_PREVIEW_FALLBACK
	if sz.x < 1.0 or sz.y < 1.0:
		sz = _SPRITE_PREVIEW_FALLBACK
	_preview_icon.custom_minimum_size = sz
	_preview_icon.size = sz
	call_deferred("_apply_center_split")

func _refresh_preview_summary() -> void:
	if _preview_summary == null:
		return
	if _draft != null and _id_field != null:
		_apply_form_to_draft()
		var row := _items.resolve_list_row(_draft, _preview_modifier_ids, _modifier)
		_preview_summary.show_item(_items, row, _draft)
		return
	if _browse_mode == &"art" and _selected_meta.get("is_sprite_template", false):
		_preview_summary.show_sprite_template(_selected_meta)
		return
	if _selected_meta.has("id"):
		var def := _items.load_def(_selected_meta.get("id"))
		if def != null:
			var row := _items.resolve_list_row(def, _preview_modifier_ids, _modifier)
			_preview_summary.show_item(_items, row, def)
			return
	_preview_summary.show_empty()

func _update_category_sections_visibility() -> void:
	var cat := _current_category_id()
	if _weapon_block != null:
		_weapon_block.visible = cat == &"weapon"
	if _armor_block != null:
		_armor_block.visible = cat == &"armor"
	if _food_block != null:
		_food_block.visible = cat == &"food"
	if _valuable_block != null:
		_valuable_block.visible = cat == &"valuable"

func _on_draft_tags_changed(tags: Array[StringName]) -> void:
	if _draft != null:
		_draft.tags = _items.normalize_tags(tags, _current_category_id())
	_refresh_preview_panel()

func _on_palette_tag_selected(tag_id: StringName) -> void:
	if _tag_assign_zone == null:
		return
	var tags := _tag_assign_zone.get_tags()
	if tags.has(tag_id):
		return
	tags.append(tag_id)
	_tag_assign_zone.set_tags(_items.normalize_tags(tags, _current_category_id()))

func _on_new_pressed() -> void:
	var cat := _current_category_id()
	_draft = _items.create_blank_def(cat)
	if _browse_mode == &"art":
		if not _selected_meta.get("is_sprite_template", false):
			_set_status(_T("item_editor.status.pick_art"))
			_draft = null
			return
		_apply_sprite_template_to_draft(_selected_meta)
		_set_browse_mode(&"saved", false)
	elif not _selected_meta.is_empty() and _selected_meta.has("id"):
		var src := _items.load_def(_selected_meta.get("id"))
		if src != null:
			_draft = _items.duplicate_def(src)
			_draft.id = &""
	_sync_form_from_draft()
	_selected_list_key = _draft_selection_key()
	_refresh_preview_panel()
	_update_list_selection()
	_set_status(_T("item_editor.status.new_draft"))

func _on_clone_pressed() -> void:
	if _draft == null and _selected_meta.has("id"):
		var src := _items.load_def(_selected_meta.get("id"))
		if src != null:
			_draft = _items.duplicate_def(src)
			_draft.id = StringName("%s_copy" % src.id)
	elif _draft != null:
		_draft = _items.duplicate_def(_draft)
		_draft.id = StringName("%s_copy" % _draft.id)
	else:
		_set_status(_T("item_editor.status.pick_item"))
		return
	_sync_form_from_draft()
	_selected_list_key = _draft_selection_key()
	_update_list_selection()
	_set_status(_T("item_editor.status.cloned"))

func _on_edit_pressed() -> void:
	if _browse_mode == &"art":
		_on_new_pressed()
		return
	if not _selected_meta.has("id"):
		_set_status(_T("item_editor.status.pick_item"))
		return
	_draft = _items.load_def(_selected_meta.get("id"))
	if _draft == null:
		_set_status(_T("item_editor.status.load_failed"))
		return
	_sync_form_from_draft()
	_selected_list_key = _draft_selection_key()
	_refresh_preview_panel()
	_update_list_selection()
	_set_status(_T("item_editor.status.editing") % _draft.id)

func _on_delete_pressed() -> void:
	if _draft == null or String(_draft.id).is_empty():
		_set_status(_T("item_editor.status.nothing_to_delete"))
		return
	var path := "res://assets/data/items/%s.tres" % _draft.id
	if DirAccess.remove_absolute(path) != OK:
		_set_status(_T("item_editor.status.delete_failed") % path)
		return
	_draft = null
	_selected_list_key = ""
	_selected_meta = {}
	_rebuild_list()
	_set_status(_T("item_editor.status.deleted") % path)

func _on_save_pressed() -> void:
	if _draft == null:
		_draft = _items.create_blank_def(_current_category_id())
	_apply_form_to_draft()
	if String(_draft.id).is_empty():
		_set_status(_T("item_editor.status.id_required"))
		return
	var err := _items.save_def(_draft)
	if err != OK:
		_set_status(_T("item_editor.status.save_failed") % err)
		return
	_rebuild_list()
	_selected_list_key = _draft_selection_key()
	_update_list_selection()
	_set_status(_T("item_editor.status.saved") % _draft.id)

func _apply_sprite_template_to_draft(meta: Dictionary) -> void:
	if _draft == null:
		return
	_draft.category_id = meta.get("category_id", &"weapon")
	var ref := ItemSpriteRef.new()
	ref.library_path = String(meta.get("library_path", ""))
	ref.strip_cell_size = Vector2i(64, 64)
	_draft.sprite_ref = ref
	if _draft.category_data is WeaponItemData:
		var w := _draft.category_data as WeaponItemData
		w.weapon_family = meta.get("family", &"")
		w.design_type = meta.get("design_type", &"")
	if _draft.state_tiers.is_empty():
		_draft.state_tiers = _items.default_weapon_state_tiers()
	if _draft.quality_tiers.is_empty():
		_draft.quality_tiers = _items.default_quality_tiers()
	_draft.default_state_index = _preview_state
	_draft.default_quality_index = 0
	var fam := String(meta.get("family", ""))
	var typ := String(meta.get("design_type", ""))
	_draft.id = StringName("%s_%s" % [fam, typ]) if not fam.is_empty() else &"new_item"
	_draft.display_name_key = "item.%s.name" % _draft.id
	_draft.tags = _items.normalize_tags([meta.get("family", &""), &"weapon"], _draft.category_id)

func _apply_form_to_draft() -> void:
	if _draft == null:
		return
	_draft.id = StringName(_id_field.text.strip_edges())
	_draft.display_name_key = _name_key_field.text.strip_edges()
	_draft.description_key = _desc_key_field.text.strip_edges()
	_draft.weight = _weight_field.value
	_draft.base_price = _price_field.value
	_draft.max_durability = _durability_field.value
	_draft.inventory_size = Vector2i(int(_grid_w_field.value), int(_grid_h_field.value))
	if _def_state_option != null and _def_state_option.item_count > 0:
		_draft.default_state_index = _def_state_option.selected
	if _def_quality_option != null and _def_quality_option.item_count > 0:
		_draft.default_quality_index = _def_quality_option.selected
	if _tag_assign_zone != null:
		_draft.tags = _items.normalize_tags(_tag_assign_zone.get_tags(), _current_category_id())
	_draft.category_id = _current_category_id()
	if _draft.category_data is WeaponItemData:
		var w := _draft.category_data as WeaponItemData
		w.weapon_family = StringName(_weapon_family_field.text.strip_edges())
		w.design_type = StringName(_weapon_type_field.text.strip_edges())
		w.hands = int(_weapon_hands_field.value)
		w.attribute_modifier_id = StringName(_weapon_modifier_field.text.strip_edges())
		if _weapon_slot_option.selected >= 0:
			w.slot = _weapon_slot_option.get_item_metadata(_weapon_slot_option.selected)
	elif _draft.category_data is ArmorItemData:
		var a := _draft.category_data as ArmorItemData
		a.attribute_modifier_id = StringName(_armor_modifier_field.text.strip_edges())
		if _armor_slot_option.selected >= 0:
			a.slot = _armor_slot_option.get_item_metadata(_armor_slot_option.selected)
	elif _draft.category_data is FoodItemData:
		var f := _draft.category_data as FoodItemData
		f.nutrition = _food_nutrition_field.value
		f.spoilage_hours = _food_spoilage_field.value
		f.stackable = _food_stackable.button_pressed
	elif _draft.category_data is ValuableItemData:
		var v := _draft.category_data as ValuableItemData
		v.stackable = _valuable_stackable.button_pressed
		v.merchant_category = StringName(_valuable_merchant_field.text.strip_edges())

func _sync_form_from_draft() -> void:
	if _details_box == null:
		return
	if _draft == null:
		if _id_field != null:
			_id_field.text = ""
		_sync_def_tier_option_menus()
		return
	_id_field.text = String(_draft.id)
	_name_key_field.text = _draft.display_name_key
	_desc_key_field.text = _draft.description_key
	_weight_field.value = _draft.weight
	_price_field.value = _draft.base_price
	_durability_field.value = _draft.max_durability
	_grid_w_field.value = _draft.inventory_size.x
	_grid_h_field.value = _draft.inventory_size.y
	_sync_def_tier_option_menus()
	if _tag_assign_zone != null:
		_tag_assign_zone.set_tags(_draft.tags)
	_update_category_sections_visibility()
	if _draft.category_data is WeaponItemData:
		var w := _draft.category_data as WeaponItemData
		_weapon_family_field.text = String(w.weapon_family)
		_weapon_type_field.text = String(w.design_type)
		_weapon_hands_field.value = w.hands
		_weapon_modifier_field.text = String(w.attribute_modifier_id)
		for i in _weapon_slot_option.item_count:
			if _weapon_slot_option.get_item_metadata(i) == w.slot:
				_weapon_slot_option.select(i)
				break
	elif _draft.category_data is ArmorItemData:
		var a := _draft.category_data as ArmorItemData
		_armor_modifier_field.text = String(a.attribute_modifier_id)
		for i in _armor_slot_option.item_count:
			if _armor_slot_option.get_item_metadata(i) == a.slot:
				_armor_slot_option.select(i)
				break
	elif _draft.category_data is FoodItemData:
		var f := _draft.category_data as FoodItemData
		_food_nutrition_field.value = f.nutrition
		_food_spoilage_field.value = f.spoilage_hours
		_food_stackable.button_pressed = f.stackable
	elif _draft.category_data is ValuableItemData:
		var v := _draft.category_data as ValuableItemData
		_valuable_stackable.button_pressed = v.stackable
		_valuable_merchant_field.text = String(v.merchant_category)
	_refresh_preview_panel()

func _add_line_field(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(0, _BTN_H)
	_add_form_row(_details_box, placeholder, field)
	return field

func _add_spin_field(label_text: String, min_v: float, max_v: float, step: float) -> SpinBox:
	return _add_spin_field_to(_details_box, label_text, min_v, max_v, step)

func _add_line_field_to(parent: Control, placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(0, _BTN_H)
	_add_form_row(parent, placeholder, field)
	return field

func _add_option_field_to(parent: Control, label_text: String) -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, _BTN_H)
	_add_form_row(parent, label_text, opt)
	return opt

func _add_spin_field_to(parent: Control, label_text: String, min_v: float, max_v: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.custom_minimum_size = Vector2(0, _BTN_H)
	_add_form_row(parent, label_text, spin)
	return spin

func _add_filter_row(parent: Control, label_text: String) -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, _BTN_H)
	_add_form_row(parent, label_text, opt)
	return opt

func _add_form_row(parent: Control, label_text: String, field: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _FIELD_SEP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(_LABEL_WIDTH, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(field)

func _section_gap(parent: Control) -> void:
	parent.add_child(HSeparator.new())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, _SECTION_SEP)
	parent.add_child(gap)

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0))
	l.custom_minimum_size = Vector2(0, 24)
	return l

func _body_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
	Log.info(_LOG, "editor", text)

func _register_block_title(wrap: Dictionary) -> void:
	var header: Variant = wrap.get("header")
	var key: String = wrap.get("title_key", "")
	if header is Label and not key.is_empty():
		_locale_labels.append({"label": header, "key": key, "is_button": false})

func _section_header(title_key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var lbl := Label.new()
	_locale_labels.append({"label": lbl, "key": title_key, "is_button": false})
	lbl.text = _T(title_key)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0))
	lbl.custom_minimum_size = Vector2(0, 18)
	box.add_child(lbl)
	box.add_child(HSeparator.new())
	return box

func _mount_section(parent: Control, title_key: String, expand_vertical: bool) -> VBoxContainer:
	var wrap := _BLOCK.create(title_key, expand_vertical)
	_register_block_title(wrap)
	wrap.block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_vertical:
		wrap.block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(wrap.block)
	return wrap.body

func _T(key: String) -> String:
	return _I18N.translate_key(key)

func _tracked_label(key: String) -> Label:
	var label := Label.new()
	_locale_labels.append({"label": label, "key": key, "is_button": false})
	label.text = _T(key)
	return label

func _refresh_localized_ui() -> void:
	if _category_option == null or _localizing:
		return
	_localizing = true
	_refresh_localized_strings()
	if _data_ready:
		_populate_categories()
		_populate_art_strip_states()
		_populate_item_modifiers()
		if _tag_filter_flow != null:
			_tag_filter_flow.refresh(_current_category_id())
		if _tag_palette_flow != null:
			_tag_palette_flow.refresh(_current_category_id())
		if _tag_assign_zone != null and _draft != null:
			_tag_assign_zone.set_tags(_draft.tags)
		elif _tag_assign_zone != null:
			_tag_assign_zone.set_tags(_tag_assign_zone.get_tags())
		if _draft != null:
			_sync_def_tier_option_menus()
		_update_art_strip_filter_visibility()
	_localizing = false

func _refresh_localized_strings() -> void:
	_I18N.ensure_loaded()
	for spec in _action_buttons:
		if spec.has("button") and spec.has("key"):
			(spec.button as Button).text = _T(spec.key)
	for spec in _locale_labels:
		var node: Node = spec.label
		var text := _T(spec.key)
		if spec.get("is_button", false):
			if node is Button:
				(node as Button).text = text
			elif node is CheckBox:
				(node as CheckBox).text = text
		elif node is Label:
			(node as Label).text = text
