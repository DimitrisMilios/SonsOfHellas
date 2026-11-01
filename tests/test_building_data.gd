class_name TestBuildingData
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_building_defaults(failures)
	_test_building_unlock_requirements(failures)
	_test_building_slot_construction_lifecycle(failures)
	_test_building_serialization_round_trip(failures)
	return failures

static func _test_building_defaults(failures: Array[String]) -> void:
	var bld: BuildingData = BuildingData.new()
	if bld.building_id != "":
		failures.append("Expected default building_id to be empty, got: " + bld.building_id)
	if bld.upgrade_level != 1:
		failures.append("Expected default upgrade_level to be 1, got: " + str(bld.upgrade_level))
	if bld.negative_wealth_generation_penalty > 0.0:
		failures.append("Negative wealth penalty must be <= 0, got: " + str(bld.negative_wealth_generation_penalty))

static func _test_building_unlock_requirements(failures: Array[String]) -> void:
	var bld: BuildingData = BuildingData.new()
	bld.building_id = "bld_hoplite_barracks_tier3"
	bld.required_settlement_level = 3
	bld.required_resource_type = "IRON"
	
	# Fails when settlement level is too low
	if bld.is_unlocked(["IRON"], 2):
		failures.append("Building unlocked with insufficient settlement level")
		
	# Fails when missing strategic resource
	if bld.is_unlocked(["TIMBER"], 3):
		failures.append("Building unlocked without required strategic resource")
		
	# Passes when both are satisfied
	if not bld.is_unlocked(["IRON", "TIMBER"], 3):
		failures.append("Building failed to unlock when all requirements met")

static func _test_building_slot_construction_lifecycle(failures: Array[String]) -> void:
	var slot: BuildingSlotData = BuildingSlotData.new()
	slot.slot_index = 0
	
	var bld: BuildingData = BuildingData.new()
	bld.building_id = "bld_olive_grove"
	bld.turns_to_build = 2
	
	slot.queue_construction(bld)
	if not slot.is_under_construction:
		failures.append("Slot should be under construction after queueing")
	if slot.remaining_construction_turns != 2:
		failures.append("Expected 2 turns remaining, got: " + str(slot.remaining_construction_turns))
		
	# Advance 1 turn
	var finished_turn_1: bool = slot.advance_construction()
	if finished_turn_1:
		failures.append("Construction finished prematurely on turn 1")
	if slot.remaining_construction_turns != 1:
		failures.append("Expected 1 turn remaining, got: " + str(slot.remaining_construction_turns))
		
	# Advance 2nd turn -> completes
	var finished_turn_2: bool = slot.advance_construction()
	if not finished_turn_2:
		failures.append("Construction failed to complete on turn 2")
	if slot.is_under_construction:
		failures.append("Slot should no longer be under construction after completion")
	if slot.building_data != bld:
		failures.append("Slot building_data does not match completed building")

static func _test_building_serialization_round_trip(failures: Array[String]) -> void:
	var bld: BuildingData = BuildingData.new()
	bld.building_id = "bld_rice_exchange"
	bld.display_name = "Rice Exchange"
	bld.branch_type = BuildingData.BranchType.INDUSTRY_WEAVING
	bld.upgrade_level = 2
	bld.construction_cost = 850
	bld.turns_to_build = 3
	bld.base_wealth = 200.0
	bld.positive_wealth_generation = 5.0
	bld.negative_wealth_generation_penalty = -1.0
	bld.tax_modifier_bonus = 0.03
	bld.food_production_delta = -1
	bld.required_settlement_level = 2
	bld.required_resource_type = "NONE"
	
	var dict: Dictionary = bld.to_dict()
	var restored: BuildingData = BuildingData.from_dict(dict)
	
	if restored == null:
		failures.append("from_dict returned null")
		return
	if restored.building_id != bld.building_id:
		failures.append("Restored building_id mismatch: " + restored.building_id)
	if restored.branch_type != bld.branch_type:
		failures.append("Restored branch_type mismatch")
	if absf(restored.positive_wealth_generation - bld.positive_wealth_generation) > 0.001:
		failures.append("Restored PWG mismatch")
	if restored.food_production_delta != bld.food_production_delta:
		failures.append("Restored food_production_delta mismatch")
