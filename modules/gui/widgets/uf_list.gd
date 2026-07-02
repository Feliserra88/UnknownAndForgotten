@tool
@icon("res://ui/widgets/icons/list.svg")
class_name UfList
extends ScrollContainer
## Vertical list of localized entries inside a scroll area (see GAME_DESIGN section 10.6).

const _PLACEHOLDER_ITEM_KEY := "gui.placeholder.list_item"

func _enter_tree() -> void:
	_ensure_structure()
	_ensure_placeholder_items()

func _ensure_structure() -> void:
	if get_node_or_null("Items") == null:
		var box := VBoxContainer.new()
		box.name = "Items"
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(box)

## Adds one sample row when the list is empty (editor palette / new instances).
func _ensure_placeholder_items() -> void:
	var box := get_node_or_null("Items") as VBoxContainer
	if box == null or box.get_child_count() > 0:
		return
	var label := UfLabel.new()
	label.label_key = _PLACEHOLDER_ITEM_KEY
	box.add_child(label)

## Replaces the list contents with one UfLabel per entry in [param label_keys].
func set_items(label_keys: Array) -> void:
	var box := get_node_or_null("Items") as VBoxContainer
	if box == null:
		return
	for child in box.get_children():
		child.queue_free()
	for key in label_keys:
		var label := UfLabel.new()
		label.label_key = String(key)
		box.add_child(label)
