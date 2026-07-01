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

## Screen-aligned player step on a DIAMOND_DOWN isometric map (see docs/GAME_DESIGN.md §2).
## Input facing N/E/S/W maps to a grid diagonal; input diagonals map to grid cardinals.
const _ISOMETRIC_STEPS := {
	Dir.N: Vector2i(-1, -1),
	Dir.E: Vector2i(1, -1),
	Dir.S: Vector2i(1, 1),
	Dir.W: Vector2i(-1, 1),
	Dir.NE: Vector2i(0, -1),
	Dir.SE: Vector2i(1, 0),
	Dir.SW: Vector2i(0, 1),
	Dir.NW: Vector2i(-1, 0),
}

## Returns the unit grid offset for [param dir] on the x/y plane (map compass).
static func to_vector(dir: int) -> Vector2i:
	return _VECTORS[dir]

## Returns the grid cell delta for screen-aligned player movement on DIAMOND_DOWN isometric tiles.
static func to_isometric_step(dir: int) -> Vector2i:
	return _ISOMETRIC_STEPS.get(dir, Vector2i.ZERO)

## Returns the map-compass direction for a single-step [param delta], or -1 when invalid.
static func grid_dir_for_delta(delta: Vector2i) -> int:
	return between(Vector2i.ZERO, delta)

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

## Returns movement direction from a WASD vector (x = right−left, y = down−up).
static func from_input_vector(vec: Vector2) -> int:
	return _dir_from_input_vector(Vector2i(
		clampi(roundi(vec.x), -1, 1),
		clampi(roundi(vec.y), -1, 1),
	))

## Returns movement direction from held move actions (opposing keys cancel out).
static func from_input(up: bool, down: bool, left: bool, right: bool) -> int:
	if up and down:
		up = false
		down = false
	if left and right:
		left = false
		right = false
	return _dir_from_input_vector(Vector2i(int(right) - int(left), int(down) - int(up)))

static func _dir_from_input_vector(v: Vector2i) -> int:
	match v:
		Vector2i(0, -1):
			return Dir.N
		Vector2i(1, 0):
			return Dir.E
		Vector2i(0, 1):
			return Dir.S
		Vector2i(-1, 0):
			return Dir.W
		Vector2i(1, -1):
			return Dir.NE
		Vector2i(1, 1):
			return Dir.SE
		Vector2i(-1, 1):
			return Dir.SW
		Vector2i(-1, -1):
			return Dir.NW
		_:
			return -1

## Returns all four cardinal directions in index order (N, E, S, W).
static func all() -> Array[int]:
	return [Dir.N, Dir.E, Dir.S, Dir.W]
