class_name NpcVitals
extends Resource
## Runtime vital values for a single NPC instance, seeded from a VitalsTemplate.
## Not a shared definition: each NPC owns its own copy.

@export var health: float = 100.0
@export var energy: float = 100.0
@export var mana: float = 0.0
@export var sanity: float = 100.0
@export var morale: float = 100.0
@export var hunger: float = 100.0
@export var thirst: float = 100.0
@export var fatigue: float = 0.0
@export var encumbrance: float = 0.0
@export var temperature: float = 37.0

## Returns a runtime NpcVitals initialised from [param template].
static func from_template(template: VitalsTemplate) -> NpcVitals:
	var v := NpcVitals.new()
	if template == null:
		return v
	v.health = template.health
	v.energy = template.energy
	v.mana = template.mana
	v.sanity = template.sanity
	v.morale = template.morale
	v.hunger = template.hunger
	v.thirst = template.thirst
	v.fatigue = template.fatigue
	v.encumbrance = template.encumbrance
	v.temperature = template.temperature
	return v
