@tool
@icon("res://ui/templates/icons/panel_ingame_status.svg")
class_name UfStatusPanel
extends UfPanelIngame
## In-game status panel: header chrome plus vital bars (see docs/GAME_DESIGN.md section 10.5).
## Presentational only — callers pass [NpcVitals] via [method set_vitals]; domain logic stays in modules.
##
## Rows are authored in [code]ui/templates/uf_panel_ingame_status.tscn[/code] as
## [code]VitalRow_{vital_id}[/code] with a child [code]Bar[/code] ([class UfProgressBar]).

const _ROW_PREFIX := "VitalRow_"
const _BAR_NAME := "Bar"
const _TEMP_MIN := 30.0
const _TEMP_MAX := 42.0

const _VITAL_IDS: Array[StringName] = [
	&"health",
	&"energy",
	&"mana",
	&"sanity",
	&"morale",
	&"hunger",
	&"thirst",
	&"fatigue",
	&"encumbrance",
	&"temperature",
]

const _LABEL_KEYS: Dictionary = {
	&"health": "gui.vital.health",
	&"energy": "gui.vital.energy",
	&"mana": "gui.vital.mana",
	&"sanity": "gui.vital.sanity",
	&"morale": "gui.vital.morale",
	&"hunger": "gui.vital.hunger",
	&"thirst": "gui.vital.thirst",
	&"fatigue": "gui.vital.fatigue",
	&"encumbrance": "gui.vital.encumbrance",
	&"temperature": "gui.vital.temperature",
}

var _bars: Dictionary = {}

func _ready() -> void:
	super._ready()
	_refresh_vital_labels()

func _ensure_structure() -> void:
	super._ensure_structure()
	_index_vital_bars()

## Updates one vital bar when present in the authored scene.
func set_vital(vital_id: StringName, current: float, maximum: float = -1.0) -> void:
	var bar := _bars.get(vital_id, null) as UfProgressBar
	if bar == null:
		return
	if vital_id == &"temperature":
		var span := _TEMP_MAX - _TEMP_MIN
		bar.set_ratio(clampf((current - _TEMP_MIN) / span, 0.0, 1.0) if span > 0.0 else 0.0)
		return
	var max_v := maximum if maximum > 0.0 else _default_max(vital_id)
	bar.set_ratio(clampf(current / max_v, 0.0, 1.0) if max_v > 0.0 else 0.0)

## Copies all known vitals from [param vitals] into the panel bars.
func set_vitals(vitals: NpcVitals, maximums: VitalsTemplate = null) -> void:
	if vitals == null:
		return
	for vital_id in _VITAL_IDS:
		set_vital(vital_id, _read_vital(vitals, vital_id), _max_from_template(vital_id, maximums))

## Returns vital ids that have a bar node in this panel instance.
func vital_ids() -> Array:
	return _bars.keys()

func _index_vital_bars() -> void:
	_bars.clear()
	var list := get_node_or_null("Layout/ContentSlot/VitalsList") as VBoxContainer
	if list == null:
		return
	for child in list.get_children():
		if not String(child.name).begins_with(_ROW_PREFIX):
			continue
		var vital_id := StringName(String(child.name).trim_prefix(_ROW_PREFIX))
		var bar := child.get_node_or_null(_BAR_NAME) as UfProgressBar
		if bar != null:
			_bars[vital_id] = bar

func _read_vital(vitals: NpcVitals, vital_id: StringName) -> float:
	match vital_id:
		&"health":
			return vitals.health
		&"energy":
			return vitals.energy
		&"mana":
			return vitals.mana
		&"sanity":
			return vitals.sanity
		&"morale":
			return vitals.morale
		&"hunger":
			return vitals.hunger
		&"thirst":
			return vitals.thirst
		&"fatigue":
			return vitals.fatigue
		&"encumbrance":
			return vitals.encumbrance
		&"temperature":
			return vitals.temperature
		_:
			return 0.0

func _max_from_template(vital_id: StringName, template: VitalsTemplate) -> float:
	if template == null:
		return _default_max(vital_id)
	match vital_id:
		&"health":
			return template.health
		&"energy":
			return template.energy
		&"mana":
			return template.mana
		&"sanity":
			return template.sanity
		&"morale":
			return template.morale
		&"hunger":
			return template.hunger
		&"thirst":
			return template.thirst
		&"fatigue":
			return template.fatigue
		&"encumbrance":
			return template.encumbrance
		&"temperature":
			return template.temperature
		_:
			return _default_max(vital_id)

func _default_max(vital_id: StringName) -> float:
	if vital_id == &"temperature":
		return _TEMP_MAX
	return 100.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_vital_labels()

func _refresh_vital_labels() -> void:
	var list := get_node_or_null("Layout/ContentSlot/VitalsList") as VBoxContainer
	if list == null:
		return
	for child in list.get_children():
		if not String(child.name).begins_with(_ROW_PREFIX):
			continue
		var vital_id := StringName(String(child.name).trim_prefix(_ROW_PREFIX))
		var label := child.get_node_or_null("Label") as Label
		if label == null:
			continue
		var key: String = _LABEL_KEYS.get(vital_id, "")
		label.text = tr(key) if not key.is_empty() else String(vital_id)
