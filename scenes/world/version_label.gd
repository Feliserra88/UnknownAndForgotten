extends Label
## Small HUD label showing the project version (top-left).

func _ready() -> void:
	text = "v%s" % Version.get_string()
