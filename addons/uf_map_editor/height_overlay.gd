class_name MapEditorHeightOverlay
extends RefCounted
## Editor-only drawing helpers for MapHeightField visualization in uf_map_editor.
## Uses the world module's ground TileMapLayer for isometric cell geometry.

## Fill tint for a surface height z (z=0 is a faint neutral wash).
static func color_for_z(z: int) -> Color:
	if z == 0:
		return Color(1.0, 1.0, 1.0, 0.06)
	if z > 0:
		return Color(0.25, 0.55, 1.0, clampf(0.18 + float(z) * 0.07, 0.18, 0.5))
	return Color(1.0, 0.4, 0.25, clampf(0.18 + float(abs(z)) * 0.07, 0.18, 0.5))

static func hover_outline_color() -> Color:
	return Color(1.0, 0.95, 0.35, 0.95)

static func label_color(z: int) -> Color:
	if z == 0:
		return Color(1.0, 1.0, 1.0, 0.45)
	if z > 0:
		return Color(0.85, 0.92, 1.0, 0.95)
	return Color(1.0, 0.88, 0.82, 0.95)

## Isometric diamond corners in ground-layer local space (DIAMOND_DOWN).
static func diamond_local_points(ground: TileMapLayer, cell: Vector2i) -> PackedVector2Array:
	var center := ground.map_to_local(cell)
	if ground.tile_set == null:
		return PackedVector2Array()
	var hw := float(ground.tile_set.tile_size.x) * 0.5
	var hh := float(ground.tile_set.tile_size.y) * 0.5
	return PackedVector2Array([
		center + Vector2(0.0, -hh),
		center + Vector2(hw, 0.0),
		center + Vector2(0.0, hh),
		center + Vector2(-hw, 0.0),
	])

static func diamond_canvas_points(ground: TileMapLayer, cell: Vector2i, canvas_xform: Transform2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in diamond_local_points(ground, cell):
		out.append(canvas_xform * ground.to_global(p))
	return out

static func cell_label_canvas_pos(ground: TileMapLayer, cell: Vector2i, canvas_xform: Transform2D) -> Vector2:
	var local := ground.map_to_local(cell)
	if ground.tile_set != null:
		local.y -= float(ground.tile_set.tile_size.y) * 0.12
	return canvas_xform * ground.to_global(local)

static func draw_field(
	overlay: Control,
	ground: TileMapLayer,
	height_field: MapHeightField,
	canvas_xform: Transform2D,
	hover_cell: Vector2i,
	show_zero_labels: bool,
) -> void:
	if ground == null or height_field == null:
		return
	var region := height_field.region
	var font: Font = ThemeDB.fallback_font
	var font_size := 11
	for y in region.size.y:
		for x in region.size.x:
			var cell := region.position + Vector2i(x, y)
			if ground.get_cell_source_id(cell) == -1:
				continue
			var z := height_field.get_height(cell)
			if z == 0 and not show_zero_labels:
				var poly0 := diamond_canvas_points(ground, cell, canvas_xform)
				if poly0.size() >= 3:
					overlay.draw_colored_polygon(poly0, color_for_z(0))
				continue
			var poly := diamond_canvas_points(ground, cell, canvas_xform)
			if poly.size() < 3:
				continue
			overlay.draw_colored_polygon(poly, color_for_z(z))
			if z != 0 or show_zero_labels:
				var label := str(z)
				var pos := cell_label_canvas_pos(ground, cell, canvas_xform)
				var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				pos.x -= text_size.x * 0.5
				pos.y += text_size.y * 0.35
				overlay.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color(z))
	if region.has_point(hover_cell) and ground.get_cell_source_id(hover_cell) != -1:
		var hover_poly := diamond_canvas_points(ground, hover_cell, canvas_xform)
		if hover_poly.size() >= 3:
			overlay.draw_polyline(hover_poly, hover_outline_color(), 2.0, true)
