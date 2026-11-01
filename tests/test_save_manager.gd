class_name TestSaveManager
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	
	test_full_model_round_trip(failures)
	test_two_phase_validation_rejection(failures)
	test_atomic_write_and_backup_rotation(failures)
	test_corrupt_json_backup_fallback(failures)
	test_future_version_rejection(failures)
	
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func _create_save_mgr() -> Node:
	var script: Script = load("res://scripts/core/SaveManager.gd")
	var mgr: Node = Node.new()
	mgr.set_script(script)
	return mgr

static func test_full_model_round_trip(failures: Array[String]) -> void:
	var mgr: Node = _create_save_mgr()
	
	# 1. Setup rich Faction
	var fac: FactionData = FactionData.new()
	fac.faction_id = "sparta"
	fac.faction_name = "Sparta"
	fac.treasury = 4500
	fac.food_balance = 8
	fac.is_player = true
	fac.is_bankrupt = false
	
	# 2. Setup rich Province
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = "prov_sparta"
	prov.province_name = "Sparta"
	prov.owner_faction_id = "sparta"
	prov.settlement_level = 2
	prov.region_wealth = 1850.0
	prov.public_order = 42.0
	prov.unrest_pressure = 1
	prov.rebellion_cooldown = 1
	prov.tax_level_upper = 4
	prov.tax_level_lower = 2
	
	var slot0: BuildingSlotData = prov.building_slots[0]
	var bld_done: BuildingData = BuildingData.new()
	bld_done.building_id = "bld_palace_1"
	bld_done.display_name = "Civic Palace"
	slot0.building_data = bld_done
	
	var slot1: BuildingSlotData = prov.building_slots[1]
	var bld_queue: BuildingData = BuildingData.new()
	bld_queue.building_id = "bld_barracks_2"
	bld_queue.display_name = "Heavy Barracks"
	bld_queue.turns_to_build = 3
	slot1.queue_construction(bld_queue)
	
	var g_unit: UnitData = UnitData.new()
	g_unit.unit_id = "spartan_garrison"
	g_unit.unit_count = 120
	g_unit.veterancy_rank = 2
	prov.add_garrison_unit(g_unit)
	
	# 3. Setup rich Army
	var army: ArmyData = ArmyData.new()
	army.army_id = "army_leonidas"
	army.army_name = "Royal Guard"
	army.owner_faction_id = "sparta"
	army.current_province_id = "prov_sparta"
	army.stance = ArmyData.Stance.RAIDING
	army.current_action_points = 55.0
	army.max_action_points = 100.0
	army.has_retreated_this_turn = false
	
	var unit: UnitData = UnitData.new()
	unit.unit_id = "spartan_royal_hoplites"
	unit.display_name = "Royal Hoplites"
	unit.tier = 3
	unit.unit_count = 115
	unit.veterancy_rank = 4
	unit.turn_upkeep = 120
	army.add_unit(unit)
	
	# Serialize
	var factions_list: Array[FactionData] = [fac]
	var provinces_map: Dictionary = {"prov_sparta": prov}
	var armies_list: Array[ArmyData] = [army]
	
	var envelope: Dictionary = mgr.serialize_campaign(factions_list, provinces_map, armies_list, 7, 9999)
	_assert(envelope["save_version"] == 2, "Save version must be 2", failures)
	_assert(envelope.has("payload"), "Envelope must contain payload", failures)
	
	# Deserialize
	var restore: Dictionary = mgr.deserialize_campaign(envelope["payload"])
	_assert(restore["valid"], "Deserialization should be valid", failures)
	
	# Verify Faction
	var d_fac: FactionData = restore["factions"][0]
	_assert(d_fac.faction_id == "sparta", "Restored faction ID must match", failures)
	_assert(d_fac.treasury == 4500, "Restored treasury must match", failures)
	_assert(d_fac.food_balance == 8, "Restored food balance must match", failures)
	
	# Verify Province
	var d_prov: ProvinceData = restore["provinces"]["prov_sparta"]
	_assert(d_prov.region_wealth == 1850.0, "Restored wealth must match", failures)
	_assert(d_prov.unrest_pressure == 1, "Restored unrest pressure must match", failures)
	_assert(d_prov.rebellion_cooldown == 1, "Restored rebellion cooldown must match", failures)
	_assert(d_prov.tax_level_upper == 4, "Restored upper tax must match", failures)
	_assert(d_prov.building_slots[0].building_data != null, "Slot 0 building must be restored", failures)
	_assert(d_prov.building_slots[1].is_under_construction, "Slot 1 construction state must be restored", failures)
	_assert(d_prov.building_slots[1].target_building_to_construct != null, "Slot 1 target building must be restored", failures)
	_assert(d_prov.garrison_units.size() == 1, "Garrison must be restored", failures)
	_assert(d_prov.garrison_units[0].unit_count == 120, "Garrison model count must match", failures)
	
	# Verify Army
	var d_army: ArmyData = restore["armies"][0]
	_assert(d_army.stance == ArmyData.Stance.RAIDING, "Restored stance must be RAIDING", failures)
	_assert(d_army.current_action_points == 55.0, "Restored AP must match 55.0", failures)
	_assert(d_army.units.size() == 1, "Army units must be restored", failures)
	_assert(d_army.units[0].unit_count == 115, "Unit count must match 115", failures)
	_assert(d_army.units[0].veterancy_rank == 4, "Veterancy rank must match 4", failures)
	
	mgr.free()

static func test_two_phase_validation_rejection(failures: Array[String]) -> void:
	var mgr: Node = _create_save_mgr()
	
	# Payload where army references a nonexistent province
	var bad_payload: Dictionary = {
		"current_turn": 1,
		"factions": [{
			"faction_id": "sparta",
			"treasury": 1000
		}],
		"provinces": [{
			"id": "prov_sparta",
			"province_id": "prov_sparta",
			"owner_faction_id": "sparta"
		}],
		"armies": [{
			"army_id": "ghost_army",
			"owner_faction_id": "sparta",
			"current_province_id": "prov_nonexistent",
			"stance": "NORMAL",
			"units": []
		}]
	}
	
	var res: Dictionary = mgr.deserialize_campaign(bad_payload)
	_assert(not res["valid"], "Deserialization should fail when army references nonexistent province", failures)
	mgr.free()

static func test_atomic_write_and_backup_rotation(failures: Array[String]) -> void:
	var mgr: Node = _create_save_mgr()
	var test_slot: String = "test_atomic_rotation"
	
	var fac: FactionData = FactionData.new()
	fac.faction_id = "athens"
	fac.treasury = 2000
	
	var env1: Dictionary = mgr.serialize_campaign([fac], {}, [], 1)
	var ok1: bool = mgr.write_save_atomic(test_slot, env1)
	_assert(ok1, "First atomic save should succeed", failures)
	_assert(mgr.has_save_file(test_slot), "Primary save file should exist", failures)
	
	# Second write should rotate existing save to .bak
	var env2: Dictionary = mgr.serialize_campaign([fac], {}, [], 2)
	var ok2: bool = mgr.write_save_atomic(test_slot, env2)
	_assert(ok2, "Second atomic save should succeed", failures)
	
	var bak_path: String = mgr.get_save_backup_path(test_slot)
	_assert(FileAccess.file_exists(bak_path), "Backup .bak file should exist after rotation", failures)
	
	mgr.free()

static func test_corrupt_json_backup_fallback(failures: Array[String]) -> void:
	var mgr: Node = _create_save_mgr()
	var test_slot: String = "test_corrupt_fallback"
	
	var fac: FactionData = FactionData.new()
	fac.faction_id = "thebes"
	fac.treasury = 3000
	
	# Save twice to create .bak
	var env1: Dictionary = mgr.serialize_campaign([fac], {}, [], 1)
	mgr.write_save_atomic(test_slot, env1)
	var env2: Dictionary = mgr.serialize_campaign([fac], {}, [], 2)
	mgr.write_save_atomic(test_slot, env2)
	
	# Corrupt main file
	var main_path: String = mgr.get_save_file_path(test_slot)
	var file: FileAccess = FileAccess.open(main_path, FileAccess.WRITE)
	file.store_string("{ corrupted_json: true, unterminated: ")
	file.close()
	
	# Read envelope: should detect corruption and recover from .bak
	var restored_env: Dictionary = mgr.read_save_envelope(test_slot)
	_assert(not restored_env.is_empty(), "read_save_envelope should fall back to .bak when main is corrupt", failures)
	_assert(restored_env.get("save_version") == 2, "Restored backup must have save_version 2", failures)
	
	mgr.free()

static func test_future_version_rejection(failures: Array[String]) -> void:
	var mgr: Node = _create_save_mgr()
	var test_slot: String = "test_future_version"
	
	# Write envelope with save_version = 999
	var future_env: Dictionary = {
		"save_version": 999,
		"game_version": "9.9.9",
		"checksum": "abc",
		"payload": {}
	}
	mgr.write_save_atomic(test_slot, future_env)
	
	var read_env: Dictionary = mgr.read_save_envelope(test_slot)
	_assert(read_env.is_empty(), "SaveManager must refuse save files from a newer future version", failures)
	mgr.free()
