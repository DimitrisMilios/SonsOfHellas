class_name ArmyNode
extends Node2D

const BASE_BOX_SIZE: Vector2 = Vector2(52.0, 52.0)
const BASE_MOVEMENT_RADIUS: float = 120.0
const ZOC_RADIUS: float = 64.0

@export var army_id: String = ""
@export var army_data: ArmyData = null:
	set(value):
		army_data = value
		if value == null:
			view_model = null
			queue_redraw()
		else:
			var vm: ArmyViewModel = ArmyViewModel.from_army_data(value)
			update_view(vm)

var view_model: ArmyViewModel = null
var label: Label = null

var is_hovered: bool = false
var is_selected: bool = false
var is_moving: bool = false
var effective_box_size: Vector2 = BASE_BOX_SIZE
var active_tween: Tween = null

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
func update_view(vm: ArmyViewModel) -> void:
	_ensure_child_nodes()
	view_model = vm
	if vm != null:
		army_id = vm.army_id
		if label != null:
			label.text = "%s\n(%d Units | %.0f AP)" % [vm.army_name, vm.unit_cards.size(), vm.current_action_points]
	queue_redraw()

## Binds raw ArmyData domain model directly to node visuals.
func set_army_data(data: ArmyData) -> void:
	self.army_data = data

func get_unit_count() -> int:
	if view_model != null:
		return view_model.unit_cards.size()
	if army_data != null:
		return army_data.units.size()
	return 0

func get_stance() -> ArmyData.Stance:
	if view_model != null:
		return view_model.stance
	if army_data != null:
		return army_data.stance
	return ArmyData.Stance.NORMAL

func get_stance_name() -> String:
	if view_model != null:
		return view_model.stance_name
	if army_data != null:
		return army_data.get_stance_name()
	return "Normal"

func get_faction_color() -> Color:
	var fid: String = ""
	if view_model != null:
		fid = view_model.owner_faction_id.to_lower()
	elif army_data != null:
		fid = army_data.owner_faction_id.to_lower()

	match fid:
		"sparta":
			return Color(0.80, 0.15, 0.15, 0.90)
		"athens":
			return Color(0.15, 0.45, 0.85, 0.90)
		"thebes":
			return Color(0.85, 0.65, 0.10, 0.90)
		"faction_rebels":
			return Color(0.35, 0.35, 0.35, 0.90)
		_:
			return Color(0.40, 0.50, 0.60, 0.85)

func get_movement_circle_radius() -> float:
	var cur_ap: float = 0.0
	var max_ap: float = 100.0
	if view_model != null:
		cur_ap = view_model.current_action_points
		max_ap = view_model.max_action_points
	elif army_data != null:
		cur_ap = army_data.current_action_points
		max_ap = army_data.max_action_points

	if cur_ap <= 0.001:
		return 0.0
	return (cur_ap / maxf(1.0, max_ap)) * BASE_MOVEMENT_RADIUS

func get_zoc_radius() -> float:
	return ZOC_RADIUS

## Recomputes touch hit-target box size on camera zoom change.
func set_zoom(zoom_x: float) -> void:
	effective_box_size = CampaignInputRouter.calculate_effective_box_size(BASE_BOX_SIZE, zoom_x)

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func set_hovered(hovered: bool) -> void:
	is_hovered = hovered
	queue_redraw()

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
	var stance_type: ArmyData.Stance = get_stance()
	var current_ap: float = view_model.current_action_points if view_model != null else (army_data.current_action_points if army_data != null else 100.0)
	var max_ap: float = view_model.max_action_points if view_model != null else (army_data.max_action_points if army_data != null else 100.0)
	
	# Movement range AP circle (yellow ring) and ZoC radius (red ring) when selected
	if is_selected:
		var mov_rad: float = get_movement_circle_radius()
		if mov_rad > 0.0:
			draw_arc(Vector2.ZERO, mov_rad, 0.0, TAU, 48, Color(1.0, 0.85, 0.2, 0.7), 2.5)
		draw_arc(Vector2.ZERO, get_zoc_radius(), 0.0, TAU, 36, Color(1.0, 0.25, 0.25, 0.55), 2.0)
	
	# Army Banner / Shield Box
	var shield_size: Vector2 = Vector2(40.0, 48.0)
	var rect: Rect2 = Rect2(-shield_size.x / 2.0, -shield_size.y / 2.0, shield_size.x, shield_size.y)
	var bg_color: Color = get_faction_color()
	draw_rect(rect, bg_color, true)
	
	var border_color: Color = Color.GOLD if is_selected else (Color.WHITE if is_hovered else Color.BLACK)
	var border_width: float = 3.5 if (is_selected or is_hovered) else 2.0
	draw_rect(rect, border_color, false, border_width)
	
	# Tactical stance indicator ring
	match stance_type:
		ArmyData.Stance.FORCED_MARCH:
			draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color.YELLOW, 2.5)
		ArmyData.Stance.RAIDING:
			draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color.ORANGE_RED, 2.5)
		ArmyData.Stance.ENCAMPMENT:
			draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color.LIGHT_GREEN, 2.5)
		ArmyData.Stance.AMBUSH:
			draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color.MEDIUM_PURPLE, 2.5)
		ArmyData.Stance.SIEGE:
			draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color.PURPLE, 2.5)

	# General command star icon
	draw_circle(Vector2(0, -12.0), 5.0, Color.GOLD)
	
	# Unit count badge (top right)
	var badge_pos: Vector2 = Vector2(shield_size.x / 2.0 - 2.0, -shield_size.y / 2.0 + 2.0)
	draw_circle(badge_pos, 7.0, Color.BLACK)
	draw_circle(badge_pos, 5.0, Color.GOLD)
	
	# Action Points bar underneath
	var ap_pct: float = current_ap / maxf(1.0, max_ap)
	var bar_width: float = 38.0
	var bar_rect_bg: Rect2 = Rect2(-bar_width / 2.0, 26.0, bar_width, 6.0)
	var bar_rect_fill: Rect2 = Rect2(-bar_width / 2.0, 26.0, bar_width * ap_pct, 6.0)
	draw_rect(bar_rect_bg, Color(0.15, 0.15, 0.15, 0.85), true)
	draw_rect(bar_rect_fill, Color(0.15, 0.85, 0.25, 0.95), true)
