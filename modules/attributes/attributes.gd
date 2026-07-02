@tool
class_name AttributesModule
extends RefCounted
## Public facade for character stats lifecycle (see docs/ARCHITECTURE.md section 5). Centralizes
## how runtime attributes and vitals are derived from archetype templates so other modules do not
## depend on AttributeSet / NpcVitals internals. This is a Resource-only domain: no Node facade.

const ATTR_DEFAULT := AttributeSet.DEFAULT
const ATTR_MIN := AttributeSet.MIN
const ATTR_MAX := AttributeSet.MAX
const ATTR_NAMES: Array[String] = [
	"strength", "agility", "willpower", "vitality", "perception", "charisma",
]

## Clamps a single attribute value to the design range [ATTR_MIN, ATTR_MAX].
static func clamp_attribute(value: int) -> int:
	return clampi(value, ATTR_MIN, ATTR_MAX)

## Returns a mutable copy of [param base] with every attribute clamped to the design range.
static func clamp_attributes(base: AttributeSet) -> AttributeSet:
	var result := base.clone() if base != null else AttributeSet.new()
	for attr_name in ATTR_NAMES:
		result.set(attr_name, clamp_attribute(int(result.get(attr_name))))
	return result

## Returns a mutable copy of [param base] safe to store on a runtime instance (or a fresh set).
static func clone_attributes(base: AttributeSet) -> AttributeSet:
	return clamp_attributes(base.clone() if base != null else AttributeSet.new())

## Returns a runtime NpcVitals seeded from [param template] (or defaults when template is null).
static func spawn_vitals(template: VitalsTemplate) -> NpcVitals:
	return NpcVitals.from_template(template)
