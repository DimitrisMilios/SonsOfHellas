class_name BuildingSlotData
extends Resource

@export_group("Slot Identity")
@export var slot_index: int = 0
@export var building_data: BuildingData = null

@export_group("Construction Progress")
@export var is_under_construction: bool = false
@export_range(0, 20, 1) var remaining_construction_turns: int = 0
@export var target_building_to_construct: BuildingData = null

## Queues a building for construction in this slot.
func queue_construction(building: BuildingData) -> void:
	if building == null:
		return
	target_building_to_construct = building
	remaining_construction_turns = building.turns_to_build
	is_under_construction = true

## Advances construction by one turn. Returns true if construction just completed.
func advance_construction() -> bool:
	if not is_under_construction:
		return false
		
	remaining_construction_turns = maxi(0, remaining_construction_turns - 1)
	if remaining_construction_turns == 0:
		is_under_construction = false
		building_data = target_building_to_construct
		target_building_to_construct = null
		return true
		
	return false

## Cancels active construction in this slot.
func cancel_construction() -> void:
	is_under_construction = false
	remaining_construction_turns = 0
	target_building_to_construct = null

## Serializes slot to dictionary matching Settlement schema.
func to_dict() -> Dictionary:
	var bld_id: Variant = null
	if building_data != null:
		bld_id = building_data.building_id
	elif target_building_to_construct != null:
		bld_id = target_building_to_construct.building_id
		
	return {
		"slot_index": slot_index,
		"building_node_id": bld_id,
		"is_under_construction": is_under_construction,
		"remaining_construction_turns": remaining_construction_turns
	}

## Deserializes dictionary to BuildingSlotData.
static func from_dict(dict: Dictionary) -> BuildingSlotData:
	var slot: BuildingSlotData = BuildingSlotData.new()
	slot.slot_index = dict.get("slot_index", 0)
	slot.is_under_construction = dict.get("is_under_construction", false)
	slot.remaining_construction_turns = dict.get("remaining_construction_turns", 0)
	return slot
