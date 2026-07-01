@tool
class_name MapSpriteCatalog
extends Resource
## Catalog of procedural map sprites (props and decorative overlays).

@export var props: Array[MapPropDef] = []
@export var decors: Array[MapDecorDef] = []

func get_prop(id: StringName) -> MapPropDef:
	for p in props:
		if p != null and p.id == id:
			return p
	return null

func get_decor(id: StringName) -> MapDecorDef:
	for d in decors:
		if d != null and d.id == id:
			return d
	return null
