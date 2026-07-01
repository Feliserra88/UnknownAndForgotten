class_name FactionDef
extends Resource
## Data-driven faction: group membership plus the modifiers and relations it carries
## (see docs/GAME_DESIGN.md section 6). A faction answers "which group" and grants shared
## characteristics/behaviour hooks; the archetype answers "what it is". Saveable as a .tres
## asset under res://assets/data/factions/.

enum Relation { NEUTRAL, ALLY, HOSTILE }

@export var id: StringName = &""
@export var display_name_key: String = ""
## Modifier ids granted to every member (resolved by ModifierModule).
@export var granted_modifier_ids: Array[StringName] = []
@export var hostile_to: Array[StringName] = []
@export var ally_to: Array[StringName] = []
@export var tags: Array[StringName] = []

## Returns this faction's stance toward [param other_id].
func relation_to(other_id: StringName) -> Relation:
	if hostile_to.has(other_id):
		return Relation.HOSTILE
	if ally_to.has(other_id):
		return Relation.ALLY
	return Relation.NEUTRAL
