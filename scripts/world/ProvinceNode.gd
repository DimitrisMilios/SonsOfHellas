class_name ProvinceNode
extends Area2D

@export var province_data: ProvinceData

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

var is_hovered: bool = false
var is_selected: bool = false

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	if province_data != null:
		name = province_data.province_id
		position = province_data.map_position
		_update_label()
		# Register with CampaignManager
		var campaign_mgr: CampaignManager = get_node_or_null("/root/CampaignManager")
		if campaign_mgr != null:
			campaign_mgr.register_province(province_data, self)
			campaign_mgr.province_selected.connect(_on_province_selected)
			campaign_mgr.selection_cleared.connect(_on_selection_cleared)
			campaign_mgr.province_ownership_changed.connect(_on_ownership_changed)
	
	queue_redraw()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var campaign_mgr: CampaignManager = get_node_or_null("/root/CampaignManager")
		if campaign_mgr != null and province_data != null:
			campaign_mgr.select_province(province_data)

func _on_mouse_entered() -> void:
	is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()

func _on_province_selected(selected: ProvinceData) -> void:
	is_selected = (selected == province_data)
	queue_redraw()

func _on_selection_cleared() -> void:
	is_selected = false
	queue_redraw()

func _on_ownership_changed(changed_province: ProvinceData, _old_id: String, _new_id: String) -> void:
	if changed_province == province_data:
		_update_label()
		queue_redraw()

func _update_label() -> void:
	if label != null and province_data != null:
		label.text = "%s\n[%s]" % [province_data.province_name, province_data.owner_faction_id.to_upper()]

func _draw() -> void:
	if province_data == null:
		return
	
	# Determine faction color
	var fill_color: Color = Color(0.2, 0.4, 0.7, 0.7) # Default blue
	if province_data.owner_faction_id == "sparta":
		fill_color = Color(0.75, 0.15, 0.15, 0.8)
	elif province_data.owner_faction_id == "athens":
		fill_color = Color(0.15, 0.45, 0.85, 0.8)
	elif province_data.owner_faction_id == "thebes":
		fill_color = Color(0.85, 0.65, 0.10, 0.8)
	
	# Node base radius
	var radius: float = 40.0 + (province_data.settlement_tier * 6.0)
	
	# Draw node territory circle
	draw_circle(Vector2.ZERO, radius, fill_color)
	
	# Border / highlight
	var border_color: Color = Color.WHITE if is_selected else (Color.YELLOW if is_hovered else Color.BLACK)
	var border_width: float = 4.0 if (is_selected or is_hovered) else 2.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, border_color, border_width)
	
	# Draw settlement tier pips
	for i in range(province_data.settlement_tier):
		var pip_x: float = -radius + 15.0 + (i * 12.0)
		draw_circle(Vector2(pip_x, radius - 10.0), 4.0, Color.GOLD)
