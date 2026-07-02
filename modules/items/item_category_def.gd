@tool
class_name ItemCategoryDef
extends Resource
## Describes an item category schema (weapon, food, valuable, …) for editor list rows and defaults.

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var payload_script: Script
@export var list_row_fields: Array[StringName] = []
@export var default_state_tiers: Array[ItemStateTierDef] = []
@export var default_quality_tiers: Array[ItemQualityTierDef] = []
