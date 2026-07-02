@icon("res://ui/widgets/icons/list.svg")
class_name UfList
extends ScrollContainer
## Scrollable list container (see GAME_DESIGN section 10.6).
## Put row widgets in [method get_items_slot]; they flow vertically or horizontally.
## Overflow scrolls automatically. [method set_items] is a shortcut for localized labels.
##
## Structure is authored in [code]uf_list.tscn[/code] ([code]Items[/code] + rows). Do not redefine
## [code]Items[/code] in parent scenes; add rows under [code]UfList/Items[/code] only.

enum Flow {
	VERTICAL,
	HORIZONTAL,
}

@export var flow: Flow = Flow.VERTICAL:
	set(value):
		if flow == value:
			return
		flow = value
		if is_node_ready() and not Engine.is_editor_hint():
			_apply_runtime_structure()

func _ready() -> void:
	if not Engine.is_editor_hint():
		_apply_runtime_structure()

## Returns the flow container where list rows must be added.
func get_items_slot() -> Container:
	return get_node_or_null("Items") as Container

## Replaces the list contents with one [UfLabel] per entry in [param label_keys].
func set_items(label_keys: Array) -> void:
	var items := get_items_slot()
	if items == null:
		return
	for child in items.get_children():
		child.queue_free()
	for key in label_keys:
		var label := UfLabel.new()
		label.label_key = String(key)
		items.add_child(label)

func _apply_runtime_structure() -> void:
	var items := get_node_or_null("Items") as Container
	if items == null:
		return
	if not _container_matches_flow(items):
		items = _migrate_flow_container(items)
	_configure_items_container(items)
	_apply_scroll_modes()

func _migrate_flow_container(items: Container) -> Container:
	var saved_children: Array[Node] = items.get_children()
	remove_child(items)
	items.queue_free()
	var replacement := _create_items_container()
	replacement.name = "Items"
	add_child(replacement)
	for child in saved_children:
		replacement.add_child(child)
	return replacement

func _create_items_container() -> Container:
	match flow:
		Flow.HORIZONTAL:
			return HBoxContainer.new()
		_:
			return VBoxContainer.new()

func _container_matches_flow(items: Container) -> bool:
	match flow:
		Flow.HORIZONTAL:
			return items is HBoxContainer
		_:
			return items is VBoxContainer

func _configure_items_container(items: Container) -> void:
	items.layout_mode = 2
	if items is VBoxContainer:
		items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	elif items is HBoxContainer:
		items.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		items.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _apply_scroll_modes() -> void:
	match flow:
		Flow.HORIZONTAL:
			horizontal_scroll_mode = SCROLL_MODE_AUTO
			vertical_scroll_mode = SCROLL_MODE_DISABLED
		_:
			horizontal_scroll_mode = SCROLL_MODE_DISABLED
			vertical_scroll_mode = SCROLL_MODE_AUTO
