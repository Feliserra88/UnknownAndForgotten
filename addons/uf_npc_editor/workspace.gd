@tool
extends Control
## NPC editor workspace (debug skeleton). Three columns: details, rig preview, inspection + item list.

const _ITEM := preload("res://addons/uf_npc_editor/compatible_item.gd")
const _I18N := preload("res://addons/uf_npc_editor/editor_i18n.gd")
const _DEFAULT_ARCHETYPE_ID := &"humanoid"
const _LOG := "NPC"
const _STARTER_EQUIPMENT: Array = [
	[&"head", &"equipo_humano_cabeza_dummy"],
	[&"body", &"equipo_humano_cuerpo_dummy"],
	[&"arm_left", &"equipo_humano_brazo_izq_dummy"],
	[&"arm_right", &"equipo_humano_brazo_der_dummy"],
]
const _ATTR_NAMES: Array[String] = ["strength", "agility", "willpower", "vitality", "perception", "charisma"]
const _ORIENTATIONS: Array[StringName] = [&"front", &"back", &"side_left", &"side_right"]
const _MARGIN := 8
const _PANEL_SEP := 6
const _FIELD_SEP := 6
const _SECTION_SEP := 8
const _LABEL_WIDTH := 96
const _BTN_H := 26
const _INSPECTION_SCROLL_MIN := Vector2(200, 80)
const _ITEMS_PANEL_MIN_H := 160
const _INSPECTION_CHROME_H := 28

var _npc: NpcModule
var _gui: GuiModule
var _faction: FactionModule
var _modifier: ModifierModule
var _equipment: EquipmentModule
var _items: ItemsModule

var _archetype: NpcArchetype
var _instance: NpcInstanceData
var _archetype_paths: Array[String] = []
var _data_ready: bool = false

var _archetype_option: OptionButton
var _faction_option: OptionButton
var _modifier_option: OptionButton
var _status_label: Label
var _details_box: VBoxContainer
var _attr_total_label: Label
var _preview_host: Control
var _preview_viewport: SubViewport
var _appearance: NpcAppearanceController
var _inspection_holder: VBoxContainer
var _inspection_panel: UfInspectionPanel
var _items_box: VBoxContainer
var _cols: HSplitContainer
var _center_right: HSplitContainer
var _right_split: VSplitContainer
var _details_scroll: ScrollContainer
var _inspection_scroll: ScrollContainer
var _items_scroll: ScrollContainer
var _locale_labels: Array[Dictionary] = []
var _action_buttons: Array[Dictionary] = []
var _orientation_buttons: Array[Dictionary] = []
var _localizing: bool = false

func setup() -> void:
	_npc = NpcModule.new()
	add_child(_npc)
	_gui = GuiModule.new()
	add_child(_gui)
	_faction = FactionModule.new()
	_modifier = ModifierModule.new()
	_equipment = EquipmentModule.new()
	_items = ItemsModule.new()
	_npc.set_facades(_faction, _modifier, _equipment)
	_build_ui()
	_refresh_localized_strings()

func ensure_ready() -> void:
	_fit_to_parent()
	if not _data_ready:
		call_deferred("_bootstrap_data")
	else:
		_refresh_localized_ui()
		if _archetype != null:
			call_deferred("_rebuild_all")
	_finalize_layout()
	call_deferred("_finalize_layout")

func sync_layout() -> void:
	_fit_to_parent()
	_sync_preview_viewport_size()
	_finalize_layout()

func _fit_to_parent() -> void:
	var parent := get_parent() as Control
	if parent == null or parent.size.y < 8:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = parent.size

func _bootstrap_data() -> void:
	_populate_archetypes()
	_populate_factions()
	_populate_modifiers()
	var item_count := _equipment.list_items().size()
	_set_status(_T("npc_editor.status.catalog_stats") % [_archetype_paths.size(), item_count])
	if _archetype_paths.is_empty():
		_set_status(_T("npc_editor.status.no_archetypes"))
		return
	var idx := 0
	for i in _archetype_paths.size():
		var archetype := load(_archetype_paths[i]) as NpcArchetype
		if archetype != null and archetype.id == _DEFAULT_ARCHETYPE_ID:
			idx = i
			break
	_archetype_option.set_block_signals(true)
	_archetype_option.select(idx)
	_archetype_option.set_block_signals(false)
	_load_archetype(_archetype_paths[idx])
	_data_ready = true
	call_deferred("_finalize_layout")

func _finalize_layout() -> void:
	_apply_column_splits()
	_sync_preview_viewport_size()
	_sync_right_vertical_split()
	_center_preview_rig()

func _apply_column_splits() -> void:
	if _cols == null or _cols.size.x < 480:
		return
	var total_w := _cols.size.x
	_cols.split_offset = clampi(int(total_w * 0.24), 220, int(total_w * 0.32))
	if _center_right != null:
		var sep := _cols.get_theme_constant("separation", "HSplitContainer")
		var inner_w := maxi(total_w - _cols.split_offset - sep, 320)
		_center_right.split_offset = clampi(int(inner_w * 0.58), 260, int(inner_w * 0.72))
	if _right_split != null and _right_split.size.y > _ITEMS_PANEL_MIN_H + _INSPECTION_SCROLL_MIN.y:
		_sync_right_vertical_split()

func _sync_right_vertical_split() -> void:
	if _right_split == null or _inspection_holder == null:
		return
	_inspection_holder.update_minimum_size()
	var content_h := int(_inspection_holder.get_combined_minimum_size().y)
	if content_h < 8 and _inspection_panel != null:
		content_h = int(_inspection_panel.get_combined_minimum_size().y)
	var sep := _right_split.get_theme_constant("separation", "VSplitContainer")
	var avail := _right_split.size.y - sep
	if avail < _ITEMS_PANEL_MIN_H + _INSPECTION_SCROLL_MIN.y:
		return
	var top_h := clampi(
		content_h + _INSPECTION_CHROME_H,
		_INSPECTION_SCROLL_MIN.y,
		avail - _ITEMS_PANEL_MIN_H,
	)
	_right_split.split_offset = top_h
	if _inspection_scroll != null:
		_inspection_scroll.custom_minimum_size.y = maxi(content_h, 1)
		_inspection_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _sync_preview_viewport_size() -> void:
	if _preview_host == null or _preview_viewport == null:
		return
	var sz := _preview_host.size
	if sz.x < 8 or sz.y < 8:
		return
	_preview_viewport.size = Vector2i(int(sz.x), int(sz.y))

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

	var cols := HSplitContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	_cols = cols

	_build_left_column(cols)
	_center_right = HSplitContainer.new()
	_center_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(_center_right)
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

func _build_toolbar(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", _FIELD_SEP)
	panel.add_child(bar)

	bar.add_child(_tracked_label("npc_editor.toolbar.archetype"))
	_archetype_option = _toolbar_option()
	_archetype_option.custom_minimum_size = Vector2(180, _BTN_H)
	_archetype_option.item_selected.connect(_on_archetype_selected)
	bar.add_child(_archetype_option)

	bar.add_child(_tracked_label("npc_editor.toolbar.faction"))
	_faction_option = _toolbar_option()
	_faction_option.custom_minimum_size = Vector2(150, _BTN_H)
	_faction_option.item_selected.connect(_on_faction_selected)
	bar.add_child(_faction_option)

	bar.add_child(_tracked_label("npc_editor.toolbar.modifier"))
	_modifier_option = _toolbar_option()
	_modifier_option.custom_minimum_size = Vector2(150, _BTN_H)
	_modifier_option.item_selected.connect(_on_modifier_selected)
	bar.add_child(_modifier_option)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var save := Button.new()
	save.disabled = true
	save.custom_minimum_size = Vector2(100, _BTN_H)
	_action_buttons.append({"button": save, "key": "npc_editor.action.save_todo"})
	bar.add_child(save)

func _build_left_column(parent: HSplitContainer) -> void:
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(left)
	_details_scroll = left
	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", _FIELD_SEP)
	_details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_details_box)

func _build_center_column(parent: HSplitContainer) -> void:
	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", _FIELD_SEP)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	center.add_child(_tracked_section_label("npc_editor.preview"))
	center.add_child(HSeparator.new())

	var preview_frame := Panel.new()
	preview_frame.custom_minimum_size = Vector2(240, 240)
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(preview_frame)
	_preview_host = preview_frame

	var preview_svc := SubViewportContainer.new()
	preview_svc.stretch = true
	preview_svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_host.add_child(preview_svc)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(320, 320)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_viewport.handle_input_locally = false
	_preview_viewport.disable_3d = true
	preview_svc.add_child(_preview_viewport)

	var orient := HBoxContainer.new()
	orient.alignment = BoxContainer.ALIGNMENT_CENTER
	orient.add_theme_constant_override("separation", _FIELD_SEP)
	center.add_child(orient)
	for o in _ORIENTATIONS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, _BTN_H)
		b.pressed.connect(_on_orientation_pressed.bind(o))
		_orientation_buttons.append({"button": b, "key": "npc_editor.orient.%s" % o})
		b.text = _T("npc_editor.orient.%s" % o)
		orient.add_child(b)

func _build_right_column(parent: HSplitContainer) -> void:
	var right := VSplitContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(right)
	_right_split = right

	var top_inspection := VBoxContainer.new()
	top_inspection.add_theme_constant_override("separation", _FIELD_SEP)
	top_inspection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_inspection.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(top_inspection)

	top_inspection.add_child(_tracked_section_label("npc_editor.inspection"))
	top_inspection.add_child(HSeparator.new())

	var inspection_scroll := ScrollContainer.new()
	inspection_scroll.custom_minimum_size = Vector2(_INSPECTION_SCROLL_MIN.x, 0)
	inspection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspection_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	inspection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_inspection.add_child(inspection_scroll)
	_inspection_scroll = inspection_scroll
	_inspection_holder = VBoxContainer.new()
	_inspection_holder.add_theme_constant_override("separation", _FIELD_SEP)
	_inspection_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspection_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	inspection_scroll.add_child(_inspection_holder)

	var items_panel := VBoxContainer.new()
	items_panel.add_theme_constant_override("separation", _FIELD_SEP)
	items_panel.custom_minimum_size = Vector2(_INSPECTION_SCROLL_MIN.x, _ITEMS_PANEL_MIN_H)
	items_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(items_panel)
	items_panel.add_child(_tracked_section_label("npc_editor.compatible_items"))
	items_panel.add_child(HSeparator.new())

	var items_scroll := ScrollContainer.new()
	items_scroll.custom_minimum_size = Vector2(_INSPECTION_SCROLL_MIN.x, 80)
	items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	items_panel.add_child(items_scroll)
	_items_scroll = items_scroll
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 6)
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_scroll.add_child(_items_box)

# --- Population ---------------------------------------------------------------

func _populate_archetypes() -> void:
	_archetype_paths = _npc.catalog_archetype_paths()
	_archetype_option.clear()
	for path in _archetype_paths:
		var archetype := load(path) as NpcArchetype
		if archetype == null:
			continue
		var label := _archetype_display_name(archetype)
		_archetype_option.add_item(label if not label.is_empty() else String(archetype.id))

func _populate_factions() -> void:
	_faction_option.clear()
	for def in _faction.list_catalog_defs():
		var label := _T(def.display_name_key) if not def.display_name_key.is_empty() else String(def.id)
		_faction_option.add_item(label)
		_faction_option.set_item_metadata(_faction_option.item_count - 1, def.id)

func _populate_modifiers() -> void:
	_modifier_option.clear()
	_modifier_option.add_item(_T("npc_editor.modifier.add"))
	_modifier_option.set_item_metadata(0, &"")
	for def in _modifier.list_defs():
		_modifier_option.add_item(String(def.id))
		_modifier_option.set_item_metadata(_modifier_option.item_count - 1, def.id)

func _load_archetype(path: String) -> void:
	_archetype = load(path) as NpcArchetype
	if _archetype == null:
		_set_status(_T("npc_editor.status.load_failed") % path)
		return
	_instance = NpcInstanceData.new()
	_instance.apply_archetype(_archetype)
	_npc.assemble(_instance)
	_apply_starter_loadout()
	_sync_faction_picker()
	_rebuild_all()
	_set_status(_T("npc_editor.status.loaded") % [_archetype.id, _count_compatible_items()])

func _rebuild_all() -> void:
	if _archetype == null or _instance == null:
		return
	_rebuild_preview()
	_rebuild_inspection()
	_rebuild_items()
	_rebuild_details()
	call_deferred("_refresh_scroll_areas")
	call_deferred("_sync_right_vertical_split")
	call_deferred("_finalize_layout")

func _refresh_scroll_areas() -> void:
	for scroll in [_details_scroll, _inspection_scroll, _items_scroll]:
		if scroll != null:
			scroll.update_minimum_size()

func _count_compatible_items() -> int:
	var tags := _archetype.resolve_tags()
	var count := 0
	for item in _equipment.list_items():
		if item == null:
			continue
		if item.allows_archetype(tags):
			count += 1
	return count

func _apply_starter_loadout() -> void:
	if _archetype == null or _archetype.id != _DEFAULT_ARCHETYPE_ID:
		return
	for pair in _STARTER_EQUIPMENT:
		var inst := _items.create_instance(pair[1])
		_instance.equipment.equip(pair[0], inst)

func _sync_faction_picker() -> void:
	if _faction_option == null or _instance == null:
		return
	var active: StringName = &"none"
	if not _instance.faction_ids.is_empty():
		active = _instance.faction_ids[0]
	_faction_option.set_block_signals(true)
	for i in _faction_option.item_count:
		if _faction_option.get_item_metadata(i) == active:
			_faction_option.select(i)
			break
	_faction_option.set_block_signals(false)

func _rebuild_preview() -> void:
	if _preview_viewport == null:
		return
	for child in _preview_viewport.get_children():
		child.free()
	_appearance = NpcAppearanceController.new()
	_preview_viewport.add_child(_appearance)
	_center_preview_rig()
	_appearance.build_from(_archetype)
	_appearance.set_orientation(_instance.orientation)
	_reapply_equipment_visuals()
	call_deferred("_center_preview_rig")
	if _appearance.slot_part_ids().is_empty():
		Log.warn(_LOG, "preview: no rig parts for archetype %s" % _archetype.id)

func _center_preview_rig() -> void:
	if _preview_viewport == null or _appearance == null:
		return
	var vp := Vector2(_preview_viewport.size)
	_appearance.position = Vector2(vp.x * 0.5, vp.y * 0.68)

func _reapply_equipment_visuals() -> void:
	if _appearance == null:
		return
	for slot in _instance.equipment.occupied_slots():
		var inst := _instance.equipment.get_instance(slot)
		if inst != null:
			var icon_tex := _items.resolve_icon(inst)
			if icon_tex != null:
				_appearance.set_equipment_texture(slot, icon_tex)

func _rebuild_inspection() -> void:
	for child in _inspection_holder.get_children():
		child.queue_free()
	var layout := _archetype.resolve_inspection_layout()
	if layout == null:
		_inspection_holder.add_child(_body_label(_T("npc_editor.hint.no_inspection_layout")))
		return
	_inspection_panel = _gui.create_inspection_panel_for_archetype(_archetype)
	if _inspection_panel == null:
		_inspection_holder.add_child(_body_label(_T("npc_editor.hint.inspection_build_failed")))
		return
	_inspection_panel.draggable = false
	_inspection_panel.show_close_button = false
	_inspection_panel.show_minimize_button = false
	_inspection_panel.show_drag_handle = false
	_inspection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspection_panel.custom_minimum_size = Vector2(240, 0)
	_inspection_holder.add_child(_inspection_panel)
	if not _inspection_panel.item_dropped.is_connected(_on_item_dropped):
		_inspection_panel.item_dropped.connect(_on_item_dropped)
	if not _inspection_panel.item_removed.is_connected(_on_item_removed):
		_inspection_panel.item_removed.connect(_on_item_removed)
	for slot in _instance.equipment.occupied_slots():
		var inst := _instance.equipment.get_instance(slot)
		if inst != null:
			var icon_tex := _items.resolve_icon(inst)
			_inspection_panel.set_slot_item(slot, inst.def_id, icon_tex)

func _rebuild_items() -> void:
	for child in _items_box.get_children():
		child.queue_free()
	if _archetype == null:
		_items_box.add_child(_body_label(_T("npc_editor.hint.no_archetype")))
		return
	var tags := _archetype.resolve_tags()
	var items: Array[ItemDef] = []
	for item in _equipment.list_items():
		if item == null:
			continue
		if item.allows_archetype(tags):
			items.append(item)
	items.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		return String(a.id) < String(b.id))
	if items.is_empty():
		_items_box.add_child(_body_label(_T("npc_editor.hint.no_items_for_tags") % ", ".join(_string_list(tags))))
		return
	for item in items:
		var entry := _ITEM.new()
		entry.custom_minimum_size = Vector2(0, 36)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_items_box.add_child(entry)
		var label := _T(item.display_name_key) if not item.display_name_key.is_empty() else String(item.id)
		entry.setup(item.id, label, item.icon)

func _rebuild_details() -> void:
	for child in _details_box.get_children():
		child.queue_free()
	if _archetype == null or _instance == null:
		_details_box.add_child(_body_label(_T("npc_editor.hint.no_archetype")))
		return
	_details_box.add_child(_section_label(_archetype_display_name(_archetype)))
	_details_box.add_child(_body_label(_T("npc_editor.detail.id") % _archetype.id))
	_details_box.add_child(_body_label(_T("npc_editor.detail.tags") % ", ".join(_string_list(_archetype.resolve_tags()))))
	_section_gap(_details_box)
	_details_box.add_child(_section_label(_T("npc_editor.section.base_attributes")))
	_attr_total_label = Label.new()
	_attr_total_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.7))
	_details_box.add_child(_attr_total_label)
	_refresh_attribute_total()
	for attr in _ATTR_NAMES:
		_details_box.add_child(_attribute_row(attr))
	_section_gap(_details_box)
	_details_box.add_child(_section_label(_T("npc_editor.section.vitals")))
	_details_box.add_child(_body_label(_T("npc_editor.detail.health_energy") % [_instance.vitals.health, _instance.vitals.energy]))
	_section_gap(_details_box)
	_details_box.add_child(_section_label(_T("npc_editor.section.factions")))
	var factions := _string_list(_instance.faction_ids)
	_details_box.add_child(_body_label(", ".join(factions) if not factions.is_empty() else _T("npc_editor.hint.none")))
	_section_gap(_details_box)
	_details_box.add_child(_section_label(_T("npc_editor.section.modifiers")))
	_append_modifiers_by_kind()
	_section_gap(_details_box)
	_details_box.add_child(_section_label(_T("npc_editor.section.equipped_items")))
	_append_equipped_item_stats()

func _append_equipped_item_stats() -> void:
	if _instance == null:
		return
	for slot in _instance.equipment.occupied_slots():
		var inst := _instance.equipment.get_instance(slot)
		if inst == null:
			continue
		var item := _equipment.load_item(inst.def_id)
		var name := _T(item.display_name_key) if item != null and not item.display_name_key.is_empty() else String(inst.def_id)
		_details_box.add_child(_body_label(_T("npc_editor.detail.slot_item") % [slot, name]))
		var bonus := _items.resolve_effective_attributes(inst, _modifier)
		var lines: Array[String] = []
		for attr in _ATTR_NAMES:
			var val := int(bonus.get(attr))
			if val != 0:
				lines.append("%s %+d" % [attr, val])
		if lines.is_empty():
			lines.append(_T("npc_editor.hint.no_stat_bonus"))
		_details_box.add_child(_body_label("  " + ", ".join(lines)))
		if not inst.modifier_ids.is_empty():
			_details_box.add_child(_body_label("  " + _T("npc_editor.detail.mods") % ", ".join(_string_list(inst.modifier_ids))))

func _append_modifiers_by_kind() -> void:
	var defs := _modifier.resolve(_instance.modifier_ids)
	for def in defs:
		var name := _T(def.display_name_key) if not def.display_name_key.is_empty() else String(def.id)
		_details_box.add_child(_body_label("• %s (%s)" % [name, def.id]))

func _attribute_row(attr_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _FIELD_SEP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = _T("npc_editor.attr.%s" % attr_name)
	label.custom_minimum_size = Vector2(_LABEL_WIDTH, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = AttributesModule.ATTR_MIN
	spin.max_value = AttributesModule.ATTR_MAX
	spin.step = 1
	spin.custom_minimum_size = Vector2(0, _BTN_H)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value = int(_instance.attributes.get(attr_name))
	spin.value_changed.connect(_on_attribute_changed.bind(attr_name))
	row.add_child(spin)
	return row

func _refresh_attribute_total() -> void:
	if _attr_total_label == null or _instance == null:
		return
	var total := 0
	for attr in _ATTR_NAMES:
		total += int(_instance.attributes.get(attr))
	_attr_total_label.text = _T("npc_editor.attributes_total") % total

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_preview_viewport_size()
		_center_preview_rig()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		call_deferred("sync_layout")
		if _data_ready:
			call_deferred("_refresh_localized_ui")
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		if _data_ready:
			_refresh_localized_ui()

# --- Signal handlers ---------------------------------------------------------

func _on_archetype_selected(index: int) -> void:
	if index >= 0 and index < _archetype_paths.size():
		_load_archetype(_archetype_paths[index])

func _on_faction_selected(index: int) -> void:
	if _instance == null:
		return
	var fid: StringName = _faction_option.get_item_metadata(index)
	_instance.faction_ids.clear()
	_instance.faction_ids.append(fid)
	_instance.modifier_ids = _archetype.resolve_default_modifiers()
	_npc.assemble(_instance)
	_rebuild_details()

func _on_modifier_selected(index: int) -> void:
	if _instance == null or index <= 0:
		return
	var mid: StringName = _modifier_option.get_item_metadata(index)
	if not String(mid).is_empty() and not _instance.modifier_ids.has(mid):
		_instance.modifier_ids.append(mid)
	_modifier_option.select(0)
	_rebuild_details()

func _on_orientation_pressed(orientation: StringName) -> void:
	if _instance == null:
		return
	_instance.orientation = orientation
	if _appearance != null:
		_appearance.set_orientation(orientation)

func _on_item_dropped(slot_id: StringName, payload: Dictionary) -> void:
	var item_id := StringName(payload.get("item_id", &""))
	var item := _equipment.load_item(item_id)
	if item == null or item.get_equip_slot() != slot_id:
		return
	var from_slot := StringName(payload.get("from_slot", &""))
	if not String(from_slot).is_empty() and from_slot != slot_id:
		_instance.equipment.unequip(from_slot)
		_inspection_panel.clear_slot(from_slot)
		_appearance.clear_equipment_texture(from_slot)
	var inst := _items.create_instance(item_id)
	_instance.equipment.equip(slot_id, inst)
	var icon_tex := _items.resolve_icon(inst)
	_inspection_panel.set_slot_item(slot_id, item_id, icon_tex)
	_appearance.set_equipment_texture(slot_id, icon_tex)

func _on_item_removed(slot_id: StringName) -> void:
	_instance.equipment.unequip(slot_id)
	if _appearance != null:
		_appearance.clear_equipment_texture(slot_id)

func _on_attribute_changed(value: float, attr_name: String) -> void:
	_instance.attributes.set(attr_name, AttributesModule.clamp_attribute(int(value)))
	_refresh_attribute_total()

# --- UI helpers --------------------------------------------------------------

func _T(key: String) -> String:
	return _I18N.translate_key(key)

func _tracked_label(key: String) -> Label:
	var label := Label.new()
	_locale_labels.append({"label": label, "key": key, "is_button": false})
	label.text = _T(key)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

func _tracked_section_label(key: String) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0))
	label.custom_minimum_size = Vector2(0, 24)
	_locale_labels.append({"label": label, "key": key, "is_button": false})
	label.text = _T(key)
	return label

func _archetype_display_name(archetype: NpcArchetype) -> String:
	if archetype == null:
		return ""
	if not archetype.display_name_key.is_empty():
		return _T(archetype.display_name_key)
	return String(archetype.id)

func _refresh_localized_ui() -> void:
	if _localizing:
		return
	_localizing = true
	_refresh_localized_strings()
	if _data_ready:
		_populate_archetypes()
		_populate_factions()
		_populate_modifiers()
		if _archetype != null:
			_rebuild_items()
			_rebuild_details()
			_refresh_attribute_total()
	_localizing = false

func _refresh_localized_strings() -> void:
	_I18N.ensure_loaded()
	for spec in _action_buttons:
		if spec.has("button") and spec.has("key"):
			(spec.button as Button).text = _T(spec.key)
	for spec in _orientation_buttons:
		if spec.has("button") and spec.has("key"):
			(spec.button as Button).text = _T(spec.key)
	for spec in _locale_labels:
		var node: Node = spec.label
		if not is_instance_valid(node):
			continue
		if node is Label:
			(node as Label).text = _T(spec.key)

func _toolbar_option() -> OptionButton:
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return opt

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0))
	label.custom_minimum_size = Vector2(0, 24)
	return label

func _body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _section_gap(parent: Control) -> void:
	parent.add_child(HSeparator.new())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, _SECTION_SEP)
	parent.add_child(gap)

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _string_list(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		out.append(String(id))
	return out
