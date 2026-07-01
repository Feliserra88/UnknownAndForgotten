@tool
extends Control
## NPC editor workspace: 3-column layout (details / rig preview / inspection) driven entirely by the
## public module facades. In-memory only in this iteration: editing composes an NpcInstanceData and
## updates the live preview; saving archetypes back to .tres is a follow-up task.

const _ITEM := preload("res://addons/uf_npc_editor/compatible_item.gd")
const _ARCHETYPE_DIR := "res://assets/data/archetypes"
const _LOG := "NPC"
const _ATTR_NAMES: Array[String] = ["strength", "agility", "willpower", "vitality", "perception", "charisma"]
const _ORIENTATIONS: Array[StringName] = [&"front", &"back", &"side_left", &"side_right"]

var _npc: NpcModule
var _gui: GuiModule
var _faction: FactionModule
var _modifier: ModifierModule
var _equipment: EquipmentModule

var _archetype: NpcArchetype
var _instance: NpcInstanceData
var _archetype_paths: Array[String] = []

var _archetype_option: OptionButton
var _faction_option: OptionButton
var _modifier_option: OptionButton
var _details_box: VBoxContainer
var _effective_label: Label
var _preview_viewport: SubViewport
var _appearance: NpcAppearanceController
var _inspection_holder: VBoxContainer
var _inspection_panel: UfInspectionPanel
var _items_box: VBoxContainer

## Instantiates the module facades and builds the workspace. Call once after adding to the tree.
func setup() -> void:
	_npc = NpcModule.new()
	add_child(_npc)
	_gui = GuiModule.new()
	add_child(_gui)
	_faction = FactionModule.new()
	_modifier = ModifierModule.new()
	_equipment = EquipmentModule.new()
	_npc.set_facades(_faction, _modifier, _equipment)
	_build_ui()
	_populate_archetypes()
	_populate_factions()
	_populate_modifiers()
	if not _archetype_paths.is_empty():
		_load_archetype(_archetype_paths[0])

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bar := HBoxContainer.new()
	root.add_child(bar)
	bar.add_child(_plain_label("Archetype"))
	_archetype_option = OptionButton.new()
	_archetype_option.item_selected.connect(_on_archetype_selected)
	bar.add_child(_archetype_option)
	bar.add_child(_plain_label("  Faction"))
	_faction_option = OptionButton.new()
	_faction_option.item_selected.connect(_on_faction_selected)
	bar.add_child(_faction_option)
	bar.add_child(_plain_label("  Add modifier"))
	_modifier_option = OptionButton.new()
	_modifier_option.item_selected.connect(_on_modifier_selected)
	bar.add_child(_modifier_option)
	var save := Button.new()
	save.text = "Save archetype (TODO)"
	save.disabled = true
	bar.add_child(save)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 6)
	root.add_child(cols)

	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	_details_box = VBoxContainer.new()
	_details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_details_box)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 2.0
	cols.add_child(center)
	center.add_child(_heading("Preview"))
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(svc)
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(260, 340)
	_preview_viewport.transparent_bg = true
	svc.add_child(_preview_viewport)
	var orient := HBoxContainer.new()
	orient.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(orient)
	for o in _ORIENTATIONS:
		var b := Button.new()
		b.text = String(o)
		b.pressed.connect(_on_orientation_pressed.bind(o))
		orient.add_child(b)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(290, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_inspection_holder = VBoxContainer.new()
	_inspection_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_inspection_holder)
	right.add_child(_heading("Compatible items"))
	var items_scroll := ScrollContainer.new()
	items_scroll.custom_minimum_size = Vector2(0, 150)
	right.add_child(items_scroll)
	_items_box = VBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_scroll.add_child(_items_box)

# --- Population ---------------------------------------------------------------

func _populate_archetypes() -> void:
	_archetype_paths.clear()
	_archetype_option.clear()
	var dir := DirAccess.open(_ARCHETYPE_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var path := "%s/%s" % [_ARCHETYPE_DIR, file]
		_archetype_paths.append(path)
		_archetype_option.add_item(file.get_basename())

func _populate_factions() -> void:
	_faction_option.clear()
	_faction_option.add_item("(none)")
	_faction_option.set_item_metadata(0, &"")
	for def in _faction.list_defs():
		var label := tr(def.display_name_key) if not def.display_name_key.is_empty() else String(def.id)
		_faction_option.add_item(label)
		_faction_option.set_item_metadata(_faction_option.item_count - 1, def.id)

func _populate_modifiers() -> void:
	_modifier_option.clear()
	_modifier_option.add_item("(add...)")
	_modifier_option.set_item_metadata(0, &"")
	for def in _modifier.list_defs():
		_modifier_option.add_item(String(def.id))
		_modifier_option.set_item_metadata(_modifier_option.item_count - 1, def.id)

# --- Archetype load ----------------------------------------------------------

func _load_archetype(path: String) -> void:
	_archetype = load(path) as NpcArchetype
	if _archetype == null:
		Log.warn(_LOG, "editor: failed to load archetype %s" % path)
		return
	_instance = NpcInstanceData.new()
	_instance.apply_archetype(_archetype)
	_npc.assemble(_instance)
	_rebuild_preview()
	_rebuild_inspection()
	_rebuild_items()
	_rebuild_details()

func _rebuild_preview() -> void:
	for child in _preview_viewport.get_children():
		child.queue_free()
	_appearance = NpcAppearanceController.new()
	_preview_viewport.add_child(_appearance)
	_appearance.position = Vector2(_preview_viewport.size.x / 2.0, _preview_viewport.size.y * 0.72)
	_appearance.build_from(_archetype)
	_appearance.set_orientation(_instance.orientation)
	_reapply_equipment_visuals()

func _reapply_equipment_visuals() -> void:
	if _appearance == null:
		return
	for slot in _instance.equipment.occupied_slots():
		var item := _equipment.load_item(_instance.equipment.get_item(slot))
		if item != null:
			_appearance.set_equipment_texture(slot, item.icon)

func _rebuild_inspection() -> void:
	for child in _inspection_holder.get_children():
		child.queue_free()
	var layout := _archetype.resolve_inspection_layout()
	_inspection_panel = _gui.create_inspection_panel(layout)
	if _inspection_panel == null:
		_inspection_holder.add_child(_plain_label("No inspection layout for this archetype."))
		return
	_inspection_panel.draggable = false
	_inspection_panel.item_dropped.connect(_on_item_dropped)
	_inspection_panel.item_removed.connect(_on_item_removed)
	_inspection_holder.add_child(_inspection_panel)
	for slot in _instance.equipment.occupied_slots():
		var item := _equipment.load_item(_instance.equipment.get_item(slot))
		if item != null:
			_inspection_panel.set_slot_item(slot, item.id, item.icon)

func _rebuild_items() -> void:
	for child in _items_box.get_children():
		child.queue_free()
	var tags := _archetype.resolve_tags()
	for item in _equipment.list_items():
		if not item.allows_archetype(tags):
			continue
		var entry := _ITEM.new()
		_items_box.add_child(entry)
		entry.setup(item.id, tr(item.display_name_key), item.icon)

# --- Details column ----------------------------------------------------------

func _rebuild_details() -> void:
	for child in _details_box.get_children():
		child.queue_free()
	if _archetype == null or _instance == null:
		return
	_details_box.add_child(_heading(_archetype.get_display_name()))
	_details_box.add_child(_plain_label("id: %s" % _archetype.id))
	_details_box.add_child(_plain_label("tags: %s" % ", ".join(_string_list(_archetype.resolve_tags()))))

	_details_box.add_child(_heading("Base attributes"))
	for attr in _ATTR_NAMES:
		_details_box.add_child(_attribute_row(attr))

	_details_box.add_child(_heading("Effective (with modifiers)"))
	_effective_label = Label.new()
	_effective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_box.add_child(_effective_label)
	_refresh_effective()

	_details_box.add_child(_heading("Vitals"))
	_details_box.add_child(_plain_label("health: %.0f  energy: %.0f  mana: %.0f" % [
		_instance.vitals.health, _instance.vitals.energy, _instance.vitals.mana,
	]))

	_details_box.add_child(_heading("Factions"))
	var factions := _string_list(_instance.faction_ids)
	_details_box.add_child(_plain_label(", ".join(factions) if not factions.is_empty() else "(none)"))

	_details_box.add_child(_heading("Modifiers"))
	_append_modifiers_by_kind()

func _append_modifiers_by_kind() -> void:
	var defs := _modifier.resolve(_instance.modifier_ids)
	var kind_names := {
		ModifierDef.Kind.TRAIT: "Traits",
		ModifierDef.Kind.MALADY: "Maladies",
		ModifierDef.Kind.STATUS: "Status",
		ModifierDef.Kind.SCALER: "Scalers",
	}
	for kind in kind_names:
		var names: Array[String] = []
		for def in defs:
			if def.kind == kind:
				names.append(tr(def.display_name_key) if not def.display_name_key.is_empty() else String(def.id))
		if not names.is_empty():
			_details_box.add_child(_plain_label("%s: %s" % [kind_names[kind], ", ".join(names)]))

func _attribute_row(attr_name: String) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = attr_name
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 999
	spin.step = 1
	spin.value = int(_instance.attributes.get(attr_name))
	spin.value_changed.connect(_on_attribute_changed.bind(attr_name))
	row.add_child(spin)
	return row

func _refresh_effective() -> void:
	if _effective_label == null:
		return
	var eff := _npc.effective_attributes(_instance)
	var lines: Array[String] = []
	for attr in _ATTR_NAMES:
		var base_value := int(_instance.attributes.get(attr))
		var eff_value := int(eff.get(attr))
		var suffix := "" if base_value == eff_value else "  (base %d)" % base_value
		lines.append("%s: %d%s" % [attr, eff_value, suffix])
	_effective_label.text = "\n".join(lines)

# --- Signal handlers ---------------------------------------------------------

func _on_archetype_selected(index: int) -> void:
	if index >= 0 and index < _archetype_paths.size():
		_load_archetype(_archetype_paths[index])

func _on_faction_selected(index: int) -> void:
	if _instance == null:
		return
	var fid: StringName = _faction_option.get_item_metadata(index)
	_instance.faction_ids.clear()
	if not String(fid).is_empty():
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
	if item == null:
		return
	if item.slot != slot_id:
		Log.detail(_LOG, "drop", "item %s rejected by slot %s" % [item_id, slot_id])
		return
	var from_slot := StringName(payload.get("from_slot", &""))
	if not String(from_slot).is_empty() and from_slot != slot_id:
		_instance.equipment.unequip(from_slot)
		_inspection_panel.clear_slot(from_slot)
		_appearance.clear_equipment_texture(from_slot)
	_instance.equipment.equip(slot_id, item_id)
	_inspection_panel.set_slot_item(slot_id, item_id, item.icon)
	_appearance.set_equipment_texture(slot_id, item.icon)
	_refresh_effective()

func _on_item_removed(slot_id: StringName) -> void:
	if _instance == null:
		return
	_instance.equipment.unequip(slot_id)
	if _appearance != null:
		_appearance.clear_equipment_texture(slot_id)
	_refresh_effective()

func _on_attribute_changed(value: float, attr_name: String) -> void:
	if _instance == null:
		return
	_instance.attributes.set(attr_name, int(value))
	_refresh_effective()

# --- Small UI helpers --------------------------------------------------------

func _plain_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	return label

func _string_list(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		out.append(String(id))
	return out
