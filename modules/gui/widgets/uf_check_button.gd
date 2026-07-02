@tool
class_name UfCheckButton
extends CheckButton
## Localized on/off widget built on Godot's native CheckButton, suitable for panel toggles
## and settings rows (see GAME_DESIGN section 10.6).

@export var label_key: String = "":
	set(value):
		label_key = value
		text = tr(value) if not value.is_empty() else ""
