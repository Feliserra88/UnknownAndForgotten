@tool
class_name StructureCatalog
extends Resource
## Catalog of modular structure pieces for a building kit (e.g. dark_medieval_wood).

@export var kit_id: StringName = &""
@export var display_name_key: String = ""
@export var pieces: Array[StructurePieceDef] = []

func get_piece(id: StringName) -> StructurePieceDef:
	for piece in pieces:
		if piece != null and piece.id == id:
			return piece
	return null

func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for piece in pieces:
		if piece != null and not piece.id.is_empty():
			out.append(piece.id)
	return out

func get_display_name() -> String:
	return tr(display_name_key) if not display_name_key.is_empty() else String(kit_id)
