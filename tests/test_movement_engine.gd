class_name TestMovementEngine
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_base_movement_cost(failures)
	_test_road_infrastructure_discount(failures)
	_test_terrain_modifiers(failures)
	_test_adjacency_validation(failures)
	_test_ap_insufficiency_and_epsilon(failures)
	_test_siege_stance_immobility(failures)
	_test_zoc_hostile_interception(failures)
	_test_zoc_ap_reduction_to_zero(failures)
	_test_trade_route_raiding_income(failures)
	_test_retreat_vector_and_destination_selection(failures)
	_test_movement_execution_purity_and_application(failures)
	return failures

static func _create_test_provinces() -> Array[ProvinceData]:
	var p1: ProvinceData = ProvinceData.new()
	p1.province_id = "prov_sparta"
	p1.province_name = "Sparta"
	p1.owner_faction_id = "faction_sparta"
	p1.adjacent_province_ids = ["prov_corinth"]
	
	var p2: ProvinceData = ProvinceData.new()
	p2.province_id = "prov_corinth"
	p2.province_name = "Corinth"
	p2.owner_faction_id = "faction_corinth"
	p2.adjacent_province_ids = ["prov_sparta", "prov_athens"]
	
	var p3: ProvinceData = ProvinceData.new()
	p3.province_id = "prov_athens"
	p3.province_name = "Athens"
	p3.owner_faction_id = "faction_athens"
	p3.adjacent_province_ids = ["prov_corinth"]
	
	return [p1, p2, p3]

static func _test_base_movement_cost(failures: Array[String]) -> void:
	var cost: float = MovementEngine.calculate_ap_cost("plains", 0)
	if not is_equal_approx(cost, 40.0):
		failures.append("Base plains movement cost should be 40.0, got: %f" % cost)

static func _test_road_infrastructure_discount(failures: Array[String]) -> void:
	# Paved roads (Tier 1: M_road = 0.33) -> 40.0 / 1.33 = ~30.075 AP
	var paved_cost: float = MovementEngine.calculate_ap_cost("plains", 1)
	if absf(paved_cost - 30.075) > 0.1:
		failures.append("Expected paved road cost ~30.075 AP, got: %f" % paved_cost)
		
	# Highway (Tier 2: M_road = 0.60) -> 40.0 / 1.60 = 25.0 AP
	var highway_cost: float = MovementEngine.calculate_ap_cost("plains", 2)
	if not is_equal_approx(highway_cost, 25.0):
		failures.append("Expected highway road cost 25.0 AP, got: %f" % highway_cost)

static func _test_terrain_modifiers(failures: Array[String]) -> void:
	# Mountain/Rough terrain (1.5x)
	var mountain_cost: float = MovementEngine.calculate_ap_cost("mountain", 0)
	if not is_equal_approx(mountain_cost, 60.0):
		failures.append("Expected mountain cost 60.0 AP, got: %f" % mountain_cost)
		
	# Forest terrain (1.25x)
	var forest_cost: float = MovementEngine.calculate_ap_cost("forest", 0)
	if not is_equal_approx(forest_cost, 50.0):
		failures.append("Expected forest cost 50.0 AP, got: %f" % forest_cost)

static func _test_adjacency_validation(failures: Array[String]) -> void:
	var provs: Array[ProvinceData] = _create_test_provinces()
	var sparta: ProvinceData = provs[0]
	var corinth: ProvinceData = provs[1]
	var athens: ProvinceData = provs[2]
	
	var army: ArmyData = ArmyData.new()
	army.current_action_points = 100.0
	army.current_province_id = "prov_sparta"
	
	# Sparta to Corinth is adjacent
	if not MovementEngine.can_move_to_province(army, sparta, corinth):
		failures.append("Adjacent movement Sparta -> Corinth failed validation")
		
	# Sparta to Athens is NOT adjacent (separated by Corinth)
	if MovementEngine.can_move_to_province(army, sparta, athens):
		failures.append("Non-adjacent movement Sparta -> Athens succeeded validation")

static func _test_ap_insufficiency_and_epsilon(failures: Array[String]) -> void:
	var provs: Array[ProvinceData] = _create_test_provinces()
	var army: ArmyData = ArmyData.new()
	army.current_action_points = 35.0 # Need 40.0
	
	if MovementEngine.can_move_to_province(army, provs[0], provs[1]):
		failures.append("Movement succeeded with insufficient AP (35.0 vs 40.0 cost)")
		
	# Precision epsilon test: 39.9995 with 0.001 epsilon should succeed for 40.0
	army.current_action_points = 39.9995
	if not MovementEngine.can_move_to_province(army, provs[0], provs[1]):
		failures.append("Movement with float precision epsilon failed validation")

static func _test_siege_stance_immobility(failures: Array[String]) -> void:
	var provs: Array[ProvinceData] = _create_test_provinces()
	var army: ArmyData = ArmyData.new()
	army.current_action_points = 100.0
	army.stance = ArmyData.Stance.SIEGE
	
	if MovementEngine.can_move_to_province(army, provs[0], provs[1]):
		failures.append("Army in Siege stance should be stationary (0 movement)")

static func _test_zoc_hostile_interception(failures: Array[String]) -> void:
	var provs: Array[ProvinceData] = _create_test_provinces()
	var sparta: ProvinceData = provs[0]
	var corinth: ProvinceData = provs[1] # Owned by faction_corinth (hostile)
	
	var army: ArmyData = ArmyData.new()
	army.owner_faction_id = "faction_sparta"
	army.current_action_points = 100.0
	
	var intercept: bool = MovementEngine.is_hostile_intercept(army, corinth, [])
	if not intercept:
		failures.append("Moving into hostile-owned province should trigger interception/engagement")
		
	# Friendly province move
	corinth.owner_faction_id = "faction_sparta"
	var friendly_intercept: bool = MovementEngine.is_hostile_intercept(army, corinth, [])
	if friendly_intercept:
		failures.append("Moving into friendly province should not trigger interception")

static func _test_zoc_ap_reduction_to_zero(failures: Array[String]) -> void:
	var provs: Array[ProvinceData] = _create_test_provinces()
	var sparta: ProvinceData = provs[0]
	var corinth: ProvinceData = provs[1]
	corinth.owner_faction_id = "faction_corinth" # Hostile
	
	var army: ArmyData = ArmyData.new()
	army.owner_faction_id = "faction_sparta"
	army.current_province_id = "prov_sparta"
	army.current_action_points = 100.0
	
	var res: Dictionary = MovementEngine.calculate_movement_result(army, sparta, corinth, "plains", 0)
	if not res["triggers_engagement"]:
		failures.append("Expected movement to hostile province to trigger engagement")
	if res["remaining_ap"] != 0.0:
		failures.append("ZoC hostile interception should reduce remaining AP to 0.0, got: %f" % res["remaining_ap"])

static func _test_trade_route_raiding_income(failures: Array[String]) -> void:
	# I_raid = W_lane * alpha_raid (e.g., 500 wealth * 0.20 = 100 gold)
	var income: int = MovementEngine.calculate_raiding_income(500.0, 0.20)
	if income != 100:
		failures.append("Expected raiding income 100, got: %d" % income)
		
	# Clamping and zero-bound protection
	var zero_income: int = MovementEngine.calculate_raiding_income(-100.0, 0.50)
	if zero_income != 0:
		failures.append("Raiding income for negative wealth should clamp to 0")

static func _test_retreat_vector_and_destination_selection(failures: Array[String]) -> void:
	var provs: Array[ProvinceData] = _create_test_provinces()
	var sparta: ProvinceData = provs[0]
	sparta.map_position = Vector2(100.0, 100.0)
	
	var corinth: ProvinceData = provs[1]
	corinth.map_position = Vector2(200.0, 100.0)
	
	var athens: ProvinceData = provs[2]
	athens.map_position = Vector2(300.0, 100.0)
	
	var prov_map: Dictionary = {
		"prov_sparta": sparta,
		"prov_corinth": corinth,
		"prov_athens": athens
	}
	
	# Attacker at Athens (300, 100), Defender at Corinth (200, 100)
	# Retreat vector from Corinth away from Athens points LEFT (-1, 0) towards Sparta!
	var vec: Vector2 = MovementEngine.calculate_retreat_vector(corinth.map_position, athens.map_position)
	if not is_equal_approx(vec.x, -1.0) or not is_equal_approx(vec.y, 0.0):
		failures.append("Expected retreat vector (-1.0, 0.0), got: " + str(vec))
		
	var def_army: ArmyData = ArmyData.new()
	def_army.owner_faction_id = "faction_corinth"
	def_army.current_province_id = "prov_corinth"
	
	var att_army: ArmyData = ArmyData.new()
	att_army.owner_faction_id = "faction_athens"
	att_army.current_province_id = "prov_athens"
	
	# Sparta is neutral/friendly (owner = faction_sparta, not hostile faction_athens)
	var best_retreat: String = MovementEngine.find_best_retreat_province(def_army, corinth, att_army, prov_map)
	if best_retreat != "prov_sparta":
		failures.append("Expected retreat destination to be prov_sparta, got: " + best_retreat)

static func _test_movement_execution_purity_and_application(failures: Array[String]) -> void:
	var provs: Array[ProvinceData] = _create_test_provinces()
	provs[1].owner_faction_id = "faction_sparta" # Friendly province for peaceful move
	var army: ArmyData = ArmyData.new()
	army.owner_faction_id = "faction_sparta"
	army.current_province_id = "prov_sparta"
	army.current_action_points = 100.0
	
	var result: Dictionary = MovementEngine.calculate_movement_result(army, provs[0], provs[1], "plains", 0)
	
	# Purity test
	if army.current_action_points != 100.0:
		failures.append("calculate_movement_result mutated army AP")
	if not result["success"]:
		failures.append("Expected movement result success to be true")
	if not is_equal_approx(result["ap_cost"], 40.0):
		failures.append("Expected ap_cost 40.0, got: %f" % result["ap_cost"])
	if not is_equal_approx(result["remaining_ap"], 60.0):
		failures.append("Expected remaining_ap 60.0, got: %f" % result["remaining_ap"])
		
	# Application test
	MovementEngine.apply_movement(army, result, "prov_corinth")
	if absf(army.current_action_points - 60.0) > 0.001:
		failures.append("apply_movement failed to deduct AP correctly, remaining: %f" % army.current_action_points)
	if army.current_province_id != "prov_corinth":
		failures.append("apply_movement failed to update current_province_id")
