class_name ArmyNode
extends Area2D

const BASE_BOX_SIZE: Vector2 = Vector2(52.0, 52.0)

@export var army_id: String = ""
var view_model: ArmyViewModel = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

var is_hovered: bool = false
var is_selected: bool = false
var is_moving: bool = false
var effective_box_size: Vector2 = BASE_BOX_SIZE
var active_tween: Tween = null

func _ready() -> void:
	input_pickable = false # Managed centrally by CampaignInputRouter
	_update_collision_shape()
	queue_redraw()

## Ingests an immutable view-model snapshot and refreshes visuals.
func update_view(vm: ArmyViewModel) -> void:
	view_model = vm
	if vm != null:
		army_id = vm.army_id
		if label != null:
			label.text = "%s\n(%d Units | %.0f AP)" % [vm.army_name, vm.unit_cards.size(), vm.current_action_points]
	queue_redraw()

## Recomputes touch hit-target box size on camera zoom change.
func set_zoom(zoom_x: float) -> void:
	effective_box_size = CampaignInputRouter.calculate_effective_box_size(BASE_BOX_SIZE, zoom_x)
	_update_collision_shape()

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func set_hovered(hovered: bool) -> void:
	is_hovered = hovered
	queue_redraw()

func _update_collision_shape() -> void:
	if collision_shape != null:
		var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		if rect_shape == null:
			rect_shape = RectangleShape2D.new()
			collision_shape.shape = rect_shape
		rect_shape.size = effective_box_size

## Animates movement to destination and updates state safely.
func animate_move_to(destination: Vector2, duration: float = 0.45) -> Tween:
	cancel_active_tween()
	is_moving = true
	active_tween = create_tween()
	active_tween.tween_property(self, "position", destination, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_callback(func() -> void:
		is_moving = false
		queue_redraw()
	)
	return active_tween

func cancel_active_tween() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
		active_tween = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cancel_active_tween()

func _draw() -> void:
	var owner_fid: String = view_model.owner_faction_id if view_model != null else ""
	var stance_type: ArmyData.Stance = view_model.stance if view_model != null else ArmyData.Stance.NORMAL
	var current_ap: float = view_model.current_action_points if view_model != null else 100.0
	var max_ap: float = view_model.max_action_points if view_model != null else 100.0
	
	var shield_size: Vector2 = Vector2(40.0, 48.0)
	var rect: Rect2 = Rect2(-shield_size.x / 2.0, -shield_size.y / 2.0, shield_size.x, shield_size.y)
	
	var bg_color: Color = Color(0.75, 0.2, 0.2) if owner_fid == "sparta" else Color(0.2, 0.45, 0.8)
	if owner_fid == "thebes":
		bg_color = Color(0.85, 0.65, 0.1)
	elif owner_fid == "faction_rebels":
		bg_color = Color(0.3, 0.3, 0.3)
		
	draw_rect(rect, bg_color, true)
	
	var border_color: Color = Color.GOLD if is_selected else (Color.WHITE if is_hovered else Color.BLACK)
	var border_width: float = 3.5 if (is_selected or is_hovered) else 2.0
	draw_rect(rect, border_color, false, border_width)
	
	# Stance highlight ring
	if stance_type == ArmyData.Stance.RAIDING:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color.ORANGE_RED, 2.5)
	elif stance_type == ArmyData.Stance.SIEGE:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color.PURPLE, 2.5)
	elif stance_type == ArmyData.Stance.FORCED_MARCH:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color.YELLOW, 2.5)
		
	# General star icon
	draw_circle(Vector2(0, -12.0), 5.0, Color.GOLD)
	
	# Action Points bar underneath
	var ap_pct: float = current_ap / maxf(1.0, max_ap)
	var bar_width: float = 38.0
	var bar_rect_bg: Rect2 = Rect2(-bar_width / 2.0, 26.0, bar_width, 6.0)
	var bar_rect_fill: Rect2 = Rect2(-bar_width / 2.0, 26.0, bar_width * ap_pct, 6.0)
	draw_rect(bar_rect_bg, Color(0.15, 0.15, 0.15, 0.85), true)
	draw_rect(bar_rect_fill, Color(0.15, 0.85, 0.25, 0.95), true)
