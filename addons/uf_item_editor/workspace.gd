@tool
extends Control
## Item editor workspace: left properties, center browse list, right actions and filters.

const _ROW := preload("res://addons/uf_item_editor/item_list_row.gd")
const _LOG := "ITM"

var _items: ItemsModule
var _modifier: ModifierModule
var _draft: ItemDef
var _data_ready: bool = false
var _selected_meta: Dictionary = {}
var _browse_tab: int = 0
var _preview_state: int = 0
var _preview_quality: int = 0
var _preview_modifier_ids: Array[StringName] = []

var _category_option: OptionButton
var _family_option: OptionButton
var _state_option: OptionButton
var _quality_option: OptionButton
var _modifier_option: OptionButton
var _tag_filter: LineEdit
var _status_label: Label
var _details_box: VBoxContainer
var _list_box: VBoxContainer
var _preview_icon: TextureRect
var _cols: HSplitContainer
var _splits_initialized: bool = false
var _id_field: LineEdit
var _name_key_field: LineEdit
var _desc_key_field: LineEdit
var _weight_field: SpinBox
var _price_field: SpinBox
var _durability_field: SpinBox
var _grid_w_field: SpinBox
var _grid_h_field: SpinBox
var _tags_field: LineEdit
var _weapon_family_field: LineEdit
var _weapon_type_field: LineEdit
var _weapon_slot_option: OptionButton
var _weapon_hands_field: SpinBox
var _weapon_modifier_field: LineEdit
var _weapon_section: VBoxContainer
var _armor_section: VBoxContainer
var _food_section: VBoxContainer
var _valuable_section: VBoxContainer
var _armor_slot_option: OptionButton
var _armor_modifier_field: LineEdit
var _food_nutrition_field: SpinBox
var _food_spoilage_field: SpinBox
var _food_stackable: CheckBox
var _valuable_stackable: CheckBox
var _valuable_merchant_field: LineEdit
var _tier_state_box: VBoxContainer
var _tier_quality_box: VBoxContainer

func setup() -> void:
	_items = ItemsModule.new()
	_modifier = ModifierModule.new()
	_build_ui()

func ensure_ready() -> void:
	if not _data_ready:
		call_deferred("_bootstrap_data")
	else:
		call_deferred("_rebuild_list")

func sync_layout() -> void:
	_finalize_layout()

func _bootstrap_data() -> void:
	_populate_categories()
	_populate_weapon_families()
	_populate_preview_tiers()
	_populate_item_modifiers()
	_rebuild_list()
	_set_status("Ready")
	_data_ready = true
	call_deferred("_finalize_layout")

func _finalize_layout() -> void:
	if not _splits_initialized and _cols != null:
		_cols.split_offset = 280
		_splits_initialized = true

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)
	_build_toolbar(root)
	_cols = HSplitContainer.new()
	_cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_cols)
	_build_left_column(_cols)
	_build_center_column(_cols)
	_build_right_column(_cols)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	root.add_child(_status_label)

func _build_toolbar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)
	bar.add_child(_label("Category"))
	_category_option = OptionButton.new()
	_category_option.custom_minimum_size = Vector2(140, 28)
	_category_option.item_selected.connect(_on_category_changed)
	bar.add_child(_category_option)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(80, 28)
	save_btn.pressed.connect(_on_save_pressed)
	bar.add_child(save_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

func _build_left_column(parent: HSplitContainer) -> void:
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(left)
	_details_box = VBoxContainer.new()
	_details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_details_box)
	_rebuild_details_form()

func _build_center_column(parent: HSplitContainer) -> void:
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(360, 0)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	var tabs := HBoxContainer.new()
	center.add_child(tabs)
	var sprites_btn := Button.new()
	sprites_btn.text = "Sprites"
	sprites_btn.pressed.connect(func() -> void:
		_browse_tab = 0
		_rebuild_list()
	)
	tabs.add_child(sprites_btn)
	var items_btn := Button.new()
	items_btn.text = "Items"
	items_btn.pressed.connect(func() -> void:
		_browse_tab = 1
		_rebuild_list()
	)
	tabs.add_child(items_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)
	_preview_icon = TextureRect.new()
	_preview_icon.custom_minimum_size = Vector2(0, 96)
	_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(_preview_icon)

func _build_right_column(parent: HSplitContainer) -> void:
	var right := ScrollContainer.new()
	right.custom_minimum_size = Vector2(240, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(right)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(box)
	box.add_child(_section("Actions"))
	for spec in [
		["New", _on_new_pressed],
		["Clone", _on_clone_pressed],
		["Edit", _on_edit_pressed],
		["Delete", _on_delete_pressed],
	]:
		var btn := Button.new()
		btn.text = spec[0]
		btn.pressed.connect(spec[1])
		box.add_child(btn)
	box.add_child(_section("Filters"))
	box.add_child(_label("Family"))
	_family_option = OptionButton.new()
	_family_option.item_selected.connect(func(_i: int) -> void: _rebuild_list())
	box.add_child(_family_option)
	box.add_child(_label("Preview state"))
	_state_option = OptionButton.new()
	_state_option.item_selected.connect(_on_preview_state_changed)
	box.add_child(_state_option)
	box.add_child(_label("Preview quality"))
	_quality_option = OptionButton.new()
	_quality_option.item_selected.connect(_on_preview_quality_changed)
	box.add_child(_quality_option)
	box.add_child(_label("Preview modifier"))
	_modifier_option = OptionButton.new()
	_modifier_option.item_selected.connect(_on_preview_modifier_changed)
	box.add_child(_modifier_option)
	box.add_child(_label("Tag filter"))
	_tag_filter = LineEdit.new()
	_tag_filter.placeholder_text = "sword, 2handed…"
	_tag_filter.text_submitted.connect(func(_t: String) -> void: _rebuild_list())
	box.add_child(_tag_filter)

func _rebuild_details_form() -> void:
	if _details_box == null:
		return
	for child in _details_box.get_children():
		child.queue_free()
	_details_box.add_child(_section("Item properties"))
	_id_field = _add_line_field("id")
	_name_key_field = _add_line_field("display_name_key")
	_desc_key_field = _add_line_field("description_key")
	_weight_field = _add_spin_field("weight", 0, 9999, 0.1)
	_price_field = _add_spin_field("base_price", 0, 999999, 1)
	_durability_field = _add_spin_field("max_durability", 0, 9999, 1)
	_grid_w_field = _add_spin_field("grid_w", 1, 8, 1)
	_grid_h_field = _add_spin_field("grid_h", 1, 8, 1)
	_tags_field = _add_line_field("tags (comma)")
	_tier_state_box = VBoxContainer.new()
	_details_box.add_child(_section("State tiers"))
	_details_box.add_child(_tier_state_box)
	var reset_state := Button.new()
	reset_state.text = "Reset default state tiers"
	reset_state.pressed.connect(_on_reset_state_tiers)
	_tier_state_box.add_child(reset_state)
	_tier_quality_box = VBoxContainer.new()
	_details_box.add_child(_section("Quality tiers"))
	_details_box.add_child(_tier_quality_box)
	var reset_quality := Button.new()
	reset_quality.text = "Reset default quality tiers"
	reset_quality.pressed.connect(_on_reset_quality_tiers)
	_tier_quality_box.add_child(reset_quality)
	_weapon_section = VBoxContainer.new()
	_details_box.add_child(_section("Weapon payload"))
	_details_box.add_child(_weapon_section)
	_weapon_family_field = _add_line_field_to(_weapon_section, "weapon_family")
	_weapon_type_field = _add_line_field_to(_weapon_section, "design_type")
	_weapon_section.add_child(_label("equip slot"))
	_weapon_slot_option = OptionButton.new()
	for slot in [&"arm_right", &"arm_left", &"belt", &"back"]:
		_weapon_slot_option.add_item(String(slot), -1)
		_weapon_slot_option.set_item_metadata(_weapon_slot_option.item_count - 1, slot)
	_weapon_section.add_child(_weapon_slot_option)
	_weapon_hands_field = _add_spin_field_to(_weapon_section, "hands", 1, 2, 1)
	_weapon_modifier_field = _add_line_field_to(_weapon_section, "attribute_modifier_id")
	_armor_section = VBoxContainer.new()
	_details_box.add_child(_section("Armor payload"))
	_details_box.add_child(_armor_section)
	_armor_section.add_child(_label("equip slot"))
	_armor_slot_option = OptionButton.new()
	for slot in [&"head", &"body", &"arm_left", &"arm_right", &"belt", &"neck", &"ring_1", &"ring_2", &"feet", &"back"]:
		_armor_slot_option.add_item(String(slot), -1)
		_armor_slot_option.set_item_metadata(_armor_slot_option.item_count - 1, slot)
	_armor_section.add_child(_armor_slot_option)
	_armor_modifier_field = _add_line_field_to(_armor_section, "attribute_modifier_id")
	_food_section = VBoxContainer.new()
	_details_box.add_child(_section("Food payload"))
	_details_box.add_child(_food_section)
	_food_nutrition_field = _add_spin_field_to(_food_section, "nutrition", 0, 999, 1)
	_food_spoilage_field = _add_spin_field_to(_food_section, "spoilage_hours", 0, 9999, 1)
	_food_stackable = CheckBox.new()
	_food_stackable.text = "stackable"
	_food_stackable.button_pressed = true
	_food_section.add_child(_food_stackable)
	_valuable_section = VBoxContainer.new()
	_details_box.add_child(_section("Valuable payload"))
	_details_box.add_child(_valuable_section)
	_valuable_stackable = CheckBox.new()
	_valuable_stackable.text = "stackable"
	_valuable_stackable.button_pressed = true
	_valuable_section.add_child(_valuable_stackable)
	_valuable_merchant_field = _add_line_field_to(_valuable_section, "merchant_category")
	_update_category_sections_visibility()
	_sync_form_from_draft()

func _populate_categories() -> void:
	_category_option.clear()
	for cat in _items.list_categories():
		_category_option.add_item(tr(cat.display_name_key) if not cat.display_name_key.is_empty() else String(cat.id))
		_category_option.set_item_metadata(_category_option.item_count - 1, cat.id)
	if _category_option.item_count > 0:
		_category_option.select(0)

func _populate_weapon_families() -> void:
	_family_option.clear()
	_family_option.add_item("(all)", -1)
	_family_option.set_item_metadata(0, &"")
	var seen: Dictionary = {}
	for entry in _items.list_sprite_templates(&"weapon"):
		var fam: StringName = entry.get("family", &"")
		if String(fam).is_empty() or seen.has(fam):
			continue
		seen[fam] = true
		_family_option.add_item(String(fam))
		_family_option.set_item_metadata(_family_option.item_count - 1, fam)

func _populate_preview_tiers() -> void:
	_state_option.clear()
	for tier in _items.default_weapon_state_tiers():
		_state_option.add_item(tr(tier.display_name_key) if not tier.display_name_key.is_empty() else String(tier.id))
	_quality_option.clear()
	for tier in _items.default_quality_tiers():
		_quality_option.add_item(tr(tier.display_name_key) if not tier.display_name_key.is_empty() else String(tier.id))

func _current_category_id() -> StringName:
	var idx := _category_option.selected
	if idx < 0:
		return &"weapon"
	return _category_option.get_item_metadata(idx)

func _current_family_filter() -> StringName:
	if _family_option == null or _family_option.selected < 0:
		return &""
	return _family_option.get_item_metadata(_family_option.selected)

func _rebuild_list() -> void:
	if _list_box == null:
		return
	for child in _list_box.get_children():
		child.queue_free()
	var tag_filter := _tag_filter.text.strip_edges().to_lower() if _tag_filter != null else ""
	if _browse_tab == 0:
		_append_sprite_rows(tag_filter)
	else:
		_append_item_rows(tag_filter)

func _append_sprite_rows(tag_filter: String) -> void:
	var family := _current_family_filter()
	var entries := _items.list_sprite_templates(_current_category_id(), family)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")) < String(b.get("label", ""))
	)
	if entries.is_empty():
		_list_box.add_child(_body_label("No sprite templates."))
		return
	for entry in entries:
		if not tag_filter.is_empty() and not String(entry.get("label", "")).to_lower().contains(tag_filter):
			continue
		var row := _ROW.new()
		row.custom_minimum_size = Vector2(0, 56)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list_box.add_child(row)
		row.setup(entry, true)
		row.row_selected.connect(_on_row_selected)

func _append_item_rows(tag_filter: String) -> void:
	var filter := {"category_id": _current_category_id()}
	var defs := _items.list_defs(filter)
	defs.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		return String(a.id) < String(b.id)
	)
	if defs.is_empty():
		_list_box.add_child(_body_label("No saved items for this category."))
		return
	for def in defs:
		if not tag_filter.is_empty():
			var hit := false
			for t in def.tags:
				if String(t).to_lower().contains(tag_filter):
					hit = true
					break
			if not hit and not String(def.id).to_lower().contains(tag_filter):
				continue
		var row_data := _items.resolve_list_row(
			def,
			_preview_state,
			_preview_quality,
			_preview_modifier_ids,
		)
		var row := _ROW.new()
		row.custom_minimum_size = Vector2(0, 72)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list_box.add_child(row)
		row.setup(row_data, false)
		row.row_selected.connect(_on_row_selected)

func _on_row_selected(meta: Dictionary) -> void:
	_selected_meta = meta
	_refresh_preview_icon()

func _on_category_changed(_idx: int) -> void:
	_update_category_sections_visibility()
	_rebuild_list()

func _on_preview_state_changed(idx: int) -> void:
	_preview_state = idx
	_refresh_preview_icon()
	if _browse_tab == 1:
		_rebuild_list()

func _on_preview_quality_changed(idx: int) -> void:
	_preview_quality = idx
	_refresh_preview_icon()
	if _browse_tab == 1:
		_rebuild_list()

func _on_preview_modifier_changed(idx: int) -> void:
	_preview_modifier_ids.clear()
	if idx > 0 and _modifier_option != null:
		var mid: StringName = _modifier_option.get_item_metadata(idx)
		if not String(mid).is_empty():
			_preview_modifier_ids.append(mid)
	_refresh_preview_icon()
	if _browse_tab == 1:
		_rebuild_list()

func _populate_item_modifiers() -> void:
	if _modifier_option == null:
		return
	_modifier_option.clear()
	_modifier_option.add_item("(none)", -1)
	_modifier_option.set_item_metadata(0, &"")
	for def in _modifier.list_by_kind(ModifierDef.Kind.ITEM):
		_modifier_option.add_item(tr(def.display_name_key) if not def.display_name_key.is_empty() else String(def.id))
		_modifier_option.set_item_metadata(_modifier_option.item_count - 1, def.id)

func _on_reset_state_tiers() -> void:
	if _draft == null:
		return
	_draft.state_tiers = _items.default_weapon_state_tiers()
	_set_status("State tiers reset")

func _on_reset_quality_tiers() -> void:
	if _draft == null:
		return
	_draft.quality_tiers = _items.default_quality_tiers()
	_set_status("Quality tiers reset")

func _refresh_preview_icon() -> void:
	if _preview_icon == null:
		return
	if _draft != null:
		var inst := ItemInstance.new()
		inst.def_id = _draft.id
		inst.state_index = _preview_state
		inst.quality_index = _preview_quality
		inst.modifier_ids = _preview_modifier_ids.duplicate()
		_preview_icon.texture = _items.resolve_icon(inst, _draft)
		return
	if _selected_meta.has("icon"):
		_preview_icon.texture = _selected_meta.get("icon")
	elif _selected_meta.has("library_path"):
		var path: String = _selected_meta.get("library_path", "")
		if ResourceLoader.exists(path):
			_preview_icon.texture = load(path) as Texture2D
	else:
		_preview_icon.texture = null

func _update_category_sections_visibility() -> void:
	var cat := _current_category_id()
	if _weapon_section != null:
		_weapon_section.visible = cat == &"weapon"
	if _armor_section != null:
		_armor_section.visible = cat == &"armor"
	if _food_section != null:
		_food_section.visible = cat == &"food"
	if _valuable_section != null:
		_valuable_section.visible = cat == &"valuable"

func _on_new_pressed() -> void:
	var cat := _current_category_id()
	_draft = _items.create_blank_def(cat)
	if _selected_meta.get("is_sprite_template", false):
		_apply_sprite_template_to_draft(_selected_meta)
	elif not _selected_meta.is_empty() and _selected_meta.has("id"):
		var src := _items.load_def(_selected_meta.get("id"))
		if src != null:
			_draft = _items.duplicate_def(src)
			_draft.id = &""
	_sync_form_from_draft()
	_refresh_preview_icon()
	_set_status("New draft")

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
		_set_status("Select an item to clone")
		return
	_sync_form_from_draft()
	_set_status("Cloned to draft")

func _on_edit_pressed() -> void:
	if _selected_meta.get("is_sprite_template", false):
		_on_new_pressed()
		return
	if not _selected_meta.has("id"):
		_set_status("Select an item row")
		return
	_draft = _items.load_def(_selected_meta.get("id"))
	if _draft == null:
		_set_status("Failed to load item")
		return
	_sync_form_from_draft()
	_refresh_preview_icon()
	_set_status("Editing %s" % _draft.id)

func _on_delete_pressed() -> void:
	if _draft == null or String(_draft.id).is_empty():
		_set_status("Nothing to delete")
		return
	var path := "res://assets/data/items/%s.tres" % _draft.id
	if DirAccess.remove_absolute(path) != OK:
		_set_status("Delete failed: %s" % path)
		return
	_draft = null
	_rebuild_list()
	_set_status("Deleted %s" % path)

func _on_save_pressed() -> void:
	if _draft == null:
		_draft = _items.create_blank_def(_current_category_id())
	_apply_form_to_draft()
	if String(_draft.id).is_empty():
		_set_status("id is required")
		return
	var err := _items.save_def(_draft)
	if err != OK:
		_set_status("Save failed (%s)" % err)
		return
	_rebuild_list()
	_set_status("Saved %s" % _draft.id)

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
	var fam := String(meta.get("family", ""))
	var typ := String(meta.get("design_type", ""))
	_draft.id = StringName("%s_%s" % [fam, typ]) if not fam.is_empty() else &"new_item"
	_draft.display_name_key = "item.%s.name" % _draft.id
	_draft.tags = [meta.get("family", &""), &"weapon"]

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
	_draft.tags.clear()
	for part in _tags_field.text.split(","):
		var t := part.strip_edges()
		if not t.is_empty():
			_draft.tags.append(StringName(t))
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
		return
	_id_field.text = String(_draft.id)
	_name_key_field.text = _draft.display_name_key
	_desc_key_field.text = _draft.description_key
	_weight_field.value = _draft.weight
	_price_field.value = _draft.base_price
	_durability_field.value = _draft.max_durability
	_grid_w_field.value = _draft.inventory_size.x
	_grid_h_field.value = _draft.inventory_size.y
	var tag_parts: PackedStringArray = []
	for t in _draft.tags:
		tag_parts.append(String(t))
	_tags_field.text = ", ".join(tag_parts)
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
	_refresh_preview_icon()

func _add_line_field(placeholder: String) -> LineEdit:
	_details_box.add_child(_label(placeholder))
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_box.add_child(field)
	return field

func _add_spin_field(label_text: String, min_v: float, max_v: float, step: float) -> SpinBox:
	return _add_spin_field_to(_details_box, label_text, min_v, max_v, step)

func _add_line_field_to(parent: Control, placeholder: String) -> LineEdit:
	parent.add_child(_label(placeholder))
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(field)
	return field

func _add_spin_field_to(parent: Control, label_text: String, min_v: float, max_v: float, step: float) -> SpinBox:
	parent.add_child(_label(label_text))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
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
