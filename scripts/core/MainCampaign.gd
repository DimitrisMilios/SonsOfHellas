class_name MainCampaign
extends Node2D

@export var faction_resources: Array[FactionData] = []
@export var province_resources: Array[ProvinceData] = []
@export var army_resources: Array[ArmyData] = []

@onready var world_container: Node2D = $World
@onready var roads_container: Node2D = $World/Roads
@onready var map_view: CampaignMapView = $World/CampaignMapView
@onready var camera: CampaignCamera = $CampaignCamera
@onready var hud: CampaignHUD = $CampaignHUD

# Touch gesture discrimination tracking
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: int = 0
var _is_touching: bool = false
var _mouse_start_pos: Vector2 = Vector2.ZERO
var _mouse_start_time: int = 0
var _is_mouse_down: bool = false

func _ready() -> void:
	_ensure_references()
	_load_default_presets_if_empty()
	_initialize_factions()
	_initialize_campaign_manager()
	_wire_signals()
	_draw_road_connections()
	
	# Initial map view build
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null and map_view != null:
		map_view.rebuild_from_state(campaign_mgr.provinces, campaign_mgr.armies)

	# Start turn loop
	var turn_mgr: Node = get_node_or_null("/root/TurnManager")
	if turn_mgr != null and turn_mgr.has_method("start_campaign"):
		turn_mgr.start_campaign()

func _ensure_references() -> void:
	if world_container == null:
		world_container = get_node_or_null("World") as Node2D
	if roads_container == null:
		roads_container = get_node_or_null("World/Roads") as Node2D
	if map_view == null:
		map_view = get_node_or_null("World/CampaignMapView") as CampaignMapView
	if camera == null:
		camera = get_node_or_null("CampaignCamera") as CampaignCamera
	if hud == null:
		hud = get_node_or_null("CampaignHUD") as CampaignHUD

func _load_default_presets_if_empty() -> void:
	if faction_resources.is_empty():
		faction_resources.append(load("res://resources/factions/sparta.tres") as FactionData)
		faction_resources.append(load("res://resources/factions/athens.tres") as FactionData)
		faction_resources.append(load("res://resources/factions/thebes.tres") as FactionData)

	if province_resources.is_empty():
		province_resources.append(load("res://resources/provinces/sparta.tres") as ProvinceData)
		province_resources.append(load("res://resources/provinces/corinth.tres") as ProvinceData)
		province_resources.append(load("res://resources/provinces/athens.tres") as ProvinceData)
		province_resources.append(load("res://resources/provinces/thebes.tres") as ProvinceData)

	if army_resources.is_empty():
		army_resources.append(load("res://resources/armies/spartan_army.tres") as ArmyData)
		army_resources.append(load("res://resources/armies/athenian_army.tres") as ArmyData)

func _initialize_factions() -> void:
	var turn_mgr: Node = get_node_or_null("/root/TurnManager")
	if turn_mgr != null and turn_mgr.has_method("register_faction"):
		for faction: FactionData in faction_resources:
			if faction != null:
				turn_mgr.register_faction(faction)

func _initialize_campaign_manager() -> void:
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null:
		for p: ProvinceData in province_resources:
			if p != null:
				campaign_mgr.register_province(p)
		for a: ArmyData in army_resources:
			if a != null:
				campaign_mgr.register_army(a)

func _wire_signals() -> void:
	_ensure_references()
	if camera != null and map_view != null:
		if not camera.zoom_changed.is_connected(map_view.on_camera_zoom_changed):
			camera.zoom_changed.connect(map_view.on_camera_zoom_changed)
		map_view.on_camera_zoom_changed(camera.zoom)

	if is_inside_tree():
		var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
		if campaign_mgr != null:
			if not campaign_mgr.province_selected.is_connected(_on_province_selected):
				campaign_mgr.province_selected.connect(_on_province_selected)
			if not campaign_mgr.army_selected.is_connected(_on_army_selected):
				campaign_mgr.army_selected.connect(_on_army_selected)
			if not campaign_mgr.selection_cleared.is_connected(_on_selection_cleared):
				campaign_mgr.selection_cleared.connect(_on_selection_cleared)
			if not campaign_mgr.province_ownership_changed.is_connected(_on_ownership_changed):
				campaign_mgr.province_ownership_changed.connect(_on_ownership_changed)
			if not campaign_mgr.army_movement_completed.is_connected(_on_movement_completed):
				campaign_mgr.army_movement_completed.connect(_on_movement_completed)

func _on_province_selected(p: ProvinceData) -> void:
	if hud != null:
		var vm: ProvinceViewModel = ProvinceViewModel.from_province_data(p)
		hud.display_province_view_model(vm)
	if map_view != null:
		map_view.select_entity(p.province_id, "province")

func _on_army_selected(a: ArmyData) -> void:
	if hud != null:
		var vm: ArmyViewModel = ArmyViewModel.from_army_data(a)
		hud.display_army_view_model(vm)
	if map_view != null:
		map_view.select_entity(a.army_id, "army")

func _on_selection_cleared() -> void:
	if hud != null:
		hud.clear_selection()
	if map_view != null:
		map_view.clear_selection()

func _on_ownership_changed(_p: ProvinceData, _old_id: String, _new_id: String) -> void:
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null and map_view != null:
		map_view.rebuild_from_state(campaign_mgr.provinces, campaign_mgr.armies)

func _on_movement_completed(_a: ArmyData, _to_id: String) -> void:
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null and map_view != null:
		map_view.rebuild_from_state(campaign_mgr.provinces, campaign_mgr.armies)

func _unhandled_input(event: InputEvent) -> void:
	# --- Mobile Screen Touch Tap Detection ---
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event.position
			_touch_start_time = Time.get_ticks_msec()
			_is_touching = true
		elif _is_touching:
			_is_touching = false
			var duration_ms: float = float(Time.get_ticks_msec() - _touch_start_time)
			if CampaignInputRouter.is_tap_gesture(_touch_start_pos, event.position, duration_ms):
				_dispatch_tap(event.position)

	# --- Desktop Mouse Click Tap Detection ---
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_start_pos = event.position
			_mouse_start_time = Time.get_ticks_msec()
			_is_mouse_down = true
		elif _is_mouse_down:
			_is_mouse_down = false
			var duration_ms: float = float(Time.get_ticks_msec() - _mouse_start_time)
			if CampaignInputRouter.is_tap_gesture(_mouse_start_pos, event.position, duration_ms):
				_dispatch_tap(event.position)

func _dispatch_tap(screen_pos: Vector2) -> void:
	if camera == null:
		return
	var world_pos: Vector2 = camera.screen_to_world(screen_pos)
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null and campaign_mgr.has_method("handle_world_tap"):
		campaign_mgr.handle_world_tap(world_pos)

func _draw_road_connections() -> void:
	if roads_container == null:
		return
	
	var drawer: Node2D = Node2D.new()
	drawer.name = "RoadLinesDrawer"
	drawer.draw.connect(func() -> void:
		var drawn_pairs: Dictionary = {}
		for prov_data: ProvinceData in province_resources:
			if prov_data == null:
				continue
			for adj_id: String in prov_data.adjacent_province_ids:
				var pair_key_1: String = "%s_%s" % [prov_data.province_id, adj_id]
				var pair_key_2: String = "%s_%s" % [adj_id, prov_data.province_id]
				if drawn_pairs.has(pair_key_1) or drawn_pairs.has(pair_key_2):
					continue
				
				var neighbor: ProvinceData = _find_province_by_id(adj_id)
				if neighbor != null:
					drawer.draw_line(prov_data.map_position, neighbor.map_position, Color(0.75, 0.65, 0.45, 0.6), 4.0, true)
					drawn_pairs[pair_key_1] = true
	)
	roads_container.add_child(drawer)
	drawer.queue_redraw()

func _find_province_by_id(target_id: String) -> ProvinceData:
	for p: ProvinceData in province_resources:
		if p != null and p.province_id == target_id:
			return p
	return null
