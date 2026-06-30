class_name NpcBody
extends Node2D
## Presentation root of an NPC scene. Receives a runtime NpcInstanceData and drives the
## appearance controller. Logic lives in modules; this node only wires data to visuals.

const _LOG := "NPC"

var instance: NpcInstanceData

var _pending_archetype: NpcArchetype

## Binds [param p_instance] and [param archetype] and builds the rig (deferred until in tree).
func initialize(p_instance: NpcInstanceData, archetype: NpcArchetype) -> void:
	instance = p_instance
	_pending_archetype = archetype
	if is_node_ready():
		_apply()

func _ready() -> void:
	if _pending_archetype != null:
		_apply()

func _apply() -> void:
	var appearance := get_node_or_null("Appearance") as NpcAppearanceController
	if appearance == null:
		Log.warn(_LOG, "npc_body missing Appearance controller")
		return
	appearance.build_from(_pending_archetype)
	appearance.sync_from_instance(instance)
	Log.info(_LOG, "spawn", "uid=%d archetype=%s cell=%s" % [instance.uid, instance.archetype_id, instance.grid_cell])
	_pending_archetype = null
