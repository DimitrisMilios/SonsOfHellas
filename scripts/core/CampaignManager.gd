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
var selected_entity_id: String = ""
var selected_entity_type: String = ""

func _ready() -> void:
	if is_inside_tree():
		var turn_manager_node: Node = get_node_or_null("/root/TurnManager")
		if turn_manager_node != null:
			if turn_manager_node.has_signal("turn_started"):
				turn_manager_node.turn_started.connect(_on_turn_started)
			if turn_manager_node.has_signal("round_completed"):
				turn_manager_node.round_completed.connect(_on_round_completed)

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
	selected_army = null
	selected_province = province_data
	if province_data != null:
		selected_entity_id = province_data.province_id
		selected_entity_type = "province"
		province_selected.emit(province_data)
	else:
		selected_entity_id = ""
		selected_entity_type = ""
		selection_cleared.emit()

## Selects an army on the campaign map.
func select_army(army_data: ArmyData) -> void:
	selected_province = null
	selected_army = army_data
	if army_data != null:
		selected_entity_id = army_data.army_id
		selected_entity_type = "army"
		army_selected.emit(army_data)
	else:
		selected_entity_id = ""
		selected_entity_type = ""
		selection_cleared.emit()

## Clears current campaign selection.
func clear_selection() -> void:
	selected_province = null
	selected_army = null
	selected_entity_id = ""
	selected_entity_type = ""
	selection_cleared.emit()

## Updates tactical stance for a registered army.
func set_army_stance(army_id: String, new_stance: ArmyData.Stance) -> bool:
	for army: ArmyData in armies:
		if army != null and army.army_id == army_id:
			var success: bool = army.set_stance(new_stance)
			if success and selected_army == army:
				army_selected.emit(army)
			return success
	return false

## Dispatches a touch tap at world coordinates through CampaignInputRouter.
func handle_world_tap(tap_world_pos: Vector2, custom_candidates: Array = [], zoom_x: float = 1.0) -> void:
	# Check input gate if TurnManager exists
	if is_inside_tree():
		var turn_mgr: Node = get_node_or_null("/root/TurnManager")
		if turn_mgr != null and turn_mgr.has_method("can_accept_command"):
			if not turn_mgr.can_accept_command():
				return

	var candidates: Array = []
	if not custom_candidates.is_empty():
		candidates = custom_candidates
	else:
		for army: ArmyData in armies:
			if army != null:
				var army_pos: Vector2 = Vector2.ZERO
				if provinces.has(army.current_province_id):
					army_pos = provinces[army.current_province_id].map_position
				var eff_box: Vector2 = CampaignInputRouter.calculate_effective_box_size(Vector2(52, 52), zoom_x)
				candidates.append({
					"id": army.army_id,
					"type": "army",
					"pos": army_pos,
					"box_size": eff_box
				})

		for prov: ProvinceData in provinces.values():
			if prov != null:
				var eff_r: float = CampaignInputRouter.calculate_effective_world_radius(56.0, zoom_x)
				candidates.append({
					"id": prov.province_id,
					"type": "province",
					"pos": prov.map_position,
					"radius": eff_r
				})

	var pick: Dictionary = CampaignInputRouter.pick_candidate(tap_world_pos, candidates, selected_entity_id)
	if not pick.get("hit", false):
		if selected_army != null and tap_world_pos.x >= -100.0 and tap_world_pos.x <= 2200.0 and tap_world_pos.y >= -100.0 and tap_world_pos.y <= 1200.0:
			execute_free_march(selected_army, tap_world_pos)
			return
		clear_selection()
		return

	var hit_id: String = str(pick.get("id", ""))
	var hit_type: String = str(pick.get("type", ""))

	if hit_type == "army":
		if selected_army != null and selected_army.army_id != hit_id:
			var target_army: ArmyData = null
			for other_a: ArmyData in armies:
				if other_a != null and other_a.army_id == hit_id:
					target_army = other_a
					break
			if target_army != null and target_army.owner_faction_id != selected_army.owner_faction_id:
				execute_free_march(selected_army, _get_army_world_position(target_army))
				return
		for a: ArmyData in armies:
			if a != null and a.army_id == hit_id:
				select_army(a)
				return
	elif hit_type == "province":
		if provinces.has(hit_id):
			var prov: ProvinceData = provinces[hit_id]
			# If army selected and player clicks another province, attempt move
			if selected_army != null and selected_army.current_province_id != hit_id:
				var validation: Dictionary = validate_army_move(selected_army, hit_id)
				if validation["valid"]:
					execute_army_move(selected_army, hit_id)
					return
				else:
					# Free-march towards distant target province!
					execute_free_march(selected_army, prov.map_position + Vector2(25.0, -25.0))
					return
			select_province(prov)

## Validates whether an army can legally move to target province.
func validate_army_move(army: ArmyData, target_province_id: String) -> Dictionary:
	if is_inside_tree():
		var turn_mgr: Node = get_node_or_null("/root/TurnManager")
		if turn_mgr != null and turn_mgr.has_method("can_accept_command"):
			if not turn_mgr.can_accept_command():
				return {"valid": false, "cost": 0.0, "triggers_engagement": false, "reason": "Cannot move while turn is processing."}

	if army == null:
		return {"valid": false, "cost": 0.0, "triggers_engagement": false, "reason": "No army selected."}
	
	if not provinces.has(target_province_id):
		return {"valid": false, "cost": 0.0, "triggers_engagement": false, "reason": "Target province does not exist."}
	
	var current_province: ProvinceData = provinces.get(army.current_province_id, null)
	if current_province == null:
		return {"valid": false, "cost": 0.0, "triggers_engagement": false, "reason": "Army is not currently stationed in a valid province."}
	
	if current_province.province_id == target_province_id:
		return {"valid": false, "cost": 0.0, "triggers_engagement": false, "reason": "Army is already in this province."}
	
	var target_province: ProvinceData = provinces[target_province_id]
	var mov_res: Dictionary = MovementEngine.calculate_movement_result(
		army, current_province, target_province, "plains", 0, armies
	)
	
	return {
		"valid": mov_res.get("success", false),
		"cost": mov_res.get("ap_cost", 0.0),
		"triggers_engagement": mov_res.get("triggers_engagement", false),
		"reason": mov_res.get("reason", "OK")
	}

## Executes movement, consumes AP, and resolves encounters according to AutoResolveEngine.
func execute_army_move(army: ArmyData, target_province_id: String) -> bool:
	var validation: Dictionary = validate_army_move(army, target_province_id)
	if not validation["valid"]:
		move_rejected.emit(validation["reason"])
		return false
	
	var from_province_id: String = army.current_province_id
	var ap_cost: float = validation["cost"]
	var target_province: ProvinceData = provinces[target_province_id]
	var triggers_engagement: bool = validation.get("triggers_engagement", false)

	# Consume Action Points and handle ZoC interception
	army.consume_action_points(ap_cost)
	if triggers_engagement:
		# Entering hostile Zone of Control halts further movement and expends all remaining AP
		army.current_action_points = 0.0

	army_movement_started.emit(army, from_province_id, target_province_id)

	# Check for opposing hostile forces in destination
	var hostile_army: ArmyData = _find_hostile_army_in_province(target_province_id, army.owner_faction_id)
	
	if hostile_army != null:
		# Field battle against opposing army
		var battle_result: BattleResult = AutoResolveEngine.resolve_battle(army, hostile_army, {"is_settlement_siege": false})
		AutoResolveEngine.apply_battle_result(battle_result, army, hostile_army)
		_handle_post_battle_armies(battle_result, target_province)
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
			garrison_army.general_command_stars = 1
			garrison_army.stance = ArmyData.Stance.ENCAMPMENT

			var battle_result: BattleResult = AutoResolveEngine.resolve_battle(
				army, garrison_army, {
					"is_settlement_siege": true,
					"fortification_level": target_province.settlement_level
				}
			)
			AutoResolveEngine.apply_battle_result(battle_result, army, garrison_army)
			target_province.garrison_units = garrison_army.units.duplicate()
			
			if battle_result.attacker_won:
				_transfer_province_ownership(target_province, army.owner_faction_id)
				army.current_province_id = target_province_id
				army_movement_completed.emit(army, target_province_id)
			battle_triggered.emit(battle_result)
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

func _handle_post_battle_armies(result: BattleResult, contested_province: ProvinceData) -> void:
	if result.attacker_army.units.is_empty():
		_disband_army(result.attacker_army)
	if result.defender_army.units.is_empty():
		_disband_army(result.defender_army)
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
		clear_selection()

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

## Returns world map position of army
func _get_army_world_position(army: ArmyData) -> Vector2:
	if army == null:
		return Vector2.ZERO
	if army.map_position != Vector2.ZERO:
		return army.map_position
	if provinces.has(army.current_province_id):
		return provinces[army.current_province_id].map_position + Vector2(25.0, -25.0)
	return Vector2.ZERO

## Free-march movement across open campaign terrain
func execute_free_march(army: ArmyData, destination: Vector2) -> bool:
	if army == null:
		return false
	if is_inside_tree():
		var turn_mgr: Node = get_node_or_null("/root/TurnManager")
		if turn_mgr != null and turn_mgr.has_method("can_accept_command"):
			if not turn_mgr.can_accept_command():
				move_rejected.emit("Cannot move while turn is processing.")
				return false

	if army.current_action_points <= 0.001:
		move_rejected.emit("Army has depleted all Action Points this turn.")
		return false

	var from_pos: Vector2 = _get_army_world_position(army)
	var total_dist: float = from_pos.distance_to(destination)
	if total_dist < 10.0:
		clear_selection()
		return false

	# 2.5 pixels per 1 AP (e.g. 100 AP = 250 px max march per turn)
	const PIXELS_PER_AP: float = 2.5
	var ap_needed: float = total_dist / PIXELS_PER_AP
	var ap_spent: float = minf(ap_needed, army.current_action_points)
	var actual_dist: float = ap_spent * PIXELS_PER_AP
	var march_target: Vector2 = from_pos.move_toward(destination, actual_dist)

	# Deduct Action Points
	army.consume_action_points(ap_spent)
	army.map_position = march_target

	# Check settlement arrival (within 45px of any province center)
	var arrived_prov: ProvinceData = null
	for p: ProvinceData in provinces.values():
		if p != null and p.map_position.distance_to(march_target) <= 45.0:
			arrived_prov = p
			march_target = p.map_position + Vector2(25.0, -25.0)
			army.map_position = march_target
			break

	if arrived_prov != null:
		army.current_province_id = arrived_prov.province_id
	else:
		army.current_province_id = ""

	# Animate node movement visually
	if army_nodes.has(army.army_id):
		var node: ArmyNode = army_nodes[army.army_id] as ArmyNode
		if node != null and is_instance_valid(node):
			node.animate_move_to(march_target, 0.40)

	army_movement_completed.emit(army, army.current_province_id)

	# Check for enemy collision
	var hostile_enemy: ArmyData = null
	for other_a: ArmyData in armies:
		if other_a != null and other_a != army and other_a.owner_faction_id != army.owner_faction_id and not other_a.units.is_empty():
			var other_pos: Vector2 = _get_army_world_position(other_a)
			if other_pos.distance_to(march_target) <= 45.0:
				hostile_enemy = other_a
				break

	if hostile_enemy != null:
		var battle_result: BattleResult = AutoResolveEngine.resolve_battle(army, hostile_enemy, {"is_settlement_siege": false})
		AutoResolveEngine.apply_battle_result(battle_result, army, hostile_enemy)
		_handle_post_battle_armies(battle_result, arrived_prov)
		battle_triggered.emit(battle_result)
	elif arrived_prov != null and arrived_prov.owner_faction_id != "" and arrived_prov.owner_faction_id != army.owner_faction_id:
		# Settlement siege assault
		_execute_siege_assault(army, arrived_prov)

	if selected_army == army:
		army_selected.emit(army)
	return true

func _execute_siege_assault(army: ArmyData, target_province: ProvinceData) -> void:
	if not target_province.garrison_units.is_empty():
		var garrison_army: ArmyData = ArmyData.new()
		garrison_army.army_id = "garrison_" + target_province.province_id
		garrison_army.army_name = "%s Garrison" % target_province.province_name
		garrison_army.owner_faction_id = target_province.owner_faction_id
		garrison_army.units = target_province.garrison_units.duplicate()
		garrison_army.general_command_stars = 1
		garrison_army.stance = ArmyData.Stance.ENCAMPMENT

		var battle_result: BattleResult = AutoResolveEngine.resolve_battle(
			army, garrison_army, {
				"is_settlement_siege": true,
				"fortification_level": target_province.settlement_level
			}
		)
		AutoResolveEngine.apply_battle_result(battle_result, army, garrison_army)
		target_province.garrison_units = garrison_army.units.duplicate()
		
		if battle_result.attacker_won:
			_transfer_province_ownership(target_province, army.owner_faction_id)
			army.current_province_id = target_province.province_id
			army_movement_completed.emit(army, target_province.province_id)
		battle_triggered.emit(battle_result)
	else:
		_transfer_province_ownership(target_province, army.owner_faction_id)
		army.current_province_id = target_province.province_id
		army_movement_completed.emit(army, target_province.province_id)

## Builds or upgrades infrastructure in a held province.
func construct_building(province_id: String, building: BuildingData) -> bool:
	if not provinces.has(province_id) or building == null:
		return false
	var prov: ProvinceData = provinces[province_id]
	var turn_mgr: Node = get_node_or_null("/root/TurnManager") if is_inside_tree() else null
	var active_fac: FactionData = turn_mgr.get_active_faction() if (turn_mgr != null and turn_mgr.has_method("get_active_faction")) else null
	if active_fac != null and active_fac.treasury < building.build_cost:
		move_rejected.emit("Insufficient treasury (%d Gold required)." % building.build_cost)
		return false

	if active_fac != null:
		active_fac.deduct_treasury(building.build_cost)
		if turn_mgr != null and turn_mgr.has_signal("player_gold_changed") and active_fac.is_player:
			turn_mgr.player_gold_changed.emit(active_fac.treasury, -building.build_cost)

	var slot: BuildingSlotData = BuildingSlotData.new()
	slot.slot_index = prov.building_slots.size()
	slot.building_data = building
	prov.building_slots.append(slot)
	prov.region_wealth += 150.0
	province_selected.emit(prov)
	return true

## Recruits a unit into a province's garrison or stationed army.
func recruit_unit(province_id: String, unit: UnitData) -> bool:
	if not provinces.has(province_id) or unit == null:
		return false
	var prov: ProvinceData = provinces[province_id]
	var turn_mgr: Node = get_node_or_null("/root/TurnManager") if is_inside_tree() else null
	var active_fac: FactionData = turn_mgr.get_active_faction() if (turn_mgr != null and turn_mgr.has_method("get_active_faction")) else null
	if active_fac != null and active_fac.treasury < unit.recruitment_cost:
		move_rejected.emit("Insufficient treasury (%d Gold required)." % unit.recruitment_cost)
		return false

	if active_fac != null:
		active_fac.deduct_treasury(unit.recruitment_cost)
		if turn_mgr != null and turn_mgr.has_signal("player_gold_changed") and active_fac.is_player:
			turn_mgr.player_gold_changed.emit(active_fac.treasury, -unit.recruitment_cost)

	prov.garrison_units.append(unit)
	province_selected.emit(prov)
	return true

## Raises a new field army stack outside a friendly settlement.
func raise_new_army(province_id: String, faction_id: String = "sparta") -> ArmyData:
	if not provinces.has(province_id):
		return null
	var prov: ProvinceData = provinces[province_id]
	var new_army: ArmyData = ArmyData.new()
	new_army.army_id = "%s_army_%d" % [faction_id, armies.size() + 1]
	new_army.army_name = "%s Host" % prov.province_name
	new_army.owner_faction_id = faction_id
	new_army.current_province_id = ""
	new_army.map_position = prov.map_position + Vector2(30.0, -30.0)
	new_army.current_action_points = 100.0
	new_army.max_action_points = 100.0

	var hoplite_unit: UnitData = load("res://resources/units/spartan_hoplites.tres") as UnitData
	if hoplite_unit != null:
		new_army.units.append(hoplite_unit)

	register_army(new_army)
	select_army(new_army)
	return new_army

# --- Diplomacy Management ---
var diplomatic_agreements: Dictionary = {}

func get_diplomacy_status(fac_a: String, fac_b: String) -> String:
	var k1: String = "%s_%s" % [fac_a, fac_b]
	var k2: String = "%s_%s" % [fac_b, fac_a]
	if diplomatic_agreements.has(k1):
		return diplomatic_agreements[k1]
	if diplomatic_agreements.has(k2):
		return diplomatic_agreements[k2]
	return "Neutral"

func set_diplomacy_status(fac_a: String, fac_b: String, status: String) -> void:
	var k1: String = "%s_%s" % [fac_a, fac_b]
	diplomatic_agreements[k1] = status
