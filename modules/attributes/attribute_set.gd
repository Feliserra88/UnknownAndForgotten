@tool
class_name AttributeSet
extends Resource
## Base character attributes (see docs/GAME_DESIGN.md section 8.7). Saveable as a .tres asset.
## Runtime modifiers are applied elsewhere; this holds the unmodified base values.

@export var strength: int = 5
@export var agility: int = 5
@export var willpower: int = 5
@export var vitality: int = 5
@export var perception: int = 5
@export var charisma: int = 5

## Returns a mutable copy safe to store on a runtime instance.
func clone() -> AttributeSet:
	return duplicate(true)
