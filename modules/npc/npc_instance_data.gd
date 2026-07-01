@tool
class_name NpcInstanceData
extends RefCounted
## Mutable runtime state for a single NPC (see docs/GAME_DESIGN.md section 5.7).
## Never references a shared .tres directly: attributes/vitals are duplicated on apply.

var uid: int = 0
var archetype_id: StringName = &""
var display_name_key: String = ""
var grid_cell: Vector3i = Vector3i.ZERO
var orientation: StringName = &"front"
var attributes: AttributeSet
var vitals: NpcVitals
var faction_ids: Array[StringName] = []
var traits: Array[StringName] = []
## Modifier ids active on this instance (defaults + faction grants + runtime). See ModifierModule.
var modifier_ids: Array[StringName] = []
var equipment: EquipmentState = EquipmentState.new()

static var _next_uid: int = 1

## Seeds this instance from [param archetype], duplicating attributes and vitals into owned copies.
func apply_archetype(archetype: NpcArchetype) -> void:
	uid = _next_uid
	_next_uid += 1
	archetype_id = archetype.id
	display_name_key = archetype.display_name_key
	attributes = AttributesModule.clone_attributes(archetype.resolve_attributes())
	vitals = AttributesModule.spawn_vitals(archetype.resolve_vitals())
	faction_ids = archetype.resolve_factions()
	traits = archetype.default_traits.duplicate()
	modifier_ids = archetype.resolve_default_modifiers()
	equipment = EquipmentState.new()

## Returns base attributes with all modifiers (and equipped item modifiers when [param equipment_module]
## is given) applied via [param modifier_module]. Base attributes are left untouched.
func effective_attributes(modifier_module: ModifierModule, equipment_module: EquipmentModule = null) -> AttributeSet:
	if modifier_module == null:
		return AttributesModule.clone_attributes(attributes)
	var ids: Array = modifier_ids.duplicate()
	if equipment_module != null:
		for mid in equipment_module.attribute_modifier_ids(equipment):
			if not ids.has(mid):
				ids.append(mid)
	return modifier_module.apply(attributes, modifier_module.resolve(ids))

## Returns the localized display name for this instance.
func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(archetype_id)
