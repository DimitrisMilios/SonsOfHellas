class_name CampaignMapView
extends Node2D

signal entity_selected(entity_id: String, entity_type: String)
signal selection_cleared()

var province_nodes: Dictionary = {} # province_id -> ProvinceNode
var army_nodes: Dictionary = {}     # army_id -> ArmyNode

var selected_entity_id: String = ""
var selected_entity_type: String = ""
var current_zoom_x: float = 1.0

var provinces_container: Node2D = null
var armies_container: Node2D = null
var roads_container: Node2D = null

func _init() -> void:
	roads_container = Node2D.new()
	roads_container.name = "Roads"
	add_child(roads_container)

	provinces_container = Node2D.new()
	provinces_container.name = "Provinces"
	add_child(provinces_container)

	armies_container = Node2D.new()
	armies_container.name = "Armies"
	add_child(armies_container)

const PROVINCE_SCENE: PackedScene = preload("res://scenes/ProvinceNode.tscn")
const ARMY_SCENE: PackedScene = preload("res://scenes/ArmyNode.tscn")

## Spawns or updates a passive ProvinceNode view.
func spawn_province_node(data: ProvinceData, faction: FactionData = null) -> ProvinceNode:
	if data == null:
		return null
		
	var node: ProvinceNode
	if province_nodes.has(data.province_id):
		node = province_nodes[data.province_id]
	else:
		if PROVINCE_SCENE != null:
			node = PROVINCE_SCENE.instantiate() as ProvinceNode
		if node == null:
			node = ProvinceNode.new()
		node.name = data.province_id
		province_nodes[data.province_id] = node
		provinces_container.add_child(node)
		
	var vm: ProvinceViewModel = ProvinceViewModel.from_province_data(data, faction)
	node.update_view(vm)
	node.set_zoom(current_zoom_x)
	return node

## Spawns or updates a passive ArmyNode view.
func spawn_army_node(data: ArmyData, start_pos: Vector2) -> ArmyNode:
	if data == null:
		return null
		
	var node: ArmyNode
	if army_nodes.has(data.army_id):
		node = army_nodes[data.army_id]
	else:
		if ARMY_SCENE != null:
			node = ARMY_SCENE.instantiate() as ArmyNode
		if node == null:
			node = ArmyNode.new()
		node.name = data.army_id
		node.position = start_pos
		army_nodes[data.army_id] = node
		armies_container.add_child(node)
		
	var vm: ArmyViewModel = ArmyViewModel.from_army_data(data)
	node.update_view(vm)
	node.set_zoom(current_zoom_x)
	return node

## Safely removes an army node without memory leaks or dangling callbacks.
func remove_army_node(army_id: String) -> void:
	if not army_nodes.has(army_id):
		return
		
	var node: ArmyNode = army_nodes[army_id]
	if node != null and is_instance_valid(node):
		node.cancel_active_tween()
		if selected_entity_id == army_id:
			clear_selection()
		army_nodes.erase(army_id)
		node.queue_free()
	else:
		army_nodes.erase(army_id)

## Completely reconciles visual scene nodes against underlying domain state.
func rebuild_from_state(provinces_map: Dictionary, armies_list: Array) -> void:
	# 1. Reconcile Provinces
	var active_prov_ids: Dictionary = {}
	for pid: Variant in provinces_map.keys():
		var p_data: ProvinceData = provinces_map[pid]
		if p_data != null:
			active_prov_ids[p_data.province_id] = true
			spawn_province_node(p_data)
			
	var prov_to_remove: Array[String] = []
	for pid: String in province_nodes.keys():
		if not active_prov_ids.has(pid):
			prov_to_remove.append(pid)
	for pid: String in prov_to_remove:
		var node: ProvinceNode = province_nodes[pid]
		province_nodes.erase(pid)
		if node != null and is_instance_valid(node):
			node.queue_free()
			
	# 2. Reconcile Armies
	var active_army_ids: Dictionary = {}
	for a: Variant in armies_list:
		if a is ArmyData:
			active_army_ids[a.army_id] = true
			var start_pos: Vector2 = Vector2.ZERO
			if provinces_map.has(a.current_province_id):
				start_pos = provinces_map[a.current_province_id].map_position + Vector2(25.0, -25.0)
			spawn_army_node(a, start_pos)
			
	var armies_to_remove: Array[String] = []
	for aid: String in army_nodes.keys():
		if not active_army_ids.has(aid):
			armies_to_remove.append(aid)
	for aid: String in armies_to_remove:
		remove_army_node(aid)

## Gathers candidates with clamped touch hitboxes for CampaignInputRouter.
func get_touch_candidates(zoom_x: float) -> Array[Dictionary]:
	current_zoom_x = zoom_x
	var candidates: Array[Dictionary] = []
	
	for pid: String in province_nodes.keys():
		var p_node: ProvinceNode = province_nodes[pid]
		if p_node != null and is_instance_valid(p_node):
			var r: float = CampaignInputRouter.calculate_effective_world_radius(ProvinceNode.BASE_RADIUS, zoom_x)
			candidates.append({
				"id": pid,
				"type": "province",
				"pos": p_node.position,
				"radius": r,
				"box_size": Vector2.ZERO
			})
			
	for aid: String in army_nodes.keys():
		var a_node: ArmyNode = army_nodes[aid]
		if a_node != null and is_instance_valid(a_node):
			var box: Vector2 = CampaignInputRouter.calculate_effective_box_size(ArmyNode.BASE_BOX_SIZE, zoom_x)
			candidates.append({
				"id": aid,
				"type": "army",
				"pos": a_node.position,
				"radius": box.x / 2.0,
				"box_size": box
			})
			
	return candidates

func select_entity(entity_id: String, entity_type: String) -> void:
	clear_selection()
	selected_entity_id = entity_id
	selected_entity_type = entity_type
	
	if entity_type == "army" and army_nodes.has(entity_id):
		army_nodes[entity_id].set_selected(true)
	elif entity_type == "province" and province_nodes.has(entity_id):
		province_nodes[entity_id].set_selected(true)
		
	entity_selected.emit(entity_id, entity_type)

func clear_selection() -> void:
	if selected_entity_type == "army" and army_nodes.has(selected_entity_id):
		army_nodes[selected_entity_id].set_selected(false)
	elif selected_entity_type == "province" and province_nodes.has(selected_entity_id):
		province_nodes[selected_entity_id].set_selected(false)
		
	selected_entity_id = ""
	selected_entity_type = ""
	selection_cleared.emit()

func on_camera_zoom_changed(new_zoom: Vector2) -> void:
	current_zoom_x = new_zoom.x
	for p_node: ProvinceNode in province_nodes.values():
		if p_node != null and is_instance_valid(p_node):
			p_node.set_zoom(current_zoom_x)
	for a_node: ArmyNode in army_nodes.values():
		if a_node != null and is_instance_valid(a_node):
			a_node.set_zoom(current_zoom_x)
