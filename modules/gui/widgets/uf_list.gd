@tool
@icon("res://ui/widgets/icons/list.svg")
class_name UfList
extends ScrollContainer
## Scrollable list container (see GAME_DESIGN section 10.6).
## Put row widgets in [method get_items_slot]; they flow vertically or horizontally.
## Overflow scrolls automatically. [method set_items] is a shortcut for localized labels.

enum Flow {
	VERTICAL,
	HORIZONTAL,
}

const _PLACEHOLDER_ITEM_KEY := "gui.placeholder.list_item"

@export var flow: Flow = Flow.VERTICAL:
	set(value):
		if flow == value:
			return
		flow = value
		if is_inside_tree():
			call_deferred("_ensure_structure")

func _enter_tree() -> void:
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
	call_deferred("_ensure_structure")

func _ready() -> void:
	_ensure_placeholder_items()

func _on_child_entered_tree(node: Node) -> void:
	if node.name == "Items" and node is Container:
		return
	call_deferred("_ensure_structure")

## Returns the flow container where list rows must be added.
func get_items_slot() -> Container:
	_ensure_structure()
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

func _ensure_structure() -> void:
	var items := _resolve_items_container()
	if items == null:
		return
	_configure_items_container(items)
	_merge_duplicate_items(items)
	_adopt_orphan_children(items)
	_apply_scroll_modes()

func _resolve_items_container() -> Container:
	var items := get_node_or_null("Items") as Container
	if items != null and not _container_matches_flow(items):
		var saved_children: Array[Node] = items.get_children()
		remove_child(items)
		items.queue_free()
		items = null
		var replacement := _create_items_container()
		replacement.name = "Items"
		add_child(replacement)
		_set_editor_owner(replacement)
		for child in saved_children:
			replacement.add_child(child)
			_set_editor_owner(child)
		items = replacement
	elif items == null:
		items = _create_items_container()
		items.name = "Items"
		add_child(items)
		_set_editor_owner(items)
	return items

func _merge_duplicate_items(primary: Container) -> void:
	for child in get_children():
		if child == primary:
			continue
		if child.name == "Items" and child is Container:
			var extra := child as Container
			for row in extra.get_children():
				primary.add_child(row)
				_set_editor_owner(row)
			extra.queue_free()

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

func _adopt_orphan_children(items: Container) -> void:
	var orphans: Array[Node] = []
	for child in get_children():
		if child != items:
			orphans.append(child)
	for i in orphans.size():
		var orphan: Node = orphans[i]
		if orphan is Control:
			(orphan as Control).layout_mode = 2
		items.add_child(orphan)
		items.move_child(orphan, i)
		_set_editor_owner(orphan)

func _apply_scroll_modes() -> void:
	match flow:
		Flow.HORIZONTAL:
			horizontal_scroll_mode = SCROLL_MODE_AUTO
			vertical_scroll_mode = SCROLL_MODE_DISABLED
		_:
			horizontal_scroll_mode = SCROLL_MODE_DISABLED
			vertical_scroll_mode = SCROLL_MODE_AUTO

func _set_editor_owner(node: Node) -> void:
	if Engine.is_editor_hint() and owner != null:
		node.owner = owner

## Adds one sample row when the list is empty (editor palette / new instances).
func _ensure_placeholder_items() -> void:
	if not Engine.is_editor_hint():
		return
	var items := get_items_slot()
	if items == null or items.get_child_count() > 0:
		return
	var label := UfLabel.new()
	label.label_key = _PLACEHOLDER_ITEM_KEY
	items.add_child(label)
	_set_editor_owner(label)
