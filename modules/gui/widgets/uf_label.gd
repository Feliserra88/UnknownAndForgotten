@tool
@icon("res://ui/widgets/icons/label.svg")
class_name UfLabel
extends Label
## Localized label widget; set [member label_key] in the scene — script default is empty (see §10.6).

@export var label_key: String = "":
	set(value):
		label_key = value
		text = tr(value) if not value.is_empty() else ""
