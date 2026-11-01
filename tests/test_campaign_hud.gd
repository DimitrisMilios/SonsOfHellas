class_name TestCampaignHUD
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_hud_controls_touch_dimensions(failures)
	test_province_view_model_binding(failures)
	test_army_view_model_binding(failures)
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
	
	# Verify EndTurnButton adheres to >= 48px height rule
	var end_btn: Button = hud.end_turn_button
	_assert(end_btn != null, "EndTurnButton must be present", failures)
	if end_btn != null:
		_assert(end_btn.custom_minimum_size.y >= 48.0, 
			"EndTurnButton height must be >= 48px for mobile touch standard, got: %f" % end_btn.custom_minimum_size.y, failures)
		_assert(end_btn.custom_minimum_size.x >= 140.0,
			"EndTurnButton width must be >= 140px, got: %f" % end_btn.custom_minimum_size.x, failures)
	
	hud.free()

static func test_province_view_model_binding(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	
	var prov_vm: ProvinceViewModel = ProvinceViewModel.new()
	prov_vm.province_id = "prov_sparta"
	prov_vm.province_name = "Sparta"
	prov_vm.owner_faction_id = "sparta"
	prov_vm.settlement_tier = 4
	prov_vm.public_order = 18.5
	prov_vm.region_wealth = 2200.0
	prov_vm.tax_level_lower = 3
	prov_vm.unrest_pressure = 0
	
	hud.display_province_view_model(prov_vm)
	_assert(hud.info_panel.visible, "Info panel must become visible on province selection", failures)
	_assert(hud.title_label.text.contains("Sparta"), "Title label must display province name", failures)
	_assert(hud.details_label.text.contains("Tier 4") or hud.details_label.text.contains("Settlement Tier: 4"), 
		"Details must display settlement tier", failures)
	
	hud.clear_selection()
	_assert(not hud.info_panel.visible, "Info panel must hide on clear_selection()", failures)
	
	hud.free()

static func test_army_view_model_binding(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	
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

static func test_turn_processing_gating(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/UI/CampaignHUD.tscn")
	var hud: CampaignHUD = hud_scene.instantiate() as CampaignHUD
	
	hud.on_turn_processing_started()
	_assert(hud.end_turn_button.disabled, "EndTurnButton must be disabled while turn is processing", failures)
	
	hud.on_turn_processing_finished()
	_assert(not hud.end_turn_button.disabled, "EndTurnButton must be re-enabled after turn completes", failures)
	
	hud.free()
