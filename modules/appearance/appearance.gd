class_name AppearanceModule
extends RefCounted
## Public facade for the NPC visual rig (see docs/ARCHITECTURE.md section 5). Encapsulates locating
## and driving the NpcAppearanceController so callers never traverse the "MotionPivot/Appearance"
## node path themselves, keeping the appearance rig an implementation detail.

## Relative path of the appearance controller inside an NPC body scene.
const CONTROLLER_PATH := "MotionPivot/Appearance"

## Returns the NpcAppearanceController under [param body], or null when absent.
static func find_controller(body: Node) -> NpcAppearanceController:
	if body == null:
		return null
	return body.get_node_or_null(CONTROLLER_PATH) as NpcAppearanceController

## Rebuilds the rig on [param body] from [param archetype]. Returns false when the rig is missing.
static func build_rig(body: Node, archetype: NpcArchetype) -> bool:
	var controller := find_controller(body)
	if controller == null:
		return false
	controller.build_from(archetype)
	return true

## Sets the facing [param orientation] on [param body]'s rig when present.
static func set_orientation(body: Node, orientation: StringName) -> void:
	var controller := find_controller(body)
	if controller != null:
		controller.set_orientation(orientation)

## Toggles walk/idle animation on [param body]'s rig when present.
static func set_moving(body: Node, moving: bool) -> void:
	var controller := find_controller(body)
	if controller != null:
		controller.set_moving(moving)
