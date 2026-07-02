@tool
extends EditorPlugin
## GUI tools plugin: composes domain panels through the gui module public API (UfPanel + Uf*
## widgets) and saves them as reusable PackedScene assets under res://ui/panels/
## (see docs/GAME_DESIGN.md section 10.9). No domain logic is duplicated here.

const _DockScript := preload("res://addons/uf_gui_tools/dock.gd")

var _dock: Control
var _gui: GuiModule

func _enter_tree() -> void:
	_gui = GuiModule.new()
	_dock = _DockScript.new()
	_dock.name = "UF GUI"
	_dock.setup(self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null
	_gui = null

## Builds a domain panel of [param kind] with [param title_key] and the widget ids in
## [param widgets], then saves it as res://ui/panels/<panel_id>.tscn. Returns the saved path or "".
func create_domain_panel(panel_id: String, kind: StringName, title_key: String, widgets: Array) -> String:
	var clean_id := panel_id.strip_edges()
	if clean_id.is_empty():
		set_dock_status("Enter a panel id first.")
		return ""
	var panel := _gui.create_panel(kind, title_key)
	if panel == null:
		set_dock_status("Unknown panel kind: %s" % kind)
		return ""
	_populate_widgets(panel, widgets)
	var path := _save_panel(panel, clean_id)
	panel.free()
	return path

func _populate_widgets(panel: UfPanel, widgets: Array) -> void:
	var slot := panel.get_content_slot()
	if slot == null:
		return
	for id in widgets:
		var widget := _build_widget(String(id))
		if widget != null:
			slot.add_child(widget)

func _build_widget(id: String) -> Control:
	var widget := _gui.instantiate_widget(id)
	return widget

func _save_panel(panel: UfPanel, panel_id: String) -> String:
	DirAccess.make_dir_recursive_absolute(GuiModule.PANELS_DIR)
	_set_owner_recursive(panel, panel)
	var scene := PackedScene.new()
	var pack_result := scene.pack(panel)
	if pack_result != OK:
		set_dock_status("Pack failed (%d)." % pack_result)
		return ""
	var path := "%s/%s.tscn" % [GuiModule.PANELS_DIR, panel_id]
	var save_result := ResourceSaver.save(scene, path)
	if save_result != OK:
		set_dock_status("Save failed (%d)." % save_result)
		return ""
	get_editor_interface().get_resource_filesystem().scan()
	set_dock_status("Saved %s" % path)
	return path

## Assigns [param owner_node] as owner to every descendant so PackedScene.pack keeps them.
func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child != owner_node:
			child.owner = owner_node
		_set_owner_recursive(child, owner_node)

func set_dock_status(text: String) -> void:
	if _dock != null and _dock.has_method("set_status"):
		_dock.set_status(text)
	push_warning("[UF GUI] %s" % text)
