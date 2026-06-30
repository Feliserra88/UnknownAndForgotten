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

static var _next_uid: int = 1

## Seeds this instance from [param archetype], duplicating attributes and vitals into owned copies.
func apply_archetype(archetype: NpcArchetype) -> void:
	uid = _next_uid
	_next_uid += 1
	archetype_id = archetype.id
	display_name_key = archetype.display_name_key
	var base_attrs := archetype.resolve_attributes()
	attributes = base_attrs.clone() if base_attrs != null else AttributeSet.new()
	vitals = NpcVitals.from_template(archetype.resolve_vitals())
	faction_ids = archetype.default_factions.duplicate()
	traits = archetype.default_traits.duplicate()

## Returns the localized display name for this instance.
func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(archetype_id)
