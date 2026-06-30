class_name TileTags
extends RefCounted
## Non-exclusive tile type flags. A single tile may combine several of these.
## Bit order must match the @export_flags hints on TileDef and TileModifierDef.

enum Tag {
	GROUND = 1 << 0,
	WALKABLE = 1 << 1,
	WALL = 1 << 2,
	WATER = 1 << 3,
	HAZARD = 1 << 4,
	INTERACTABLE = 1 << 5,
	COVER = 1 << 6,
	VISION_BLOCKER = 1 << 7,
}

## Human-readable hint string shared by every @export_flags that uses tile tags.
const FLAG_HINT := "Ground,Walkable,Wall,Water,Hazard,Interactable,Cover,VisionBlocker"
