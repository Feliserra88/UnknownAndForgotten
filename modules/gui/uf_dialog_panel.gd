@tool
@icon("res://ui/templates/icons/dialog.svg")
class_name UfDialogPanel
extends UfPanel
## Panel with accept/cancel actions in a footer. Emits [signal confirmed] / [signal cancelled]
## (see docs/GAME_DESIGN.md section 10.5).

signal confirmed
signal cancelled

@export var accept_key: String = "gui.action.accept":
	set(value):
		accept_key = value
		_refresh_footer()
@export var cancel_key: String = "gui.action.cancel":
	set(value):
		cancel_key = value
		_refresh_footer()

func _ensure_structure() -> void:
	super._ensure_structure()
	var layout := get_node_or_null("Layout")
	if layout != null and layout.get_node_or_null("Footer") == null:
		var footer := HBoxContainer.new()
		footer.name = "Footer"
		footer.alignment = BoxContainer.ALIGNMENT_END
		var cancel := Button.new()
		cancel.name = "CancelButton"
		var accept := Button.new()
		accept.name = "AcceptButton"
		footer.add_child(cancel)
		footer.add_child(accept)
		layout.add_child(footer)
	_refresh_footer()

func _ready() -> void:
	super._ready()
	var accept := _accept_button()
	if accept != null and not accept.pressed.is_connected(_on_accept):
		accept.pressed.connect(_on_accept)
	var cancel := _cancel_button()
	if cancel != null and not cancel.pressed.is_connected(_on_cancel):
		cancel.pressed.connect(_on_cancel)

func _accept_button() -> Button:
	return get_node_or_null("Layout/Footer/AcceptButton") as Button

func _cancel_button() -> Button:
	return get_node_or_null("Layout/Footer/CancelButton") as Button

func _refresh_footer() -> void:
	var accept := _accept_button()
	if accept != null:
		accept.text = tr(accept_key)
	var cancel := _cancel_button()
	if cancel != null:
		cancel.text = tr(cancel_key)

func _on_accept() -> void:
	confirmed.emit()

func _on_cancel() -> void:
	cancelled.emit()
