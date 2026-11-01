class_name CampaignInputRouter
extends RefCounted

## Minimum touch target dimension in screen pixels (Android/iOS standard)
const MIN_TOUCH_PX: float = 48.0
const MAX_TAP_DISPLACEMENT: float = 10.0
const MAX_TAP_DURATION_MS: float = 250.0

## Calculates clamped world-space radius guaranteeing at least MIN_TOUCH_PX on screen.
static func calculate_effective_world_radius(base_radius: float, zoom_x: float, min_px: float = MIN_TOUCH_PX) -> float:
	var safe_zoom: float = maxf(0.01, zoom_x)
	var min_world_radius: float = min_px / (2.0 * safe_zoom)
	return maxf(base_radius, min_world_radius)

## Calculates clamped world-space box size guaranteeing at least MIN_TOUCH_PX on screen.
static func calculate_effective_box_size(base_size: Vector2, zoom_x: float, min_px: float = MIN_TOUCH_PX) -> Vector2:
	var safe_zoom: float = maxf(0.01, zoom_x)
	var min_world_dim: float = min_px / safe_zoom
	return Vector2(maxf(base_size.x, min_world_dim), maxf(base_size.y, min_world_dim))

## Validates whether a touch interaction qualifies as a tap rather than a pan/pinch.
static func is_tap_gesture(
	press_pos: Vector2,
	release_pos: Vector2,
	duration_ms: float,
	max_disp: float = MAX_TAP_DISPLACEMENT,
	max_time: float = MAX_TAP_DURATION_MS
) -> bool:
	return press_pos.distance_to(release_pos) <= max_disp and duration_ms <= max_time

## Command gate check against CampaignState.IDLE (0).
static func can_process_input(campaign_state: int) -> bool:
	return campaign_state == 0

## Arbitrates touch candidates (armies and provinces) using priority and tap-again cycling.
static func pick_candidate(
	tap_world_pos: Vector2,
	candidates: Array,
	currently_selected_id: String = ""
) -> Dictionary:
	var hit_armies: Array[Dictionary] = []
	var hit_provinces: Array[Dictionary] = []
	
	for c: Variant in candidates:
		if not (c is Dictionary):
			continue
		var pos: Vector2 = c.get("pos", Vector2.ZERO)
		var c_type: String = str(c.get("type", ""))
		
		if c_type == "army":
			var box: Vector2 = c.get("box_size", Vector2(52, 52))
			var rect: Rect2 = Rect2(pos - (box / 2.0), box)
			if rect.has_point(tap_world_pos):
				hit_armies.append(c)
		else:
			var radius: float = float(c.get("radius", 56.0))
			if pos.distance_to(tap_world_pos) <= radius:
				hit_provinces.append(c)
				
	# 1. Tap-again cycling: if currently selected army is tapped again, switch to underlying province
	if not hit_armies.is_empty() and currently_selected_id != "":
		for a_hit: Dictionary in hit_armies:
			if a_hit.get("id") == currently_selected_id and not hit_provinces.is_empty():
				var underlying: Dictionary = hit_provinces[0]
				return {
					"hit": true,
					"id": str(underlying.get("id", "")),
					"type": "province"
				}
				
	# 2. Army hit priority over overlapping province
	if not hit_armies.is_empty():
		var best_army: Dictionary = hit_armies[0]
		return {
			"hit": true,
			"id": str(best_army.get("id", "")),
			"type": "army"
		}
		
	# 3. Closest candidate fallback
	var all_hits: Array[Dictionary] = []
	all_hits.append_array(hit_provinces)
	
	if all_hits.is_empty():
		return {"hit": false, "id": "", "type": ""}
		
	all_hits.sort_custom(func(c1: Dictionary, c2: Dictionary) -> bool:
		var p1: Vector2 = c1.get("pos", Vector2.ZERO)
		var p2: Vector2 = c2.get("pos", Vector2.ZERO)
		return p1.distance_to(tap_world_pos) < p2.distance_to(tap_world_pos)
	)
	
	var closest: Dictionary = all_hits[0]
	return {
		"hit": true,
		"id": str(closest.get("id", "")),
		"type": str(closest.get("type", "province"))
	}
