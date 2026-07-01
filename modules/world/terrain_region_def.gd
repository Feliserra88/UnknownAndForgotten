class_name TerrainRegionDef
extends Resource
## Describes a Wang-painted terrain feature in procedural generation.

enum PlacementKind { BLOB, PATH }

@export var id: StringName = &""
## References [TerrainSetDef.id] in the biome terrain catalog.
@export var terrain_set_id: StringName = &""
## Key in [TerrainSetDef.terrain_ids] (e.g. water, dirt_path, cave_floor).
@export var terrain_name: StringName = &""
@export var placement_kind: PlacementKind = PlacementKind.BLOB
@export var placement_rule: TilePlacementRule
@export var body_count: int = 2
@export var path_count: int = 1
