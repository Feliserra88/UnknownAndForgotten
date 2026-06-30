extends Node
## Reads the project VERSION file (major / minor / bump). Display format: X.Y.B.

const _PATH := "res://VERSION"

var major: int = 0
var minor: int = 0
var bump: int = 0

func _ready() -> void:
	_load()

## Returns the version string as major.minor.bump.
func get_string() -> String:
	return "%d.%d.%d" % [major, minor, bump]

func _load() -> void:
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		push_warning("[VER] missing VERSION file at %s" % _PATH)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.find("=") == -1:
			_parse_dotted(line)
			return
		var sep := line.find("=")
		var key := line.substr(0, sep).strip_edges()
		var value := line.substr(sep + 1).strip_edges()
		match key:
			"major":
				major = int(value)
			"minor":
				minor = int(value)
			"bump":
				bump = int(value)

func _parse_dotted(line: String) -> void:
	var parts := line.split(".")
	if parts.size() < 3:
		return
	major = int(parts[0])
	minor = int(parts[1])
	bump = int(parts[2])
