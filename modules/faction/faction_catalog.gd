@tool
class_name FactionCatalog
extends Resource
## Ordered registry of faction definitions (see docs/GAME_DESIGN.md section 6).
## Single source of truth: editors and runtime list via FactionModule.list_catalog_defs().

const DEFAULT_PATH := "res://assets/data/factions/catalog.tres"

## res:// paths to FactionDef .tres files, in display order.
@export var entries: Array[String] = []

static func load_default() -> FactionCatalog:
	return load(DEFAULT_PATH) as FactionCatalog

## Loads every faction listed in [param catalog] (or the default catalog when null).
func load_factions(catalog: FactionCatalog = null) -> Array[FactionDef]:
	var source := catalog if catalog != null else self
	var out: Array[FactionDef] = []
	for path in source.entries:
		if path.is_empty():
			continue
		var def := load(path) as FactionDef
		if def != null:
			out.append(def)
	return out
