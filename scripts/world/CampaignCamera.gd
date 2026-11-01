class_name CampaignCamera
extends Camera2D

@export_group("Pan Settings")
@export var pan_speed: float = 650.0
@export var drag_speed: float = 1.0
@export var pan_smoothing: float = 14.0
@export var inertia_friction: float = 0.90

@export_group("Zoom Settings")
@export var zoom_speed: float = 0.15
@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.2
@export var zoom_smoothness: float = 12.0

@export_group("Map Boundaries")
@export var map_bounds_min: Vector2 = Vector2(-200.0, -200.0)
@export var map_bounds_max: Vector2 = Vector2(2000.0, 1500.0)

# Touch tracking dictionary: touch_index (int) -> ScreenPosition (Vector2)
var touches: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_pinch_zoom: Vector2 = Vector2.ONE
var pan_velocity: Vector2 = Vector2.ZERO

var target_zoom: Vector2 = Vector2.ONE
var is_mouse_dragging: bool = false

func _ready() -> void:
	target_zoom = zoom

func _process(delta: float) -> void:
	_handle_pan_keys(delta)
	_apply_touch_inertia(delta)
	_smooth_zoom(delta)
	_clamp_camera_position()

func _unhandled_input(event: InputEvent) -> void:
	# --- Touch Events (Mobile Touch & Pinch-to-Zoom) ---
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			pan_velocity = Vector2.ZERO
			if touches.size() == 2:
				var touch_keys: Array = touches.keys()
				initial_pinch_distance = touches[touch_keys[0]].distance_to(touches[touch_keys[1]])
				initial_pinch_zoom = target_zoom
		else:
			touches.erase(event.index)
			if touches.size() < 2:
				initial_pinch_distance = 0.0

	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 1:
			# Single finger drag: Pan camera
			var delta_pan: Vector2 = -event.relative * (1.0 / zoom.x) * drag_speed
			position += delta_pan
			pan_velocity = delta_pan / maxf(get_process_delta_time(), 0.001) * 0.04
		elif touches.size() == 2:
			# Two finger pinch: Zoom camera
			var touch_keys: Array = touches.keys()
			var current_dist: float = touches[touch_keys[0]].distance_to(touches[touch_keys[1]])
			if initial_pinch_distance > 10.0:
				var pinch_factor: float = current_dist / initial_pinch_distance
				var new_val: float = clampf(initial_pinch_zoom.x * pinch_factor, min_zoom, max_zoom)
				target_zoom = Vector2(new_val, new_val)

	# --- Desktop Mouse & Keyboard Controls (For Editor / PC Testing) ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_mouse_dragging = true
			else:
				is_mouse_dragging = false

	elif event is InputEventMouseMotion and is_mouse_dragging:
		position -= event.relative * (1.0 / zoom.x) * drag_speed

func _handle_pan_keys(delta: float) -> void:
	var move_vector: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vector.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vector.x += 1.0

	if move_vector != Vector2.ZERO:
		position += move_vector.normalized() * (pan_speed / zoom.x) * delta
		pan_velocity = Vector2.ZERO

func _apply_touch_inertia(delta: float) -> void:
	if touches.is_empty() and not is_mouse_dragging:
		if pan_velocity.length_squared() > 1.0:
			position += pan_velocity * delta
			pan_velocity *= pow(inertia_friction, delta * 60.0)
		else:
			pan_velocity = Vector2.ZERO

func _adjust_zoom(delta_zoom: float) -> void:
	var new_val: float = clampf(target_zoom.x + delta_zoom, min_zoom, max_zoom)
	target_zoom = Vector2(new_val, new_val)

func _smooth_zoom(delta: float) -> void:
	zoom = zoom.lerp(target_zoom, delta * zoom_smoothness)

func _clamp_camera_position() -> void:
	position.x = clampf(position.x, map_bounds_min.x, map_bounds_max.x)
	position.y = clampf(position.y, map_bounds_min.y, map_bounds_max.y)
