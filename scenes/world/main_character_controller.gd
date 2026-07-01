extends Node
## Demo controller: grid-step movement (4-dir) with walk/idle animation and orientation flip.
## Parent must be an NpcBody under a WorldModule.

const _LOG := "NPC"

var _body: NpcBody
var _world: WorldModule
var _appearance: NpcAppearanceController
var _is_stepping: bool = false
var _repeat_delay: float = 0.0
var _step_duration: float = 0.15
var _repeat_interval: float = 0.18
var _ready_ok: bool = false

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	_body = get_parent() as NpcBody
	if _body == null:
		Log.warn(_LOG, "main_character_controller: parent is not NpcBody")
		return
	_world = _find_world_module(_body)
	if _world == null:
		Log.warn(_LOG, "main_character_controller: no WorldModule ancestor")
		return
	_appearance = _body.get_node_or_null("Appearance") as NpcAppearanceController
	_step_duration = Config.get_float("NPC_STEP_DURATION", _step_duration)
	_repeat_interval = Config.get_float("NPC_STEP_REPEAT", _repeat_interval)
	_ready_ok = true
	_snap_to_cell()

func _process(delta: float) -> void:
	if not _ready_ok or _body == null or _world == null:
		return
	if _is_stepping:
		return
	if _repeat_delay > 0.0:
		_repeat_delay -= delta
	var dir := _read_grid_direction()
	if dir == -1:
		if _appearance != null:
			_appearance.set_moving(false)
		return
	if _repeat_delay > 0.0:
		return
	_try_step(dir)

func _try_step(dir: int) -> void:
	if _body.instance == null:
		return
	var from := _body.instance.grid_cell
	if not _world.can_move(from, dir):
		return
	var offset := Direction.to_vector(dir)
	var target_xy := Vector2i(from.x, from.y) + offset
	var target := Vector3i(target_xy.x, target_xy.y, _world.cell_height(target_xy))
	_is_stepping = true
	_repeat_delay = _repeat_interval
	_set_orientation_for_direction(dir)
	if _appearance != null:
		_appearance.set_moving(true)
	var tween := create_tween()
	tween.tween_property(_body, "global_position", _world.grid_to_world(target), _step_duration)
	tween.finished.connect(func() -> void:
		_body.instance.grid_cell = target
		_is_stepping = false
		if _appearance != null:
			_appearance.set_moving(false)
		_snap_to_cell()
	)

func _read_grid_direction() -> int:
	if Input.is_action_pressed(&"move_up"):
		return Direction.Dir.N
	if Input.is_action_pressed(&"move_down"):
		return Direction.Dir.S
	if Input.is_action_pressed(&"move_left"):
		return Direction.Dir.W
	if Input.is_action_pressed(&"move_right"):
		return Direction.Dir.E
	return -1

func _set_orientation_for_direction(dir: int) -> void:
	var orientation: StringName
	match dir:
		Direction.Dir.E:
			orientation = &"side_right"
		Direction.Dir.W:
			orientation = &"side_left"
		Direction.Dir.N:
			orientation = &"back"
		Direction.Dir.S:
			orientation = &"front"
		_:
			orientation = &"front"
	if _appearance != null:
		_appearance.set_orientation(orientation)
	if _body.instance != null:
		_body.instance.orientation = orientation

func _snap_to_cell() -> void:
	if _body == null or _world == null or _body.instance == null:
		return
	_body.global_position = _world.grid_to_world(_body.instance.grid_cell)
	_world.sync_actor_display_rotations()

func _find_world_module(from: Node) -> WorldModule:
	var node: Node = from
	while node != null:
		if node is WorldModule:
			return node as WorldModule
		node = node.get_parent()
	return null
