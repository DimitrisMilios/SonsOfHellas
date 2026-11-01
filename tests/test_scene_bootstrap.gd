class_name TestSceneBootstrap
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_scene_bootstrap_integrity(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_scene_bootstrap_integrity(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/MainCampaign.tscn")
	_assert(scene != null, "MainCampaign.tscn must be loadable", failures)
	if scene == null:
		return
		
	var main: MainCampaign = scene.instantiate() as MainCampaign
	_assert(main != null, "Instantiated node must be MainCampaign", failures)
	if main == null:
		return
		
	# Verify subcomponents are present
	var camera: CampaignCamera = main.get_node_or_null("CampaignCamera") as CampaignCamera
	_assert(camera != null, "MainCampaign must have CampaignCamera", failures)
	
	var world: Node2D = main.get_node_or_null("World") as Node2D
	_assert(world != null, "MainCampaign must have World node", failures)
	
	var map_view: CampaignMapView = main.get_node_or_null("World/CampaignMapView") as CampaignMapView
	_assert(map_view != null, "World must have CampaignMapView", failures)
	
	var hud: CampaignHUD = main.get_node_or_null("CampaignHUD") as CampaignHUD
	_assert(hud != null, "MainCampaign must have CampaignHUD", failures)
	
	# Trigger initialization lifecycle
	main._load_default_presets_if_empty()
	_assert(main.faction_resources.size() >= 3, "Default presets should have at least 3 factions", failures)
	_assert(main.province_resources.size() >= 4, "Default presets should have at least 4 provinces", failures)
	_assert(main.army_resources.size() >= 2, "Default presets should have at least 2 armies", failures)
	
	main.free()
