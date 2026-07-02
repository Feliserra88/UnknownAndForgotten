@tool
@icon("res://ui/widgets/icons/grid.svg")
class_name UfGridContainer
extends GridContainer
## Grid widget for inventory / skill slots (see GAME_DESIGN section 10.6). Holds only layout;
## domain logic lives in the relevant module, never in the widget.

const _DEFAULT_COLUMNS := 2
const _DEFAULT_CELL_COUNT := 4
const _CELL_MIN_SIZE := Vector2(48, 48)

func _enter_tree() -> void:
	_ensure_placeholder_cells()

## Fills a 2×2 grid with empty slot panels when the container has no children yet.
func _ensure_placeholder_cells() -> void:
	if get_child_count() > 0:
		return
	columns = _DEFAULT_COLUMNS
	for _i in _DEFAULT_CELL_COUNT:
		add_child(_make_placeholder_cell())

func _make_placeholder_cell() -> Panel:
	var cell := Panel.new()
	cell.custom_minimum_size = _CELL_MIN_SIZE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return cell
