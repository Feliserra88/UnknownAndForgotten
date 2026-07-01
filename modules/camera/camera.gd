class_name CameraRig
extends Node2D
## Isometric camera rig: middle-mouse drag pan only (see docs/GAME_DESIGN.md §2.2).
## View rotation is fixed at 0° to match the 2D tile editor and DIAMOND_DOWN TileSet.

const _LOG := "CAM"

@export var mouse_pan_sensitivity: float = 1.0

@onready var _camera: Camera2D = $Camera2D

var _world: WorldModule

func _ready() -> void:
	mouse_pan_sensitivity = Config.get_float("CAMERA_MOUSE_PAN_SENSITIVITY", mouse_pan_sensitivity)
	_world = get_parent() as WorldModule
	if _camera != null:
		_camera.ignore_rotation = true
	_reset_map_layers_transform()
	rotation = 0.0
	if _world != null:
		_world.sync_actor_display_rotations()
	Log.info(_LOG, "init", "camera rig ready (fixed view, pan only)")

## Always 0 — kept for WorldModule actor upright sync API.
func get_view_rotation_rad() -> float:
	return 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			position -= motion.relative * mouse_pan_sensitivity
			get_viewport().set_input_as_handled()

## Centres the camera rig on [param world_pos].
func focus_on(world_pos: Vector2) -> void:
	position = world_pos

func _reset_map_layers_transform() -> void:
	if _world == null:
		return
	var map_layers := _world.get_map_layers()
	if map_layers == null:
		return
	map_layers.position = Vector2.ZERO
	map_layers.rotation = 0.0
