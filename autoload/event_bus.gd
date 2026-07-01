extends Node
## Domain event bus for decoupled module communication (see docs/ARCHITECTURE.md section 6).
## Channels are the StringName constants in core/events.gd; payloads are documented Dictionaries.
## Backed by Godot user signals so listeners get native connect/disconnect semantics.

const _LOG := "EVT"

func _ready() -> void:
	for event in GameEvents.all():
		if not has_user_signal(event):
			add_user_signal(event, [{"name": "payload", "type": TYPE_DICTIONARY}])

## Publishes [param event] with [param payload] to every subscriber. Unknown events are
## registered on demand so ad-hoc channels still work, but prefer declaring them in GameEvents.
func publish(event: StringName, payload: Dictionary = {}) -> void:
	if not has_user_signal(event):
		add_user_signal(event, [{"name": "payload", "type": TYPE_DICTIONARY}])
	Log.info(_LOG, "publish", "%s (%d listeners)" % [event, get_signal_connection_list(event).size()])
	Log.detail(_LOG, "payload", "%s %s" % [event, payload])
	emit_signal(event, payload)

## Subscribes [param callable] to [param event]. The callable receives the payload Dictionary.
func subscribe(event: StringName, callable: Callable) -> void:
	if not has_user_signal(event):
		add_user_signal(event, [{"name": "payload", "type": TYPE_DICTIONARY}])
	if not is_connected(event, callable):
		connect(event, callable)

## Removes a previous [method subscribe] for [param event] / [param callable].
func unsubscribe(event: StringName, callable: Callable) -> void:
	if has_user_signal(event) and is_connected(event, callable):
		disconnect(event, callable)
