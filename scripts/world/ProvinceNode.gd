class_name ProvinceNode
extends Area2D

const BASE_RADIUS: float = 56.0

@export var province_id: String = ""
var view_model: ProvinceViewModel = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

var is_hovered: bool = false
var is_selected: bool = false
var effective_touch_radius: float = BASE_RADIUS

func _ready() -> void:
	input_pickable = false # Managed centrally by CampaignInputRouter
	_update_collision_shape()
	queue_redraw()

## Ingests an immutable view-model snapshot and refreshes visuals.
func update_view(vm: ProvinceViewModel) -> void:
	view_model = vm
	if vm != null:
		province_id = vm.province_id
		position = vm.map_position
		if label != null:
			label.text = "%s\n[%s]" % [vm.province_name, vm.owner_faction_id.to_upper()]
	queue_redraw()

## Recomputes touch hit-target radius on camera zoom change.
func set_zoom(zoom_x: float) -> void:
	effective_touch_radius = CampaignInputRouter.calculate_effective_world_radius(BASE_RADIUS, zoom_x)
	_update_collision_shape()

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func set_hovered(hovered: bool) -> void:
	is_hovered = hovered
	queue_redraw()

func _update_collision_shape() -> void:
	if collision_shape != null:
		var circle: CircleShape2D = collision_shape.shape as CircleShape2D
		if circle == null:
			circle = CircleShape2D.new()
			collision_shape.shape = circle
		circle.radius = effective_touch_radius

func _draw() -> void:
	var tier: int = view_model.settlement_tier if view_model != null else 1
	var owner_fid: String = view_model.owner_faction_id if view_model != null else ""
	var unrest_p: int = view_model.unrest_pressure if view_model != null else 0
	
	var fill_color: Color = Color(0.25, 0.45, 0.75, 0.8) # Neutral / default
	if owner_fid == "sparta":
		fill_color = Color(0.75, 0.15, 0.15, 0.85)
	elif owner_fid == "athens":
		fill_color = Color(0.15, 0.45, 0.85, 0.85)
	elif owner_fid == "thebes":
		fill_color = Color(0.85, 0.65, 0.10, 0.85)
	elif owner_fid == "faction_rebels":
		fill_color = Color(0.35, 0.35, 0.35, 0.85)
		
	var radius: float = BASE_RADIUS + float(tier * 3.0)
	draw_circle(Vector2.ZERO, radius, fill_color)
	
	# Selection / hover outline
	var border_color: Color = Color.GOLD if is_selected else (Color.WHITE if is_hovered else Color.BLACK)
	var border_width: float = 4.0 if (is_selected or is_hovered) else 2.5
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, border_color, border_width)
	
	# Unrest warning indicator ring if unrest_pressure > 0
	if unrest_p > 0:
		var alert_color: Color = Color.ORANGE_RED if unrest_p >= 2 else Color.ORANGE
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 32, alert_color, 3.0)
		
	# Settlement tier pips
	for i in range(tier):
		var pip_x: float = -radius + 16.0 + (float(i) * 12.0)
		draw_circle(Vector2(pip_x, radius - 12.0), 3.5, Color.GOLD)
