@tool
extends Node
## Reads runtime configuration from venv.ini and exposes typed getters.
## Single source of truth for runtime-modifiable options (see docs/ARCHITECTURE.md section 8).
## @tool: editor plugins and @tool modules (uf_map_editor, WorldModule) call getters in the editor.

const _CONFIG_PATH := "res://venv.ini"

var _values: Dictionary = {}

func _ready() -> void:
	_load()

func _ensure_loaded() -> void:
	if _values.is_empty():
		_load()

## Reloads every value from venv.ini, discarding the previous snapshot.
func reload() -> void:
	_load()

## Returns the raw string value for [param key], or [param default] when absent.
func get_string(key: String, default: String = "") -> String:
	_ensure_loaded()
	return str(_values[key]) if _values.has(key) else default

## Returns [param key] parsed as int, or [param default] when absent or invalid.
func get_int(key: String, default: int = 0) -> int:
	_ensure_loaded()
	return int(_values[key]) if _values.has(key) else default

## Returns [param key] parsed as float, or [param default] when absent.
func get_float(key: String, default: float = 0.0) -> float:
	_ensure_loaded()
	return float(_values[key]) if _values.has(key) else default

## Returns [param key] parsed as bool ("true"/"1"/"yes"), or [param default] when absent.
func get_bool(key: String, default: bool = false) -> bool:
	_ensure_loaded()
	if not _values.has(key):
		return default
	var raw := str(_values[key]).strip_edges().to_lower()
	return raw == "true" or raw == "1" or raw == "yes"

## Returns true when [param key] is present in the loaded configuration.
func has(key: String) -> bool:
	_ensure_loaded()
	return _values.has(key)

func _load() -> void:
	_values.clear()
	var file := FileAccess.open(_CONFIG_PATH, FileAccess.READ)
	if file == null:
		# Bootstrap exception: Log autoload may not exist yet while Config loads.
		push_warning("[CFG] missing config file at %s, using defaults" % _CONFIG_PATH)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var sep := line.find("=")
		if sep == -1:
			continue
		var key := line.substr(0, sep).strip_edges()
		var value := line.substr(sep + 1).strip_edges()
		if not key.is_empty():
			_values[key] = value
