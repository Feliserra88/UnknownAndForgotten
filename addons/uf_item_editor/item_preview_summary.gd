@tool
extends VBoxContainer
## Text summary beside draft sprite preview (mirrors browse list row info + category payload).

const _I18N := preload("res://addons/uf_editor_ui/editor_i18n.gd")
const _SEP := 2

func clear_summary() -> void:
	for child in get_children():
		child.queue_free()

func show_empty() -> void:
	clear_summary()
	add_child(_muted(_I18N.translate_key("item_editor.preview.empty")))

func show_sprite_template(meta: Dictionary) -> void:
	clear_summary()
	var label := String(meta.get("label", ""))
	if not label.is_empty():
		add_child(_title(label))
	add_child(_muted(_I18N.translate_key("item_editor.row.art_source")))
	var family := String(meta.get("family", ""))
	var design := String(meta.get("design_type", ""))
	if not family.is_empty() or not design.is_empty():
		var archetype := family
		if not design.is_empty():
			archetype = "%s / %s" % [archetype, design] if not archetype.is_empty() else design
		add_child(_muted("%s: %s" % [_I18N.translate_key("item_editor.preview.archetype"), archetype]))

func show_item(items: ItemsModule, row: Dictionary, def: ItemDef) -> void:
	clear_summary()
	if def == null:
		show_empty()
		return
	var name_key: String = row.get("display_name_key", "")
	var title_text := _I18N.translate_key(name_key) if not name_key.is_empty() else String(row.get("id", def.id))
	add_child(_title(title_text))
	if not String(def.id).is_empty():
		add_child(_muted("id: %s" % String(def.id)))
	add_child(_muted(
		"w:%.1f  price:%.0f  dur:%.0f  grid:%dx%d" % [
			float(row.get("weight", def.weight)),
			float(row.get("price", 0)),
			float(row.get("durability", def.max_durability)),
			int(row.get("inventory_size", def.inventory_size).x),
			int(row.get("inventory_size", def.inventory_size).y),
		]
	))
	var tags: Array = row.get("tags", def.tags)
	if not tags.is_empty():
		add_child(_muted("%s: %s" % [_I18N.translate_key("item_editor.preview.tags"), _tag_labels(items, tags)]))
	var state_key: String = row.get("state_key", "")
	var quality_key: String = row.get("quality_key", "")
	if not state_key.is_empty() or not quality_key.is_empty():
		add_child(_muted("%s / %s" % [
			_I18N.translate_key(state_key) if not state_key.is_empty() else "-",
			_I18N.translate_key(quality_key) if not quality_key.is_empty() else "-",
		]))
	var mods: Array = row.get("modifier_ids", [])
	if not mods.is_empty():
		add_child(_muted("mods: %s" % ", ".join(_string_names(mods))))
	_append_category_payload(def)

func _append_category_payload(def: ItemDef) -> void:
	if def.category_data is WeaponItemData:
		var w := def.category_data as WeaponItemData
		var archetype := String(w.weapon_family)
		if not String(w.design_type).is_empty():
			archetype = "%s / %s" % [archetype, w.design_type] if not archetype.is_empty() else String(w.design_type)
		if not archetype.is_empty():
			add_child(_muted("%s: %s" % [_I18N.translate_key("item_editor.preview.archetype"), archetype]))
		var slot := String(w.slot)
		if not slot.is_empty():
			add_child(_muted("%s: %s" % [_I18N.translate_key("item_editor.field.equip_slot"), slot]))
		add_child(_muted("%s: %d" % [_I18N.translate_key("item_editor.field.hands"), w.hands]))
		if not String(w.attribute_modifier_id).is_empty():
			add_child(_muted("%s: %s" % [_I18N.translate_key("item_editor.field.attribute_modifier_id"), w.attribute_modifier_id]))
	elif def.category_data is ArmorItemData:
		var a := def.category_data as ArmorItemData
		if not String(a.slot).is_empty():
			add_child(_muted("%s: %s" % [_I18N.translate_key("item_editor.field.equip_slot"), a.slot]))
		if not String(a.attribute_modifier_id).is_empty():
			add_child(_muted("%s: %s" % [_I18N.translate_key("item_editor.field.attribute_modifier_id"), a.attribute_modifier_id]))
	elif def.category_data is FoodItemData:
		var f := def.category_data as FoodItemData
		add_child(_muted(
			"%s: %.0f  %s: %.0f  %s: %s" % [
				_I18N.translate_key("item_editor.field.nutrition"),
				f.nutrition,
				_I18N.translate_key("item_editor.field.spoilage_hours"),
				f.spoilage_hours,
				_I18N.translate_key("item_editor.field.stackable"),
				"yes" if f.stackable else "no",
			]
		))
	elif def.category_data is ValuableItemData:
		var v := def.category_data as ValuableItemData
		var parts: PackedStringArray = []
		parts.append("%s: %s" % [_I18N.translate_key("item_editor.field.stackable"), "yes" if v.stackable else "no"])
		if not String(v.merchant_category).is_empty():
			parts.append("%s: %s" % [_I18N.translate_key("item_editor.field.merchant_category"), v.merchant_category])
		add_child(_muted("  ".join(parts)))

func _tag_labels(items: ItemsModule, tags: Array) -> String:
	var parts: PackedStringArray = []
	for raw in tags:
		var tid := StringName(String(raw))
		var def := items.load_tag_def(tid)
		if def != null and not def.display_name_key.is_empty():
			parts.append(_I18N.translate_key(def.display_name_key))
		else:
			parts.append(String(tid))
	return ", ".join(parts)

func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _string_names(arr: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for v in arr:
		out.append(String(v))
	return out
