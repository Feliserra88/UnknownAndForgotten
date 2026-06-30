class_name Direction
extends RefCounted
## Cardinal grid directions on the x/y map plane plus conversion helpers.
## Index order matches per-side rule arrays across the world module.

enum Dir { N, E, S, W }

const _VECTORS := {
	Dir.N: Vector2i(0, -1),
	Dir.E: Vector2i(1, 0),
	Dir.S: Vector2i(0, 1),
	Dir.W: Vector2i(-1, 0),
}

## Returns the unit grid offset for [param dir] on the x/y plane.
static func to_vector(dir: int) -> Vector2i:
	return _VECTORS[dir]

## Returns the opposite cardinal direction of [param dir].
static func opposite(dir: int) -> int:
	return (dir + 2) % 4

## Returns the direction from [param from_cell] to the adjacent [param to_cell], or -1 if not adjacent.
static func between(from_cell: Vector2i, to_cell: Vector2i) -> int:
	var delta := to_cell - from_cell
	for dir in _VECTORS:
		if _VECTORS[dir] == delta:
			return dir
	return -1

## Returns all four cardinal directions in index order (N, E, S, W).
static func all() -> Array[int]:
	return [Dir.N, Dir.E, Dir.S, Dir.W]
