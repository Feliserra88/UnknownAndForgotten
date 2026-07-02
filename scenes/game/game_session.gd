extends Node
class_name GameSession
## Persistent game shell: map host, HUD and bootstrap stay loaded while maps are swapped.

const _LOG := "GSN"

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Log.info(_LOG, "ready", "game session started")

## Returns the map facade used for grid logic, layers and baked map I/O.
func get_world() -> WorldModule:
	return get_node_or_null("WorldHost") as WorldModule

## Loads a baked map into WorldHost and notifies Bootstrap to reposition the player.
func change_map(map_path: String, spawn_cell: Vector2i = Vector2i(-999999, -999999)) -> bool:
	var world_host := get_world()
	if world_host == null:
		return false
	if not world_host.load_baked_map(map_path):
		Log.warn(_LOG, "change_map failed path=%s" % map_path)
		return false
	var bootstrap := get_node_or_null("Bootstrap")
	if bootstrap != null and bootstrap.has_method("on_map_loaded"):
		bootstrap.call("on_map_loaded", spawn_cell)
	Log.info(_LOG, "change_map", map_path)
	return true
