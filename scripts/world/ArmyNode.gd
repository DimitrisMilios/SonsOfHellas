class_name ArmyNode
extends Node2D

const BASE_BOX_SIZE: Vector2 = Vector2(52.0, 52.0)
const BASE_MOVEMENT_RADIUS: float = 120.0
const ZOC_RADIUS: float = 64.0

const TEX_HOPLITE: Texture2D = preload("res://assets/map/hoplite_avatar.png")
const SHIELD_SPARTA: Texture2D = preload("res://assets/ui/sparta_shield.png")
const SHIELD_ATHENS: Texture2D = preload("res://assets/ui/athens_shield.png")
const SHIELD_THEBES: Texture2D = preload("res://assets/ui/thebes_shield.png")
const SHIELD_CORINTH: Texture2D = preload("res://assets/ui/corinth_shield.png")
const SHIELD_ROME: Texture2D = preload("res://assets/ui/rome_shield.png")
const SHIELD_CARTHAGE: Texture2D = preload("res://assets/ui/carthage_shield.png")
const SHIELD_EGYPT: Texture2D = preload("res://assets/ui/egypt_shield.png")
const SHIELD_MACEDON: Texture2D = preload("res://assets/ui/macedon_shield.png")
const SHIELD_SELEUCID: Texture2D = preload("res://assets/ui/seleucid_shield.png")

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
			return Color(0.85, 0.15, 0.15, 0.90)
		"athens":
			return Color(0.15, 0.45, 0.85, 0.90)
		"thebes":
			return Color(0.85, 0.65, 0.10, 0.90)
		"corinth":
			return Color(0.15, 0.58, 0.62, 0.90)
		"rome":
			return Color(0.75, 0.10, 0.12, 0.90)
		"carthage":
			return Color(0.55, 0.15, 0.50, 0.90)
		"egypt":
			return Color(0.10, 0.60, 0.65, 0.90)
		"macedon", "thessaly":
			return Color(0.45, 0.15, 0.60, 0.90)
		"seleucid", "pontus":
			return Color(0.85, 0.45, 0.15, 0.90)
		"thrace":
			return Color(0.60, 0.40, 0.20, 0.90)
		"faction_rebels":
			return Color(0.35, 0.35, 0.35, 0.90)
		_:
			return Color(0.40, 0.50, 0.60, 0.85)

func get_faction_shield() -> Texture2D:
	var fid: String = ""
	if view_model != null:
		fid = view_model.owner_faction_id.to_lower()
	elif army_data != null:
		fid = army_data.owner_faction_id.to_lower()

	match fid:
		"sparta":
			return SHIELD_SPARTA
		"athens":
			return SHIELD_ATHENS
		"thebes":
			return SHIELD_THEBES
		"corinth":
			return SHIELD_CORINTH
		"rome":
			return SHIELD_ROME
		"carthage":
			return SHIELD_CARTHAGE
		"egypt":
			return SHIELD_EGYPT
		"macedon", "thessaly":
			return SHIELD_MACEDON
		"seleucid", "pontus":
			return SHIELD_SELEUCID
		_:
			return SHIELD_SPARTA

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
	var bg_color: Color = get_faction_color()
	
	# Movement range AP circle (yellow ring) and ZoC radius (red ring) when selected
	if is_selected:
		var mov_rad: float = get_movement_circle_radius()
		if mov_rad > 0.0:
			draw_arc(Vector2.ZERO, mov_rad, 0.0, TAU, 48, Color(1.0, 0.85, 0.2, 0.7), 2.5)
		draw_arc(Vector2.ZERO, get_zoc_radius(), 0.0, TAU, 36, Color(1.0, 0.25, 0.25, 0.55), 2.0)
	
	# 1. Ground oval shadow
	draw_circle(Vector2(2.0, 16.0), 18.0, Color(0.0, 0.0, 0.0, 0.45))
	
	# 2. Plinth pedestal with faction colors
	draw_circle(Vector2(0.0, 14.0), 15.0, bg_color)
	var border_color: Color = Color.GOLD if is_selected else (Color.WHITE if is_hovered else Color.BLACK)
	var border_width: float = 3.0 if (is_selected or is_hovered) else 1.8
	draw_arc(Vector2(0.0, 14.0), 15.0, 0.0, TAU, 24, border_color, border_width)

	# 3. 3D Rendered Hoplite Warrior Figurine Avatar
	if TEX_HOPLITE != null:
		var hop_sz: Vector2 = Vector2(46.0, 46.0)
		var hop_rect: Rect2 = Rect2(-hop_sz.x * 0.5, -hop_sz.y * 0.75, hop_sz.x, hop_sz.y)
		draw_texture_rect(TEX_HOPLITE, hop_rect, false)

	# 4. Faction Crest Shield standard
	var shield_tex: Texture2D = get_faction_shield()
	if shield_tex != null:
		var s_sz: Vector2 = Vector2(24.0, 24.0)
		var s_rect: Rect2 = Rect2(10.0, -38.0, s_sz.x, s_sz.y)
		draw_texture_rect(shield_tex, s_rect, false)
	
	# 5. Action Points mini-gauge bar below the figurine
	var ap_pct: float = clampf(current_ap / maxf(1.0, max_ap), 0.0, 1.0)
	draw_rect(Rect2(-16.0, 22.0, 32.0, 4.0), Color(0.1, 0.1, 0.1, 0.8), true)
	var ap_col: Color = Color(0.2, 0.85, 0.3) if ap_pct > 0.5 else (Color(0.9, 0.8, 0.2) if ap_pct > 0.25 else Color(0.9, 0.2, 0.2))
	draw_rect(Rect2(-15.0, 23.0, 30.0 * ap_pct, 2.0), ap_col, true)
	
	# 6. Selected halo
	if is_selected:
		draw_arc(Vector2(0.0, 14.0), 22.0, 0.0, TAU, 32, Color(1.0, 0.84, 0.0, 0.9), 2.5)

	# 7. Tactical stance indicator ring
	match stance_type:
		ArmyData.Stance.FORCED_MARCH:
			draw_arc(Vector2(0.0, 14.0), 26.0, 0.0, TAU, 24, Color.YELLOW, 2.5)
		ArmyData.Stance.RAIDING:
			draw_arc(Vector2(0.0, 14.0), 26.0, 0.0, TAU, 24, Color.ORANGE_RED, 2.5)
		ArmyData.Stance.ENCAMPMENT:
			draw_arc(Vector2(0.0, 14.0), 26.0, 0.0, TAU, 24, Color.LIGHT_GREEN, 2.5)
		ArmyData.Stance.AMBUSH:
			draw_arc(Vector2(0.0, 14.0), 26.0, 0.0, TAU, 24, Color.MEDIUM_PURPLE, 2.5)
		ArmyData.Stance.SIEGE:
			draw_arc(Vector2(0.0, 14.0), 26.0, 0.0, TAU, 24, Color.PURPLE, 2.5)
