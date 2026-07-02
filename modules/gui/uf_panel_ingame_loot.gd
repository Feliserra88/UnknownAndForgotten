@tool
@icon("res://ui/templates/icons/panel_ingame_loot.svg")
class_name UfLootPanel
extends UfPanelIngame
## In-game loot panel: header chrome plus a draggable item grid (see docs/GAME_DESIGN.md section 10).
## Presentational only — relays slot signals and handles moves/swaps within the grid; domain modules
## wire loot rules via [signal item_dropped] / [method set_slot_item].
##
## Grid layout is authored in [code]ui/templates/uf_panel_ingame_loot.tscn[/code]. [member grid_columns],
## [member grid_rows] and [member cell_size] are fallbacks when the grid is built from code.

const _SlotScript := preload("res://modules/gui/widgets/uf_item_slot.gd")
const _DEFAULT_COLUMNS := 4
const _DEFAULT_ROWS := 4
const _DEFAULT_CELL_SIZE := Vector2(40, 40)
const _GRID_SEPARATION := 2

signal item_dropped(slot_id: StringName, payload: Dictionary)
signal item_removed(slot_id: StringName)
signal slot_activated(slot_id: StringName)
signal loot_changed

@export var grid_columns: int = _DEFAULT_COLUMNS:
	set(value):
		grid_columns = maxi(value, 1)
		_ensure_loot_grid()
@export var grid_rows: int = _DEFAULT_ROWS:
	set(value):
		grid_rows = maxi(value, 1)
		_ensure_loot_grid()
@export var cell_size: Vector2 = _DEFAULT_CELL_SIZE:
	set(value):
		cell_size = value.max(Vector2(16, 16))
		_update_cell_sizes()

var _slots: Dictionary = {}
var _grid: GridContainer

func _ensure_structure() -> void:
	super._ensure_structure()
	_ensure_loot_grid()

## Returns the loot [GridContainer] under [code]ContentSlot[/code].
func get_loot_grid() -> GridContainer:
	_ensure_loot_grid()
	return _grid

## Returns the slot at grid coordinates, or null when out of range.
func get_slot_at(column: int, row: int) -> UfItemSlot:
	return get_slot(slot_id_at(column, row))

## Returns the slot id for [param column] / [param row] (row-major).
func slot_id_at(column: int, row: int) -> StringName:
	if column < 0 or row < 0 or column >= grid_columns or row >= grid_rows:
		return &""
	return StringName(str(row * grid_columns + column))

## Returns the slot with [param slot_id], if built.
func get_slot(slot_id: StringName) -> UfItemSlot:
	return _slots.get(slot_id, null) as UfItemSlot

## Returns all slot ids in the current grid.
func slot_ids() -> Array:
	return _slots.keys()

## Sets [param item_id] with [param tex] on [param slot_id], if present.
func set_slot_item(slot_id: StringName, item_id: StringName, tex: Texture2D) -> void:
	var slot := get_slot(slot_id)
	if slot != null:
		slot.set_item(item_id, tex)
		loot_changed.emit()

## Clears the item shown in [param slot_id], if present.
func clear_slot(slot_id: StringName) -> void:
	var slot := get_slot(slot_id)
	if slot != null:
		slot.clear_item()
		loot_changed.emit()

func _ensure_loot_grid() -> void:
	var content := get_content_slot()
	if content == null:
		return
	_grid = content.get_node_or_null("LootGrid") as GridContainer
	if _grid == null:
		_grid = GridContainer.new()
		_grid.name = "LootGrid"
		_grid.columns = grid_columns
		_grid.add_theme_constant_override("h_separation", _GRID_SEPARATION)
		_grid.add_theme_constant_override("v_separation", _GRID_SEPARATION)
		_add_structural_child(content, _grid)
	if Engine.is_editor_hint() and _grid.get_child_count() > 0:
		_refresh_slots_cache()
		return
	var expected := grid_columns * grid_rows
	if _grid.columns != grid_columns or _grid.get_child_count() != expected:
		_rebuild_grid()

func _refresh_slots_cache() -> void:
	if _grid == null:
		return
	_slots.clear()
	for child in _grid.get_children():
		if child is UfItemSlot:
			var slot := child as UfItemSlot
			_slots[slot.slot_id] = slot
			_wire_slot(slot)

func _rebuild_grid() -> void:
	if _grid == null:
		return
	_slots.clear()
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
	var item_id := StringName(payload.get("item_id", &""))
	if String(item_id).is_empty():
		return
	var dest := get_slot(slot_id)
	if dest == null:
		return
	var from_slot := StringName(payload.get("from_slot", &""))
	var icon_tex: Texture2D = payload.get("icon", null) as Texture2D
	if not String(from_slot).is_empty():
		if from_slot == slot_id:
			return
		var source := get_slot(from_slot)
		if source != null:
			icon_tex = icon_tex if icon_tex != null else source.item_texture()
			var dest_item := dest.item_id()
			var dest_tex := dest.item_texture()
			source.clear_item()
			dest.set_item(item_id, icon_tex)
			if not String(dest_item).is_empty():
				source.set_item(dest_item, dest_tex)
		else:
			dest.set_item(item_id, icon_tex)
	else:
		dest.set_item(item_id, icon_tex)
	loot_changed.emit()
	item_dropped.emit(slot_id, payload)

func _on_slot_item_removed(slot_id: StringName) -> void:
	clear_slot(slot_id)
	item_removed.emit(slot_id)

func _on_slot_activated(slot_id: StringName) -> void:
	slot_activated.emit(slot_id)
