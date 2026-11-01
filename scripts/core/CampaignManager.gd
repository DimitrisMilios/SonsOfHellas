class_name CampaignManager
extends Node

## Signals for UI and World visualization
signal province_selected(province_data: ProvinceData)
signal army_selected(army_data: ArmyData)
signal selection_cleared()
signal army_movement_started(army_data: ArmyData, from_id: String, to_id: String)
signal army_movement_completed(army_data: ArmyData, to_id: String)
signal battle_triggered(result: BattleResult)
signal move_rejected(reason: String)
signal province_ownership_changed(province_data: ProvinceData, old_owner_id: String, new_owner_id: String)

@export_group("Campaign State")
var provinces: Dictionary = {}         # province_id (String) -> ProvinceData
var province_nodes: Dictionary = {}   # province_id (String) -> Node
var armies: Array[ArmyData] = []
var army_nodes: Dictionary = {}       # army_id (String) -> Node

var selected_province: ProvinceData = null
var selected_army: ArmyData = null

func _ready() -> void:
	# Connect to TurnManager turn triggers if autoload exists
	var turn_manager_node: Node = get_node_or_null("/root/TurnManager")
	if turn_manager_node != null:
		turn_manager_node.connect("turn_started", Callable(self, "_on_turn_started"))
		turn_manager_node.connect("round_completed", Callable(self, "_on_round_completed"))

## Registers a province data container and optional scene node.
func register_province(data: ProvinceData, node: Node = null) -> void:
	if data == null or data.province_id.is_empty():
		return
	provinces[data.province_id] = data
	if node != null:
		province_nodes[data.province_id] = node

## Registers an army data container and optional scene node.
func register_army(data: ArmyData, node: Node = null) -> void:
	if data == null or data.army_id.is_empty():
		return
	if not armies.has(data):
		armies.append(data)
	if node != null:
		army_nodes[data.army_id] = node

## Selects a province on the campaign map.
func select_province_by_id(province_id: String) -> void:
	if not provinces.has(province_id):
		return
	var target_province: ProvinceData = provinces[province_id]
	select_province(target_province)

func select_province(province_data: ProvinceData) -> void:
	# If an army is already selected and player clicks an adjacent province, attempt movement
	if selected_army != null:
		var current_prov_id: String = selected_army.current_province_id
		if current_prov_id != province_data.province_id:
			var validation: Dictionary = validate_army_move(selected_army, province_data.province_id)
			if validation["valid"]:
				execute_army_move(selected_army, province_data.province_id)
				return
			else:
				move_rejected.emit(validation["reason"])
	
	selected_army = null
	selected_province = province_data
	province_selected.emit(province_data)

## Selects an army on the campaign map.
func select_army(army_data: ArmyData) -> void:
	selected_province = null
	selected_army = army_data
	if army_data != null:
		army_selected.emit(army_data)
	else:
		selection_cleared.emit()

## Clears current campaign selection.
func clear_selection() -> void:
	selected_province = null
	selected_army = null
	selection_cleared.emit()

## Validates whether an army can legally move to target province.
func validate_army_move(army: ArmyData, target_province_id: String) -> Dictionary:
	if army == null:
		return {"valid": false, "cost": 0.0, "reason": "No army selected."}
	
	if not provinces.has(target_province_id):
		return {"valid": false, "cost": 0.0, "reason": "Target province does not exist."}
	
	var current_province: ProvinceData = provinces.get(army.current_province_id, null)
	if current_province == null:
		return {"valid": false, "cost": 0.0, "reason": "Army is not currently stationed in a valid province."}
	
	if current_province.province_id == target_province_id:
		return {"valid": false, "cost": 0.0, "reason": "Army is already in this province."}
	
	if not current_province.is_adjacent_to(target_province_id):
		return {"valid": false, "cost": 0.0, "reason": "Target province is not adjacent."}
	
	var ap_cost: float = ArmyData.BASE_MOVEMENT_AP_COST
	if army.stance == ArmyData.Stance.FORCED_MARCH:
		ap_cost *= 0.8
	
	if army.current_action_points < ap_cost:
		return {"valid": false, "cost": ap_cost, "reason": "Insufficient Action Points (Requires %.0f, has %.0f)." % [ap_cost, army.current_action_points]}
	
	return {"valid": true, "cost": ap_cost, "reason": "Move valid."}

## Executes movement, consumes AP, and resolves hostile encounters if present.
func execute_army_move(army: ArmyData, target_province_id: String) -> bool:
	var validation: Dictionary = validate_army_move(army, target_province_id)
	if not validation["valid"]:
		move_rejected.emit(validation["reason"])
		return false
	
	var from_province_id: String = army.current_province_id
	var ap_cost: float = validation["cost"]
	var target_province: ProvinceData = provinces[target_province_id]

	# Consume Action Points
	army.consume_action_points(ap_cost)
	army_movement_started.emit(army, from_province_id, target_province_id)

	# Check for opposing hostile forces in destination
	var hostile_army: ArmyData = _find_hostile_army_in_province(target_province_id, army.owner_faction_id)
	
	if hostile_army != null:
		# Field battle against opposing army
		var battle_result: BattleResult = AutoResolveCalculator.resolve_battle(army, hostile_army)
		_apply_battle_outcome(battle_result, target_province)
		battle_triggered.emit(battle_result)
		
		if battle_result.attacker_won:
			army.current_province_id = target_province_id
			army_movement_completed.emit(army, target_province_id)
		return true

	elif target_province.owner_faction_id != "" and target_province.owner_faction_id != army.owner_faction_id:
		# Assaulting enemy settlement garrison
		if not target_province.garrison_units.is_empty():
			var garrison_army: ArmyData = ArmyData.new()
			garrison_army.army_id = "garrison_" + target_province.province_id
			garrison_army.army_name = "%s Garrison" % target_province.province_name
			garrison_army.owner_faction_id = target_province.owner_faction_id
			garrison_army.units = target_province.garrison_units.duplicate()
			garrison_army.general_leadership_rating = 0.8
			garrison_army.stance = ArmyData.Stance.ENCAMP

			var battle_result: BattleResult = AutoResolveCalculator.resolve_battle(army, garrison_army)
			_apply_battle_outcome(battle_result, target_province)
			battle_triggered.emit(battle_result)

			if battle_result.attacker_won:
				army.current_province_id = target_province_id
				army_movement_completed.emit(army, target_province_id)
			return true
		else:
			# Undefended settlement captured immediately
			_transfer_province_ownership(target_province, army.owner_faction_id)
			army.current_province_id = target_province_id
			army_movement_completed.emit(army, target_province_id)
			return true
	else:
		# Friendly or neutral province move
		army.current_province_id = target_province_id
		army_movement_completed.emit(army, target_province_id)
		return true

## Updates army units, casualties, and province control following battle resolution.
func _apply_battle_outcome(result: BattleResult, contested_province: ProvinceData) -> void:
	# Update attacker roster
	result.attacker_army.units = result.attacker_survivors.duplicate()
	if result.attacker_army.units.is_empty():
		_disband_army(result.attacker_army)
	
	# Update defender roster
	result.defender_army.units = result.defender_survivors.duplicate()
	if result.defender_army.units.is_empty():
		_disband_army(result.defender_army)
		# If defender was destroyed in its own settlement, attacker claims province
		if result.attacker_won and contested_province.owner_faction_id != result.attacker_army.owner_faction_id:
			_transfer_province_ownership(contested_province, result.attacker_army.owner_faction_id)

## Changes province owner and notifies listeners.
func _transfer_province_ownership(province: ProvinceData, new_owner_id: String) -> void:
	var old_owner: String = province.owner_faction_id
	province.owner_faction_id = new_owner_id
	province.public_order = clampf(province.public_order - 30.0, -100.0, 100.0) # Conquest unrest
	province_ownership_changed.emit(province, old_owner, new_owner_id)

func _disband_army(army: ArmyData) -> void:
	armies.erase(army)
	if army_nodes.has(army.army_id):
		var node: Node = army_nodes[army.army_id]
		if is_instance_valid(node):
			node.queue_free()
		army_nodes.erase(army.army_id)
	if selected_army == army:
		selected_army = null
		selection_cleared.emit()

func _find_hostile_army_in_province(province_id: String, my_faction_id: String) -> ArmyData:
	for army: ArmyData in armies:
		if army.current_province_id == province_id and army.owner_faction_id != my_faction_id and not army.units.is_empty():
			return army
	return null

## Called at the start of a faction's turn to reset AP and simulate growth.
func _on_turn_started(_turn_number: int, active_faction: FactionData) -> void:
	if active_faction == null:
		return
	
	# Reset AP for faction's armies
	for army: ArmyData in armies:
		if army.owner_faction_id == active_faction.faction_id:
			army.reset_action_points()

	# Process province growth and public order
	for province_id: String in provinces.keys():
		var prov: ProvinceData = provinces[province_id]
		if prov.owner_faction_id == active_faction.faction_id:
			prov.process_turn_progression()

	# Recalculate faction economy figures
	_refresh_faction_economics(active_faction)

func _on_round_completed(_turn_number: int) -> void:
	pass

## Recalculates total income and upkeeps for a given faction.
func _refresh_faction_economics(faction: FactionData) -> void:
	var total_inc: int = 0
	var total_upk: int = 0
	
	for prov: ProvinceData in provinces.values():
		if prov.owner_faction_id == faction.faction_id:
			total_inc += roundi(prov.calculate_total_tax())
	
	for army: ArmyData in armies:
		if army.owner_faction_id == faction.faction_id:
			total_upk += army.calculate_total_upkeep()
	
	faction.total_income = total_inc
	faction.total_upkeep = total_upk
