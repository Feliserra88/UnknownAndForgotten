@tool
class_name FactionModule
extends RefCounted
## Public facade for factions (see docs/GAME_DESIGN.md section 6). Loads FactionDef assets and
## exposes their granted modifiers and relations. Resource-only domain: callers use this facade,
## never FactionDef internals.

const _LOG := "FAC"
const DIR := "res://assets/data/factions"
const _Catalog := preload("res://modules/faction/faction_catalog.gd")

## Returns factions from the project catalog (assets/data/factions/catalog.tres).
func list_catalog_defs() -> Array[FactionDef]:
	var catalog: FactionCatalog = _Catalog.load_default()
	if catalog == null:
		Log.warn(_LOG, "list_catalog_defs: missing catalog")
		return []
	return catalog.load_factions()

## Returns the FactionDef for [param id] from the catalog, or null when missing.
func load_def(id: StringName) -> FactionDef:
	if String(id).is_empty():
		return null
	for def in list_catalog_defs():
		if def.id == id:
			return def
	var path := "%s/%s.tres" % [DIR, id]
	if ResourceLoader.exists(path):
		return load(path) as FactionDef
	Log.warn(_LOG, "load_def: missing %s" % id)
	return null

## Returns every FactionDef asset found in DIR.
func list_defs() -> Array[FactionDef]:
	var out: Array[FactionDef] = []
	var dir := _open_dir(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var def := load("%s/%s" % [DIR, file]) as FactionDef
		if def != null:
			out.append(def)
	return out

func _open_dir(dir_path: String) -> DirAccess:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		dir = DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		Log.warn(_LOG, "cannot open dir %s" % dir_path)
	return dir

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
