class_name FactionModule
extends RefCounted
## Public facade for factions (see docs/GAME_DESIGN.md section 6). Loads FactionDef assets and
## exposes their granted modifiers and relations. Resource-only domain: callers use this facade,
## never FactionDef internals.

const _LOG := "FAC"
const DIR := "res://assets/data/factions"

## Returns the FactionDef for [param id] loaded from DIR, or null when missing.
func load_def(id: StringName) -> FactionDef:
	if String(id).is_empty():
		return null
	var path := "%s/%s.tres" % [DIR, id]
	if not ResourceLoader.exists(path):
		Log.warn(_LOG, "load_def: missing %s" % path)
		return null
	return load(path) as FactionDef

## Returns every FactionDef asset found in DIR.
func list_defs() -> Array[FactionDef]:
	var out: Array[FactionDef] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var def := load("%s/%s" % [DIR, file]) as FactionDef
		if def != null:
			out.append(def)
	return out

## Returns the modifier ids granted by every faction in [param faction_ids] (deduplicated).
func granted_modifier_ids(faction_ids: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for fid in faction_ids:
		var def := load_def(StringName(fid))
		if def == null:
			continue
		for mid in def.granted_modifier_ids:
			if not out.has(mid):
				out.append(mid)
	return out

## Returns the relation from faction [param a] toward faction [param b].
func relation(a: StringName, b: StringName) -> FactionDef.Relation:
	var def := load_def(a)
	return def.relation_to(b) if def != null else FactionDef.Relation.NEUTRAL
