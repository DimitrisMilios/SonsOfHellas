class_name TestCampaignCamera
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_camera_zoom_clamping(failures)
	test_camera_position_bounds(failures)
	test_zoom_changed_signal(failures)
	test_inertia_damping(failures)
	return failures

static func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

static func test_camera_zoom_clamping(failures: Array[String]) -> void:
	var camera: CampaignCamera = CampaignCamera.new()
	camera.min_zoom = 0.4
	camera.max_zoom = 2.2
	camera._ready()
	
	# Attempt to set zoom beyond max limit
	camera._adjust_zoom(5.0)
	_assert(camera.target_zoom.x <= camera.max_zoom + 0.0001, "Target zoom must not exceed max_zoom (2.2), got: " + str(camera.target_zoom.x), failures)
	
	# Attempt to set zoom below min limit
	camera._adjust_zoom(-10.0)
	_assert(camera.target_zoom.x >= camera.min_zoom - 0.0001, "Target zoom must not go below min_zoom (0.4), got: " + str(camera.target_zoom.x), failures)
	
	camera.free()

static func test_camera_position_bounds(failures: Array[String]) -> void:
	var camera: CampaignCamera = CampaignCamera.new()
	camera.map_bounds_min = Vector2(-200.0, -200.0)
	camera.map_bounds_max = Vector2(2000.0, 1500.0)
	camera._ready()
	
	# Push position beyond top-left bounds
	camera.position = Vector2(-500.0, -800.0)
	camera._clamp_camera_position()
	_assert(camera.position.x == -200.0 and camera.position.y == -200.0,
		"Camera position must clamp to map_bounds_min, got: " + str(camera.position), failures)
	
	# Push position beyond bottom-right bounds
	camera.position = Vector2(3000.0, 2500.0)
	camera._clamp_camera_position()
	_assert(camera.position.x == 2000.0 and camera.position.y == 1500.0,
		"Camera position must clamp to map_bounds_max, got: " + str(camera.position), failures)
	
	camera.free()

static func test_zoom_changed_signal(failures: Array[String]) -> void:
	var camera: CampaignCamera = CampaignCamera.new()
	camera.min_zoom = 0.4
	camera.max_zoom = 2.2
	camera._ready()
	
	var emitted_zoom: Array = [Vector2.ZERO]
	camera.zoom_changed.connect(func(z: Vector2) -> void:
		emitted_zoom[0] = z
	)
	
	camera.target_zoom = Vector2(1.5, 1.5)
	camera._smooth_zoom(1.0) # Apply smoothing step
	
	_assert(emitted_zoom[0] != Vector2.ZERO, "zoom_changed signal should be emitted on zoom update", failures)
	_assert(absf(camera.zoom.x - emitted_zoom[0].x) < 0.001, "Emitted zoom must match camera zoom", failures)
	
	camera.free()

static func test_inertia_damping(failures: Array[String]) -> void:
	var camera: CampaignCamera = CampaignCamera.new()
	camera.inertia_friction = 0.90
	camera._ready()
	
	camera.pan_velocity = Vector2(500.0, 500.0)
	camera._apply_touch_inertia(1.0 / 60.0) # 1 frame
	
	_assert(camera.pan_velocity.length() < 707.0, "Pan velocity must damp over time", failures)
	_assert(camera.pan_velocity.x > 0.0, "Pan velocity should remain positive while decaying", failures)
	
	# Simulate 120 frames of decay (2 seconds)
	for i in range(120):
		camera._apply_touch_inertia(1.0 / 60.0)
	
	_assert(camera.pan_velocity == Vector2.ZERO, "Pan velocity must eventually come to complete rest", failures)
	
	camera.free()
