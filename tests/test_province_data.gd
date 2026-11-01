class_name TestProvinceData
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_settlement_level_slot_capacity(failures)
	_test_tax_level_clamping(failures)
	_test_garrison_management(failures)
	_test_consecutive_unrest_tracking(failures)
	_test_province_serialization_round_trip(failures)
	return failures

static func _test_settlement_level_slot_capacity(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	prov.set_settlement_level(1)
	if prov.building_slots.size() != 1:
		failures.append("Level 1 settlement should have exactly 1 slot, got: " + str(prov.building_slots.size()))
		
	prov.set_settlement_level(3)
	if prov.building_slots.size() != 3:
		failures.append("Level 3 settlement should have exactly 3 slots, got: " + str(prov.building_slots.size()))
		
	# Fill all 3 slots
	for i: int in range(3):
		var bld: BuildingData = BuildingData.new()
		bld.building_id = "bld_" + str(i)
		prov.building_slots[i].building_data = bld
		
	if prov.can_add_building():
		failures.append("can_add_building() should be false when all 3 slots are occupied")
		
	# Attempting to add 4th building must fail
	var extra_bld: BuildingData = BuildingData.new()
	extra_bld.building_id = "extra_bld"
	var added: bool = prov.add_building(extra_bld)
	if added:
		failures.append("add_building() allowed adding beyond max capacity")

static func _test_tax_level_clamping(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	prov.set_tax_levels(0, 10)
	if prov.tax_level_upper != 1:
		failures.append("Expected tax_level_upper to clamp to 1, got: " + str(prov.tax_level_upper))
	if prov.tax_level_lower != 5:
		failures.append("Expected tax_level_lower to clamp to 5, got: " + str(prov.tax_level_lower))

static func _test_garrison_management(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	var unit: UnitData = UnitData.new()
	unit.unit_id = "garrison_hoplite"
	unit.is_building_garrison = true
	
	prov.add_garrison_unit(unit)
	if prov.garrison_units.size() != 1:
		failures.append("Expected 1 garrison unit, got: " + str(prov.garrison_units.size()))
	if not prov.garrison_units[0].is_building_garrison:
		failures.append("Expected garrison unit flag to be preserved")

static func _test_consecutive_unrest_tracking(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	prov.public_order = -15.0
	prov.update_unrest_counter()
	if prov.consecutive_unrest_turns != 1:
		failures.append("Expected consecutive_unrest_turns to be 1 after negative PO, got: " + str(prov.consecutive_unrest_turns))
		
	prov.update_unrest_counter()
	if prov.consecutive_unrest_turns != 2:
		failures.append("Expected consecutive_unrest_turns to be 2 after second negative PO, got: " + str(prov.consecutive_unrest_turns))
		
	# Positive PO resets counter
	prov.public_order = 10.0
	prov.update_unrest_counter()
	if prov.consecutive_unrest_turns != 0:
		failures.append("Expected consecutive_unrest_turns to reset to 0 after positive PO, got: " + str(prov.consecutive_unrest_turns))

static func _test_province_serialization_round_trip(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = "set_sparta"
	prov.province_name = "Sparta"
	prov.owner_faction_id = "faction_sparta"
	prov.map_position = Vector2(400.0, 300.0)
	prov.set_settlement_level(2)
	prov.region_wealth = 3200.0
	prov.public_order = 45.0
	prov.consecutive_unrest_turns = 0
	prov.tax_level_upper = 2
	prov.tax_level_lower = 3
	prov.tax_exemption_status = false
	prov.population_surplus = 120
	prov.adjacent_province_ids = ["set_corinth", "set_athens"]
	
	var bld: BuildingData = BuildingData.new()
	bld.building_id = "bld_spartan_barracks"
	prov.building_slots[0].building_data = bld
	
	var garrison: UnitData = UnitData.new()
	garrison.unit_id = "unit_spartan_youth"
	prov.add_garrison_unit(garrison)
	
	var dict: Dictionary = prov.to_dict()
	var restored: ProvinceData = ProvinceData.from_dict(dict)
	
	if restored == null:
		failures.append("from_dict returned null")
		return
	if restored.province_id != prov.province_id:
		failures.append("Restored province_id mismatch")
	if restored.settlement_level != 2:
		failures.append("Restored settlement_level mismatch")
	if restored.building_slots.size() != 2:
		failures.append("Restored building_slots size mismatch")
	if restored.building_slots[0].building_data == null or restored.building_slots[0].building_data.building_id != "bld_spartan_barracks":
		failures.append("Restored slot building_data mismatch")
	if absf(restored.region_wealth - 3200.0) > 0.1:
		failures.append("Restored region_wealth mismatch")
	if restored.adjacent_province_ids != prov.adjacent_province_ids:
		failures.append("Restored adjacent_province_ids mismatch")
