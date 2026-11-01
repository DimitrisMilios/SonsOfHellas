class_name TestCampaignInputRouter
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	
	test_clamped_touch_target_scaling(failures)
	test_gesture_discrimination(failures)
	test_army_priority_over_province(failures)
	test_closest_candidate_fallback(failures)
	test_tap_again_cycling(failures)
	test_input_gate_rejection(failures)
	
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_clamped_touch_target_scaling(failures: Array[String]) -> void:
	# At zoom = 1.0, base radius = 56.0. min_touch_px = 48.0 -> min world radius = 24.0.
	# Max(56.0, 24.0) = 56.0
	var r1: float = CampaignInputRouter.calculate_effective_world_radius(56.0, 1.0, 48.0)
	_assert(r1 == 56.0, "At zoom 1.0, effective radius should match base radius 56.0", failures)
	
	# At zoom = 0.4 (zoomed out): min world radius = 48.0 / (2 * 0.4) = 60.0.
	# Max(56.0, 60.0) = 60.0 -> On screen: 60 * 0.4 * 2 = 48 px!
	var r2: float = CampaignInputRouter.calculate_effective_world_radius(56.0, 0.4, 48.0)
	_assert(r2 == 60.0, "At zoom 0.4, effective radius should scale up to 60.0 px world-space", failures)

static func test_gesture_discrimination(failures: Array[String]) -> void:
	# Clean quick tap: displacement = 4px, duration = 120ms -> Valid tap
	var is_tap_1: bool = CampaignInputRouter.is_tap_gesture(Vector2(100, 100), Vector2(104, 100), 120.0)
	_assert(is_tap_1, "Small movement and quick release should qualify as tap", failures)
	
	# Pan drag: displacement = 40px -> Not a tap
	var is_tap_2: bool = CampaignInputRouter.is_tap_gesture(Vector2(100, 100), Vector2(140, 100), 120.0)
	_assert(not is_tap_2, "Displacement > 10px must be rejected as pan gesture", failures)
	
	# Long press: duration = 500ms -> Not a tap
	var is_tap_3: bool = CampaignInputRouter.is_tap_gesture(Vector2(100, 100), Vector2(100, 100), 500.0)
	_assert(not is_tap_3, "Duration > 250ms must be rejected as hold gesture", failures)

static func test_army_priority_over_province(failures: Array[String]) -> void:
	var prov: Dictionary = {
		"id": "prov_sparta",
		"type": "province",
		"pos": Vector2(200, 200),
		"radius": 56.0,
		"box_size": Vector2.ZERO
	}
	var army: Dictionary = {
		"id": "army_sparta",
		"type": "army",
		"pos": Vector2(225, 175),
		"radius": 26.0,
		"box_size": Vector2(52, 52)
	}
	
	# Tap directly at Vector2(225, 175), which is inside both the army box and province circle
	var hit: Dictionary = CampaignInputRouter.pick_candidate(
		Vector2(225, 175),
		[prov, army],
		""
	)
	_assert(hit["hit"], "Touch pick should register a hit", failures)
	_assert(hit["type"] == "army", "Army should have hit priority over overlapping province", failures)
	_assert(hit["id"] == "army_sparta", "Selected ID should be army_sparta", failures)

static func test_closest_candidate_fallback(failures: Array[String]) -> void:
	var prov1: Dictionary = {
		"id": "prov_1",
		"type": "province",
		"pos": Vector2(100, 100),
		"radius": 56.0,
		"box_size": Vector2.ZERO
	}
	var prov2: Dictionary = {
		"id": "prov_2",
		"type": "province",
		"pos": Vector2(300, 100),
		"radius": 56.0,
		"box_size": Vector2.ZERO
	}
	
	# Tap closer to prov1: (120, 100) -> dist to prov1 is 20, dist to prov2 is 180
	var hit: Dictionary = CampaignInputRouter.pick_candidate(
		Vector2(120, 100),
		[prov1, prov2],
		""
	)
	_assert(hit["hit"] and hit["id"] == "prov_1", "Closest candidate should be selected", failures)

static func test_tap_again_cycling(failures: Array[String]) -> void:
	var prov: Dictionary = {
		"id": "prov_sparta",
		"type": "province",
		"pos": Vector2(200, 200),
		"radius": 56.0,
		"box_size": Vector2.ZERO
	}
	var army: Dictionary = {
		"id": "army_sparta",
		"type": "army",
		"pos": Vector2(225, 175),
		"radius": 26.0,
		"box_size": Vector2(52, 52)
	}
	
	# If army_sparta is ALREADY selected and player taps the overlapping area again,
	# tap-again cycling switches selection to prov_sparta!
	var hit: Dictionary = CampaignInputRouter.pick_candidate(
		Vector2(225, 175),
		[prov, army],
		"army_sparta" # already selected
	)
	_assert(hit["hit"] and hit["type"] == "province", "Tap-again should cycle to underlying province", failures)
	_assert(hit["id"] == "prov_sparta", "Selected ID should cycle to prov_sparta", failures)

static func test_input_gate_rejection(failures: Array[String]) -> void:
	_assert(CampaignInputRouter.can_process_input(0), "IDLE state (0) should allow input", failures)
	_assert(not CampaignInputRouter.can_process_input(1), "PROCESSING_TURN (1) must reject input", failures)
	_assert(not CampaignInputRouter.can_process_input(2), "AWAITING_PLAYER_BATTLE (2) must reject map input", failures)
