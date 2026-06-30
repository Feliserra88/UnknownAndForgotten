class_name TilePlacementRule
extends Resource
## Procedural placement constraints consumed by the world_gen solver. Saveable as a .tres asset.

## Reject placements that end up with no same-type orthogonal neighbour.
@export var forbid_isolated: bool = false

## Cluster size bounds for blob-like tiles (e.g. water bodies). 0 = unconstrained.
@export var min_cluster_size: int = 0
@export var max_cluster_size: int = 0

## Minimum compactness (0..1) for clusters; higher favours rounded shapes. 0 = ignored.
@export_range(0.0, 1.0, 0.01) var roundness_min: float = 0.0

## Marks tiles that must form continuous lines (e.g. paths, rivers).
@export var is_linear: bool = false

## Minimum same-type collinear neighbours required (path needs 2: front and back).
@export var min_collinear_neighbors: int = 0

## Allowed orthogonal neighbour tile ids. Empty means any neighbour is allowed.
@export var allowed_neighbors: Array[StringName] = []

## Forbidden orthogonal neighbour tile ids; takes precedence over allowed_neighbors.
@export var forbidden_neighbors: Array[StringName] = []
