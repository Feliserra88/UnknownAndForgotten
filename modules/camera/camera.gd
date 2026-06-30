class_name CameraRig
extends Node2D
## Isometric camera rig: middle-mouse drag pan and Q/E rotation (see docs/GAME_DESIGN.md §2.2).
## Tilt/projection come from the TileSet, not the camera.

const _LOG := "CAM"

@export var mouse_pan_sensitivity: float = 1.0
@export var rotation_speed: float = 1.6

func _ready() -> void:
	mouse_pan_sensitivity = Config.get_float("CAMERA_MOUSE_PAN_SENSITIVITY", mouse_pan_sensitivity)
	Log.info(_LOG, "init", "camera rig ready")

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Q):
		rotation -= rotation_speed * delta
	if Input.is_key_pressed(KEY_E):
		rotation += rotation_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			position -= motion.relative.rotated(rotation) * mouse_pan_sensitivity
			get_viewport().set_input_as_handled()

## Centres the camera rig on [param world_pos].
func focus_on(world_pos: Vector2) -> void:
	position = world_pos
