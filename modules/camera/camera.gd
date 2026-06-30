class_name CameraRig
extends Node2D
## Isometric camera rig: pans and rotates over the 2D plane with fixed zoom and tilt
## (see docs/GAME_DESIGN.md section 2.2). Tilt/projection come from the TileSet, not the camera.

const _LOG := "CAM"

@export var pan_speed: float = 420.0
@export var rotation_speed: float = 1.6

func _ready() -> void:
	Log.info(_LOG, "init", "camera rig ready")

func _process(delta: float) -> void:
	var move := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if move != Vector2.ZERO:
		position += move.rotated(rotation) * pan_speed * delta
	if Input.is_key_pressed(KEY_Q):
		rotation -= rotation_speed * delta
	if Input.is_key_pressed(KEY_E):
		rotation += rotation_speed * delta

## Centres the camera rig on [param world_pos].
func focus_on(world_pos: Vector2) -> void:
	position = world_pos
