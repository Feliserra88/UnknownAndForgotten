class_name MapEditorStructureOverlay
extends RefCounted
## Editor-only ghost preview for StructurePieceDef placement in uf_map_editor.

const _HeightOverlay := preload("res://addons/uf_map_editor/height_overlay.gd")

static func draw_preview(
	overlay: Control,
	ground: TileMapLayer,
	canvas_xform: Transform2D,
	cell: Vector2i,
	piece: StructurePieceDef,
) -> void:
	if overlay == null or ground == null or piece == null:
		return
	if cell.x < -900000:
		return
	for footprint_cell in piece.footprint_cells(cell):
		var pts := _HeightOverlay.diamond_canvas_points(ground, footprint_cell, canvas_xform)
		if pts.size() >= 3:
			overlay.draw_colored_polygon(pts, Color(0.55, 0.85, 1.0, 0.14))
			overlay.draw_polyline(pts, Color(0.55, 0.9, 1.0, 0.75), 2.0, true)
	if piece.sprite_texture == null:
		return
	var local_pos := ground.map_to_local(cell) + piece.local_offset
	var tex: Texture2D = piece.sprite_texture
	var size := tex.get_size()
	var offset := Vector2(
		0.0,
		-float(size.y) * 0.5 + float(piece.y_sort_origin),
	)
	var top_left := local_pos + offset - size * 0.5
	var canvas_top_left := canvas_xform * top_left
	var canvas_size := canvas_xform.basis_xform() * size
	overlay.draw_texture_rect(tex, Rect2(canvas_top_left, canvas_size), false, Color(1.0, 1.0, 1.0, 0.55))

static func draw_connect_hints(
	overlay: Control,
	ground: TileMapLayer,
	canvas_xform: Transform2D,
	cell: Vector2i,
	piece: StructurePieceDef,
) -> void:
	if piece == null or piece.connect_hints == 0:
		return
	var center := canvas_xform * ground.map_to_local(cell)
	var hw := 10.0
	if ground.tile_set != null:
		hw = float(ground.tile_set.tile_size.x) * 0.18
	var color := Color(1.0, 0.85, 0.35, 0.9)
	if piece.has_connect_hint(1):
		overlay.draw_line(center, center + Vector2(0.0, -hw * 2.0), color, 2.0)
	if piece.has_connect_hint(2):
		overlay.draw_line(center, center + Vector2(hw * 2.0, 0.0), color, 2.0)
	if piece.has_connect_hint(4):
		overlay.draw_line(center, center + Vector2(0.0, hw * 2.0), color, 2.0)
	if piece.has_connect_hint(8):
		overlay.draw_line(center, center + Vector2(-hw * 2.0, 0.0), color, 2.0)
