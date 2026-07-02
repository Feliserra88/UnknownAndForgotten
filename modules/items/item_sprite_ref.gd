@tool
class_name ItemSpriteRef
extends Resource
## Points at a sprite asset or strip under res://assets/visuals/equipment/.

@export var library_path: String = ""
@export var strip_cell_size: Vector2i = Vector2i(64, 64)

## Returns true when [member library_path] points at an existing resource.
func is_valid() -> bool:
	return not library_path.is_empty() and ResourceLoader.exists(library_path)
