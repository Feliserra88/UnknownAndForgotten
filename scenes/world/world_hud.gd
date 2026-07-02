extends CanvasLayer
## HUD for world_root: loads game panels from ui/panels/ and toggles them via Input Map.

const _LOG := "GUI"
const _DEFAULT_INVENTORY := "res://ui/panels/uf_inventory.tscn"

@export var inventory_panel_path: String = _DEFAULT_INVENTORY

var _gui: GuiModule
var _inventory: UfPanelIngame

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_gui = GuiModule.new()
	add_child(_gui)
	_load_inventory_panel()

func _load_inventory_panel() -> void:
	_inventory = _gui.load_panel(inventory_panel_path)
	if _inventory == null:
		Log.warn(_LOG, "world_hud: failed to load %s" % inventory_panel_path)
		return
	add_child(_inventory)
	_inventory.hide()
	_inventory.position = Vector2(16, 28)
	if _inventory.has_signal("panel_closed"):
		_inventory.panel_closed.connect(_on_inventory_closed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()

func _toggle_inventory() -> void:
	if _inventory == null:
		return
	_inventory.visible = not _inventory.visible

func _on_inventory_closed() -> void:
	if _inventory != null:
		_inventory.hide()
