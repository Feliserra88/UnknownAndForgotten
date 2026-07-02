@tool
extends VBoxContainer
## Dock UI for the GUI tools plugin. Palette drag-and-drop plus batch panel asset creation.

const _PaletteScript := preload("res://addons/uf_gui_tools/widget_palette.gd")

const _KINDS: Array[StringName] = [&"panel", &"info", &"dialog", &"tabbed"]
const _WIDGET_IDS: Array[String] = ["label", "button", "list", "grid", "layout_region", "equipment_slot"]

var _plugin: EditorPlugin
var _gui: GuiModule
var _id: LineEdit
var _title: LineEdit
var _kind: OptionButton
var _widget_checks: Array[CheckBox] = []
var _status: Label

func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_gui = GuiModule.new()
	_build()

func _build() -> void:
	add_theme_constant_override("separation", 4)
	_title_label("UF GUI Tools")
	var hint := Label.new()
	hint.text = "Drag panels or widgets into an open UI scene (hold Ctrl to parent under selection)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	_title_label("Panels")
	var panel_palette := _PaletteScript.new()
	panel_palette.set_entries(_gui.panel_palette_entries())
	add_child(panel_palette)

	_title_label("Widgets")
	var widget_palette := _PaletteScript.new()
	widget_palette.set_entries(_gui.widget_palette_entries())
	add_child(widget_palette)

	add_child(HSeparator.new())
	_title_label("Batch create asset")
	var batch_hint := Label.new()
	batch_hint.text = "Or compose via checkboxes and save a game panel under res://ui/panels/."
	batch_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(batch_hint)

	_id = _line("Panel id (file name)", "inventory_panel")
	_title = _line("Title key", "gui.inventory.title")
	_kind = _options("Base kind", _kind_labels())

	_title_label("Widgets in content")
	for id in _WIDGET_IDS:
		var check := CheckBox.new()
		check.text = id
		add_child(check)
		_widget_checks.append(check)

	_button("Create panel asset", _on_create_pressed)

	add_child(HSeparator.new())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 40)
	add_child(_status)

func _on_create_pressed() -> void:
	if _plugin == null:
		set_status("Plugin not ready — reload the project.")
		return
	var widgets := []
	for i in _WIDGET_IDS.size():
		if _widget_checks[i].button_pressed:
			widgets.append(_WIDGET_IDS[i])
	_plugin.callv(&"create_domain_panel", [_id.text, _KINDS[_kind.selected], _title.text, widgets])

func set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func _kind_labels() -> Array:
	var labels := []
	for k in _KINDS:
		labels.append(String(k))
	return labels

func _title_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(label)

func _line(label: String, value: String) -> LineEdit:
	var caption := Label.new()
	caption.text = label
	add_child(caption)
	var line := LineEdit.new()
	line.text = value
	add_child(line)
	return line

func _options(label: String, items: Array) -> OptionButton:
	var caption := Label.new()
	caption.text = label
	add_child(caption)
	var option := OptionButton.new()
	for item in items:
		option.add_item(str(item))
	add_child(option)
	return option

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	add_child(button)
