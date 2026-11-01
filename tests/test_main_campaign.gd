class_name TestMainCampaign
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_main_campaign_instantiation_and_nodes(failures)
	test_initial_greek_provinces_and_armies(failures)
	test_signal_wiring_camera_to_map_view(failures)
	test_signal_wiring_campaign_manager_to_hud_and_view(failures)
	test_turn_1_bootstrap_spartan_player(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_main_campaign_instantiation_and_nodes(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/MainCampaign.tscn")
	_assert(scene != null, "MainCampaign.tscn must be loadable", failures)
	if scene == null:
		return
		
	var main: MainCampaign = scene.instantiate() as MainCampaign
	_assert(main != null, "Instantiated node must be MainCampaign", failures)
	if main == null:
		return
		
	var camera: CampaignCamera = main.get_node_or_null("CampaignCamera") as CampaignCamera
	_assert(camera != null, "MainCampaign must have CampaignCamera", failures)
	
	var world: Node2D = main.get_node_or_null("World") as Node2D
	_assert(world != null, "MainCampaign must have World node", failures)
	
	var roads: Node2D = main.get_node_or_null("World/Roads") as Node2D
	_assert(roads != null, "World must have Roads container", failures)
	
	var map_view: CampaignMapView = main.get_node_or_null("World/CampaignMapView") as CampaignMapView
	_assert(map_view != null, "World must have CampaignMapView", failures)
	
	var hud: CampaignHUD = main.get_node_or_null("CampaignHUD") as CampaignHUD
	_assert(hud != null, "MainCampaign must have CampaignHUD", failures)
	
	main.free()

static func test_initial_greek_provinces_and_armies(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/MainCampaign.tscn")
	var main: MainCampaign = scene.instantiate() as MainCampaign
	main._load_default_presets_if_empty()
	
	# Verify 4 Greek provinces
	var prov_ids: Array[String] = []
	for p: ProvinceData in main.province_resources:
		if p != null:
			prov_ids.append(p.province_id)
			
	_assert(prov_ids.has("sparta"), "Should contain sparta province, got: " + str(prov_ids), failures)
	_assert(prov_ids.has("athens"), "Should contain athens province, got: " + str(prov_ids), failures)
	_assert(prov_ids.has("corinth"), "Should contain corinth province, got: " + str(prov_ids), failures)
	_assert(prov_ids.has("thebes"), "Should contain thebes province, got: " + str(prov_ids), failures)
	
	# Verify starting armies
	_assert(main.army_resources.size() >= 2, "Should contain at least 2 starting armies", failures)
	
	# Verify factions
	var fac_ids: Array[String] = []
	for f: FactionData in main.faction_resources:
		if f != null:
			fac_ids.append(f.faction_id)
	_assert(fac_ids.has("sparta"), "Should contain sparta faction", failures)
	_assert(fac_ids.has("athens"), "Should contain athens faction", failures)
	_assert(fac_ids.has("thebes"), "Should contain thebes faction", failures)
	
	main.free()

static func test_signal_wiring_camera_to_map_view(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/MainCampaign.tscn")
	var main: MainCampaign = scene.instantiate() as MainCampaign
	main._wire_signals()
	
	# Emit zoom_changed from camera and assert map_view zoom reflects it
	main.camera.zoom = Vector2(1.5, 1.5)
	main.camera.zoom_changed.emit(Vector2(1.5, 1.5))
	
	_assert(is_equal_approx(main.map_view.current_zoom_x, 1.5), 
		"map_view current_zoom_x must track camera zoom_changed, got: %f" % main.map_view.current_zoom_x, failures)
	
	main.free()

static func test_signal_wiring_campaign_manager_to_hud_and_view(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/MainCampaign.tscn")
	var main: MainCampaign = scene.instantiate() as MainCampaign
	main._ensure_references()
	if main.hud != null:
		main.hud._ensure_references()
	main._wire_signals()
	
	# Simulate province selected
	var p: ProvinceData = ProvinceData.new()
	p.province_id = "prov_sparta"
	p.province_name = "Sparta"
	p.owner_faction_id = "sparta"
	p.settlement_level = 3
	
	main._on_province_selected(p)
	_assert(main.hud.info_panel.visible, "HUD info panel must open on province selection", failures)
	_assert(main.map_view.selected_entity_id == "prov_sparta", "map_view selected_entity_id must update to prov_sparta", failures)
	
	# Simulate selection cleared
	main._on_selection_cleared()
	_assert(not main.hud.info_panel.visible, "HUD info panel must close on clear selection", failures)
	_assert(main.map_view.selected_entity_id.is_empty(), "map_view selection must clear", failures)
	
	main.free()

static func test_turn_1_bootstrap_spartan_player(failures: Array[String]) -> void:
	var spartan_fac: FactionData = load("res://resources/factions/sparta.tres") as FactionData
	_assert(spartan_fac != null, "Sparta faction resource must be loadable", failures)
	if spartan_fac != null:
		_assert(spartan_fac.is_player, "Spartan faction must be configured as player", failures)
		_assert(spartan_fac.faction_name == "Sparta", "Faction name must be Sparta", failures)
