class_name TestAutoResolveEngine
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_unit_combat_power_formula(failures)
	_test_matchup_multipliers(failures)
	_test_logit_win_probability(failures)
	_test_casualty_calculation_curves(failures)
	_test_unit_level_risk_weighting_and_armor(failures)
	_test_victory_margin_classification(failures)
	_test_wipeout_under_20_percent(failures)
	_test_settlement_siege_defender_wipeout(failures)
	_test_second_retreat_wipeout(failures)
	_test_simulation_purity_and_apply(failures)
	return failures

static func _create_test_unit(id: String, role_tag: UnitData.RoleTag, count: int, attack: int, defense: int, armor: int) -> UnitData:
	var u: UnitData = UnitData.new()
	u.unit_id = id
	u.display_name = id.capitalize()
	u.role_tags = [role_tag]
	u.unit_count = count
	u.melee_attack = attack
	u.melee_defense = defense
	u.armor = armor
	u.charge_bonus = 5
	return u

static func _test_unit_combat_power_formula(failures: Array[String]) -> void:
	var unit: UnitData = _create_test_unit("spartan_hoplite", UnitData.RoleTag.INFANTRY_SPEAR, 120, 14, 18, 45)
	# Melee value: 14 + 0.6(18) + 0.5(45) + 0.4(5) = 14 + 10.8 + 22.5 + 2.0 = 49.3
	# Power: 120 * 49.3 * 1.0 = 5916.0
	var cp: float = AutoResolveEngine.calculate_unit_base_power(unit)
	if absf(cp - 5916.0) > 1.0:
		failures.append("Expected unit combat power ~5916.0, got: %f" % cp)

static func _test_matchup_multipliers(failures: Array[String]) -> void:
	# Spear vs Cavalry = 1.75
	var spear_vs_cav: float = AutoResolveEngine.get_matchup_multiplier([UnitData.RoleTag.INFANTRY_SPEAR], [UnitData.RoleTag.CAVALRY_HEAVY])
	if not is_equal_approx(spear_vs_cav, 1.75):
		failures.append("Spear vs Cavalry matchup should be 1.75, got: %f" % spear_vs_cav)
		
	# Cavalry vs Spear = 0.50
	var cav_vs_spear: float = AutoResolveEngine.get_matchup_multiplier([UnitData.RoleTag.CAVALRY_HEAVY], [UnitData.RoleTag.INFANTRY_SPEAR])
	if not is_equal_approx(cav_vs_spear, 0.50):
		failures.append("Cavalry vs Spear matchup should be 0.50, got: %f" % cav_vs_spear)
		
	# Cavalry vs Missile = 1.60
	var cav_vs_missile: float = AutoResolveEngine.get_matchup_multiplier([UnitData.RoleTag.CAVALRY_LIGHT], [UnitData.RoleTag.MISSILE_BOW])
	if not is_equal_approx(cav_vs_missile, 1.60):
		failures.append("Cavalry vs Missile matchup should be 1.60, got: %f" % cav_vs_missile)

static func _test_logit_win_probability(failures: Array[String]) -> void:
	# Equal power -> 50%
	var p_equal: float = AutoResolveEngine.calculate_win_probability(1000.0, 1000.0)
	if not is_equal_approx(p_equal, 0.50):
		failures.append("Equal power win probability should be 0.50, got: %f" % p_equal)
		
	# 2:1 ratio (2000 vs 1000) -> 2^2.5 / (2^2.5 + 1^2.5) = 5.657 / 6.657 = ~0.8497
	var p_2to1: float = AutoResolveEngine.calculate_win_probability(2000.0, 1000.0)
	if absf(p_2to1 - 0.850) > 0.01:
		failures.append("2:1 ratio win probability should be ~0.85, got: %f" % p_2to1)
		
	# Division by zero guard: 0 vs 0 must return 0.50 and not crash or NaN
	var p_zero: float = AutoResolveEngine.calculate_win_probability(0.0, 0.0)
	if is_nan(p_zero) or not is_equal_approx(p_zero, 0.50):
		failures.append("0 vs 0 power should safely return 0.50 without NaN")

static func _test_casualty_calculation_curves(failures: Array[String]) -> void:
	# 2:1 power ratio (Victor 2000, Loser 1000)
	# Victor loss: 0.40 * (1000/2000)^1.5 = 0.40 * (0.5)^1.5 = 0.40 * 0.35355 = ~0.1414 (14.1%)
	var victor_loss: float = AutoResolveEngine.calculate_victor_casualty_ratio(2000.0, 1000.0)
	if absf(victor_loss - 0.1414) > 0.01:
		failures.append("Expected victor casualty ratio ~0.1414, got: %f" % victor_loss)
		
	# Loser loss: min(1.0, 0.60 + 0.40 * (2000/1000)) = min(1.0, 1.40) = 1.0 (100%)
	var loser_loss: float = AutoResolveEngine.calculate_loser_casualty_ratio(2000.0, 1000.0)
	if not is_equal_approx(loser_loss, 1.0):
		failures.append("Expected loser casualty ratio 1.0 for 2:1 disadvantage, got: %f" % loser_loss)

static func _test_unit_level_risk_weighting_and_armor(failures: Array[String]) -> void:
	# Frontline spear unit vs Protected general
	var spear: UnitData = _create_test_unit("spear", UnitData.RoleTag.INFANTRY_SPEAR, 100, 10, 10, 20)
	var general: UnitData = _create_test_unit("gen", UnitData.RoleTag.HERO_UNIT, 40, 15, 15, 40)
	
	var spear_rate: float = AutoResolveEngine.calculate_unit_casualty_rate(spear, 0.20, 25.0)
	var gen_rate: float = AutoResolveEngine.calculate_unit_casualty_rate(general, 0.20, 25.0)
	
	if spear_rate <= gen_rate:
		failures.append("Spearmen (frontline) should suffer higher casualty rate than General bodyguard")
		
	# Armor = 0 division by zero check
	var unarmored: UnitData = _create_test_unit("naked", UnitData.RoleTag.INFANTRY_SPEAR, 100, 10, 10, 0)
	var safe_rate: float = AutoResolveEngine.calculate_unit_casualty_rate(unarmored, 0.20, 25.0)
	if is_nan(safe_rate) or is_inf(safe_rate):
		failures.append("Unarmored unit casualty calculation resulted in NaN or INF")

static func _test_victory_margin_classification(failures: Array[String]) -> void:
	# Decisive: Ratio >= 1.75, Victor Loss <= 20%
	var decisive: String = AutoResolveEngine.classify_victory(2.0, 0.15)
	if decisive != "Decisive Victory":
		failures.append("Expected Decisive Victory, got: " + decisive)
		
	# Heroic: Ratio < 0.80 (outnumbered), Victor Loss <= 15%
	var heroic: String = AutoResolveEngine.classify_victory(0.70, 0.10)
	if heroic != "Heroic Victory":
		failures.append("Expected Heroic Victory, got: " + heroic)
		
	# Close: 1.10 <= Ratio < 1.75, Victor Loss <= 45%
	var close_vic: String = AutoResolveEngine.classify_victory(1.30, 0.30)
	if close_vic != "Close Victory":
		failures.append("Expected Close Victory, got: " + close_vic)
		
	# Pyrrhic: Victor Loss > 45%
	var pyrrhic: String = AutoResolveEngine.classify_victory(1.05, 0.50)
	if pyrrhic != "Pyrrhic Victory":
		failures.append("Expected Pyrrhic Victory, got: " + pyrrhic)

static func _test_wipeout_under_20_percent(failures: Array[String]) -> void:
	var att: ArmyData = ArmyData.new()
	att.add_unit(_create_test_unit("att_spear", UnitData.RoleTag.INFANTRY_SPEAR, 300, 15, 15, 30))
	
	var def: ArmyData = ArmyData.new()
	def.add_unit(_create_test_unit("def_peasant", UnitData.RoleTag.INFANTRY_SPEAR, 50, 5, 5, 5))
	
	# Attacker dominates overwhelmingly, forced roll 0.01 (attacker wins)
	var res: BattleResult = AutoResolveEngine.simulate_battle(att, def, {}, 0.01)
	if not res.attacker_won:
		failures.append("Attacker should win simulation")
	if not res.is_wipeout:
		failures.append("Defeated small force should be wiped out (survivors < 20%)")

static func _test_settlement_siege_defender_wipeout(failures: Array[String]) -> void:
	var att: ArmyData = ArmyData.new()
	att.add_unit(_create_test_unit("att_legion", UnitData.RoleTag.INFANTRY_SPEAR, 200, 12, 12, 30))
	
	var def: ArmyData = ArmyData.new()
	def.add_unit(_create_test_unit("def_garrison", UnitData.RoleTag.INFANTRY_SPEAR, 100, 10, 10, 20))
	
	# Siege defense context: is_settlement_siege = true
	var res: BattleResult = AutoResolveEngine.simulate_battle(att, def, {"is_settlement_siege": true}, 0.01)
	if not res.is_wipeout:
		failures.append("Defender defeated in settlement siege must be 100% wiped out")

static func _test_second_retreat_wipeout(failures: Array[String]) -> void:
	var att: ArmyData = ArmyData.new()
	att.add_unit(_create_test_unit("att_force", UnitData.RoleTag.INFANTRY_SPEAR, 120, 12, 12, 25))
	
	var def: ArmyData = ArmyData.new()
	def.add_unit(_create_test_unit("def_force", UnitData.RoleTag.INFANTRY_SPEAR, 100, 10, 10, 20))
	def.has_retreated_this_turn = true # Already retreated once this turn
	
	var res: BattleResult = AutoResolveEngine.simulate_battle(att, def, {}, 0.01)
	if not res.is_wipeout:
		failures.append("Army that has already retreated this turn must be wiped out on second defeat")

static func _test_simulation_purity_and_apply(failures: Array[String]) -> void:
	var att: ArmyData = ArmyData.new()
	var att_unit: UnitData = _create_test_unit("att_1", UnitData.RoleTag.INFANTRY_SPEAR, 120, 12, 12, 25)
	att.add_unit(att_unit)
	
	var def: ArmyData = ArmyData.new()
	var def_unit: UnitData = _create_test_unit("def_1", UnitData.RoleTag.INFANTRY_SPEAR, 100, 10, 10, 20)
	def.add_unit(def_unit)
	
	var res: BattleResult = AutoResolveEngine.simulate_battle(att, def, {}, 0.01)
	
	# Purity check: simulate_battle must not mutate original units
	if att_unit.unit_count != 120:
		failures.append("simulate_battle mutated attacker unit count")
	if def_unit.unit_count != 100:
		failures.append("simulate_battle mutated defender unit count")
		
	# Apply check: apply_battle_result modifies the state
	AutoResolveEngine.apply_battle_result(res, att, def)
	if att_unit.unit_count >= 120:
		failures.append("apply_battle_result failed to apply casualties to attacker")
