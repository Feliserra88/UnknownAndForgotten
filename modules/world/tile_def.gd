@tool
class_name TileDef
extends Resource
## Parent definition of a map tile: non-exclusive type flags, per-side rules,
## placement constraints and allowed modifiers. Saveable as a .tres asset.

@export var id: StringName = &""
@export var display_name_key: String = ""
@export_flags("Ground", "Walkable", "Wall", "Water", "Hazard", "Interactable", "Cover", "VisionBlocker") var tags: int = 0

@export_group("Behaviour")
## Per-direction passability, vision and cover. When null, behaviour falls back to tags.
@export var side_rules: TileSideRules
## Constraints applied by the procedural generator. When null, the tile is unconstrained.
@export var placement_rule: TilePlacementRule
## Modifiers (wet, burning, ...) that may be applied to this tile.
@export var allowed_modifiers: Array[TileModifierDef] = []

@export_group("Art")
## Optional isometric sprite. When set, used instead of the placeholder diamond in the TileSet atlas.
@export var art_texture: Texture2D

@export_group("Placeholder visual")
## Flat colour used to build the placeholder diamond when [member art_texture] is unset.
@export var placeholder_color: Color = Color.MAGENTA

@export_group("TileSet mapping")
## Atlas source id assigned when the TileSet is built (runtime only; not saved on disk).
@export var source_id: int = 0
## Atlas coordinates assigned when the TileSet is built (runtime only; not saved on disk).
@export var atlas_coords: Vector2i = Vector2i.ZERO

## Returns true when [param tag] (a TileTags.Tag value) is set.
func has_tag(tag: int) -> bool:
	return (tags & tag) != 0

## Returns the localized display name for this tile.
func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(id)

## Returns whether the tile can be traversed through [param dir].
## Requires the Walkable tag; per-side rules further restrict individual directions.
func is_walkable_from(dir: int) -> bool:
	if not has_tag(TileTags.Tag.WALKABLE):
		return false
	if side_rules != null:
		return side_rules.is_passable(dir)
	return true

## Returns whether the tile blocks line of sight through [param dir].
func blocks_vision_from(dir: int) -> bool:
	if side_rules != null:
		return side_rules.does_block_vision(dir)
	return has_tag(TileTags.Tag.VISION_BLOCKER)

## Returns whether the tile grants cover toward [param dir].
func provides_cover_to(dir: int) -> bool:
	if side_rules != null:
		return side_rules.does_provide_cover(dir)
	return has_tag(TileTags.Tag.COVER)
