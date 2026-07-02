@tool
@icon("res://ui/widgets/icons/button.svg")
class_name UfButton
extends Button
## Localized button widget; set [member label_key] in the scene — script default is empty (see §10.6).

@export var label_key: String = "":
	set(value):
		label_key = value
		text = tr(value) if not value.is_empty() else ""
