class_name BiomeDef
extends Resource
## Describes a biome for procedural generation: which tiles it uses and how the relief
## and water/path features behave. Saveable as a .tres asset.

@export var id: StringName = &""
@export var display_name_key: String = ""

@export_group("Ground")
## Base ground tile id painted across the whole area.
@export var ground_tile: StringName = &""

@export_group("Relief")
## Inclusive z range for the generated height field.
@export var z_min: int = 0
@export var z_max: int = 2
## Noise frequency driving the height field; lower means smoother relief.
@export var height_noise_frequency: float = 0.08

@export_group("Water")
## Tile id used for water bodies (its placement rule controls size and roundness).
@export var water_tile: StringName = &""
## Approximate number of water bodies to attempt across the area.
@export var water_body_count: int = 2
## Noise frequency used to seed water body centres.
@export var water_noise_frequency: float = 0.12

@export_group("Paths")
## Tile id used for paths (its placement rule enforces connectivity).
@export var path_tile: StringName = &""
## Number of paths to trace across the area.
@export var path_count: int = 1

@export_group("Terrain (Wang)")
## Wang-painted terrain features (water, paths, cave floors, interior floors).
@export var terrain_regions: Array[TerrainRegionDef] = []

@export_group("Scatter")
## Tall props as free sprites (trees, large rocks) on the `Props` layer.
@export var scatter_props: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var scatter_prop_chance: float = 0.025
## Small decorative sprites (pebbles, flowers) on the `Decor` layer.
@export var scatter_decor: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var scatter_decor_chance: float = 0.07
## Tile ids scattered on the `objects` layer (legacy tall tiles with gameplay tags).
@export var scatter_tiles: Array[StringName] = []
## Gameplay modifier ids scattered on cells (rare; most decor uses [member scatter_decor]).
@export var scatter_modifiers: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var scatter_chance: float = 0.05
@export_range(0.0, 1.0, 0.01) var scatter_modifier_chance: float = 0.0
