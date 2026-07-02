@tool
class_name InspectionLayoutDef
extends Resource
## Links an NPC archetype to its artist-authored equipment panel scene (see docs/GAME_DESIGN.md §5.5.5).
## Runtime loads [member panel_path] only; optional fields below are authoring reference, not fallbacks.

## Background silhouette reference for artists (not used at runtime).
@export var background_texture: Texture2D
## Panel size hint in pixels for the background area (authoring reference).
@export var background_size: Vector2 = Vector2(240, 300)
## Required artist panel under res://ui/panels/equipment/. GuiModule instantiates this scene.
@export_file("*.tscn") var panel_path: String = ""
## Slot placements for authoring: { "slot_id": StringName, "rect": Rect2 (normalized 0..1) }.
## Not used at runtime; slots live in the panel [code].tscn[/code].
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
