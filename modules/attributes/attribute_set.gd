@tool
class_name AttributeSet
extends Resource
## Base character attributes (see docs/GAME_DESIGN.md section 8.7). Saveable as a .tres asset.
## Runtime modifiers are applied elsewhere; this holds the unmodified base values.

const DEFAULT := 10
const MIN := 1
const MAX := 30

@export_range(MIN, MAX, 1) var strength: int = DEFAULT
@export_range(MIN, MAX, 1) var agility: int = DEFAULT
@export_range(MIN, MAX, 1) var willpower: int = DEFAULT
@export_range(MIN, MAX, 1) var vitality: int = DEFAULT
@export_range(MIN, MAX, 1) var perception: int = DEFAULT
@export_range(MIN, MAX, 1) var charisma: int = DEFAULT

## Returns a mutable copy safe to store on a runtime instance.
func clone() -> AttributeSet:
	return duplicate(true)
