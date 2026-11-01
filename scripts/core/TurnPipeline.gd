class_name TurnPipeline
extends RefCounted

## Enumeration of the 7 deterministic pipeline turn stages.
enum TurnStage {
	REVENUE = 1,
	AI_TURNS = 2,
	CONSTRUCTION = 3,
	MOVEMENT = 4,
	CONFLICT = 5,
	UPKEEP = 6,
	RESET = 7
}

## Context container encapsulating campaign state for pure execution.
class CampaignContext extends RefCounted:
	var current_turn: int = 1
	var campaign_seed: int = 1337
	var factions: Dictionary = {}         # faction_id (String) -> FactionData
	var provinces: Dictionary = {}        # province_id (String) -> ProvinceData
	var armies: Array[ArmyData] = []
	var event_log: Array[Dictionary] = []
	var awaiting_player_battle: BattleResult = null
	var is_player_battle_pending: bool = false

	func add_faction(f: FactionData) -> void:
		if f != null and not f.faction_id.is_empty():
			factions[f.faction_id] = f

	func add_province(p: ProvinceData) -> void:
		if p != null and not p.province_id.is_empty():
			provinces[p.province_id] = p

	func add_army(a: ArmyData) -> void:
		if a != null and not armies.has(a):
			armies.append(a)

	func remove_army(a: ArmyData) -> void:
		armies.erase(a)

	func log_event(event_type: String, details: Dictionary) -> void:
		var entry: Dictionary = {
			"turn": current_turn,
			"type": event_type,
			"timestamp": Time.get_ticks_usec()
		}
		for k in details.keys():
			entry[k] = details[k]
		event_log.append(entry)

	func get_sorted_faction_ids() -> Array[String]:
		var ids: Array[String] = []
		for fid: Variant in factions.keys():
			ids.append(str(fid))
		ids.sort()
		return ids

	func get_sorted_province_ids() -> Array[String]:
		var ids: Array[String] = []
		for pid: Variant in provinces.keys():
			ids.append(str(pid))
		ids.sort()
		return ids

	func get_sorted_armies() -> Array[ArmyData]:
		var sorted: Array[ArmyData] = armies.duplicate()
		sorted.sort_custom(func(a: ArmyData, b: ArmyData) -> bool:
			return a.army_id < b.army_id
		)
		return sorted

## Executes the full 7-step turn progression deterministically.
static func execute_turn(context: CampaignContext, ai_engine: RefCounted = null) -> Dictionary:
	if context == null:
		return {"success": false, "reason": "Null context"}

	step_1_revenue(context)
	step_2_ai_turns(context, ai_engine)
	step_3_construction(context)
	step_4_movement(context, ai_engine)
	
	var conflict_res: Dictionary = step_5_conflict(context)
	if context.is_player_battle_pending:
		return {
			"success": true,
			"paused_for_battle": true,
			"battle_result": context.awaiting_player_battle,
			"new_turn": context.current_turn
		}

	step_6_upkeep(context)
	step_7_reset(context)

	return {
		"success": true,
		"paused_for_battle": false,
		"new_turn": context.current_turn,
		"conflicts": conflict_res
	}

## Step 1: Active Faction Tax & Revenue Settlement
static func step_1_revenue(context: CampaignContext) -> void:
	var faction_ids: Array[String] = context.get_sorted_faction_ids()
	
	for fid: String in faction_ids:
		var faction: FactionData = context.factions[fid]
		if faction == null:
			continue
			
		var total_tax: float = 0.0
		var held_provinces: Array[ProvinceData] = []
		
		# Find owned provinces
		for pid: String in context.get_sorted_province_ids():
			var prov: ProvinceData = context.provinces[pid]
			if prov != null and prov.owner_faction_id == fid:
				held_provinces.append(prov)
				
		var held_count: int = held_provinces.size()
		
		# Process regional taxes and net wealth growth
		for prov: ProvinceData in held_provinces:
			var econ: Dictionary = EconomyCalculator.calculate_province_economy(prov, faction, held_count)
			var tax_yield: float = float(econ.get("tax_income", 0))
			total_tax += tax_yield
			prov.region_wealth = float(econ.get("new_region_wealth", prov.region_wealth))
			
		var gross_income: float = total_tax + float(faction.trade_income + faction.base_purse + faction.tribute_income + faction.raiding_income)
		faction.treasury += roundi(gross_income)
		faction.total_income = roundi(gross_income)
		
		context.log_event("revenue_collected", {
			"faction_id": fid,
			"gross_income": gross_income,
			"total_tax": total_tax,
			"treasury": faction.treasury
		})

## Step 2: Sequential AI Faction Processing
static func step_2_ai_turns(context: CampaignContext, ai_engine: RefCounted = null) -> void:
	var faction_ids: Array[String] = context.get_sorted_faction_ids()
	
	for fid: String in faction_ids:
		var faction: FactionData = context.factions[fid]
		if faction == null or faction.is_player:
			continue
			
		if fid == "faction_rebels":
			_process_rebel_behavior(context)
		elif ai_engine != null and ai_engine.has_method("process_faction_economy_and_recruitment"):
			ai_engine.call("process_faction_economy_and_recruitment", faction, context)

## Step 3: Construction & Recruitment Progress Timers
static func step_3_construction(context: CampaignContext) -> void:
	var province_ids: Array[String] = context.get_sorted_province_ids()
	
	for pid: String in province_ids:
		var prov: ProvinceData = context.provinces[pid]
		if prov == null:
			continue
			
		for slot: Variant in prov.building_slots:
			if slot is BuildingSlotData and slot.is_under_construction:
				slot.remaining_construction_turns -= 1
				if slot.remaining_construction_turns <= 0:
					slot.building_data = slot.target_building_to_construct
					slot.target_building_to_construct = null
					slot.is_under_construction = false
					context.log_event("building_completed", {
						"province_id": pid,
						"building_id": slot.building_data.building_id if slot.building_data != null else ""
					})

## Step 4: AI Strategic Movement & Action Phase
static func step_4_movement(context: CampaignContext, ai_engine: RefCounted = null) -> void:
	var faction_ids: Array[String] = context.get_sorted_faction_ids()
	
	for fid: String in faction_ids:
		var faction: FactionData = context.factions[fid]
		if faction == null or faction.is_player or fid == "faction_rebels":
			continue
			
		if ai_engine != null and ai_engine.has_method("process_faction_movement"):
			ai_engine.call("process_faction_movement", faction, context)

## Step 5: Collision & Conflict Resolution (Pairwise, deterministic)
static func step_5_conflict(context: CampaignContext) -> Dictionary:
	var battles_resolved: int = 0
	var province_ids: Array[String] = context.get_sorted_province_ids()
	
	for pid: String in province_ids:
		var prov: ProvinceData = context.provinces[pid]
		if prov == null:
			continue
			
		# Gather all field armies stationed in this province
		var prov_armies: Array[ArmyData] = []
		for a: ArmyData in context.armies:
			if a != null and a.current_province_id == pid and not a.units.is_empty():
				prov_armies.append(a)
				
		prov_armies.sort_custom(func(a: ArmyData, b: ArmyData) -> bool:
			return a.army_id < b.army_id
		)
		
		# Resolve pairwise hostile encounters
		var i: int = 0
		while i < prov_armies.size():
			var a1: ArmyData = prov_armies[i]
			var j: int = i + 1
			while j < prov_armies.size():
				var a2: ArmyData = prov_armies[j]
				if a1.owner_faction_id != a2.owner_faction_id:
					# Hostile army encounter
					var res: BattleResult = AutoResolveEngine.resolve_battle(a1, a2, {"is_settlement_siege": false})
					AutoResolveEngine.apply_battle_result(res, a1, a2)
					battles_resolved += 1
					context.log_event("battle_resolved", {
						"province_id": pid,
						"attacker_id": a1.army_id,
						"defender_id": a2.army_id,
						"attacker_won": res.attacker_won
					})
					
					var f1: FactionData = context.factions.get(a1.owner_faction_id)
					var f2: FactionData = context.factions.get(a2.owner_faction_id)
					if (f1 != null and f1.is_player) or (f2 != null and f2.is_player):
						context.is_player_battle_pending = true
						context.awaiting_player_battle = res
						
					if a1.units.is_empty():
						context.remove_army(a1)
						prov_armies.erase(a1)
						i -= 1
						break
					if a2.units.is_empty():
						context.remove_army(a2)
						prov_armies.erase(a2)
						j -= 1
				j += 1
			i += 1
			
		# Check hostile army against undefended or garrisoned settlement
		for army: ArmyData in prov_armies:
			if prov.owner_faction_id != "" and prov.owner_faction_id != army.owner_faction_id:
				if not prov.garrison_units.is_empty():
					var garrison_army: ArmyData = ArmyData.new()
					garrison_army.army_id = "garrison_" + prov.province_id
					garrison_army.owner_faction_id = prov.owner_faction_id
					garrison_army.units = prov.garrison_units.duplicate()
					garrison_army.stance = ArmyData.Stance.ENCAMPMENT
					
					var g_res: BattleResult = AutoResolveEngine.resolve_battle(army, garrison_army, {
						"is_settlement_siege": true,
						"settlement_level": prov.settlement_level
					})
					AutoResolveEngine.apply_battle_result(g_res, army, garrison_army)
					battles_resolved += 1
					
					if g_res.attacker_won:
						prov.owner_faction_id = army.owner_faction_id
						prov.public_order = clampf(prov.public_order - 30.0, -100.0, 100.0)
						prov.garrison_units.clear()
						context.log_event("settlement_conquered", {
							"province_id": pid,
							"conqueror_faction": army.owner_faction_id
						})
				else:
					prov.owner_faction_id = army.owner_faction_id
					prov.public_order = clampf(prov.public_order - 30.0, -100.0, 100.0)
					context.log_event("settlement_conquered", {
						"province_id": pid,
						"conqueror_faction": army.owner_faction_id
					})
					
	return {"battles_resolved": battles_resolved}

## Step 6: Upkeep Deductions, Bankruptcy & Attrition
static func step_6_upkeep(context: CampaignContext) -> void:
	var faction_ids: Array[String] = context.get_sorted_faction_ids()
	
	for fid: String in faction_ids:
		var faction: FactionData = context.factions[fid]
		if faction == null:
			continue
			
		var total_upkeep: int = 0
		var faction_armies: Array[ArmyData] = []
		
		for a: ArmyData in context.armies:
			if a != null and a.owner_faction_id == fid:
				faction_armies.append(a)
				total_upkeep += a.calculate_total_upkeep()
				
		faction.total_upkeep = total_upkeep
		
		if faction.treasury >= total_upkeep:
			faction.treasury -= total_upkeep
			faction.is_bankrupt = false
		else:
			var deficit: int = total_upkeep - faction.treasury
			faction.treasury = 0
			faction.is_bankrupt = true
			context.log_event("faction_bankrupt", {
				"faction_id": fid,
				"deficit": deficit
			})
			
			# Deterministic bankruptcy desertion on field armies
			faction_armies.sort_custom(func(a: ArmyData, b: ArmyData) -> bool:
				return a.army_id < b.army_id
			)
			
			for army: ArmyData in faction_armies:
				if deficit <= 0:
					break
				if army.units.is_empty():
					continue
					
				# Sort candidate units: veterancy asc -> tier asc -> unit_id asc
				var candidates: Array[UnitData] = army.units.duplicate()
				candidates.sort_custom(func(u1: UnitData, u2: UnitData) -> bool:
					if u1.veterancy_rank != u2.veterancy_rank:
						return u1.veterancy_rank < u2.veterancy_rank
					if u1.tier != u2.tier:
						return u1.tier < u2.tier
					return u1.unit_id < u2.unit_id
				)
				
				# Maximum 25% of stack may desert per turn
				var max_losses: int = maxi(1, floori(army.units.size() * 0.25))
				var losses: int = 0
				
				for u: UnitData in candidates:
					if losses >= max_losses or deficit <= 0:
						break
					deficit -= u.turn_upkeep
					army.remove_unit(u)
					losses += 1
					context.log_event("unit_deserted", {
						"faction_id": fid,
						"army_id": army.army_id,
						"unit_id": u.unit_id
					})
					
				if army.units.is_empty():
					context.remove_army(army)

## Step 7: Public Order Accumulation, Rebel Spawns, AP Reset & Turn Advance
static func step_7_reset(context: CampaignContext) -> void:
	var province_ids: Array[String] = context.get_sorted_province_ids()
	
	for pid: String in province_ids:
		var prov: ProvinceData = context.provinces[pid]
		if prov == null:
			continue
			
		var faction: FactionData = context.factions.get(prov.owner_faction_id)
		
		# Evaluate Public Order
		var po: int = EconomyCalculator.calculate_public_order(prov, faction)
		prov.public_order = float(po)
		
		# Asymmetric unrest pressure update
		if prov.public_order < 0.0:
			prov.consecutive_unrest_turns += 1
			prov.unrest_pressure += 1
		elif prov.public_order >= prov.calm_margin:
			prov.consecutive_unrest_turns = 0
			prov.unrest_pressure = maxi(0, prov.unrest_pressure - 1)
		else:
			prov.consecutive_unrest_turns = 0
			# Intermediate range 0 <= PO < calm_margin: unrest_pressure remains unchanged
			
		# Check rebellion trigger
		if prov.rebellion_cooldown > 0:
			prov.rebellion_cooldown -= 1
		elif prov.unrest_pressure >= 2:
			_spawn_rebellion(context, prov)
			
	# AP restoration for all armies
	for a: ArmyData in context.armies:
		if a != null:
			a.reset_action_points()
			a.has_retreated_this_turn = false
			
	# Advance turn counter
	context.current_turn += 1
	context.log_event("turn_advanced", {"new_turn": context.current_turn})

## Spawns rebel army outside settlement under SIEGE stance.
static func _spawn_rebellion(context: CampaignContext, prov: ProvinceData) -> void:
	var rebel_army: ArmyData = ArmyData.new()
	rebel_army.army_id = "rebel_%s_%d" % [prov.province_id, context.current_turn]
	rebel_army.army_name = "%s Rebels" % prov.province_name
	rebel_army.owner_faction_id = "faction_rebels"
	rebel_army.current_province_id = prov.province_id
	rebel_army.stance = ArmyData.Stance.SIEGE
	
	var unit_count_to_spawn: int = 2 + prov.settlement_level
	for idx in range(unit_count_to_spawn):
		var rebel_unit: UnitData = UnitData.new()
		rebel_unit.unit_id = "rebel_militia_%s_%d" % [prov.province_id, idx]
		rebel_unit.display_name = "Rebel Partisans"
		rebel_unit.tier = 1
		rebel_unit.unit_count = 100
		rebel_unit.melee_attack = 8
		rebel_unit.melee_defense = 8
		rebel_unit.armor = 15
		rebel_unit.morale = 8
		rebel_unit.turn_upkeep = 0 # Rebels have zero upkeep
		rebel_unit.upkeep_cost = 0
		rebel_unit.role_tags = [UnitData.RoleTag.INFANTRY_SPEAR]
		rebel_army.add_unit(rebel_unit)
		
	context.add_army(rebel_army)
	prov.unrest_pressure = 0
	prov.consecutive_unrest_turns = 0
	prov.rebellion_cooldown = 2
	
	context.log_event("rebellion_spawned", {
		"province_id": prov.province_id,
		"army_id": rebel_army.army_id,
		"unit_count": unit_count_to_spawn
	})

## Lightweight AI behavior for rebel stacks in Step 2.
static func _process_rebel_behavior(context: CampaignContext) -> void:
	for a: ArmyData in context.armies:
		if a != null and a.owner_faction_id == "faction_rebels":
			var prov: ProvinceData = context.provinces.get(a.current_province_id)
			if prov != null and prov.owner_faction_id != "faction_rebels":
				# Rebel sieging settlement
				var garrison_cp: float = 0.0
				for g: UnitData in prov.garrison_units:
					if g != null:
						garrison_cp += g.get_combat_value()
				var rebel_cp: float = 0.0
				for u: UnitData in a.units:
					if u != null:
						rebel_cp += u.get_combat_value()
						
				var fort_mult: float = 1.0 + float(prov.settlement_level) * 0.25
				var ratio: float = rebel_cp / maxf(1.0, garrison_cp * fort_mult)
				
				# Assault if power ratio >= 1.0, otherwise hold siege
				if ratio >= 1.0:
					a.stance = ArmyData.Stance.NORMAL
				else:
					a.stance = ArmyData.Stance.SIEGE
