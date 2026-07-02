@tool
class_name NpcArchetypeCatalog
extends Resource
## Ordered registry of playable archetype definitions (see docs/GAME_DESIGN.md section 5.3).
## Single source of truth: editors and runtime list via NpcModule.list_catalog_archetypes().

const DEFAULT_PATH := "res://assets/data/archetypes/catalog.tres"

## res:// paths to NpcArchetype .tres files, in display order.
@export var entries: Array[String] = []

static func load_default() -> NpcArchetypeCatalog:
	return load(DEFAULT_PATH) as NpcArchetypeCatalog

## Loads every archetype listed in [param catalog] (or the default catalog when null).
func load_archetypes(catalog: NpcArchetypeCatalog = null) -> Array[NpcArchetype]:
	var source := catalog if catalog != null else self
	var out: Array[NpcArchetype] = []
	for path in source.entries:
		if path.is_empty():
			continue
		var archetype := load(path) as NpcArchetype
		if archetype != null:
			out.append(archetype)
	return out
