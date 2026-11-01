class_name TestCampaignHUD
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_hud_controls_touch_dimensions(failures)
	test_season_year_formatting(failures)
	test_top_bar_data_update(failures)
	test_province_view_model_binding(failures)
	test_army_view_model_binding(failures)
	test_auto_resolve_modal(failures)
	test_turn_processing_gating(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_hud_controls_touch_dimensions(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	_assert(hud_scene != null, "CampaignHUD.tscn must be loadable", failures)
	if hud_scene == null:
		return
		
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	_assert(hud != null, "Instantiated node must be CampaignHUD", failures)
	if hud == null:
		return
	hud._ensure_references()
		
	# Check Safe Area root container presence
	var safe_area: SafeAreaContainer = hud.get_node_or_null("SafeAreaContainer") as SafeAreaContainer
	_assert(safe_area != null, "CampaignHUD must wrap UI in SafeAreaContainer", failures)
	
	# Verify EndTurnButton adheres to >= 44x44px rule (we enforce >= 48px standard)
	var end_btn: Button = hud.end_turn_button
	_assert(end_btn != null, "EndTurnButton must be present", failures)
	if end_btn != null:
		_assert(end_btn.custom_minimum_size.y >= 44.0, 
			"EndTurnButton height must be >= 44px, got: %f" % end_btn.custom_minimum_size.y, failures)
		_assert(end_btn.custom_minimum_size.x >= 44.0,
			"EndTurnButton width must be >= 44px, got: %f" % end_btn.custom_minimum_size.x, failures)
	
	# Verify BattleDialog OK button adheres to >= 44x44px rule
	if hud.battle_dialog != null:
		var ok_btn: Button = hud.battle_dialog.get_ok_button()
		if ok_btn != null:
			_assert(ok_btn.custom_minimum_size.y >= 44.0, 
				"BattleDialog OK button height must be >= 44px, got: %f" % ok_btn.custom_minimum_size.y, failures)
			_assert(ok_btn.custom_minimum_size.x >= 44.0, 
				"BattleDialog OK button width must be >= 44px, got: %f" % ok_btn.custom_minimum_size.x, failures)
	
	hud.free()

static func test_season_year_formatting(failures: Array[String]) -> void:
	_assert(CampaignHUD.format_season_year(1) == "Spring, 431 BC", 
		"Turn 1 should be 'Spring, 431 BC', got: " + CampaignHUD.format_season_year(1), failures)
	_assert(CampaignHUD.format_season_year(2) == "Summer, 431 BC", 
		"Turn 2 should be 'Summer, 431 BC', got: " + CampaignHUD.format_season_year(2), failures)
	_assert(CampaignHUD.format_season_year(3) == "Autumn, 431 BC", 
		"Turn 3 should be 'Autumn, 431 BC', got: " + CampaignHUD.format_season_year(3), failures)
	_assert(CampaignHUD.format_season_year(4) == "Winter, 431 BC", 
		"Turn 4 should be 'Winter, 431 BC', got: " + CampaignHUD.format_season_year(4), failures)
	_assert(CampaignHUD.format_season_year(5) == "Spring, 430 BC", 
		"Turn 5 should be 'Spring, 430 BC', got: " + CampaignHUD.format_season_year(5), failures)

static func test_top_bar_data_update(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	hud._ensure_references()
	
	var fac: FactionData = FactionData.new()
	fac.faction_id = "sparta"
	fac.faction_name = "Sparta"
	fac.is_player = true
	fac.food_balance = 8
	
	hud.update_top_bar(3, fac, 2500, 420)
	
	_assert(hud.turn_label != null and hud.turn_label.text.contains("Turn 3"), "Turn label must display Turn 3", failures)
	_assert(hud.season_label != null and hud.season_label.text == "Autumn, 431 BC", "Season label must display Autumn, 431 BC", failures)
	_assert(hud.treasury_label != null and hud.treasury_label.text.contains("2500"), "Treasury label must display 2500", failures)
	_assert(hud.income_label != null and hud.income_label.text.contains("+420"), "Income label must display +420", failures)
	_assert(hud.food_label != null and hud.food_label.text.contains("+8"), "Food label must display +8", failures)
	
	hud.free()

static func test_province_view_model_binding(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	hud._ensure_references()
	
	var prov_vm: ProvinceViewModel = ProvinceViewModel.new()
	prov_vm.province_id = "prov_sparta"
	prov_vm.province_name = "Sparta"
	prov_vm.owner_faction_id = "sparta"
	prov_vm.settlement_tier = 4
	prov_vm.public_order = 18.5
	prov_vm.region_wealth = 2200.0
	prov_vm.tax_income = 350
	prov_vm.tax_level_upper = 4
	prov_vm.tax_level_lower = 3
	prov_vm.unrest_pressure = 1
	prov_vm.consecutive_unrest_turns = 1
	prov_vm.building_slots_summary = [
		{"name": "Palace", "tier": 2, "is_building": false, "turns_left": 0},
		{"name": "Barracks", "tier": 1, "is_building": true, "turns_left": 2}
	]
	
	hud.display_province_view_model(prov_vm)
	_assert(hud.info_panel.visible, "Info panel must become visible on province selection", failures)
	_assert(hud.title_label.text.contains("Sparta"), "Title label must display province name", failures)
	_assert(hud.details_label.text.contains("Settlement Tier: 4") or hud.details_label.text.contains("Tier 4"), 
		"Details must display settlement tier", failures)
	_assert(hud.details_label.text.contains("Public Order: 18.5"), "Details must display public order value", failures)
	_assert(hud.details_label.text.contains("Unrest Pressure: 1"), "Details must display unrest pressure", failures)
	_assert(hud.details_label.text.contains("Palace"), "Details must list Palace building", failures)
	
	hud.clear_selection()
	_assert(not hud.info_panel.visible, "Info panel must hide on clear_selection()", failures)
	
	hud.free()

static func test_army_view_model_binding(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	hud._ensure_references()
	
	var army_vm: ArmyViewModel = ArmyViewModel.new()
	army_vm.army_id = "army_sparta"
	army_vm.army_name = "Spartan Royal Phalanx"
	army_vm.owner_faction_id = "sparta"
	army_vm.stance = ArmyData.Stance.FORCED_MARCH
	army_vm.stance_name = "Forced March"
	army_vm.current_action_points = 75.0
	army_vm.max_action_points = 150.0
	army_vm.total_combat_power = 1800.0
	army_vm.total_upkeep = 120
	army_vm.unit_cards = [
		{"name": "Spartan Hoplites", "tier": 3, "count": 120, "veterancy": 2, "combat_value": 450.0}
	]
	
	hud.display_army_view_model(army_vm)
	_assert(hud.info_panel.visible, "Info panel must become visible on army selection", failures)
	_assert(hud.title_label.text.contains("Spartan Royal Phalanx"), "Title label must display army name", failures)
	_assert(hud.stance_container.visible, "Stance container must be visible for armies", failures)
	_assert(hud.details_label.text.contains("120 Gold") or hud.details_label.text.contains("120"), 
		"Details must display total upkeep", failures)
	
	hud.free()

static func test_auto_resolve_modal(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	hud._ensure_references()
	
	var res: BattleResult = BattleResult.new()
	res.attacker_won = true
	res.outcome_classification = "Decisive Victory"
	res.attacker_win_probability = 0.85
	
	hud._on_battle_triggered(res)
	_assert(hud.battle_dialog != null, "BattleDialog must be present", failures)
	_assert(hud.battle_dialog.title.contains("Victory"), "Battle dialog title should display Victory", failures)
	
	hud.free()

static func test_turn_processing_gating(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	hud._ensure_references()
	
	hud.on_turn_processing_started()
	_assert(hud.end_turn_button.disabled, "EndTurnButton must be disabled while turn is processing", failures)
	
	hud.on_turn_processing_finished()
	_assert(not hud.end_turn_button.disabled, "EndTurnButton must be re-enabled after turn completes", failures)
	
	hud.free()
