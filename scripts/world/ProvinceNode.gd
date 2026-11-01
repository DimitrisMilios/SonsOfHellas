class_name ProvinceNode
extends Node2D

const BASE_RADIUS: float = 56.0

const TIER_NAMES: Dictionary = {
	1: "Fort",
	2: "Town",
	3: "City",
	4: "Metropolis",
	5: "Citadel"
}

@export var province_id: String = ""
@export var province_data: ProvinceData = null:
	set(value):
		province_data = value
		if value == null:
			view_model = null
			queue_redraw()
		else:
			var vm: ProvinceViewModel = ProvinceViewModel.from_province_data(value)
			update_view(vm)

var view_model: ProvinceViewModel = null
var label: Label = null

var is_hovered: bool = false
var is_selected: bool = false
var effective_touch_radius: float = BASE_RADIUS

func _ready() -> void:
	set_process(false)
	_ensure_child_nodes()
	queue_redraw()

func _ensure_child_nodes() -> void:
	if label == null:
		label = get_node_or_null("Label") as Label
		if label == null:
			label = Label.new()
			add_child(label)
		if label == null:
			label = Label.new()
			add_child(label)

## Ingests an immutable view-model snapshot and refreshes visuals.
func update_view(vm: ProvinceViewModel) -> void:
	_ensure_child_nodes()
	view_model = vm
	if vm != null:
		province_id = vm.province_id
		position = vm.map_position
		if label != null:
			label.text = "%s\n[%s - %s]" % [vm.province_name, vm.owner_faction_id.to_upper(), get_settlement_tier_name()]
	queue_redraw()

## Binds raw ProvinceData domain model directly to node visuals.
func set_province_data(data: ProvinceData) -> void:
	self.province_data = data

func get_settlement_tier() -> int:
	if view_model != null:
		return view_model.settlement_tier
	if province_data != null:
		return province_data.settlement_level
	return 1

func get_settlement_tier_name() -> String:
	return TIER_NAMES.get(get_settlement_tier(), "Fort")

func has_unrest_alert() -> bool:
	if view_model != null:
		return view_model.unrest_pressure > 0 or view_model.consecutive_unrest_turns > 0 or view_model.public_order < 0.0
	if province_data != null:
		return province_data.unrest_pressure > 0 or province_data.consecutive_unrest_turns > 0 or province_data.public_order < 0.0
	return false

func get_faction_color() -> Color:
	var fid: String = ""
	if view_model != null:
		fid = view_model.owner_faction_id.to_lower()
	elif province_data != null:
		fid = province_data.owner_faction_id.to_lower()

	match fid:
		"sparta":
			return Color(0.80, 0.15, 0.15, 0.85)
		"athens":
			return Color(0.15, 0.45, 0.85, 0.85)
		"thebes":
			return Color(0.85, 0.65, 0.10, 0.85)
		"faction_rebels":
			return Color(0.35, 0.35, 0.35, 0.85)
		_:
			return Color(0.35, 0.45, 0.60, 0.80)

## Recomputes touch hit-target radius on camera zoom change.
func set_zoom(zoom_x: float) -> void:
	effective_touch_radius = CampaignInputRouter.calculate_effective_world_radius(BASE_RADIUS, zoom_x)

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func set_hovered(hovered: bool) -> void:
	is_hovered = hovered
	queue_redraw()

func _draw() -> void:
	var tier: int = get_settlement_tier()
	var fill_color: Color = get_faction_color()
	var radius: float = BASE_RADIUS + float(tier * 3.0)
	
	draw_circle(Vector2.ZERO, radius, fill_color)
	
	# Selection / hover outline
	var border_color: Color = Color.GOLD if is_selected else (Color.WHITE if is_hovered else Color.BLACK)
	var border_width: float = 4.0 if (is_selected or is_hovered) else 2.5
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, border_color, border_width)
	
	# Unrest warning indicator ring and badge if has_unrest_alert()
	if has_unrest_alert():
		var alert_color: Color = Color.RED
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 32, alert_color, 3.5)
		# Red alert badge in top-right corner
		var badge_pos: Vector2 = Vector2(radius * 0.70, -radius * 0.70)
		draw_circle(badge_pos, 8.0, Color.RED)
		draw_circle(badge_pos, 4.0, Color.WHITE)
		
	# Settlement tier pips along bottom
	for i in range(tier):
		var pip_x: float = -radius + 16.0 + (float(i) * 12.0)
		draw_circle(Vector2(pip_x, radius - 12.0), 3.5, Color.GOLD)
