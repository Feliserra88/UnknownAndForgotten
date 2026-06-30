@tool
extends Node
## Central logging facility. Every trace passes through here, gated per module by venv.ini.
## Format: "YYYY/MM/DD hh:mm:ss [COD] type message" (see docs/ARCHITECTURE.md section 9).
## @tool: callable from @tool modules while the map editor runs in the Godot editor.

enum Level { OFF = 0, SUMMARY = 1, DETAIL = 2 }

## Maps 3-letter module codes to their venv.ini config key suffix (LOG_<KEY>_LEVEL).
const _MODULE_KEYS := {
	"CFG": "CONFIG",
	"LOG": "LOG",
	"WLD": "WORLD",
	"WGN": "WORLD_GEN",
	"CAM": "CAMERA",
	"NPC": "NPC",
	"APP": "APPEARANCE",
	"ATR": "ATTRIBUTES",
}

## Logs a summary-level event ([param code] = module, [param type] = short category).
func info(code: String, type: String, message: String) -> void:
	_emit(code, type, message, Level.SUMMARY)

## Logs a detail-level event, shown only when the module gate is set to 2.
func detail(code: String, type: String, message: String) -> void:
	_emit(code, type, message, Level.DETAIL)

## Logs a warning, visible whenever the module gate is at least 1.
func warn(code: String, message: String) -> void:
	_emit(code, "warn", message, Level.SUMMARY)

## Logs an error, visible whenever the module gate is at least 1.
func err(code: String, message: String) -> void:
	_emit(code, "err", message, Level.SUMMARY)

func _emit(code: String, type: String, message: String, required: int) -> void:
	if _gate(code) < required:
		return
	print("%s [%s] %s %s" % [_timestamp(), code, type, message])

func _gate(code: String) -> int:
	var suffix: String = _MODULE_KEYS.get(code, code)
	return Config.get_int("LOG_%s_LEVEL" % suffix, Level.SUMMARY)

func _timestamp() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d/%02d/%02d %02d:%02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
