@tool
class_name ItemTagDef
extends Resource
## Canonical item tag for editor assignment and list filtering (see assets/data/item_tags/).

@export var id: StringName = &""
@export var display_name_key: String = ""
## Empty = valid for every category; otherwise only listed category ids.
@export var categories: Array[StringName] = []
@export var chip_color: Color = Color(0.32, 0.46, 0.62, 1.0)

## Returns whether this tag may be assigned to items in [param category_id].
func applies_to_category(category_id: StringName) -> bool:
	if categories.is_empty():
		return true
	return categories.has(category_id)
