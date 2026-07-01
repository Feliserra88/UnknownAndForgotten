class_name ModifierModule
extends RefCounted
## Public facade for stat/behaviour overlays (see docs/GAME_DESIGN.md section 8). Loads ModifierDef
## assets from disk and resolves their combined effect on an AttributeSet. Resource-only domain:
## other modules depend on this facade, never on ModifierDef internals directly.

const _LOG := "MOD"
const DIR := "res://assets/data/modifiers"

## Returns the ModifierDef for [param id] loaded from DIR, or null when missing.
func load_def(id: StringName) -> ModifierDef:
	if String(id).is_empty():
		return null
	var path := "%s/%s.tres" % [DIR, id]
	if not ResourceLoader.exists(path):
		Log.warn(_LOG, "load_def: missing %s" % path)
		return null
	return load(path) as ModifierDef

## Returns every ModifierDef asset found in DIR.
func list_defs() -> Array[ModifierDef]:
	var out: Array[ModifierDef] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var def := load("%s/%s" % [DIR, file]) as ModifierDef
		if def != null:
			out.append(def)
	return out

## Returns the ModifierDefs whose kind matches [param kind].
func list_by_kind(kind: ModifierDef.Kind) -> Array[ModifierDef]:
	var out: Array[ModifierDef] = []
	for def in list_defs():
		if def.kind == kind:
			out.append(def)
	return out

## Resolves [param ids] to ModifierDefs via [method load_def], dropping unknown ids.
func resolve(ids: Array) -> Array[ModifierDef]:
	var out: Array[ModifierDef] = []
	for id in ids:
		var def := load_def(StringName(id))
		if def != null:
			out.append(def)
	return out

## Returns a new AttributeSet = [param base] with every def in [param defs] applied
## (all additives first, then all multipliers). Base is left untouched.
func apply(base: AttributeSet, defs: Array) -> AttributeSet:
	var result: AttributeSet = base.clone() if base != null else AttributeSet.new()
	for def in defs:
		if def == null:
			continue
		for key in def.additive:
			result.set(key, int(result.get(key)) + int(def.additive[key]))
	for def in defs:
		if def == null:
			continue
		for key in def.multiplicative:
			var scaled := float(result.get(key)) * (1.0 + float(def.multiplicative[key]))
			result.set(key, int(round(scaled)))
	return result
