@tool
class_name ItemDef
extends Resource
## Data-driven item definition (see docs/GAME_DESIGN.md section 7). Shared .tres under
## res://assets/data/items/; runtime variation lives in ItemInstance.

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var category_id: StringName = &""
@export var tags: Array[StringName] = []
@export var icon: Texture2D
@export var sprite_ref: ItemSpriteRef
@export var inventory_size: Vector2i = Vector2i(1, 1)
@export var weight: float = 0.0
@export var base_price: float = 0.0
@export var max_durability: float = 100.0
@export var state_tiers: Array[ItemStateTierDef] = []
@export var quality_tiers: Array[ItemQualityTierDef] = []
@export var allowed_archetype_tags: Array[StringName] = []
@export var category_data: Resource

## Returns whether this item can be equipped by an archetype exposing [param archetype_tags].
func allows_archetype(archetype_tags: Array) -> bool:
	if allowed_archetype_tags.is_empty():
		return true
	for tag in allowed_archetype_tags:
		if archetype_tags.has(tag):
			return true
	return false

## Returns the equipment slot when this item is wearable, or empty otherwise.
func get_equip_slot() -> StringName:
	if category_data is ArmorItemData:
		return (category_data as ArmorItemData).slot
	if category_data is WeaponItemData:
		return (category_data as WeaponItemData).slot
	return &""

## Returns true when this definition occupies an equipment slot.
func is_equipable() -> bool:
	return not String(get_equip_slot()).is_empty()

## Returns the optional ModifierDef id granted while this item is equipped.
func get_attribute_modifier_id() -> StringName:
	if category_data is ArmorItemData:
		return (category_data as ArmorItemData).attribute_modifier_id
	if category_data is WeaponItemData:
		return (category_data as WeaponItemData).attribute_modifier_id
	return &""

## Returns the EquipmentVisualDef when defined on category payload.
func get_visual() -> EquipmentVisualDef:
	if category_data is ArmorItemData:
		return (category_data as ArmorItemData).visual
	if category_data is WeaponItemData:
		return (category_data as WeaponItemData).visual
	return null

## Returns the state tier at [param index], or null when out of range.
func get_state_tier(index: int) -> ItemStateTierDef:
	if index < 0 or index >= state_tiers.size():
		return null
	return state_tiers[index]

## Returns the quality tier at [param index], or null when out of range.
func get_quality_tier(index: int) -> ItemQualityTierDef:
	if index < 0 or index >= quality_tiers.size():
		return null
	return quality_tiers[index]
