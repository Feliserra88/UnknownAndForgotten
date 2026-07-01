class_name ModifierDef
extends Resource
## Data-driven stat/behaviour overlay applied on top of an NPC's base attributes
## (see docs/GAME_DESIGN.md section 8). One Resource type covers traits, maladies, status
## effects and plain scalers via [member kind]; new overlays are new .tres assets, not new modules.
## Saveable as a .tres asset under res://assets/data/modifiers/.

## Overlay category. Same math for all; kind only groups them in UI and queries.
enum Kind { TRAIT, MALADY, STATUS, SCALER }

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var kind: Kind = Kind.TRAIT
## Flat amount added per attribute name (e.g. {"strength": 2}). Applied before multipliers.
@export var additive: Dictionary = {}
## Fractional bonus per attribute name (e.g. {"strength": 0.2} = +20%). Applied after additives.
@export var multiplicative: Dictionary = {}
@export var tags: Array[StringName] = []

## Returns whether this modifier carries [param tag].
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
