@tool
extends RefCounted
## Editor UI layout helpers (keep in sync with uf_editor_ui/editor_block.gd).

const BTN_GRID_COLS := 2

static func create_button_grid(columns: int = BTN_GRID_COLS, separation: int = 4) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = maxi(1, columns)
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return grid

static func add_grid_button(grid: GridContainer, height: int = 26) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, height)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(btn)
	return btn
