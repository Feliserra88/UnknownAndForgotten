class_name WorldGenModule
extends Node
## Public facade for procedural map generation. Orchestrates the TileMapLayer API through
## the WorldModule; never duplicates its cell storage (see docs/GAME_DESIGN.md section 4).

const _LOG := "WGN"
const _Field := preload("res://modules/world_gen/_private/field_biome.gd")
const _Generator := preload("res://modules/world_gen/_private/generator.gd")

## Builds the placeholder "field" tile catalog (grass, path, water, wall, bush, door).
func build_field_catalog() -> TileCatalog:
	return _Field.build_catalog()

## Builds the modifier definitions available in the field biome.
func build_field_modifiers() -> Array[TileModifierDef]:
	return _Field.build_modifiers()

## Builds the field biome definition.
func build_field_biome() -> BiomeDef:
	return _Field.build_biome()

## Builds a default generation request for the field biome over [param area] with [param gen_seed].
func build_field_request(area: Rect2i, gen_seed: int) -> WorldGenRequest:
	var request := WorldGenRequest.new()
	request.biome = build_field_biome()
	request.area = area
	request.gen_seed = gen_seed
	return request

## Generates the map described by [param request] into [param world]; returns a report dict.
func generate(request: WorldGenRequest, world: WorldModule) -> Dictionary:
	if request == null or request.biome == null:
		Log.warn(_LOG, "generate: missing request or biome")
		return {}
	return _Generator.generate(request, world)
