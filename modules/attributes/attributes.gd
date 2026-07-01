@tool
class_name AttributesModule
extends RefCounted
## Public facade for character stats lifecycle (see docs/ARCHITECTURE.md section 5). Centralizes
## how runtime attributes and vitals are derived from archetype templates so other modules do not
## depend on AttributeSet / NpcVitals internals. This is a Resource-only domain: no Node facade.

## Returns a mutable copy of [param base] safe to store on a runtime instance (or a fresh set).
static func clone_attributes(base: AttributeSet) -> AttributeSet:
	return base.clone() if base != null else AttributeSet.new()

## Returns a runtime NpcVitals seeded from [param template] (or defaults when template is null).
static func spawn_vitals(template: VitalsTemplate) -> NpcVitals:
	return NpcVitals.from_template(template)
