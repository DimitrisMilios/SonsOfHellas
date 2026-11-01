class_name TestCampaignManager
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_campaign_manager_move_validation(failures)
	test_campaign_manager_movement_execution(failures)
	test_province_transfer_on_siege_victory(failures)
	test_world_tap_arbitration_and_selection(failures)
	test_stance_update(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func _setup_test_manager() -> Node:
	# Instantiate CampaignManager node directly for headless testing
	var script: GDScript = load("res://scripts/core/CampaignManager.gd")
	var mgr: Node = script.new()
	
	var p1: ProvinceData = ProvinceData.new()
	p1.province_id = "prov_sparta"
	p1.province_name = "Sparta"
	p1.owner_faction_id = "sparta"
	p1.map_position = Vector2(100, 100)
	p1.adjacent_province_ids = ["prov_corinth"]
	p1.public_order = 50.0
	
	var p2: ProvinceData = ProvinceData.new()
	p2.province_id = "prov_corinth"
	p2.province_name = "Corinth"
	p2.owner_faction_id = "athens"
	p2.map_position = Vector2(200, 100)
	p2.adjacent_province_ids = ["prov_sparta", "prov_athens"]
	p2.public_order = 40.0
	
	var p3: ProvinceData = ProvinceData.new()
	p3.province_id = "prov_athens"
	p3.province_name = "Athens"
	p3.owner_faction_id = "athens"
	p3.map_position = Vector2(300, 100)
	p3.adjacent_province_ids = ["prov_corinth"]
	p3.public_order = 60.0
	
	mgr.register_province(p1)
	mgr.register_province(p2)
	mgr.register_province(p3)
	
	var a1: ArmyData = ArmyData.new()
	a1.army_id = "spartan_army"
	a1.army_name = "Spartan Cohort"
	a1.owner_faction_id = "sparta"
	a1.current_province_id = "prov_sparta"
	a1.current_action_points = 100.0
	a1.max_action_points = 100.0
	
	var u: UnitData = UnitData.new()
	u.unit_id = "spartan_hoplite"
	u.display_name = "Spartan Hoplite"
	u.tier = 2
	u.unit_count = 120
	u.armor = 50
	u.melee_attack = 45
	u.melee_defense = 40
	a1.add_unit(u)
	
	mgr.register_army(a1)
	return mgr

static func test_campaign_manager_move_validation(failures: Array[String]) -> void:
	var mgr: Node = _setup_test_manager()
	var army: ArmyData = mgr.armies[0]
	
	# Valid move to adjacent province
	var v_valid: Dictionary = mgr.validate_army_move(army, "prov_corinth")
	_assert(v_valid["valid"], "Move to adjacent Corinth should be valid", failures)
	_assert(v_valid["cost"] == 40.0, "Base movement AP cost should be 40.0, got: " + str(v_valid["cost"]), failures)
	
	# Invalid move to non-adjacent province (Athens is 2 steps away)
	var v_non_adj: Dictionary = mgr.validate_army_move(army, "prov_athens")
	_assert(not v_non_adj["valid"], "Move to non-adjacent Athens must be rejected", failures)
	
	# Invalid move when AP is insufficient
	army.current_action_points = 10.0
	var v_low_ap: Dictionary = mgr.validate_army_move(army, "prov_corinth")
	_assert(not v_low_ap["valid"], "Move with 10 AP must be rejected (cost is 40)", failures)
	
	mgr.free()

static func test_campaign_manager_movement_execution(failures: Array[String]) -> void:
	var mgr: Node = _setup_test_manager()
	var army: ArmyData = mgr.armies[0]
	
	# Make Corinth friendly so movement doesn't trigger battle
	var corinth: ProvinceData = mgr.provinces["prov_corinth"]
	corinth.owner_faction_id = "sparta"
	
	var move_started_fired: Array = [false]
	var move_completed_fired: Array = [false]
	
	mgr.army_movement_started.connect(func(_a: ArmyData, _from: String, _to: String) -> void:
		move_started_fired[0] = true
	)
	mgr.army_movement_completed.connect(func(_a: ArmyData, _to: String) -> void:
		move_completed_fired[0] = true
	)
	
	var ok: bool = mgr.execute_army_move(army, "prov_corinth")
	_assert(ok, "execute_army_move should succeed for friendly adjacent move", failures)
	_assert(army.current_province_id == "prov_corinth", "Army location should update to Corinth", failures)
	_assert(army.current_action_points == 60.0, "Army AP should decrease by 40 (100 - 40 = 60), got: " + str(army.current_action_points), failures)
	_assert(move_started_fired[0], "army_movement_started signal must be emitted", failures)
	_assert(move_completed_fired[0], "army_movement_completed signal must be emitted", failures)
	
	mgr.free()

static func test_province_transfer_on_siege_victory(failures: Array[String]) -> void:
	var mgr: Node = _setup_test_manager()
	var army: ArmyData = mgr.armies[0]
	var corinth: ProvinceData = mgr.provinces["prov_corinth"]
	corinth.owner_faction_id = "athens"
	corinth.public_order = 50.0
	corinth.garrison_units.clear() # Undefended
	
	var ownership_changed_fired: Array = [false]
	mgr.province_ownership_changed.connect(func(_p: ProvinceData, old_o: String, new_o: String) -> void:
		ownership_changed_fired[0] = (old_o == "athens" and new_o == "sparta")
	)
	
	var ok: bool = mgr.execute_army_move(army, "prov_corinth")
	_assert(ok, "Attacking undefended settlement should succeed", failures)
	_assert(corinth.owner_faction_id == "sparta", "Corinth ownership should transfer to Sparta", failures)
	_assert(corinth.public_order == 20.0, "Public order should decrease by 30 on conquest (50 - 30 = 20), got: " + str(corinth.public_order), failures)
	_assert(ownership_changed_fired[0], "province_ownership_changed signal must be emitted", failures)
	
	mgr.free()

static func test_world_tap_arbitration_and_selection(failures: Array[String]) -> void:
	var mgr: Node = _setup_test_manager()
	
	var selected_prov_id: Array = [""]
	var selected_army_id: Array = [""]
	
	mgr.province_selected.connect(func(p: ProvinceData) -> void:
		selected_prov_id[0] = p.province_id
	)
	mgr.army_selected.connect(func(a: ArmyData) -> void:
		selected_army_id[0] = a.army_id
	)
	mgr.selection_cleared.connect(func() -> void:
		selected_prov_id[0] = ""
		selected_army_id[0] = ""
	)
	
	# Tap on spartan army at (100, 100) -> Army has priority
	mgr.handle_world_tap(Vector2(100, 100))
	_assert(selected_army_id[0] == "spartan_army", "First tap on (100, 100) should select spartan_army", failures)
	
	# Tap-again cycling: tapping on selected army again switches selection to underlying province
	mgr.handle_world_tap(Vector2(100, 100))
	_assert(selected_prov_id[0] == "prov_sparta", "Second tap on selected army should cycle to prov_sparta", failures)
	
	# Tap outside on empty void (5000, 5000) clears selection
	mgr.handle_world_tap(Vector2(5000, 5000))
	_assert(selected_prov_id[0] == "" and selected_army_id[0] == "", "Tapping void should clear selection", failures)
	
	mgr.free()

static func test_stance_update(failures: Array[String]) -> void:
	var mgr: Node = _setup_test_manager()
	var army: ArmyData = mgr.armies[0]
	
	var success: bool = mgr.set_army_stance(army.army_id, ArmyData.Stance.FORCED_MARCH)
	_assert(success, "set_army_stance should succeed for valid stance transition", failures)
	_assert(army.stance == ArmyData.Stance.FORCED_MARCH, "Army stance must be FORCED_MARCH", failures)
	_assert(army.max_action_points == 150.0, "Forced March max AP should be 150.0", failures)
	
	mgr.free()
