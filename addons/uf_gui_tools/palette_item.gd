@tool
extends Button
## Single draggable palette tile; returns editor file-drop data for its scene path.

var _scene_path: String = ""

## Configures the tile label and the scene path used when dragging into the viewport.
func setup(label: String, scene_path: String) -> void:
	text = label
	_scene_path = scene_path
	tooltip_text = scene_path
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _scene_path.is_empty() or not ResourceLoader.exists(_scene_path):
		return null
	var preview := Label.new()
	preview.text = text
	set_drag_preview(preview)
	return {
		"type": "files",
		"files": PackedStringArray([_scene_path]),
	}
