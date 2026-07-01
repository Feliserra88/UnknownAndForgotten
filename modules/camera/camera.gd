class_name CameraRig
extends Node2D
## Isometric camera rig: middle-mouse drag pan and Q/E rotation (see docs/GAME_DESIGN.md §2.2).
## Actors stay upright via WorldModule.sync_actor_display_rotations() (counter-rotation).

const _LOG := "CAM"

@export var mouse_pan_sensitivity: float = 1.0
@export var rotation_speed: float = 1.6

@onready var _camera: Camera2D = $Camera2D

var _world: WorldModule
var _view_rotation: float = 0.0

func _ready() -> void:
	mouse_pan_sensitivity = Config.get_float("CAMERA_MOUSE_PAN_SENSITIVITY", mouse_pan_sensitivity)
	_world = get_parent() as WorldModule
	if _camera != null:
		_camera.ignore_rotation = false
	_reset_map_layers_transform()
	_view_rotation = _resolve_default_rotation_rad()
	_apply_view_rotation()
	Log.info(_LOG, "init", "camera rig ready rotation_deg=%.2f" % rad_to_deg(_view_rotation))

## Current view rotation in radians (rig rotation).
func get_view_rotation_rad() -> float:
	return _view_rotation

## Rotation (radians) that aligns isometric diamond edges with the screen horizontal for the
## configured tile size. Use when CAMERA_DEFAULT_ROTATION_DEG is missing from venv.ini.
static func iso_edge_horizontal_rotation_rad(tile_width: int, tile_height: int) -> float:
	var tw := maxf(float(tile_width), 1.0)
	var th := maxf(float(tile_height), 1.0)
	return atan2(th * 0.5, tw * 0.5)

func _resolve_default_rotation_rad() -> float:
	if not Config.has("CAMERA_DEFAULT_ROTATION_DEG"):
		var tw := Config.get_int("WORLD_TILE_WIDTH", 64)
		var th := Config.get_int("WORLD_TILE_HEIGHT", 32)
		return iso_edge_horizontal_rotation_rad(tw, th)
	return deg_to_rad(Config.get_float("CAMERA_DEFAULT_ROTATION_DEG", 0.0))

func _process(delta: float) -> void:
	var changed := false
	if Input.is_key_pressed(KEY_Q):
		_view_rotation -= rotation_speed * delta
		changed = true
	if Input.is_key_pressed(KEY_E):
		_view_rotation += rotation_speed * delta
		changed = true
	if changed:
		_apply_view_rotation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			position -= motion.relative.rotated(_view_rotation) * mouse_pan_sensitivity
			get_viewport().set_input_as_handled()

## Centres the camera rig on [param world_pos].
func focus_on(world_pos: Vector2) -> void:
	position = world_pos

func _apply_view_rotation() -> void:
	rotation = _view_rotation
	if _world != null:
		_world.sync_actor_display_rotations()

func _reset_map_layers_transform() -> void:
	if _world == null:
		return
	var map_layers := _world.get_map_layers()
	if map_layers == null:
		return
	map_layers.position = Vector2.ZERO
	map_layers.rotation = 0.0
