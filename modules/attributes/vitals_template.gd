class_name VitalsTemplate
extends Resource
## Maximum values for an NPC's vital variables (see docs/GAME_DESIGN.md section 8.2).
## Saveable as a .tres asset; runtime current values live in NpcVitals.

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
