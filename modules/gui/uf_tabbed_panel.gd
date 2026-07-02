@tool
@icon("res://ui/templates/icons/tabbed.svg")
class_name UfTabbedPanel
extends UfPanel
## Panel hosting a TabContainer inside the content slot; tabs are added via [method add_tab]
## (see docs/GAME_DESIGN.md section 10.5).

func _ensure_structure() -> void:
	super._ensure_structure()
	var content := get_node_or_null("Layout/ContentSlot")
	if content != null and content.get_node_or_null("Tabs") == null:
		var tabs := TabContainer.new()
		tabs.name = "Tabs"
		tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_add_structural_child(content, tabs)

## Adds [param control] as a new tab titled with localization [param title_key].
func add_tab(title_key: String, control: Control) -> void:
	var tabs := _tabs()
	if tabs == null or control == null:
		return
	control.name = title_key if not title_key.is_empty() else "Tab"
	tabs.add_child(control)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tr(title_key))

func _tabs() -> TabContainer:
	return get_node_or_null("Layout/ContentSlot/Tabs") as TabContainer
