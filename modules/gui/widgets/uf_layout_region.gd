@tool
@icon("res://ui/widgets/icons/layout_region.svg")
class_name UfLayoutRegion
extends Control
## Free-layout zone inside a flow-based ContentSlot (VBoxContainer). Place as a child of ContentSlot
## when you need anchor-based positioning: widgets dropped inside use the 2D editor to move and resize
## with the mouse. Moving this region (or its parent panel) keeps child offsets relative to the region.

@export var region_min_size: Vector2 = Vector2(240, 160):
	set(value):
		region_min_size = value.max(Vector2(16, 16))
		_sync_min_size()

func _enter_tree() -> void:
	_sync_min_size()
	if Engine.is_editor_hint() and not resized.is_connected(_on_resized):
		resized.connect(_on_resized)

func _sync_min_size() -> void:
	custom_minimum_size = region_min_size

func _on_resized() -> void:
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(Vector2.ONE, size - Vector2(2, 2))
	draw_rect(rect, Color(0.35, 0.55, 0.85, 0.12), true)
	draw_rect(rect, Color(0.45, 0.65, 0.95, 0.55), false, 1.0)
