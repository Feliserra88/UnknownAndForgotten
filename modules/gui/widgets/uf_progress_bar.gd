@tool
class_name UfProgressBar
extends ProgressBar
## Reusable progress bar widget for vitals / loading / task state. Keeps a small public API
## while relying on the shared GUI theme for styling (see GAME_DESIGN section 10.6).

@export_range(0.0, 1.0, 0.01) var ratio: float = 0.5:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		_sync_ratio()

func _enter_tree() -> void:
	min_value = 0.0
	max_value = 100.0
	show_percentage = true
	_sync_ratio()

## Sets the bar using a normalized [param value] in the [0, 1] range.
func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)
	_sync_ratio()

func _sync_ratio() -> void:
	value = ratio * 100.0
