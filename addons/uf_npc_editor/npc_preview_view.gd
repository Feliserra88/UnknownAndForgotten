@tool
extends VBoxContainer
## Reusable NPC rig preview: SubViewport canvas + rotate-left/right + walk/stop toggle.

signal orientation_changed(orientation: StringName)
signal moving_changed(moving: bool)

const _LAYOUT := preload("res://addons/uf_npc_editor/editor_layout.gd")

const VIEWPORT_SIZE := Vector2i(320, 320)
const PREVIEW_SCALE := 3.0
const FOOT_ANCHOR := Vector2(0.5, 0.62)
const BTN_H := 26
const ROTATE_BTN_W := 36
const WALK_BTN_W := 88

var _viewport: SubViewport
var _camera: Camera2D
var _appearance: NpcAppearanceController
var _rotate_left_btn: Button
var _rotate_right_btn: Button
var _walk_btn: Button
var _translate_fn: Callable = Callable()

var _orientation: StringName = &"front"
var _moving: bool = false

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_constant_override("separation", 6)

	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(240, 240)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(frame)

	var preview_svc := SubViewportContainer.new()
	preview_svc.stretch = true
	preview_svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(preview_svc)

	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	preview_svc.add_child(_viewport)

	_camera = Camera2D.new()
	_camera.name = "PreviewCamera"
	_viewport.add_child(_camera)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 6)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(controls)

	_rotate_left_btn = Button.new()
	_rotate_left_btn.custom_minimum_size = Vector2(ROTATE_BTN_W, BTN_H)
	_rotate_left_btn.focus_mode = Control.FOCUS_NONE
	_rotate_left_btn.pressed.connect(_on_rotate_left)
	controls.add_child(_rotate_left_btn)

	_rotate_right_btn = Button.new()
	_rotate_right_btn.custom_minimum_size = Vector2(ROTATE_BTN_W, BTN_H)
	_rotate_right_btn.focus_mode = Control.FOCUS_NONE
	_rotate_right_btn.pressed.connect(_on_rotate_right)
	controls.add_child(_rotate_right_btn)

	_walk_btn = Button.new()
	_walk_btn.custom_minimum_size = Vector2(WALK_BTN_W, BTN_H)
	_walk_btn.toggle_mode = true
	_walk_btn.focus_mode = Control.FOCUS_NONE
	_walk_btn.toggled.connect(_on_walk_toggled)
	controls.add_child(_walk_btn)

	_refresh_control_labels()

func set_translate_fn(fn: Callable) -> void:
	_translate_fn = fn
	_refresh_control_labels()

func get_orientation() -> StringName:
	return _orientation

func get_moving() -> bool:
	return _moving

func get_appearance() -> NpcAppearanceController:
	return _appearance

## Rebuilds the rig from [param archetype] and applies [param orientation] (resets walk to idle).
func rebuild(archetype: NpcArchetype, orientation: StringName = &"front") -> void:
	_orientation = orientation
	_set_moving(false, false)
	_clear_rig()
	if archetype == null:
		return
	_appearance = NpcAppearanceController.new()
	_viewport.add_child(_appearance)
	_center_rig()
	_appearance.build_from(archetype)
	_apply_facing()
	call_deferred("_center_rig")

## Syncs equipment layers from [param instance] (icons fallback via [param items]).
func sync_equipment(
	instance: NpcInstanceData,
	equipment: EquipmentModule,
	items: ItemsModule,
) -> void:
	if _appearance == null or instance == null:
		return
	for slot in instance.equipment.occupied_slots():
		var inst := instance.equipment.get_instance(slot)
		if inst == null:
			continue
		var visual := equipment.resolve_visual(inst.def_id)
		if visual != null:
			_appearance.apply_equipment(slot, visual)
			continue
		var icon_tex := items.resolve_icon(inst) if items != null else null
		if icon_tex != null:
			_appearance.set_equipment_texture(slot, icon_tex)
		else:
			_appearance.clear_equipment(slot)

func refresh_localized_controls() -> void:
	_refresh_control_labels()

func _on_rotate_left() -> void:
	_set_orientation(CutoutOrientation.rotate_facing(_orientation, -1))

func _on_rotate_right() -> void:
	_set_orientation(CutoutOrientation.rotate_facing(_orientation, 1))

func _on_walk_toggled(pressed: bool) -> void:
	_set_moving(pressed, true)

func _set_orientation(orientation: StringName) -> void:
	if _orientation == orientation:
		return
	_orientation = orientation
	_apply_facing()
	orientation_changed.emit(_orientation)

func _set_moving(moving: bool, emit_signal: bool) -> void:
	if _moving == moving and _walk_btn.button_pressed == moving:
		return
	_moving = moving
	_walk_btn.set_block_signals(true)
	_walk_btn.button_pressed = moving
	_walk_btn.set_block_signals(false)
	_refresh_walk_label()
	if _appearance != null:
		_appearance.set_moving(_moving)
	if emit_signal:
		moving_changed.emit(_moving)

func _apply_facing() -> void:
	if _appearance != null:
		_appearance.set_orientation(_orientation)

func _clear_rig() -> void:
	if _appearance != null and is_instance_valid(_appearance):
		_appearance.queue_free()
	_appearance = null
	for child in _viewport.get_children():
		if child != _camera:
			child.queue_free()

func _center_rig() -> void:
	if _appearance == null:
		return
	var vp := Vector2(VIEWPORT_SIZE)
	var anchor := Vector2(vp.x * FOOT_ANCHOR.x, vp.y * FOOT_ANCHOR.y)
	_appearance.position = anchor
	_appearance.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	if _camera != null:
		_camera.position = anchor
		_camera.reset_smoothing()

func _refresh_control_labels() -> void:
	var tr := _tr
	_rotate_left_btn.text = "←"
	_rotate_right_btn.text = "→"
	_rotate_left_btn.tooltip_text = tr.call("npc_editor.preview.rotate_left")
	_rotate_right_btn.tooltip_text = tr.call("npc_editor.preview.rotate_right")
	_refresh_walk_label()

func _refresh_walk_label() -> void:
	var tr := _tr
	if _moving:
		_walk_btn.text = tr.call("npc_editor.preview.stop")
		_walk_btn.tooltip_text = tr.call("npc_editor.preview.stop_hint")
	else:
		_walk_btn.text = tr.call("npc_editor.preview.walk")
		_walk_btn.tooltip_text = tr.call("npc_editor.preview.walk_hint")

func _tr(key: String) -> String:
	if _translate_fn.is_valid():
		return String(_translate_fn.call(key))
	return key
