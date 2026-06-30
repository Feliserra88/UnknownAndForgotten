class_name TileSideRules
extends Resource
## Per-direction passability and directional properties of a tile.
## Arrays are indexed by Direction.Dir order (N, E, S, W). Saveable as a .tres asset.

@export var passable: Array[bool] = [true, true, true, true]
@export var blocks_vision: Array[bool] = [false, false, false, false]
@export var provides_cover: Array[bool] = [false, false, false, false]

## Returns whether movement may cross this tile through [param dir].
func is_passable(dir: int) -> bool:
	return _at(passable, dir, true)

## Returns whether line of sight is blocked when looking through [param dir].
func does_block_vision(dir: int) -> bool:
	return _at(blocks_vision, dir, false)

## Returns whether the tile grants cover toward [param dir].
func does_provide_cover(dir: int) -> bool:
	return _at(provides_cover, dir, false)

func _at(arr: Array, dir: int, default: bool) -> bool:
	return arr[dir] if dir >= 0 and dir < arr.size() else default
