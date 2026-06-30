class_name MapHeightField
extends Resource
## Per-cell surface height (z) for the x/y map plane, parallel to the TileMapLayers.
## Godot's 2D tilemap stores no height, so z lives here. Saveable as a .tres asset.

@export var region: Rect2i = Rect2i()
## Visual pixels added per z unit when projecting cells to world space.
@export var height_step: int = 8
@export var heights: PackedInt32Array = PackedInt32Array()

## Resizes the field to [param new_region] and clears every height to 0.
func resize(new_region: Rect2i) -> void:
	region = new_region
	heights.resize(new_region.size.x * new_region.size.y)
	heights.fill(0)

## Returns the z height at [param cell], or 0 when outside the region.
func get_height(cell: Vector2i) -> int:
	var i := _index(cell)
	return heights[i] if i != -1 else 0

## Sets the z height at [param cell]; ignored when outside the region.
func set_height(cell: Vector2i, z: int) -> void:
	var i := _index(cell)
	if i != -1:
		heights[i] = z

## Adds [param delta] to the z height at [param cell], clamped to a sane range.
func add_height(cell: Vector2i, delta: int) -> void:
	var i := _index(cell)
	if i != -1:
		heights[i] = clampi(heights[i] + delta, -64, 64)

func _index(cell: Vector2i) -> int:
	if not region.has_point(cell):
		return -1
	var local := cell - region.position
	return local.y * region.size.x + local.x
