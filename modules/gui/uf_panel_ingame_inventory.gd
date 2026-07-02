@tool
@icon("res://ui/templates/icons/panel_ingame_loot.svg")
class_name UfInventoryPanel
extends UfPanelIngame
## In-game inventory panel: draggable item grid backed by EquipmentState (see docs/GAME_DESIGN.md
## section 7). Presentational grid with opaque instance payloads; domain sync via bridge script.

const _SlotScript := preload("res://modules/gui/widgets/uf_item_slot.gd")
const _DEFAULT_COLUMNS := 6
const _DEFAULT_ROWS := 4
const _DEFAULT_CELL_SIZE := Vector2(40, 40)
const _GRID_SEPARATION := 2

signal inventory_changed
signal item_dropped(slot_id: StringName, payload: Dictionary)
signal item_removed(slot_id: StringName)
signal slot_activated(slot_id: StringName)

@export var grid_columns: int = _DEFAULT_COLUMNS:
	set(value):
		grid_columns = maxi(value, 1)
		_ensure_inventory_grid()
@export var grid_rows: int = _DEFAULT_ROWS:
	set(value):
		grid_rows = maxi(value, 1)
		_ensure_inventory_grid()
@export var cell_size: Vector2 = _DEFAULT_CELL_SIZE:
	set(value):
		cell_size = value.max(Vector2(16, 16))
		_update_cell_sizes()

var _slots: Dictionary = {}
var _grid: GridContainer
var _uid_by_slot: Dictionary = {}

func _ensure_structure() -> void:
	super._ensure_structure()
	_ensure_inventory_grid()

## Returns the inventory [GridContainer] under [code]ContentSlot[/code].
func get_inventory_grid() -> GridContainer:
	_ensure_inventory_grid()
	return _grid

## Returns the slot id for grid coordinates (row-major).
func slot_id_at(column: int, row: int) -> StringName:
	if column < 0 or row < 0 or column >= grid_columns or row >= grid_rows:
		return &""
	return StringName(str(row * grid_columns + column))

## Returns the slot with [param slot_id], if built.
func get_slot(slot_id: StringName) -> UfItemSlot:
	return _slots.get(slot_id, null) as UfItemSlot

## Clears the grid and fills cells from [param instances] in order.
func refresh_instances(instances: Array, items_module: ItemsModule) -> void:
	_uid_by_slot.clear()
	for slot in _slots.values():
		if slot is UfItemSlot:
			(slot as UfItemSlot).clear_item()
	var index := 0
	for inst in instances:
		if not (inst is ItemInstance):
			continue
		if index >= grid_columns * grid_rows:
			break
		var slot_id := slot_id_at(index % grid_columns, index / grid_columns)
		var slot := get_slot(slot_id)
		if slot == null:
			continue
		var item_inst := inst as ItemInstance
		var icon_tex := items_module.resolve_icon(item_inst)
		slot.set_instance(item_inst.instance_uid, item_inst.def_id, icon_tex)
		_uid_by_slot[slot_id] = item_inst.instance_uid
		index += 1

## Returns ItemInstance list reconstructed from non-empty grid slots (row-major).
func collect_instances(items_module: ItemsModule, equipment_state: EquipmentState) -> Array:
	var out: Array = []
	for row in grid_rows:
		for col in grid_columns:
			var slot_id := slot_id_at(col, row)
			var uid: String = _uid_by_slot.get(slot_id, "")
			if uid.is_empty():
				continue
			var inst := items_module.find_instance(equipment_state, uid)
			if inst == null:
				var slot := get_slot(slot_id)
				if slot != null and not String(slot.item_id()).is_empty():
					inst = items_module.create_instance(slot.item_id())
					inst.instance_uid = uid
			if inst != null:
				out.append(inst)
	return out

func _ensure_inventory_grid() -> void:
	var content := get_content_slot()
	if content == null:
		return
	_grid = content.get_node_or_null("InventoryGrid") as GridContainer
	if _grid == null:
		_grid = GridContainer.new()
		_grid.name = "InventoryGrid"
		_grid.columns = grid_columns
		_grid.add_theme_constant_override("h_separation", _GRID_SEPARATION)
		_grid.add_theme_constant_override("v_separation", _GRID_SEPARATION)
		_add_structural_child(content, _grid)
	var expected := grid_columns * grid_rows
	if _grid.columns != grid_columns or _grid.get_child_count() != expected:
		_rebuild_grid()

func _rebuild_grid() -> void:
	if _grid == null:
		return
	_slots.clear()
	_uid_by_slot.clear()
	for child in _grid.get_children():
		child.queue_free()
	_grid.columns = grid_columns
	var cell_count := grid_columns * grid_rows
	for index in cell_count:
		var slot_id := StringName(str(index))
		var slot := _SlotScript.new() as UfItemSlot
		slot.slot_id = slot_id
		slot.name = "Slot_%d" % index
		slot.custom_minimum_size = cell_size
		_grid.add_child(slot)
		_slots[slot_id] = slot
		_wire_slot(slot)

func _wire_slot(slot: UfItemSlot) -> void:
	if not slot.item_dropped.is_connected(_on_slot_item_dropped):
		slot.item_dropped.connect(_on_slot_item_dropped)
	if not slot.item_removed.is_connected(_on_slot_item_removed):
		slot.item_removed.connect(_on_slot_item_removed)
	if not slot.slot_activated.is_connected(_on_slot_activated):
		slot.slot_activated.connect(_on_slot_activated)

func _update_cell_sizes() -> void:
	for slot in _slots.values():
		if slot is Control:
			(slot as Control).custom_minimum_size = cell_size

func _on_slot_item_dropped(slot_id: StringName, payload: Dictionary) -> void:
	var dest := get_slot(slot_id)
	if dest == null:
		return
	var from_slot := StringName(payload.get("from_slot", &""))
	var instance_uid: String = payload.get("instance_uid", "")
	var def_id := StringName(payload.get("item_id", &""))
	var icon_tex: Texture2D = payload.get("icon", null) as Texture2D
	if not String(from_slot).is_empty() and from_slot != slot_id:
		var source := get_slot(from_slot)
		if source != null:
			icon_tex = icon_tex if icon_tex != null else source.item_texture()
			var dest_uid: String = _uid_by_slot.get(slot_id, "")
			var dest_def := dest.item_id()
			var dest_tex := dest.item_texture()
			var src_uid: String = _uid_by_slot.get(from_slot, "")
			source.clear_item()
			_uid_by_slot.erase(from_slot)
			dest.set_instance(instance_uid, def_id, icon_tex)
			if not instance_uid.is_empty():
				_uid_by_slot[slot_id] = instance_uid
			if not dest_uid.is_empty():
				source.set_instance(dest_uid, dest_def, dest_tex)
				_uid_by_slot[from_slot] = dest_uid
		else:
			dest.set_instance(instance_uid, def_id, icon_tex)
			if not instance_uid.is_empty():
				_uid_by_slot[slot_id] = instance_uid
	else:
		dest.set_instance(instance_uid, def_id, icon_tex)
		if not instance_uid.is_empty():
			_uid_by_slot[slot_id] = instance_uid
	inventory_changed.emit()
	item_dropped.emit(slot_id, payload)

func _on_slot_item_removed(slot_id: StringName) -> void:
	var slot := get_slot(slot_id)
	if slot != null:
		slot.clear_item()
	_uid_by_slot.erase(slot_id)
	inventory_changed.emit()
	item_removed.emit(slot_id)

func _on_slot_activated(slot_id: StringName) -> void:
	slot_activated.emit(slot_id)
