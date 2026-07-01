class_name GameEvents
extends RefCounted
## Central catalog of domain event channels published through the EventBus autoload.
## Emitters and subscribers share these StringName constants so modules stay decoupled
## (see docs/ARCHITECTURE.md section 6). Payloads are Dictionaries with the keys documented below.

## World map finished procedural generation.
## Payload: { region: Rect2i, seed: int }
const WORLD_GENERATED := &"world.generated"

## An NPC body was spawned and initialized.
## Payload: { uid: int, archetype_id: StringName, cell: Vector3i }
const NPC_SPAWNED := &"npc.spawned"

## Returns every registered event channel; used by EventBus to pre-declare its signals.
static func all() -> Array[StringName]:
	return [
		WORLD_GENERATED,
		NPC_SPAWNED,
	]
