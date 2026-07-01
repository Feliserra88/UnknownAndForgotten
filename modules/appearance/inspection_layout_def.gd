class_name InspectionLayoutDef
extends Resource
## Layout for an NPC inspection panel: a background silhouette plus normalized rectangles where
## equipment slot squares are placed (see docs/GAME_DESIGN.md section 5.5). Consumed by the GUI
## UfInspectionPanel so the same panel serves any archetype (humanoid, beast, ...). Data only;
## no GUI logic. Saveable as a .tres asset under res://assets/visuals/parts/.

## Background image drawn behind the slot squares (e.g. a humanoid silhouette).
@export var background_texture: Texture2D
## Panel size hint in pixels for the background area.
@export var background_size: Vector2 = Vector2(220, 320)
## Slot placements: each entry is { "slot_id": StringName, "rect": Rect2 (normalized 0..1) }.
## Rect is expressed as a fraction of the background so it scales with the panel.
@export var slots: Array[Dictionary] = []

## Returns the normalized Rect2 for [param slot_id], or a zero rect when absent.
func rect_for(slot_id: StringName) -> Rect2:
	for entry in slots:
		if StringName(entry.get("slot_id", &"")) == slot_id:
			return entry.get("rect", Rect2())
	return Rect2()

## Returns the ordered slot ids declared by this layout.
func slot_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in slots:
		out.append(StringName(entry.get("slot_id", &"")))
	return out
