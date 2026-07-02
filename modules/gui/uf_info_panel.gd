@tool
@icon("res://ui/templates/icons/info.svg")
class_name UfInfoPanel
extends UfPanel
## Informational panel: adds a close button to the header and emits [signal panel_closed] when
## closed, hiding itself (see docs/GAME_DESIGN.md section 10.5).

func _ensure_structure() -> void:
	super._ensure_structure()
	var header := get_node_or_null("Layout/Header")
	if header != null and header.get_node_or_null("CloseButton") == null:
		var close := Button.new()
		close.name = "CloseButton"
		close.text = "X"
		header.add_child(close)

func _ready() -> void:
	super._ready()
	var close := get_node_or_null("Layout/Header/CloseButton") as Button
	if close != null and not close.pressed.is_connected(_on_close_pressed):
		close.pressed.connect(_on_close_pressed)

func _on_close_pressed() -> void:
	hide()
	panel_closed.emit()
