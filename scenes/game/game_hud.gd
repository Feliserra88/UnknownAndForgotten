extends CanvasLayer
## In-game HUD: loads panels from ui/panels/ and toggles them via Input Map.

const _LOG := "GUI"
const _DEFAULT_INVENTORY := "res://ui/panels/uf_inventory.tscn"
const _BridgeScript := preload("res://scenes/game/player_inventory_bridge.gd")

@export var inventory_panel_path: String = _DEFAULT_INVENTORY

var _gui: GuiModule
var _inventory: UfInventoryPanel
var _inventory_bridge: Node

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_gui = GuiModule.new()
	add_child(_gui)
	_load_inventory_panel()

func _load_inventory_panel() -> void:
	_inventory = _gui.load_panel(inventory_panel_path) as UfInventoryPanel
	if _inventory == null:
		Log.warn(_LOG, "game_hud: failed to load %s" % inventory_panel_path)
		return
	add_child(_inventory)
	_inventory.hide()
	_inventory.position = Vector2(16, 28)
	if _inventory.has_signal("panel_closed"):
		_inventory.panel_closed.connect(_on_inventory_closed)
	_inventory_bridge = _BridgeScript.new()
	_inventory_bridge.name = "InventoryBridge"
	add_child(_inventory_bridge)
	_inventory_bridge.call("setup", _inventory)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()

func _toggle_inventory() -> void:
	if _inventory == null:
		return
	var opening := not _inventory.visible
	_inventory.visible = opening
	if opening and _inventory_bridge != null:
		_inventory_bridge.call("refresh_from_player")

func _on_inventory_closed() -> void:
	if _inventory != null:
		_inventory.hide()
