class_name SafeAreaContainer
extends MarginContainer

## Extra padding added to the bottom margin to clear the mobile gesture bar.
@export var extra_bottom_padding: int = 8

## Maximum fraction of screen dimension any single margin can consume (prevents layout collapse).
@export_range(0.05, 0.40, 0.01) var max_inset_percentage: float = 0.20

## Optional debug safe area insets to simulate notches/cutouts on desktop.
@export var debug_safe_area_insets: Rect2i = Rect2i(0, 0, 0, 0)

func _ready() -> void:
	apply_safe_area()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_size_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	# Debounce by 1 frame to let fold/unfold or orientation rotation settle
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree != null and not tree.process_frame.is_connected(apply_safe_area):
			tree.process_frame.connect(apply_safe_area, CONNECT_ONE_SHOT)
	else:
		apply_safe_area()

## Pure static calculation for safe area insets with robust fallbacks and clamping.
static func calculate_safe_insets(
	window_size: Vector2i,
	safe_area_rect: Rect2i,
	stretch_scale: float = 1.0,
	extra_bottom: int = 8,
	max_pct: float = 0.20,
	debug_override: Rect2i = Rect2i(0, 0, 0, 0)
) -> Dictionary:
	var active_rect: Rect2i = debug_override if debug_override.size != Vector2i.ZERO else safe_area_rect
	
	# Fallback: if zero, invalid, or negative coords, return zero insets
	if active_rect.size.x <= 0 or active_rect.size.y <= 0 or active_rect.position.x < 0 or active_rect.position.y < 0:
		return {
			"left": 0,
			"top": 0,
			"right": 0,
			"bottom": 0
		}
		
	var scale_factor: float = maxf(0.001, stretch_scale)
	
	var raw_left: int = active_rect.position.x
	var raw_top: int = active_rect.position.y
	var raw_right: int = maxi(0, window_size.x - (active_rect.position.x + active_rect.size.x))
	var raw_bottom: int = maxi(0, window_size.y - (active_rect.position.y + active_rect.size.y))
	
	var left_v: int = roundi(float(raw_left) / scale_factor)
	var top_v: int = roundi(float(raw_top) / scale_factor)
	var right_v: int = roundi(float(raw_right) / scale_factor)
	var bottom_v: int = roundi(float(raw_bottom) / scale_factor) + extra_bottom
	
	var max_w: int = roundi(float(window_size.x) * max_pct)
	var max_h: int = roundi(float(window_size.y) * max_pct)
	
	return {
		"left": clampi(left_v, 0, max_w),
		"top": clampi(top_v, 0, max_h),
		"right": clampi(right_v, 0, max_w),
		"bottom": clampi(bottom_v, 0, max_h)
	}

## Applies calculated insets to margin container theme overrides.
func apply_safe_area() -> void:
	var win_size: Vector2i = DisplayServer.window_get_size()
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	
	var stretch_factor: float = 1.0
	if get_viewport() != null:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		if vp_size.x > 0:
			stretch_factor = float(win_size.x) / vp_size.x
			
	var insets: Dictionary = calculate_safe_insets(
		win_size,
		safe_rect,
		stretch_factor,
		extra_bottom_padding,
		max_inset_percentage,
		debug_safe_area_insets
	)
	
	add_theme_constant_override("margin_left", insets["left"])
	add_theme_constant_override("margin_top", insets["top"])
	add_theme_constant_override("margin_right", insets["right"])
	add_theme_constant_override("margin_bottom", insets["bottom"])
