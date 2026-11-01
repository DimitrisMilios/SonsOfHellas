class_name MainCampaign
extends Node2D

@export var faction_resources: Array[FactionData] = []
@export var province_resources: Array[ProvinceData] = []
@export var army_resources: Array[ArmyData] = []

@export var province_scene: PackedScene = preload("res://scenes/ProvinceNode.tscn")
@export var army_scene: PackedScene = preload("res://scenes/ArmyNode.tscn")

@onready var world_container: Node2D = $World
@onready var roads_container: Node2D = $World/Roads
@onready var provinces_container: Node2D = $World/Provinces
@onready var armies_container: Node2D = $World/Armies
@onready var camera: CampaignCamera = $CampaignCamera

func _ready() -> void:
	_load_default_presets_if_empty()
	_initialize_factions()
	_spawn_provinces()
	_spawn_armies()
	_draw_road_connections()
	
	# Start turn loop
	var turn_mgr: TurnManager = get_node_or_null("/root/TurnManager")
	if turn_mgr != null:
		turn_mgr.start_campaign()

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
	var turn_mgr: TurnManager = get_node_or_null("/root/TurnManager")
	if turn_mgr != null:
		for faction: FactionData in faction_resources:
			if faction != null:
				turn_mgr.register_faction(faction)

func _spawn_provinces() -> void:
	for prov_data: ProvinceData in province_resources:
		if prov_data == null:
			continue
		var prov_instance: ProvinceNode = province_scene.instantiate() as ProvinceNode
		prov_instance.province_data = prov_data
		provinces_container.add_child(prov_instance)

func _spawn_armies() -> void:
	for army_data: ArmyData in army_resources:
		if army_data == null:
			continue
		var army_instance: ArmyNode = army_scene.instantiate() as ArmyNode
		army_instance.army_data = army_data
		armies_container.add_child(army_instance)

func _draw_road_connections() -> void:
	if roads_container == null:
		return
	
	# Script-driven line drawing for adjacency visualizer
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
				
				# Locate neighbor province position
				var neighbor: ProvinceData = _find_province_by_id(adj_id)
				if neighbor != null:
					drawer.draw_line(prov_data.map_position, neighbor.map_position, Color(0.7, 0.6, 0.4, 0.5), 4.0, true)
					drawn_pairs[pair_key_1] = true
	)
	roads_container.add_child(drawer)
	drawer.queue_redraw()

func _find_province_by_id(target_id: String) -> ProvinceData:
	for p: ProvinceData in province_resources:
		if p != null and p.province_id == target_id:
			return p
	return null
