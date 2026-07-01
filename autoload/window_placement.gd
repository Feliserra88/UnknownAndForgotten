extends Node
## Applies optional game-window size and screen position on startup from venv.ini (see ARCHITECTURE.md).
## Runs only at runtime (not in the editor). Deferred so DisplayServer reports the final window size.

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not Config.get_bool("GAME_WINDOW_PLACEMENT_ENABLED", false):
		return
	call_deferred("_apply")

func _apply() -> void:
	var width := Config.get_int("GAME_WINDOW_WIDTH", 0)
	var height := Config.get_int("GAME_WINDOW_HEIGHT", 0)
	if width > 0 and height > 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(width, height))
	var pos := _resolve_position()
	DisplayServer.window_set_position(pos)
	Log.detail("CFG", "win", "pos=%s size=%s" % [pos, DisplayServer.window_get_size()])

## Returns top-left pixel coordinates from corner/margin settings or absolute GAME_WINDOW_X/Y.
func _resolve_position() -> Vector2i:
	var corner := Config.get_string("GAME_WINDOW_PLACEMENT_CORNER", "bottom_right").to_lower()
	var margin := Config.get_int("GAME_WINDOW_MARGIN", 8)
	var taskbar_margin := Config.get_int("GAME_WINDOW_TASKBAR_MARGIN", 48)
	var x_abs := Config.get_int("GAME_WINDOW_X", -1)
	var y_abs := Config.get_int("GAME_WINDOW_Y", -1)
	if corner == "absolute" and x_abs >= 0 and y_abs >= 0:
		return Vector2i(x_abs, y_abs)
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var size := DisplayServer.window_get_size()
	match corner:
		"bottom_left":
			return Vector2i(margin, screen.y - size.y - margin - taskbar_margin)
		"top_right":
			return Vector2i(screen.x - size.x - margin, margin)
		"top_left":
			return Vector2i(margin, margin)
		_: # bottom_right
			return Vector2i(screen.x - size.x - margin, screen.y - size.y - margin - taskbar_margin)
