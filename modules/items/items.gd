@tool
class_name ItemsModule
extends RefCounted
## Public facade for item definitions and instances (see docs/GAME_DESIGN.md section 7).

const _LOG := "ITM"
const DIR := "res://assets/data/items"
const CATEGORIES_DIR := "res://assets/data/item_categories"

const _Catalog := preload("res://modules/items/_private/item_catalog.gd")
const _SpriteLibrary := preload("res://modules/items/_private/sprite_library.gd")
const _TagCatalog := preload("res://modules/items/_private/tag_catalog.gd")

## Returns every ItemDef, optionally filtered by category_id, tag or equip_slot.
## Optional [code]exclude_placeholders[/code] skips dev-only dummy catalog entries.
func list_defs(filter: Dictionary = {}) -> Array[ItemDef]:
	var exclude_placeholders: bool = filter.get("exclude_placeholders", false)
	var query := filter.duplicate()
	query.erase("exclude_placeholders")
	var out: Array[ItemDef] = []
	for item in _Catalog.list_filtered(query):
		if exclude_placeholders and is_placeholder_def(item):
			continue
		out.append(item)
	return out

## True for dev-only placeholder ItemDef assets (id suffix, dummy tag on item or archetype allow-list).
static func is_placeholder_def(item: ItemDef) -> bool:
	if item == null:
		return true
	if String(item.id).ends_with("_dummy"):
		return true
	const PLACEHOLDER_TAG := &"dummy"
	for raw in item.tags:
		if StringName(String(raw)) == PLACEHOLDER_TAG:
			return true
	for raw in item.allowed_archetype_tags:
		if StringName(String(raw)) == PLACEHOLDER_TAG:
			return true
	return false

## Returns the ItemDef for [param id], or null when missing.
func load_def(id: StringName) -> ItemDef:
	var item := _Catalog.load_def(id)
	if item == null:
		Log.warn(_LOG, "load_def: missing %s" % id)
	return item

## Returns every ItemCategoryDef asset.
func list_categories() -> Array[ItemCategoryDef]:
	var out: Array[ItemCategoryDef] = []
	var dir := _open_dir(CATEGORIES_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var cat := load("%s/%s" % [CATEGORIES_DIR, file]) as ItemCategoryDef
		if cat != null:
			out.append(cat)
	return out

## Returns the ItemCategoryDef for [param category_id], or null.
func load_category(category_id: StringName) -> ItemCategoryDef:
	for cat in list_categories():
		if cat.id == category_id:
			return cat
	return null

## Returns sprite template entries for new items (see _private/sprite_library.gd).
func list_sprite_templates(category_id: StringName, family: StringName = &"") -> Array[Dictionary]:
	return _SpriteLibrary.list_templates(category_id, family)

## Infers tag ids for a sprite template row (art library; not yet saved as ItemDef).
func infer_template_tags(entry: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var cat_id: StringName = entry.get("category_id", &"")
	var family := String(entry.get("family", "")).to_lower()
	if family.is_empty():
		family = String(entry.get("label", "")).to_lower()
	for def in list_tag_defs(cat_id):
		var tid := String(def.id).to_lower()
		if family == tid or (tid.length() >= 3 and family.contains(tid)):
			if not out.has(def.id):
				out.append(def.id)
	var root := load_tag_def(cat_id)
	if root != null and not out.has(root.id):
		out.append(root.id)
	return out

## True when [param item_tags] contains at least one id from [param filter_tags].
func tags_overlap_any(item_tags: Array, filter_tags: Array) -> bool:
	return _Catalog.tags_overlap_any(item_tags, filter_tags)

## Returns one frame from a horizontal state strip PNG (editor art library).
func resolve_strip_icon(
	library_path: String,
	state_index: int = 0,
	state_tiers: Array[ItemStateTierDef] = [],
	cell_size: Vector2i = Vector2i(64, 64),
) -> Texture2D:
	if library_path.is_empty() or not ResourceLoader.exists(library_path):
		return null
	var tex := load(library_path) as Texture2D
	if tex == null:
		return null
	var column := state_index
	if state_index >= 0 and state_index < state_tiers.size():
		var tier := state_tiers[state_index]
		if tier != null:
			column = tier.sprite_index
	var columns := maxi(1, int(tex.get_width() / maxi(cell_size.x, 1)))
	column = clampi(column, 0, columns - 1)
	return _slice_strip(tex, column, cell_size)

## Returns every ItemTagDef, optionally limited to [param category_id].
func list_tag_defs(category_id: StringName = &"") -> Array[ItemTagDef]:
	if String(category_id).is_empty():
		return _TagCatalog.list_all()
	return _TagCatalog.list_for_category(category_id)

## Returns the ItemTagDef for [param id], or null.
func load_tag_def(id: StringName) -> ItemTagDef:
	return _TagCatalog.load_def(id)

## Keeps only known tag ids valid for [param category_id].
func normalize_tags(tags: Array, category_id: StringName = &"") -> Array[StringName]:
	return _TagCatalog.normalize(tags, category_id)

## Localized label for a tag id (falls back to raw id).
func tag_display_name(tag_id: StringName) -> String:
	var def := load_tag_def(tag_id)
	if def != null and not def.display_name_key.is_empty():
		return tr(def.display_name_key)
	return String(tag_id)

## Creates a runtime ItemInstance from [param def_id].
## Pass [param state_override] / [param quality_override] >= 0 to force indices; otherwise uses ItemDef defaults.
func create_instance(def_id: StringName, state_override: int = -1, quality_override: int = -1) -> ItemInstance:
	var def := load_def(def_id)
	var inst := ItemInstance.new()
	inst.def_id = def_id
	inst.state_index = state_override if state_override >= 0 else (def.default_state_index if def != null else 0)
	inst.quality_index = quality_override if quality_override >= 0 else (def.default_quality_index if def != null else 0)
	if def != null and def.max_durability > 0.0:
		inst.durability = def.max_durability
	inst.ensure_uid()
	return inst

## Returns a deep duplicate of [param source] with a new empty id for cloning in the editor.
func duplicate_def(source: ItemDef) -> ItemDef:
	if source == null:
		return null
	return source.duplicate(true) as ItemDef

## Saves [param item] to res://assets/data/items/<id>.tres.
func save_def(item: ItemDef) -> Error:
	if item == null or String(item.id).is_empty():
		Log.warn(_LOG, "save_def: missing id")
		return ERR_INVALID_PARAMETER
	item.default_state_index = clampi(item.default_state_index, 0, maxi(0, item.state_tiers.size() - 1))
	item.default_quality_index = clampi(item.default_quality_index, 0, maxi(0, item.quality_tiers.size() - 1))
	var path := "%s/%s.tres" % [DIR, item.id]
	return ResourceSaver.save(item, path)

## Returns the display icon for [param instance] resolved from state tier and sprite strip.
func resolve_icon(instance: ItemInstance, def: ItemDef = null) -> Texture2D:
	if instance == null:
		return null
	if def == null:
		def = load_def(instance.def_id)
	if def == null:
		return null
	var tier := def.get_state_tier(instance.state_index)
	if tier != null and tier.icon_override != null:
		return tier.icon_override
	if def.sprite_ref != null and def.sprite_ref.is_valid() and tier != null:
		var tex := load(def.sprite_ref.library_path) as Texture2D
		if tex != null:
			return _slice_strip(tex, tier.sprite_index, def.sprite_ref.strip_cell_size)
	if def.icon != null:
		return def.icon
	return null

## Returns effective price for [param instance] after state and quality multipliers.
func resolve_price(instance: ItemInstance, def: ItemDef = null) -> float:
	if instance == null:
		return 0.0
	if def == null:
		def = load_def(instance.def_id)
	if def == null:
		return 0.0
	var price := def.base_price
	var state := def.get_state_tier(instance.state_index)
	if state != null:
		price *= state.price_multiplier
	var quality := def.get_quality_tier(instance.quality_index)
	if quality != null:
		price *= quality.price_multiplier
	return price

## Returns list-row display data for editor or UI previews.
func resolve_list_row(
	target: Variant,
	preview_modifier_ids: Array = [],
	modifier_module: ModifierModule = null,
) -> Dictionary:
	var def: ItemDef = null
	var instance: ItemInstance = null
	if target is ItemDef:
		def = target
	elif target is ItemInstance:
		instance = target
		def = load_def(instance.def_id)
	if def == null:
		return {}
	var state_idx := instance.state_index if instance != null else def.default_state_index
	var quality_idx := instance.quality_index if instance != null else def.default_quality_index
	var preview_inst := instance if instance != null else create_instance(def.id, state_idx, quality_idx)
	var icon_tex: Texture2D = resolve_icon(preview_inst, def)
	var state_tier := def.get_state_tier(state_idx)
	var quality_tier := def.get_quality_tier(quality_idx)
	var mod_ids: Array = instance.modifier_ids if instance != null else preview_modifier_ids.duplicate()
	return {
		"id": def.id,
		"display_name_key": def.display_name_key,
		"category_id": def.category_id,
		"icon": icon_tex,
		"weight": def.weight,
		"price": resolve_price(preview_inst, def),
		"durability": instance.durability if instance != null else def.max_durability,
		"inventory_size": def.inventory_size,
		"tags": def.tags,
		"state_id": state_tier.id if state_tier != null else &"",
		"state_key": state_tier.display_name_key if state_tier != null else "",
		"quality_id": quality_tier.id if quality_tier != null else &"",
		"quality_key": quality_tier.display_name_key if quality_tier != null else "",
		"modifier_ids": mod_ids,
		"equip_slot": def.get_equip_slot(),
	}

## Returns default weapon wear tiers (pristine … battered).
func default_weapon_state_tiers() -> Array[ItemStateTierDef]:
	return [
		_make_state_tier(&"pristine", "item.state.pristine", 0, 1.0, 1.0, 1.0),
		_make_state_tier(&"good", "item.state.good", 1, 0.95, 0.9, 0.95),
		_make_state_tier(&"worn", "item.state.worn", 2, 0.85, 0.75, 0.8),
		_make_state_tier(&"rusty", "item.state.rusty", 3, 0.7, 0.5, 0.6),
		_make_state_tier(&"battered", "item.state.battered", 4, 0.55, 0.35, 0.4),
	]

## Returns default quality tiers (common … epic).
func default_quality_tiers() -> Array[ItemQualityTierDef]:
	return [
		_make_quality_tier(&"common", "item.quality.common", 1.0, 1.0),
		_make_quality_tier(&"uncommon", "item.quality.uncommon", 1.1, 1.25),
		_make_quality_tier(&"rare", "item.quality.rare", 1.25, 2.0),
		_make_quality_tier(&"epic", "item.quality.epic", 1.5, 4.0),
	]

## Builds a blank ItemDef for [param category_id] using category defaults when available.
func create_blank_def(category_id: StringName) -> ItemDef:
	var def := ItemDef.new()
	def.category_id = category_id
	var cat := load_category(category_id)
	if cat != null:
		for tier in cat.default_state_tiers:
			def.state_tiers.append(tier.duplicate(true))
		for tier in cat.default_quality_tiers:
			def.quality_tiers.append(tier.duplicate(true))
		match category_id:
			&"weapon":
				def.category_data = WeaponItemData.new()
			&"food":
				def.category_data = FoodItemData.new()
			&"valuable":
				def.category_data = ValuableItemData.new()
			&"armor":
				def.category_data = ArmorItemData.new()
	else:
		def.state_tiers = default_weapon_state_tiers()
		def.quality_tiers = default_quality_tiers()
	return def

## Returns ModifierDef ids that apply to [param instance] (equipped payload + instance modifiers).
func instance_modifier_ids(instance: ItemInstance) -> Array[StringName]:
	var out: Array[StringName] = []
	if instance == null:
		return out
	var def := load_def(instance.def_id)
	if def != null:
		var mid := def.get_attribute_modifier_id()
		if not String(mid).is_empty():
			out.append(mid)
	for mid in instance.modifier_ids:
		if not out.has(mid):
			out.append(mid)
	return out

## Returns scaled ModifierDefs for [param instance] (state/quality tiers applied to payload modifier).
func resolve_modifier_defs(instance: ItemInstance, modifier_module: ModifierModule) -> Array[ModifierDef]:
	var out: Array[ModifierDef] = []
	if instance == null or modifier_module == null:
		return out
	var def := load_def(instance.def_id)
	if def == null:
		return out
	var state_mult := 1.0
	var quality_mult := 1.0
	var state_tier := def.get_state_tier(instance.state_index)
	if state_tier != null:
		state_mult = state_tier.stat_multiplier
	var quality_tier := def.get_quality_tier(instance.quality_index)
	if quality_tier != null:
		quality_mult = quality_tier.stat_multiplier
	var tier_mult := state_mult * quality_mult
	var base_id := def.get_attribute_modifier_id()
	if not String(base_id).is_empty():
		var base_def := modifier_module.load_def(base_id)
		if base_def != null:
			out.append(_scale_modifier_def(base_def, tier_mult))
	for mid in instance.modifier_ids:
		var mod_def := modifier_module.load_def(mid)
		if mod_def != null and not _has_modifier_id(out, mod_def.id):
			out.append(mod_def)
	return out

## Returns attribute bonuses granted by [param instance] alone (empty base AttributeSet).
func resolve_effective_attributes(
	instance: ItemInstance,
	modifier_module: ModifierModule,
) -> AttributeSet:
	if instance == null or modifier_module == null:
		return AttributeSet.new()
	var defs := resolve_modifier_defs(instance, modifier_module)
	return modifier_module.apply(AttributeSet.new(), defs)

## Adds [param instance] to [param state] inventory and optionally publishes [GameEvents.INVENTORY_ITEM_ADDED].
func add_to_inventory(
	state: EquipmentState,
	instance: ItemInstance,
	owner_uid: int = 0,
	publish_event: bool = true,
) -> void:
	if state == null or instance == null:
		return
	state.add_to_inventory(instance)
	if publish_event and not Engine.is_editor_hint():
		EventBus.publish(GameEvents.INVENTORY_ITEM_ADDED, {
			"owner_uid": owner_uid,
			"instance_uid": instance.instance_uid,
			"def_id": instance.def_id,
			"count": instance.count,
		})

## Removes the instance with [param instance_uid] from [param state] inventory; returns true when found.
func remove_from_inventory(state: EquipmentState, instance_uid: String) -> bool:
	if state == null or instance_uid.is_empty():
		return false
	var items := state.inventory_items()
	for i in items.size():
		var inst: ItemInstance = items[i]
		if inst != null and inst.instance_uid == instance_uid:
			state.remove_inventory_at(i)
			return true
	return false

## Returns the inventory instance with [param instance_uid], or null.
func find_instance(state: EquipmentState, instance_uid: String) -> ItemInstance:
	if state == null or instance_uid.is_empty():
		return null
	for inst in state.inventory_items():
		if inst is ItemInstance and (inst as ItemInstance).instance_uid == instance_uid:
			return inst
	return null

## Returns total carried weight for portable inventory entries in [param state].
func inventory_total_weight(state: EquipmentState) -> float:
	var total := 0.0
	if state == null:
		return total
	for inst in state.inventory_items():
		if inst is ItemInstance:
			var def := load_def((inst as ItemInstance).def_id)
			if def != null:
				total += def.weight * maxi((inst as ItemInstance).count, 1)
	return total

func _scale_modifier_def(source: ModifierDef, multiplier: float) -> ModifierDef:
	var scaled := source.duplicate(true) as ModifierDef
	var additive: Dictionary = {}
	for key in scaled.additive:
		additive[key] = int(round(float(scaled.additive[key]) * multiplier))
	scaled.additive = additive
	var multiplicative: Dictionary = {}
	for key in scaled.multiplicative:
		multiplicative[key] = float(scaled.multiplicative[key]) * multiplier
	scaled.multiplicative = multiplicative
	return scaled

func _has_modifier_id(defs: Array[ModifierDef], id: StringName) -> bool:
	for def in defs:
		if def != null and def.id == id:
			return true
	return false

func _slice_strip(tex: Texture2D, column: int, cell_size: Vector2i) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(column * cell_size.x, 0, cell_size.x, cell_size.y)
	return atlas

func _make_state_tier(
	id: StringName,
	key: String,
	sprite_index: int,
	stat_mult: float,
	price_mult: float,
	dur_mult: float,
) -> ItemStateTierDef:
	var tier := ItemStateTierDef.new()
	tier.id = id
	tier.display_name_key = key
	tier.sprite_index = sprite_index
	tier.stat_multiplier = stat_mult
	tier.price_multiplier = price_mult
	tier.durability_multiplier = dur_mult
	return tier

func _make_quality_tier(
	id: StringName,
	key: String,
	stat_mult: float,
	price_mult: float,
) -> ItemQualityTierDef:
	var tier := ItemQualityTierDef.new()
	tier.id = id
	tier.display_name_key = key
	tier.stat_multiplier = stat_mult
	tier.price_multiplier = price_mult
	return tier

## Returns combined ModifierDef ids from every equipped instance (for display lists).
func instance_modifier_ids_from_equipped(state: EquipmentState) -> Array[StringName]:
	var out: Array[StringName] = []
	if state == null:
		return out
	for inst in state.equipped_instances():
		for mid in instance_modifier_ids(inst):
			if not out.has(mid):
				out.append(mid)
	return out

func _open_dir(dir_path: String) -> DirAccess:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		dir = DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		Log.warn(_LOG, "cannot open dir %s" % dir_path)
	return dir
