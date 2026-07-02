extends Node
## Bridges the HUD inventory panel to the player EquipmentState via ItemsModule public APIs.

const _LOG := "ITM"

var _items: ItemsModule
var _panel: UfInventoryPanel
var _bound_state: EquipmentState
var _owner_uid: int = 0

func setup(panel: UfInventoryPanel) -> void:
	_items = ItemsModule.new()
	_panel = panel
	if _panel != null and not _panel.inventory_changed.is_connected(_on_inventory_changed):
		_panel.inventory_changed.connect(_on_inventory_changed)

## Rebinds to the player in group [code]player[/code] and refreshes the grid.
func refresh_from_player() -> void:
	var body := get_tree().get_first_node_in_group(&"player") as NpcBody
	if body == null or body.instance == null:
		return
	_bound_state = body.instance.equipment
	_owner_uid = body.instance.uid
	if _panel != null:
		_panel.refresh_instances(_bound_state.inventory_items(), _items)

func _on_inventory_changed() -> void:
	if _panel == null or _bound_state == null:
		return
	var instances := _panel.collect_instances(_items, _bound_state)
	_bound_state.set_inventory(instances)
	Log.detail(_LOG, "inventory", "slots=%d weight=%.1f" % [
		instances.size(),
		_items.inventory_total_weight(_bound_state),
	])
