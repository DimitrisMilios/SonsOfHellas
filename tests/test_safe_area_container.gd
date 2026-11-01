class_name TestSafeAreaContainer
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	
	test_standard_safe_area_insets(failures)
	test_invalid_zero_safe_area_fallback(failures)
	test_negative_coordinates_fallback(failures)
	test_max_percentage_clamping(failures)
	test_debug_override(failures)
	
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_standard_safe_area_insets(failures: Array[String]) -> void:
	var win: Vector2i = Vector2i(1920, 1080)
	var safe: Rect2i = Rect2i(80, 40, 1760, 1000)
	# left = 80, right = 1920 - 1840 = 80, top = 40, bottom = 1080 - 1040 = 40 + 8 extra = 48
	var insets: Dictionary = SafeAreaContainer.calculate_safe_insets(win, safe, 1.0, 8, 0.20)
	
	_assert(insets["left"] == 80, "Left inset should be 80", failures)
	_assert(insets["right"] == 80, "Right inset should be 80", failures)
	_assert(insets["top"] == 40, "Top inset should be 40", failures)
	_assert(insets["bottom"] == 48, "Bottom inset should be 40 + 8 = 48", failures)

static func test_invalid_zero_safe_area_fallback(failures: Array[String]) -> void:
	var win: Vector2i = Vector2i(1280, 720)
	var safe: Rect2i = Rect2i(0, 0, 0, 0)
	var insets: Dictionary = SafeAreaContainer.calculate_safe_insets(win, safe, 1.0, 8, 0.20)
	
	_assert(insets["left"] == 0, "Zero safe area should fallback to 0 left inset", failures)
	_assert(insets["right"] == 0, "Zero safe area should fallback to 0 right inset", failures)
	_assert(insets["top"] == 0, "Zero safe area should fallback to 0 top inset", failures)
	_assert(insets["bottom"] == 0, "Zero safe area should fallback to 0 bottom inset without extra pad", failures)

static func test_negative_coordinates_fallback(failures: Array[String]) -> void:
	var win: Vector2i = Vector2i(1280, 720)
	var safe: Rect2i = Rect2i(-50, -20, 1000, 600)
	var insets: Dictionary = SafeAreaContainer.calculate_safe_insets(win, safe, 1.0, 8, 0.20)
	
	_assert(insets["left"] == 0 and insets["top"] == 0, "Negative safe area coords must fallback to 0", failures)

static func test_max_percentage_clamping(failures: Array[String]) -> void:
	var win: Vector2i = Vector2i(1000, 1000)
	# Safe area starting at 400 (40% of screen)
	var safe: Rect2i = Rect2i(400, 400, 200, 200)
	# Clamped to 20% (200 px max)
	var insets: Dictionary = SafeAreaContainer.calculate_safe_insets(win, safe, 1.0, 0, 0.20)
	
	_assert(insets["left"] == 200, "Left inset must clamp to 200 (20% of 1000)", failures)
	_assert(insets["top"] == 200, "Top inset must clamp to 200 (20% of 1000)", failures)

static func test_debug_override(failures: Array[String]) -> void:
	var win: Vector2i = Vector2i(1920, 1080)
	var real_safe: Rect2i = Rect2i(0, 0, 0, 0) # Real is 0
	var debug_safe: Rect2i = Rect2i(60, 30, 1800, 1020)
	
	var insets: Dictionary = SafeAreaContainer.calculate_safe_insets(win, real_safe, 1.0, 8, 0.20, debug_safe)
	_assert(insets["left"] == 60, "Debug override should be respected when provided", failures)
	_assert(insets["top"] == 30, "Debug override top inset should be 30", failures)
