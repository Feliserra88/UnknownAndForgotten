@tool
@icon("res://ui/templates/icons/panel_tabbed.svg")
class_name UfTabbedPanel
extends UfPanel
## Panel whose body is a full-size [TabContainer] of [class UfTab] pages (see docs/GAME_DESIGN.md
## section 10.5). Replaces the bare panel [code]ContentSlot[/code] with tabs; each tab has its own
## [code]ContentSlot[/code].

const _TAB_SCENE := preload("res://ui/widgets/uf_tab.tscn")
const _PLACEHOLDER_TAB_KEYS: Array[String] = [
	"gui.tab.placeholder.one",
	"gui.tab.placeholder.two",
]

signal tab_changed(tab_index: int)

func _ready() -> void:
	super._ready()
	var tabs := _tabs()
	if tabs != null and not tabs.tab_changed.is_connected(_on_tabs_changed):
		tabs.tab_changed.connect(_on_tabs_changed)

## Returns the [TabContainer] that fills the panel body.
func get_tab_container() -> TabContainer:
	_ensure_structure()
	return _tabs()

## Returns the active [UfTab], or null when there are no tabs.
func get_active_tab() -> UfTab:
	var tabs := _tabs()
	if tabs == null:
		return null
	return tabs.get_current_tab_control() as UfTab

## Returns the [code]ContentSlot[/code] of the active tab, or the first tab when none is selected.
func get_content_slot() -> Container:
	var active := get_active_tab()
	if active != null:
		return active.get_content_slot()
	var tabs := _tabs()
	if tabs != null and tabs.get_child_count() > 0:
		var first := tabs.get_child(0) as UfTab
		if first != null:
			return first.get_content_slot()
	return null

## Adds a new tab page. When [param tab_title_key] is omitted, an empty [UfTab] is created.
func add_tab(tab_title_key: String, body: Control = null) -> UfTab:
	var tabs := _tabs()
	if tabs == null:
		return null
	var tab := _spawn_tab()
	tab.title_key = tab_title_key
	tabs.add_child(tab)
	if body != null:
		tab.get_content_slot().add_child(body)
	_sync_tab_title(tab)
	if Engine.is_editor_hint():
		_assign_editor_owner_tree(tab)
	return tab

## Returns the [UfTab] at [param index], or null.
func get_tab_at(index: int) -> UfTab:
	var tabs := _tabs()
	if tabs == null or index < 0 or index >= tabs.get_child_count():
		return null
	return tabs.get_child(index) as UfTab

func _ensure_structure() -> void:
	super._ensure_structure()
	var layout := get_node_or_null("Layout") as VBoxContainer
	if layout == null:
		return
	_remove_stray_layout_nodes(layout)
	if layout.get_node_or_null("Tabs") != null:
		_ensure_placeholder_tabs()
		return
	var tabs := TabContainer.new()
	tabs.name = "Tabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(0, 120)
	_add_structural_child(layout, tabs)
	_ensure_placeholder_tabs()

func _remove_stray_layout_nodes(layout: VBoxContainer) -> void:
	var header := layout.get_node_or_null("Header")
	if header != null:
		layout.remove_child(header)
		header.free()
	var slot := layout.get_node_or_null("ContentSlot")
	if slot != null:
		layout.remove_child(slot)
		slot.free()

func _ensure_placeholder_tabs() -> void:
	var tabs := _tabs()
	if tabs == null or tabs.get_child_count() > 0:
		return
	for key in _PLACEHOLDER_TAB_KEYS:
		add_tab(key)

func _spawn_tab() -> UfTab:
	return _TAB_SCENE.instantiate() as UfTab

func _tabs() -> TabContainer:
	return get_node_or_null("Layout/Tabs") as TabContainer

func _sync_tab_title(tab: UfTab) -> void:
	if tab == null:
		return
	var tabs := _tabs()
	if tabs == null:
		return
	var idx := tabs.get_tab_idx_from_control(tab)
	if idx >= 0:
		tabs.set_tab_title(idx, tr(tab.title_key) if not tab.title_key.is_empty() else "Tab")

func _on_tabs_changed(tab_index: int) -> void:
	tab_changed.emit(tab_index)
