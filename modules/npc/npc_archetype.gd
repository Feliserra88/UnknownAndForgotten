class_name NpcArchetype
extends Resource
## Data-driven archetype node (see docs/GAME_DESIGN.md section 5.3). Hierarchy is modelled as a
## chain of Resources via [member parent], not deep script inheritance. Saveable as a .tres asset.

@export var id: StringName = &""
@export var parent: NpcArchetype
@export var display_name_key: String = ""
## Visual/behaviour scene; inherited from parent when left empty.
@export var scene: PackedScene
@export var base_attributes: AttributeSet
@export var base_vitals: VitalsTemplate
@export var body_part_map: BodyPartMap
@export var part_visuals: Array[PartVisualDef] = []
@export var default_factions: Array[StringName] = []
@export var default_traits: Array[StringName] = []

const _MAX_DEPTH := 32

## Returns the nearest non-null scene walking up the parent chain.
func resolve_scene() -> PackedScene:
	for a in _chain():
		if a.scene != null:
			return a.scene
	return null

## Returns the nearest non-null base attributes walking up the parent chain.
func resolve_attributes() -> AttributeSet:
	for a in _chain():
		if a.base_attributes != null:
			return a.base_attributes
	return null

## Returns the nearest non-null vitals template walking up the parent chain.
func resolve_vitals() -> VitalsTemplate:
	for a in _chain():
		if a.base_vitals != null:
			return a.base_vitals
	return null

## Returns the nearest non-null body part map walking up the parent chain.
func resolve_body_part_map() -> BodyPartMap:
	for a in _chain():
		if a.body_part_map != null:
			return a.body_part_map
	return null

## Returns part visuals merged from root to leaf; nearer archetypes override by part_id.
func resolve_part_visuals() -> Array[PartVisualDef]:
	var by_part := {}
	var ordered := _chain()
	ordered.reverse()
	for a in ordered:
		for visual in a.part_visuals:
			if visual != null:
				by_part[visual.part_id] = visual
	var out: Array[PartVisualDef] = []
	for v in by_part.values():
		out.append(v)
	return out

## Returns the localized display name resolved from this archetype or its ancestors.
func get_display_name() -> String:
	for a in _chain():
		if not a.display_name_key.is_empty():
			return tr(a.display_name_key)
	return String(id)

## Returns the archetype chain from self to root, guarding against cycles.
func _chain() -> Array[NpcArchetype]:
	var chain: Array[NpcArchetype] = []
	var a: NpcArchetype = self
	var depth := 0
	while a != null and depth < _MAX_DEPTH:
		chain.append(a)
		a = a.parent
		depth += 1
	return chain
