class_name AutoResolveEngine
extends RefCounted

const LOGIT_SENSITIVITY_EXPONENT: float = 2.5
const MAX_VICTOR_CASUALTY_RATIO: float = 0.85
const MIN_WIN_PROBABILITY: float = 0.02
const MAX_WIN_PROBABILITY: float = 0.98
const WIPEOUT_SURVIVOR_THRESHOLD: float = 0.20

## Computes baseline unit combat power using the comprehensive Phase 1 combat value formula.
static func calculate_unit_base_power(unit: UnitData) -> float:
	if unit == null:
		return 0.0
	return unit.get_combat_value()

## Resolves rock-paper-scissors matchup multiplier between unit role tags and opponent army composition.
static func get_matchup_multiplier(unit_role_tags: Array[UnitData.RoleTag], enemy_role_tags: Array[UnitData.RoleTag]) -> float:
	if unit_role_tags.is_empty() or enemy_role_tags.is_empty():
		return 1.0
		
	var multiplier: float = 1.0
	for u_tag: UnitData.RoleTag in unit_role_tags:
		for e_tag: UnitData.RoleTag in enemy_role_tags:
			if u_tag == UnitData.RoleTag.INFANTRY_SPEAR and (e_tag == UnitData.RoleTag.CAVALRY_LIGHT or e_tag == UnitData.RoleTag.CAVALRY_HEAVY):
				multiplier = maxf(multiplier, 1.75)
			elif (u_tag == UnitData.RoleTag.CAVALRY_LIGHT or u_tag == UnitData.RoleTag.CAVALRY_HEAVY) and (e_tag == UnitData.RoleTag.MISSILE_BOW or e_tag == UnitData.RoleTag.MISSILE_SKIRMISHER):
				multiplier = maxf(multiplier, 1.60)
			elif u_tag == UnitData.RoleTag.INFANTRY_SWORD and u_tag != e_tag and e_tag == UnitData.RoleTag.INFANTRY_SPEAR:
				multiplier = maxf(multiplier, 1.35)
			elif (u_tag == UnitData.RoleTag.MISSILE_BOW or u_tag == UnitData.RoleTag.MISSILE_SKIRMISHER) and e_tag == UnitData.RoleTag.INFANTRY_SPEAR:
				multiplier = maxf(multiplier, 1.30)
			elif (u_tag == UnitData.RoleTag.CAVALRY_LIGHT or u_tag == UnitData.RoleTag.CAVALRY_HEAVY) and e_tag == UnitData.RoleTag.INFANTRY_SPEAR:
				multiplier = minf(multiplier, 0.50)
				
	return multiplier

## Calculates total army combat power with matchup bonuses and leadership/morale/fortification modifiers.
static func calculate_army_combat_power(army: ArmyData, opponent: ArmyData, is_defending: bool = false, context: Dictionary = {}) -> float:
	if army == null or army.units.is_empty():
		return 0.0
		
	# Collect enemy role tags
	var opp_tags: Array[UnitData.RoleTag] = []
	if opponent != null:
		for opp_u: UnitData in opponent.units:
			if opp_u != null:
				for tag: UnitData.RoleTag in opp_u.role_tags:
					if not opp_tags.has(tag):
						opp_tags.append(tag)
						
	var raw_power: float = 0.0
	var total_morale: float = 0.0
	var active_units_count: int = 0
	
	for unit: UnitData in army.units:
		if unit == null or unit.unit_count <= 0:
			continue
		var base_cp: float = unit.get_combat_value()
		var matchup_mod: float = get_matchup_multiplier(unit.role_tags, opp_tags)
		raw_power += (base_cp * matchup_mod)
		total_morale += float(unit.morale)
		active_units_count += 1
		
	if active_units_count == 0 or raw_power <= 0.0:
		return 0.0
		
	# 1. General Leadership Modifier (M_gen)
	var m_gen: float = 0.85 # Penalty if no general
	if army.general_command_stars >= 0:
		m_gen = 1.0 + (0.04 * float(army.general_command_stars)) + army.general_traits_bonus
		
	# 2. Army Morale Factor (M_morale)
	var avg_mo: float = total_morale / float(active_units_count)
	var m_morale: float = 0.70 + (0.05 * avg_mo)
	
	# 3. Fortification Modifier (M_fort)
	var m_fort: float = 1.0
	if is_defending:
		if context.get("is_settlement_siege", false):
			var settlement_lvl: int = int(context.get("settlement_level", 1))
			match settlement_lvl:
				1: m_fort = 1.25
				2: m_fort = 1.45
				3: m_fort = 1.70
				4: m_fort = 2.00
				5: m_fort = 2.35
				_: m_fort = 1.25
		elif army.stance == ArmyData.Stance.ENCAMPMENT:
			m_fort = 1.25
	elif army.stance == ArmyData.Stance.ENCAMPMENT:
		m_fort = 0.90
		
	# 4. Environmental & Stance Modifier (M_env)
	var m_env: float = 1.0
	if army.stance == ArmyData.Stance.AMBUSH:
		m_env = 1.30
	elif army.stance == ArmyData.Stance.FORCED_MARCH:
		m_env = 0.80
		
	if opponent != null and opponent.stance == ArmyData.Stance.AMBUSH and is_defending:
		m_morale *= 0.75 # Ambush defense morale shock
		
	var total_modified: float = raw_power * m_gen * m_morale * m_fort * m_env
	return maxf(total_modified, 1.0)

## Computes attacker logit win probability P_win in range [0.02, 0.98].
static func calculate_win_probability(attacker_power: float, defender_power: float) -> float:
	if attacker_power <= 0.0 and defender_power <= 0.0:
		return 0.50
	if attacker_power <= 0.0:
		return MIN_WIN_PROBABILITY
	if defender_power <= 0.0:
		return MAX_WIN_PROBABILITY
		
	var safe_att: float = maxf(attacker_power, 1.0)
	var safe_def: float = maxf(defender_power, 1.0)
	
	var pow_att: float = pow(safe_att, LOGIT_SENSITIVITY_EXPONENT)
	var pow_def: float = pow(safe_def, LOGIT_SENSITIVITY_EXPONENT)
	var denom: float = pow_att + pow_def
	
	if denom <= 0.0:
		return 0.50
	return clampf(pow_att / denom, MIN_WIN_PROBABILITY, MAX_WIN_PROBABILITY)

## Calculates victor casualty fraction L_victor in [0.02, 0.85].
static func calculate_victor_casualty_ratio(victor_power: float, loser_power: float) -> float:
	var safe_vic: float = maxf(victor_power, 1.0)
	var safe_los: float = maxf(loser_power, 0.0)
	var raw: float = 0.40 * pow(safe_los / safe_vic, 1.5)
	return clampf(raw, 0.02, MAX_VICTOR_CASUALTY_RATIO)

## Calculates loser casualty fraction L_loser in [0.50, 1.00].
static func calculate_loser_casualty_ratio(victor_power: float, loser_power: float) -> float:
	var safe_vic: float = maxf(victor_power, 1.0)
	var safe_los: float = maxf(loser_power, 1.0)
	var raw: float = 0.60 + (0.40 * (safe_vic / safe_los))
	return clampf(raw, 0.50, 1.00)

## Classifies victory margin based on power ratio R and victor casualty ratio.
static func classify_victory(power_ratio: float, victor_loss_ratio: float) -> String:
	if power_ratio < 0.80 and victor_loss_ratio <= 0.15:
		return "Heroic Victory"
	elif power_ratio >= 1.75 and victor_loss_ratio <= 0.20:
		return "Decisive Victory"
	elif power_ratio >= 1.10 and power_ratio < 1.75 and victor_loss_ratio <= 0.45:
		return "Close Victory"
	elif victor_loss_ratio > 0.45 or power_ratio < 1.10:
		return "Pyrrhic Victory"
	return "Close Victory"

## Classifies defeat margin for losing side.
static func classify_defeat(power_ratio: float, loser_loss_ratio: float) -> String:
	if power_ratio >= 1.75 or loser_loss_ratio >= 0.85:
		return "Crushing Defeat"
	elif power_ratio >= 1.10:
		return "Decisive Defeat"
	return "Close Defeat"

## Calculates casualty rate for individual unit with role risk and armor factors.
static func calculate_unit_casualty_rate(unit: UnitData, army_loss_ratio: float, avg_armor: float) -> float:
	if unit == null:
		return 0.0
		
	var w_risk: float = 1.0
	for tag: UnitData.RoleTag in unit.role_tags:
		match tag:
			UnitData.RoleTag.INFANTRY_SPEAR, UnitData.RoleTag.INFANTRY_SWORD:
				w_risk = maxf(w_risk, 1.30)
			UnitData.RoleTag.CAVALRY_LIGHT, UnitData.RoleTag.CAVALRY_HEAVY:
				w_risk = maxf(w_risk, 1.20)
			UnitData.RoleTag.MISSILE_BOW, UnitData.RoleTag.MISSILE_SKIRMISHER:
				w_risk = minf(w_risk, 0.70)
			UnitData.RoleTag.ARTILLERY:
				w_risk = minf(w_risk, 0.40)
			UnitData.RoleTag.HERO_UNIT:
				w_risk = minf(w_risk, 0.50)
				
	var safe_armor: float = maxf(1.0, float(unit.armor))
	var safe_avg_armor: float = maxf(1.0, avg_armor)
	var armor_modifier: float = pow(safe_avg_armor / safe_armor, 0.3)
	return clampf(army_loss_ratio * w_risk * armor_modifier, 0.0, 1.0)

## Resolves battle between attacker and defender, returning an exhaustive BattleResult value object.
static func resolve_battle(
	attacker: ArmyData,
	defender: ArmyData,
	context: Dictionary = {},
	forced_roll: float = -1.0
) -> BattleResult:
	return simulate_battle(attacker, defender, context, forced_roll)

## Simulates battle without mutating input armies. Returns an exhaustive BattleResult value object.
static func simulate_battle(
	attacker: ArmyData,
	defender: ArmyData,
	context: Dictionary = {},
	forced_roll: float = -1.0
) -> BattleResult:
	var result: BattleResult = BattleResult.new()
	result.attacker_army = attacker
	result.defender_army = defender
	result.is_siege_defense = context.get("is_settlement_siege", false)
	
	# Initial model counts
	for u: UnitData in attacker.units:
		if u != null:
			result.attacker_initial_models += u.unit_count
	for u: UnitData in defender.units:
		if u != null:
			result.defender_initial_models += u.unit_count
			
	# Forfeits if an army is empty
	if attacker.units.is_empty() or result.attacker_initial_models == 0:
		result.attacker_won = false
		result.attacker_win_probability = MIN_WIN_PROBABILITY
		result.is_wipeout = true
		result.outcome_classification = "Crushing Defeat"
		result.battle_summary = "Attacking force was nonexistent or devoid of combatants."
		return result
		
	if defender.units.is_empty() or result.defender_initial_models == 0:
		result.attacker_won = true
		result.attacker_win_probability = MAX_WIN_PROBABILITY
		result.is_wipeout = true
		result.outcome_classification = "Decisive Victory"
		result.battle_summary = "Defending force had abandoned the field."
		return result
		
	# 1. Combat power
	var att_power: float = calculate_army_combat_power(attacker, defender, false, context)
	var def_power: float = calculate_army_combat_power(defender, attacker, true, context)
	result.attacker_power = att_power
	result.defender_power = def_power
	
	# 2. Win probability
	var win_prob: float = calculate_win_probability(att_power, def_power)
	result.attacker_win_probability = win_prob
	
	# 3. Roll outcome
	var roll: float = forced_roll if forced_roll >= 0.0 else randf()
	result.attacker_won = (roll <= win_prob)
	
	# 4. Ratios & overall casualties
	var winner_power: float = att_power if result.attacker_won else def_power
	var loser_power: float = def_power if result.attacker_won else att_power
	result.power_ratio = winner_power / maxf(1.0, loser_power)
	
	result.victor_casualty_ratio = calculate_victor_casualty_ratio(winner_power, loser_power)
	result.loser_casualty_ratio = calculate_loser_casualty_ratio(winner_power, loser_power)
	
	var att_loss_ratio: float = result.victor_casualty_ratio if result.attacker_won else result.loser_casualty_ratio
	var def_loss_ratio: float = result.loser_casualty_ratio if result.attacker_won else result.victor_casualty_ratio
	
	# 5. Victory classification
	if result.attacker_won:
		result.outcome_classification = classify_victory(result.power_ratio, result.victor_casualty_ratio)
	else:
		result.outcome_classification = classify_defeat(result.power_ratio, result.loser_casualty_ratio)
		
	# 6. Distribute casualties to clones
	_simulate_unit_casualties(attacker, att_loss_ratio, result.attacker_survivors, result.attacker_destroyed_units, result, true)
	_simulate_unit_casualties(defender, def_loss_ratio, result.defender_survivors, result.defender_destroyed_units, result, false)
	
	# 7. Wipeout & retreat evaluation on the losing army
	var loser_army: ArmyData = defender if result.attacker_won else attacker
	var loser_remaining: int = result.defender_remaining_models if result.attacker_won else result.attacker_remaining_models
	var loser_initial: int = result.defender_initial_models if result.attacker_won else result.attacker_initial_models
	var p_rem: float = float(loser_remaining) / maxf(1.0, float(loser_initial))
	
	if result.is_siege_defense and not result.attacker_won:
		result.is_wipeout = false # Defender won siege
	elif result.is_siege_defense and result.attacker_won:
		# Defender lost settlement siege: 100% destroyed per spec
		result.is_wipeout = true
	elif p_rem < WIPEOUT_SURVIVOR_THRESHOLD:
		result.is_wipeout = true
	elif loser_army.has_retreated_this_turn:
		result.is_wipeout = true
	else:
		result.is_wipeout = false
		
	if result.is_wipeout:
		result.battle_summary = "Defeated army was shattered and destroyed in full."
	else:
		result.battle_summary = "Defeated army retreated with surviving remnants."
		
	return result

static func _simulate_unit_casualties(
	army: ArmyData,
	army_loss_ratio: float,
	survivors_out: Array[UnitData],
	destroyed_out: Array[UnitData],
	result: BattleResult,
	is_attacker: bool
) -> void:
	survivors_out.clear()
	destroyed_out.clear()
	
	# Compute average armor
	var total_armor_models: float = 0.0
	var total_models: int = 0
	for u: UnitData in army.units:
		if u != null:
			total_armor_models += (float(u.armor) * float(u.unit_count))
			total_models += u.unit_count
	var avg_armor: float = total_armor_models / maxf(1.0, float(total_models))
	
	var total_lost: int = 0
	var total_remaining: int = 0
	
	for original: UnitData in army.units:
		if original == null:
			continue
		var clone_u: UnitData = original.clone()
		var n_i: int = clone_u.unit_count
		var unit_loss_rate: float = calculate_unit_casualty_rate(clone_u, army_loss_ratio, avg_armor)
		var delta_n: int = mini(n_i, roundi(float(n_i) * unit_loss_rate))
		
		# Option A guarantee: force at least 1 loss if unit was exposed
		if delta_n == 0 and unit_loss_rate >= (0.50 / maxf(1.0, float(n_i))):
			delta_n = 1
			
		var new_count: int = maxi(0, n_i - delta_n)
		clone_u.unit_count = new_count
		
		total_lost += delta_n
		total_remaining += new_count
		
		result.unit_casualties[original.unit_id] = {
			"initial": n_i,
			"lost": delta_n,
			"remaining": new_count
		}
		
		if new_count <= 0:
			destroyed_out.append(clone_u)
		else:
			survivors_out.append(clone_u)
			
	if is_attacker:
		result.attacker_casualties_count = total_lost
		result.attacker_remaining_models = total_remaining
	else:
		result.defender_casualties_count = total_lost
		result.defender_remaining_models = total_remaining

## Applies battle result to live ArmyData resources (Dedicated mutation phase).
static func apply_battle_result(result: BattleResult, attacker: ArmyData, defender: ArmyData) -> void:
	if result == null or attacker == null or defender == null:
		return
		
	_apply_casualties_to_army(attacker, result.attacker_survivors)
	_apply_casualties_to_army(defender, result.defender_survivors)
		
	# Update retreat states
	var loser: ArmyData = defender if result.attacker_won else attacker
	if result.is_wipeout:
		loser.units.clear()
		loser.current_action_points = 0.0
	else:
		loser.mark_retreated()

static func _apply_casualties_to_army(army: ArmyData, survivors: Array[UnitData]) -> void:
	var survivor_map: Dictionary = {}
	for s: UnitData in survivors:
		survivor_map[s.unit_id] = s.unit_count
		
	var active_units: Array[UnitData] = []
	for u: UnitData in army.units:
		if u != null:
			if survivor_map.has(u.unit_id):
				u.unit_count = survivor_map[u.unit_id]
				active_units.append(u)
			else:
				u.unit_count = 0
	army.units = active_units
