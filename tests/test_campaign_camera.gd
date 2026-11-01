class_name TestCampaignCamera
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_camera_zoom_clamping(failures)
	test_camera_position_bounds(failures)
	test_touch_drag_pan(failures)
	test_pinch_zoom_simulation(failures)
	test_zoom_changed_signal(failures)
	test_inertia_damping(failures)
	test_keyboard_and_mouse_fallback(failures)
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
	_assert(camera.target_zoom.x <= camera.max_zoom + 0.0001, 
		"Target zoom must not exceed max_zoom (2.2), got: " + str(camera.target_zoom.x), failures)
	
	# Attempt to set zoom below min limit
	camera._adjust_zoom(-10.0)
	_assert(camera.target_zoom.x >= camera.min_zoom - 0.0001, 
		"Target zoom must not go below min_zoom (0.4), got: " + str(camera.target_zoom.x), failures)
	
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

static func test_touch_drag_pan(failures: Array[String]) -> void:
	var camera: CampaignCamera = CampaignCamera.new()
	camera.map_bounds_min = Vector2(-1000.0, -1000.0)
	camera.map_bounds_max = Vector2(3000.0, 3000.0)
	camera.position = Vector2(500.0, 500.0)
	camera._ready()
	
	# Touch 0 pressed
	var touch_down: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = Vector2(200.0, 200.0)
	camera._unhandled_input(touch_down)
	
	# Drag 0 by (50, 0)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(250.0, 200.0)
	drag.relative = Vector2(50.0, 0.0)
	camera._unhandled_input(drag)
	
	_assert(camera.position.x < 500.0, "Dragging right should pan camera left, got: " + str(camera.position.x), failures)
	_assert(camera.pan_velocity.x != 0.0, "Pan velocity should be registered from drag", failures)
	
	# Touch 0 released
	var touch_up: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	camera._unhandled_input(touch_up)
	
	_assert(camera.touches.is_empty(), "Touches should be cleared on release", failures)
	camera.free()

static func test_pinch_zoom_simulation(failures: Array[String]) -> void:
	var camera: CampaignCamera = CampaignCamera.new()
	camera.min_zoom = 0.4
	camera.max_zoom = 2.2
	camera._ready()
	
	# Touch 0 pressed at (100, 100)
	var t0: InputEventScreenTouch = InputEventScreenTouch.new()
	t0.index = 0
	t0.pressed = true
	t0.position = Vector2(100.0, 100.0)
	camera._unhandled_input(t0)
	
	# Touch 1 pressed at (200, 100) -> initial distance = 100.0
	var t1: InputEventScreenTouch = InputEventScreenTouch.new()
	t1.index = 1
	t1.pressed = true
	t1.position = Vector2(200.0, 100.0)
	camera._unhandled_input(t1)
	
	_assert(is_equal_approx(camera.initial_pinch_distance, 100.0), 
		"Initial pinch distance should be 100.0, got: " + str(camera.initial_pinch_distance), failures)
	
	# Drag touch 1 to (300, 100) -> current distance = 200.0 (pinch factor 2.0x)
	var drag1: InputEventScreenDrag = InputEventScreenDrag.new()
	drag1.index = 1
	drag1.position = Vector2(300.0, 100.0)
	camera._unhandled_input(drag1)
	
	_assert(camera.target_zoom.x > 1.0, "Spreading fingers should increase zoom, got: " + str(camera.target_zoom.x), failures)
	_assert(camera.target_zoom.x <= 2.2, "Pinch zoom must clamp to max_zoom (2.2), got: " + str(camera.target_zoom.x), failures)
	
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

static func test_keyboard_and_mouse_fallback(failures: Array[String]) -> void:
	var camera: CampaignCamera = CampaignCamera.new()
	camera._ready()
	
	var initial_zoom: float = camera.target_zoom.x
	
	# Mouse wheel up zooms in
	var wheel_up: InputEventMouseButton = InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	camera._unhandled_input(wheel_up)
	_assert(camera.target_zoom.x > initial_zoom, "Mouse wheel up should increase target zoom", failures)
	
	# Mouse middle drag pans
	var mouse_down: InputEventMouseButton = InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_MIDDLE
	mouse_down.pressed = true
	camera._unhandled_input(mouse_down)
	_assert(camera.is_mouse_dragging, "Middle mouse click should set is_mouse_dragging to true", failures)
	
	var initial_pos: Vector2 = camera.position
	var mouse_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(40.0, 20.0)
	camera._unhandled_input(mouse_motion)
	_assert(camera.position != initial_pos, "Mouse motion while dragging should update position", failures)
	
	camera.free()
