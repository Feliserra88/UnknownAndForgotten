class_name WorldGenRequest
extends Resource
## A reusable, saveable generation preset: which biome, area, seed and feature overrides.
## Saveable as a .tres asset so designers can reuse and fine-tune maps.

@export var biome: BiomeDef
## Map area in cells (x/y). position is the origin cell, size the extent.
@export var area: Rect2i = Rect2i(0, 0, 32, 32)
@export var gen_seed: int = 0

@export_group("Overrides (-1 = use biome value)")
## Overrides BiomeDef.water_body_count when >= 0.
@export var water_body_count: int = -1
## Overrides BiomeDef.path_count when >= 0.
@export var path_count: int = -1

## Returns the effective water body count, applying the override when set.
func effective_water_body_count() -> int:
	return water_body_count if water_body_count >= 0 else (biome.water_body_count if biome else 0)

## Returns the effective path count, applying the override when set.
func effective_path_count() -> int:
	return path_count if path_count >= 0 else (biome.path_count if biome else 0)
