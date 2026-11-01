class_name AutoResolveCalculator
extends RefCounted

## Calculates the effective combat power of an army factoring unit stats, composition counters,
## stance modifiers, and general leadership.
static func calculate_effective_combat_power(army: ArmyData, opponent_army: ArmyData = null, is_defending: bool = false) -> float:
	if army == null or army.units.is_empty():
		return 0.0
	
	var base_power: float = 0.0
	var role_counts: Dictionary = {
		UnitData.Role.HOPLITE: 0,
		UnitData.Role.CAVALRY: 0,
		UnitData.Role.RANGED: 0,
		UnitData.Role.SKIRMISHER: 0
	}
	
	for unit: UnitData in army.units:
		if unit == null:
			continue
		base_power += unit.get_combat_value()
		if role_counts.has(unit.role):
			role_counts[unit.role] += 1
		else:
			role_counts[unit.role] = 1

	# --- Tactical Composition & Counter Modifiers ---
	var composition_multiplier: float = 1.0
	if opponent_army != null and not opponent_army.units.is_empty():
		var opp_role_counts: Dictionary = {
			UnitData.Role.HOPLITE: 0,
			UnitData.Role.CAVALRY: 0,
			UnitData.Role.RANGED: 0,
			UnitData.Role.SKIRMISHER: 0
		}
		for opp_unit: UnitData in opponent_army.units:
			if opp_unit != null and opp_role_counts.has(opp_unit.role):
				opp_role_counts[opp_unit.role] += 1

		# Hoplite anti-cavalry phalanx bonus
		if role_counts[UnitData.Role.HOPLITE] > 0 and opp_role_counts[UnitData.Role.CAVALRY] > 0:
			composition_multiplier += 0.15
		
		# Cavalry flanking bonus against vulnerable ranged archers
		if role_counts[UnitData.Role.CAVALRY] > 0 and opp_role_counts[UnitData.Role.RANGED] > 0:
			composition_multiplier += 0.20
		
		# Ranged harassment bonus against slow infantry with inadequate cavalry screen
		if role_counts[UnitData.Role.RANGED] > 0 and opp_role_counts[UnitData.Role.HOPLITE] > 0 and opp_role_counts[UnitData.Role.CAVALRY] == 0:
			composition_multiplier += 0.15

		# Skirmisher harassment bonus against heavy phalanx
		if role_counts[UnitData.Role.SKIRMISHER] > 0 and opp_role_counts[UnitData.Role.HOPLITE] > 0:
			composition_multiplier += 0.10

	# --- General Leadership Modifier ---
	# Leadership rating 1.0 = base (100%), rating 2.0 = 130%, rating 0.5 = 85%
	var leadership_multiplier: float = 0.7 + (army.general_leadership_rating * 0.3)

	# --- Stance Modifiers ---
	var stance_multiplier: float = 1.0
	match army.stance:
		ArmyData.Stance.FORCED_MARCH:
			# Disorganized and tired from rapid marching
			stance_multiplier = 0.75
		ArmyData.Stance.ENCAMP:
			# Fortified palisade bonus when defending
			if is_defending:
				stance_multiplier = 1.30
			else:
				stance_multiplier = 0.90
		ArmyData.Stance.SIEGE:
			stance_multiplier = 1.15
		ArmyData.Stance.DEFAULT:
			stance_multiplier = 1.0

	var total_power: float = base_power * composition_multiplier * leadership_multiplier * stance_multiplier
	return maxf(total_power, 1.0)


## Calculates attacker win probability percentage (0.0 to 1.0) using a smooth exponential ratio.
static func calculate_win_probability(attacker_power: float, defender_power: float) -> float:
	var safe_att: float = maxf(attacker_power, 1.0)
	var safe_def: float = maxf(defender_power, 1.0)
	
	# Power exponent 1.5 provides a natural logistic curve
	var powered_att: float = pow(safe_att, 1.5)
	var powered_def: float = pow(safe_def, 1.5)
	
	var probability: float = powered_att / (powered_att + powered_def)
	# Clamp between 2% and 98% to preserve tactical upset potential
	return clampf(probability, 0.02, 0.98)


## Resolves battle purely using mathematical modeling and returns an exhaustive BattleResult.
static func resolve_battle(attacker: ArmyData, defender: ArmyData, forced_roll: float = -1.0) -> BattleResult:
	var result: BattleResult = BattleResult.new()
	result.attacker_army = attacker
	result.defender_army = defender

	# 1. Calculate combat power
	var att_power: float = calculate_effective_combat_power(attacker, defender, false)
	var def_power: float = calculate_effective_combat_power(defender, attacker, true)
	result.attacker_power = att_power
	result.defender_power = def_power

	# 2. Calculate win probability
	var win_prob: float = calculate_win_probability(att_power, def_power)
	result.attacker_win_probability = win_prob

	# 3. Roll outcome
	var roll: float = forced_roll if forced_roll >= 0.0 else randf()
	result.attacker_won = (roll <= win_prob)

	# 4. Casualty distribution
	var winner_power: float = att_power if result.attacker_won else def_power
	var loser_power: float = def_power if result.attacker_won else att_power
	var total_power: float = winner_power + loser_power

	# Loser suffers between 50% and 95% casualties based on how decisively they were beaten
	var loser_casualty_ratio: float = clampf(0.50 + (0.45 * (winner_power / total_power)), 0.50, 0.95)
	# Winner suffers between 8% and 45% casualties proportional to enemy resistance
	var winner_casualty_ratio: float = clampf(0.08 + (0.37 * (loser_power / total_power)), 0.08, 0.45)

	var att_loss_ratio: float = winner_casualty_ratio if result.attacker_won else loser_casualty_ratio
	var def_loss_ratio: float = loser_casualty_ratio if result.attacker_won else winner_casualty_ratio

	# Distribute unit casualties
	_distribute_casualties(attacker.units, att_loss_ratio, result.attacker_survivors, result.attacker_destroyed_units)
	_distribute_casualties(defender.units, def_loss_ratio, result.defender_survivors, result.defender_destroyed_units)

	result.attacker_casualties_count = result.attacker_destroyed_units.size()
	result.defender_casualties_count = result.defender_destroyed_units.size()

	# Formulate summary
	if result.attacker_won:
		if att_power > def_power * 1.8:
			result.battle_summary = "Decisive Attacker Victory: The defenders broke in utter rout."
		elif result.attacker_casualties_count > (attacker.units.size() / 2):
			result.battle_summary = "Pyrrhic Attacker Victory: Ground gained at severe tactical loss."
		else:
			result.battle_summary = "Clear Attacker Victory: Enemy lines shattered."
	else:
		if def_power > att_power * 1.8:
			result.battle_summary = "Decisive Defense: The attacking assault was decimated on the approach."
		else:
			result.battle_summary = "Resolute Defense: The defensive line held firm against all odds."

	return result


## Distributes casualties among an army's units based on armor, tier, and combat survivability.
static func _distribute_casualties(units: Array[UnitData], target_loss_ratio: float, survivors: Array[UnitData], casualties: Array[UnitData]) -> void:
	survivors.clear()
	casualties.clear()

	if units.is_empty():
		return

	var target_kills: int = clampi(roundi(float(units.size()) * target_loss_ratio), 0, units.size())
	if target_loss_ratio > 0.0 and target_kills == 0 and units.size() > 0:
		target_kills = 1

	# Score units by vulnerability (lower tier + lower armor = higher vulnerability)
	var unit_vulnerabilities: Array[Dictionary] = []
	for i: int in range(units.size()):
		var u: UnitData = units[i]
		if u == null:
			continue
		# Resilience score: higher tier & armor survive better
		var resilience: float = (u.tier * 25.0) + u.armor + randf_range(-15.0, 15.0)
		unit_vulnerabilities.append({
			"unit": u,
			"resilience": resilience
		})

	# Sort ascending by resilience (most vulnerable first)
	unit_vulnerabilities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["resilience"] < b["resilience"]
	)

	for i: int in range(unit_vulnerabilities.size()):
		var unit: UnitData = unit_vulnerabilities[i]["unit"]
		if i < target_kills:
			casualties.append(unit)
		else:
			survivors.append(unit)
