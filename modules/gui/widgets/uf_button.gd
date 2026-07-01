@tool
class_name UfButton
extends Button
## Localized button widget; set [member label_key] instead of raw text (see GAME_DESIGN section 10.6).

@export var label_key: String = "":
	set(value):
		label_key = value
		text = tr(value) if not value.is_empty() else ""
