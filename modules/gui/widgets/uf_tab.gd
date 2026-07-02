@tool
@icon("res://ui/widgets/icons/tab.svg")
class_name UfTab
extends MarginContainer
## One tab page for [class UfTabbedPanel]. Each instance is a direct child of Godot's
## [TabContainer]; [member title_key] drives the tab label via [code]tr()[/code].
## Put widgets inside [method get_content_slot] (see GAME_DESIGN section 10.6).

@export var title_key: String = "":
	set(value):
		title_key = value
		_sync_tab_title()

func _enter_tree() -> void:
	_ensure_structure()
	call_deferred("_sync_tab_title")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_sync_tab_title()

## Returns the container where this tab's body widgets must be added.
func get_content_slot() -> Container:
	_ensure_structure()
	return get_node_or_null("ContentSlot") as Container

func _ensure_structure() -> void:
	var slot := get_node_or_null("ContentSlot") as Container
	if slot == null:
		var legacy := get_node_or_null("Content") as Container
		if legacy != null:
			legacy.name = "ContentSlot"
			slot = legacy
		else:
			slot = VBoxContainer.new()
			slot.name = "ContentSlot"
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			add_child(slot)
	for child in get_children():
		if child != slot and (child.name == "Content" or child.name.begins_with("Content")):
			child.queue_free()

func _sync_tab_title() -> void:
	var parent := get_parent()
	if parent is TabContainer:
		var idx: int = parent.get_tab_idx_from_control(self)
		if idx >= 0:
			parent.set_tab_title(idx, tr(title_key) if not title_key.is_empty() else "Tab")
