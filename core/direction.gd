class_name Direction
extends RefCounted
## Grid directions on the x/y map plane (4 cardinals + 4 diagonals) plus conversion helpers.
## Cardinal indices 0–3 match per-side rule arrays across the world module.

enum Dir { N, E, S, W, NE, SE, SW, NW }

const _VECTORS := {
	Dir.N: Vector2i(0, -1),
	Dir.E: Vector2i(1, 0),
	Dir.S: Vector2i(0, 1),
	Dir.W: Vector2i(-1, 0),
	Dir.NE: Vector2i(1, -1),
	Dir.SE: Vector2i(1, 1),
	Dir.SW: Vector2i(-1, 1),
	Dir.NW: Vector2i(-1, -1),
}

const _OPPOSITES := {
	Dir.N: Dir.S,
	Dir.E: Dir.W,
	Dir.S: Dir.N,
	Dir.W: Dir.E,
	Dir.NE: Dir.SW,
	Dir.SE: Dir.NW,
	Dir.SW: Dir.NE,
	Dir.NW: Dir.SE,
}

## Returns the unit grid offset for [param dir] on the x/y plane.
static func to_vector(dir: int) -> Vector2i:
	return _VECTORS[dir]

## Returns true when [param dir] is a diagonal step (NE, SE, SW, NW).
static func is_diagonal(dir: int) -> bool:
	return dir == Dir.NE or dir == Dir.SE or dir == Dir.SW or dir == Dir.NW

## Returns the opposite direction of [param dir] (cardinal or diagonal).
static func opposite(dir: int) -> int:
	return _OPPOSITES.get(dir, dir)

## Returns the direction from [param from_cell] to the adjacent [param to_cell], or -1 if not adjacent.
static func between(from_cell: Vector2i, to_cell: Vector2i) -> int:
	var delta := to_cell - from_cell
	for dir in _VECTORS:
		if _VECTORS[dir] == delta:
			return dir
	return -1

## Returns the sprite orientation id for an 8-way facing [param dir].
static func to_orientation(dir: int) -> StringName:
	match dir:
		Dir.E:
			return &"side_right"
		Dir.W:
			return &"side_left"
		Dir.N:
			return &"back"
		Dir.S:
			return &"front"
		Dir.NE:
			return &"back_right"
		Dir.SE:
			return &"front_right"
		Dir.SW:
			return &"front_left"
		Dir.NW:
			return &"back_left"
		_:
			return &"front"

## Returns movement direction from held move actions (diagonals before cardinals).
static func from_input(up: bool, down: bool, left: bool, right: bool) -> int:
	if up and right:
		return Dir.NE
	if up and left:
		return Dir.NW
	if down and right:
		return Dir.SE
	if down and left:
		return Dir.SW
	if up:
		return Dir.N
	if down:
		return Dir.S
	if left:
		return Dir.W
	if right:
		return Dir.E
	return -1

## Returns all four cardinal directions in index order (N, E, S, W).
static func all() -> Array[int]:
	return [Dir.N, Dir.E, Dir.S, Dir.W]
