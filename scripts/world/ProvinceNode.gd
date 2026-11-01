class_name ProvinceNode
extends Node2D

const BASE_RADIUS: float = 56.0

const TEX_ACROPOLIS: Texture2D = preload("res://assets/map/settlement_acropolis.png")
const TEX_FORT: Texture2D = preload("res://assets/map/settlement_fort.png")
const SHIELD_SPARTA: Texture2D = preload("res://assets/ui/sparta_shield.png")
const SHIELD_ATHENS: Texture2D = preload("res://assets/ui/athens_shield.png")
const SHIELD_THEBES: Texture2D = preload("res://assets/ui/thebes_shield.png")
const SHIELD_CORINTH: Texture2D = preload("res://assets/ui/corinth_shield.png")
const SHIELD_ROME: Texture2D = preload("res://assets/ui/rome_shield.png")
const SHIELD_CARTHAGE: Texture2D = preload("res://assets/ui/carthage_shield.png")
const SHIELD_EGYPT: Texture2D = preload("res://assets/ui/egypt_shield.png")
const SHIELD_MACEDON: Texture2D = preload("res://assets/ui/macedon_shield.png")
const SHIELD_SELEUCID: Texture2D = preload("res://assets/ui/seleucid_shield.png")

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
			return Color(0.85, 0.15, 0.15, 0.85)
		"athens":
			return Color(0.15, 0.45, 0.85, 0.85)
		"thebes":
			return Color(0.85, 0.65, 0.12, 0.85)
		"corinth":
			return Color(0.15, 0.58, 0.62, 0.85)
		"rome":
			return Color(0.75, 0.10, 0.12, 0.85)
		"carthage":
			return Color(0.55, 0.15, 0.50, 0.85)
		"egypt":
			return Color(0.10, 0.60, 0.65, 0.85)
		"macedon", "thessaly":
			return Color(0.45, 0.15, 0.60, 0.85)
		"seleucid", "pontus":
			return Color(0.85, 0.45, 0.15, 0.85)
		"thrace":
			return Color(0.60, 0.40, 0.20, 0.85)
		_:
			return Color(0.35, 0.45, 0.60, 0.80)

func get_faction_shield() -> Texture2D:
	var fid: String = ""
	if view_model != null:
		fid = view_model.owner_faction_id.to_lower()
	elif province_data != null:
		fid = province_data.owner_faction_id.to_lower()

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
	
	# 1. Subtle drop-shadow on ground
	draw_circle(Vector2(2.0, 4.0), radius * 0.75, Color(0.0, 0.0, 0.0, 0.35))
	
	# 2. Carved stone plinth foundation
	draw_circle(Vector2.ZERO, radius * 0.72, Color(0.20, 0.18, 0.16, 0.75))
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 36, fill_color, 3.0)
	
	# 3. Selection / hover glowing aura
	if is_selected:
		draw_arc(Vector2.ZERO, radius * 0.88, 0.0, TAU, 48, Color(1.0, 0.84, 0.0, 0.9), 3.5)
	elif is_hovered:
		draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.8), 2.0)
	
	# 4. Settlement visual icon (3D Acropolis or Fort)
	var city_tex: Texture2D = TEX_ACROPOLIS if tier >= 3 else TEX_FORT
	if city_tex != null:
		var icon_sz: Vector2 = Vector2(52.0, 52.0) if tier >= 3 else Vector2(44.0, 44.0)
		var icon_rect: Rect2 = Rect2(-icon_sz.x * 0.5, -icon_sz.y * 0.65, icon_sz.x, icon_sz.y)
		draw_texture_rect(city_tex, icon_rect, false)

	# 5. Faction heraldic shield crest (top right)
	var shield_tex: Texture2D = get_faction_shield()
	if shield_tex != null:
		var shield_sz: Vector2 = Vector2(28.0, 28.0)
		var shield_rect: Rect2 = Rect2(12.0, -38.0, shield_sz.x, shield_sz.y)
		draw_texture_rect(shield_tex, shield_rect, false)

	# 6. Unrest warning indicator ring and badge if has_unrest_alert()
	if has_unrest_alert():
		var alert_color: Color = Color.RED
		draw_arc(Vector2.ZERO, radius * 0.80 + 6.0, 0.0, TAU, 32, alert_color, 3.0)
		var badge_pos: Vector2 = Vector2(radius * 0.55, -radius * 0.55)
		draw_circle(badge_pos, 7.0, Color.RED)
		draw_circle(badge_pos, 3.5, Color.WHITE)
		
	# 7. Settlement tier pips along bottom
	for i in range(tier):
		var pip_x: float = -radius * 0.45 + (float(i) * 12.0)
		draw_circle(Vector2(pip_x, radius * 0.45), 3.0, Color.GOLD)
