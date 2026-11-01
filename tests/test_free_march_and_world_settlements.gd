class_name TestFreeMarchAndWorldSettlements
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_free_march_on_open_terrain(failures)
	test_construct_settlement_infrastructure(failures)
	test_recruit_unit_and_raise_army(failures)
	test_diplomatic_relations(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_free_march_on_open_terrain(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/CampaignManager.gd")
	var mgr: Node = script.new()

	var spartan_fac: FactionData = FactionData.new()
	spartan_fac.faction_id = "sparta"
	spartan_fac.treasury = 1000

	var army: ArmyData = ArmyData.new()
	army.army_id = "test_army"
	army.owner_faction_id = "sparta"
	army.map_position = Vector2(100.0, 100.0)
	army.current_action_points = 100.0
	army.max_action_points = 100.0

	mgr.register_army(army)
	mgr.select_army(army)

	# Click on open terrain at (150, 100) -> distance is 50 pixels
	# At 2.5 px per AP, 50 px takes 20 AP, remaining AP should be 80.0
	var success: bool = mgr.execute_free_march(army, Vector2(150.0, 100.0))
	_assert(success, "Free march towards open ground must succeed", failures)
	_assert(is_equal_approx(army.current_action_points, 80.0), "AP must decrease by 20 (got: %f)" % army.current_action_points, failures)
	_assert(army.map_position.is_equal_approx(Vector2(150.0, 100.0)), "Army map position must update to (150, 100)", failures)

	mgr.free()

static func test_construct_settlement_infrastructure(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/CampaignManager.gd")
	var mgr: Node = script.new()

	var p: ProvinceData = ProvinceData.new()
	p.province_id = "sparta"
	p.owner_faction_id = "sparta"
	p.map_position = Vector2(1200, 500)
	mgr.register_province(p)

	var b_agora: BuildingData = load("res://resources/buildings/agora.tres") as BuildingData
	_assert(b_agora != null, "Agora building resource must exist", failures)

	if b_agora != null:
		var ok: bool = mgr.construct_building("sparta", b_agora)
		_assert(ok, "Constructing Agora must succeed", failures)
		_assert(p.building_slots.size() > 0, "Province must contain building slot", failures)

	mgr.free()

static func test_recruit_unit_and_raise_army(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/CampaignManager.gd")
	var mgr: Node = script.new()

	var p: ProvinceData = ProvinceData.new()
	p.province_id = "sparta"
	p.owner_faction_id = "sparta"
	p.map_position = Vector2(1200, 500)
	mgr.register_province(p)

	var u_hoplite: UnitData = load("res://resources/units/spartan_hoplites.tres") as UnitData
	_assert(u_hoplite != null, "Spartan hoplites unit resource must exist", failures)

	if u_hoplite != null:
		var ok: bool = mgr.recruit_unit("sparta", u_hoplite)
		_assert(ok, "Recruiting unit must succeed", failures)
		_assert(p.garrison_units.size() == 1, "Province garrison must have 1 unit", failures)

	var new_army: ArmyData = mgr.raise_new_army("sparta", "sparta")
	_assert(new_army != null, "Raising army must return valid ArmyData", failures)
	_assert(mgr.armies.has(new_army), "New army must be registered in CampaignManager", failures)
	_assert(new_army.map_position != Vector2.ZERO, "New army must have non-zero map position", failures)

	mgr.free()

static func test_diplomatic_relations(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/CampaignManager.gd")
	var mgr: Node = script.new()

	_assert(mgr.get_diplomacy_status("sparta", "athens") == "Neutral", "Default relation must be Neutral", failures)
	mgr.set_diplomacy_status("sparta", "athens", "Allied")
	_assert(mgr.get_diplomacy_status("sparta", "athens") == "Allied", "Updated relation must be Allied", failures)
	_assert(mgr.get_diplomacy_status("athens", "sparta") == "Allied", "Symmetric lookup must be Allied", failures)

	mgr.free()
