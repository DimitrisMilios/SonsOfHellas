class_name TestCampaignMapView
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	
	test_province_view_model_builder(failures)
	test_army_view_model_builder(failures)
	test_map_view_safe_removal(failures)
	test_map_view_state_reconciliation(failures)
	test_zoom_reactive_touch_bounds(failures)
	
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_province_view_model_builder(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = "prov_sparta"
	prov.province_name = "Sparta"
	prov.owner_faction_id = "sparta"
	prov.settlement_level = 3
	prov.region_wealth = 1500.0
	prov.public_order = 85.0
	prov.unrest_pressure = 1
	
	var fac: FactionData = FactionData.new()
	fac.faction_id = "sparta"
	fac.food_balance = 5
	
	var vm: ProvinceViewModel = ProvinceViewModel.from_province_data(prov, fac, 1)
	_assert(vm.province_id == "prov_sparta", "Province ID must match", failures)
	_assert(vm.settlement_tier == 3, "Settlement tier must match 3", failures)
	_assert(vm.unrest_pressure == 1, "Unrest pressure must match 1", failures)
	_assert(vm.region_wealth == 1500.0, "Region wealth must match 1500", failures)

static func test_army_view_model_builder(failures: Array[String]) -> void:
	var army: ArmyData = ArmyData.new()
	army.army_id = "spartan_army"
	army.army_name = "Phalanx"
	army.owner_faction_id = "sparta"
	army.current_province_id = "prov_sparta"
	army.stance = ArmyData.Stance.FORCED_MARCH
	army.current_action_points = 80.0
	army.max_action_points = 120.0
	
	var u: UnitData = UnitData.new()
	u.unit_id = "hoplite_veteran"
	u.display_name = "Veteran Hoplite"
	u.tier = 2
	u.unit_count = 110
	u.veterancy_rank = 3
	u.armor = 40
	u.upkeep_cost = 60
	u.turn_upkeep = 60
	army.add_unit(u)
	
	var vm: ArmyViewModel = ArmyViewModel.from_army_data(army)
	_assert(vm.army_id == "spartan_army", "Army ID must match", failures)
	_assert(vm.stance_name == "Forced March", "Stance name should be Forced March", failures)
	_assert(vm.unit_cards.size() == 1, "Unit cards size must be 1", failures)
	_assert(vm.unit_cards[0]["veterancy"] == 3, "Unit veterancy chevrons must match 3", failures)
	# Forced March maintains baseline upkeep (60)
	_assert(vm.total_upkeep == 60, "Total upkeep under Forced March must be 60", failures)

static func test_map_view_safe_removal(failures: Array[String]) -> void:
	var map_view: CampaignMapView = CampaignMapView.new()
	
	var army: ArmyData = ArmyData.new()
	army.army_id = "army_1"
	army.owner_faction_id = "sparta"
	
	var army_node: ArmyNode = map_view.spawn_army_node(army, Vector2(100, 100))
	_assert(map_view.army_nodes.has("army_1"), "MapView should register spawned army node", failures)
	
	map_view.selected_entity_id = "army_1"
	map_view.remove_army_node("army_1")
	
	_assert(not map_view.army_nodes.has("army_1"), "Army node should be erased from map view dictionary", failures)
	_assert(map_view.selected_entity_id.is_empty(), "Selection must clear when selected army is removed", failures)
	
	map_view.free()

static func test_map_view_state_reconciliation(failures: Array[String]) -> void:
	var map_view: CampaignMapView = CampaignMapView.new()
	
	var p1: ProvinceData = ProvinceData.new()
	p1.province_id = "prov_1"
	p1.province_name = "Corinth"
	
	var a1: ArmyData = ArmyData.new()
	a1.army_id = "army_1"
	a1.current_province_id = "prov_1"
	
	var a2: ArmyData = ArmyData.new()
	a2.army_id = "army_2"
	a2.current_province_id = "prov_1"
	
	# Initial reconciliation
	map_view.rebuild_from_state({"prov_1": p1}, [a1, a2])
	_assert(map_view.province_nodes.size() == 1, "Should have 1 province node", failures)
	_assert(map_view.army_nodes.size() == 2, "Should have 2 army nodes", failures)
	
	# Model state changes: army_2 is destroyed
	map_view.rebuild_from_state({"prov_1": p1}, [a1])
	_assert(map_view.army_nodes.size() == 1, "Reconciliation should prune destroyed army_2 node", failures)
	_assert(map_view.army_nodes.has("army_1"), "army_1 node should remain", failures)
	
	map_view.free()

static func test_zoom_reactive_touch_bounds(failures: Array[String]) -> void:
	var map_view: CampaignMapView = CampaignMapView.new()
	
	var p1: ProvinceData = ProvinceData.new()
	p1.province_id = "prov_1"
	p1.map_position = Vector2(300, 300)
	map_view.spawn_province_node(p1)
	
	# Candidates at zoom 1.0 (base radius 56)
	var c_zoom1: Array[Dictionary] = map_view.get_touch_candidates(1.0)
	_assert(c_zoom1[0]["radius"] == 56.0, "At zoom 1.0, radius should be base 56.0", failures)
	
	# Candidates at zoom 0.4 (scaled up to guarantee 48px screen size -> 60.0 world radius)
	var c_zoom04: Array[Dictionary] = map_view.get_touch_candidates(0.4)
	_assert(c_zoom04[0]["radius"] >= 60.0, "At zoom 0.4, candidate radius should scale to >= 60.0", failures)
	
	map_view.free()
