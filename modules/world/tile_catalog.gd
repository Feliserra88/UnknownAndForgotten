@tool
class_name TileCatalog
extends Resource
## Collection of TileDef assets looked up by id. Saveable as a .tres asset.

@export var tiles: Array[TileDef] = []

var _by_id: Dictionary = {}

## Returns the TileDef registered under [param id], or null when absent.
func get_tile(id: StringName) -> TileDef:
	_ensure_index()
	return _by_id.get(id, null)

## Returns true when a tile with [param id] exists in the catalog.
func has_tile(id: StringName) -> bool:
	_ensure_index()
	return _by_id.has(id)

## Returns every tile id contained in the catalog.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for t in tiles:
		if t != null:
			out.append(t.id)
	return out

func _ensure_index() -> void:
	if _by_id.size() == tiles.size() and not _by_id.is_empty():
		return
	_by_id.clear()
	for t in tiles:
		if t != null:
			_by_id[t.id] = t
