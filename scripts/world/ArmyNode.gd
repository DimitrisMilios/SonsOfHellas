class_name ArmyNode
extends Area2D

@export var army_data: ArmyData

@onready var label: Label = $Label

var is_hovered: bool = false
var is_selected: bool = false
var is_moving: bool = false

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	var campaign_mgr: CampaignManager = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null and army_data != null:
		campaign_mgr.register_army(army_data, self)
		campaign_mgr.army_selected.connect(_on_army_selected)
		campaign_mgr.selection_cleared.connect(_on_selection_cleared)
		campaign_mgr.army_movement_started.connect(_on_movement_started)
		
		# Position army at its starting province location
		if campaign_mgr.provinces.has(army_data.current_province_id):
			var prov: ProvinceData = campaign_mgr.provinces[army_data.current_province_id]
			# Slight offset from province center so settlement and army can both be clicked easily
			position = prov.map_position + Vector2(25.0, -25.0)

	_update_label()
	queue_redraw()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var campaign_mgr: CampaignManager = get_node_or_null("/root/CampaignManager")
		if campaign_mgr != null and army_data != null:
			campaign_mgr.select_army(army_data)

func _on_mouse_entered() -> void:
	is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()

func _on_army_selected(selected: ArmyData) -> void:
	is_selected = (selected == army_data)
	queue_redraw()

func _on_selection_cleared() -> void:
	is_selected = false
	queue_redraw()

func _on_movement_started(moving_army: ArmyData, _from_id: String, to_id: String) -> void:
	if moving_army != army_data:
		return
	
	var campaign_mgr: CampaignManager = get_node_or_null("/root/CampaignManager")
	if campaign_mgr == null or not campaign_mgr.provinces.has(to_id):
		return
	
	var target_province: ProvinceData = campaign_mgr.provinces[to_id]
	var destination: Vector2 = target_province.map_position + Vector2(25.0, -25.0)

	is_moving = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", destination, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		is_moving = false
		_update_label()
		queue_redraw()
	)

func _update_label() -> void:
	if label != null and army_data != null:
		label.text = "%s\n(%d Units | %.0f AP)" % [army_data.army_name, army_data.units.size(), army_data.current_action_points]

func _draw() -> void:
	if army_data == null:
		return

	# Distinct army shield shape
	var shield_size: Vector2 = Vector2(36.0, 44.0)
	var rect: Rect2 = Rect2(-shield_size.x / 2.0, -shield_size.y / 2.0, shield_size.x, shield_size.y)

	var bg_color: Color = Color(0.7, 0.2, 0.2) if army_data.owner_faction_id == "sparta" else Color(0.2, 0.4, 0.8)
	draw_rect(rect, bg_color, true)

	var border_color: Color = Color.GOLD if is_selected else (Color.WHITE if is_hovered else Color.BLACK)
	var border_width: float = 3.0 if (is_selected or is_hovered) else 1.5
	draw_rect(rect, border_color, false, border_width)

	# Leadership star icon
	draw_circle(Vector2(0, -10.0), 5.0, Color.GOLD)

	# AP mini bar underneath
	var ap_pct: float = army_data.current_action_points / maxf(army_data.max_action_points, 1.0)
	var bar_width: float = 34.0
	var bar_rect_bg: Rect2 = Rect2(-bar_width / 2.0, 24.0, bar_width, 5.0)
	var bar_rect_fill: Rect2 = Rect2(-bar_width / 2.0, 24.0, bar_width * ap_pct, 5.0)

	draw_rect(bar_rect_bg, Color(0.2, 0.2, 0.2, 0.8), true)
	draw_rect(bar_rect_fill, Color(0.1, 0.8, 0.2, 0.9), true)
