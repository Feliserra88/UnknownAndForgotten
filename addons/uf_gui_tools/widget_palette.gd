@tool
extends VBoxContainer
## Grid of draggable scene tiles for the UF GUI dock palette.

const _ItemScript := preload("res://addons/uf_gui_tools/palette_item.gd")

## Rebuilds the palette from [param entries] (label, path per item).
func set_entries(entries: Array, columns: int = 2) -> void:
	for child in get_children():
		child.queue_free()
	if entries.is_empty():
		return
	var grid := GridContainer.new()
	grid.columns = maxi(columns, 1)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	for entry in entries:
		var item := _ItemScript.new()
		item.setup(entry.get("label", ""), entry.get("path", ""))
		grid.add_child(item)
