class_name CutoutOrientation
extends RefCounted
## Maps runtime 8-way facing ids to cutout rig views (4 directions + optional horizontal flip).

## Returns `{ "view": StringName, "flip_h": bool }` for a runtime [param orientation].
static func resolve(orientation: StringName) -> Dictionary:
	match orientation:
		&"front", &"front_right", &"front_left":
			return {"view": &"front", "flip_h": false}
		&"back", &"back_right", &"back_left":
			return {"view": &"back", "flip_h": false}
		&"side_right":
			return {"view": &"side_right", "flip_h": false}
		&"side_left":
			return {"view": &"side_left", "flip_h": true}
		_:
			return {"view": &"front", "flip_h": false}

## Returns the texture dictionary key for [param view] when [param flip_h] mirrors side_left.
static func texture_key(view: StringName, flip_h: bool) -> StringName:
	if flip_h and view == &"side_left":
		return &"side_right"
	return view

## Cutout views supported by PartVisualDef and EquipmentVisualDef.
static func all_views() -> Array[StringName]:
	return [&"front", &"back", &"side_right", &"side_left"]
