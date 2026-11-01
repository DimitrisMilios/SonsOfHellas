class_name TestBattleResult
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_battle_result_defaults(failures)
	_test_battle_result_survivor_integrity(failures)
	_test_battle_result_formatting(failures)
	_test_decisive_classification_check(failures)
	_test_validate_survivor_integrity_method(failures)
	_test_autoresolve_engine_resolve_battle_integration(failures)
	return failures

static func _test_battle_result_defaults(failures: Array[String]) -> void:
	var res: BattleResult = BattleResult.new()
	if res.attacker_won:
		failures.append("Expected attacker_won to default to false")
	if res.attacker_power != 0.0 or res.defender_power != 0.0:
		failures.append("Expected default powers to be 0.0")
	if res.is_wipeout:
		failures.append("Expected is_wipeout to default to false")

static func _test_battle_result_survivor_integrity(failures: Array[String]) -> void:
	var res: BattleResult = BattleResult.new()
	res.attacker_initial_models = 240
	res.attacker_casualties_count = 60
	res.attacker_remaining_models = 180
	
	if res.attacker_initial_models != (res.attacker_casualties_count + res.attacker_remaining_models):
		failures.append("Attacker model count conservation violated")
		
	res.defender_initial_models = 120
	res.defender_casualties_count = 120
	res.defender_remaining_models = 0
	res.is_wipeout = true
	
	if res.defender_initial_models != (res.defender_casualties_count + res.defender_remaining_models):
		failures.append("Defender model count conservation violated")
	if not res.is_wipeout:
		failures.append("Expected is_wipeout to be true when defender models reach 0")

static func _test_battle_result_formatting(failures: Array[String]) -> void:
	var res: BattleResult = BattleResult.new()
	res.attacker_won = true
	res.attacker_power = 2000.0
	res.defender_power = 1000.0
	res.attacker_win_probability = 0.85
	res.outcome_classification = "Decisive Victory"
	res.attacker_initial_models = 240
	res.attacker_casualties_count = 34
	res.attacker_remaining_models = 206
	res.defender_initial_models = 120
	res.defender_casualties_count = 120
	res.defender_remaining_models = 0
	res.is_wipeout = true
	
	var log_msg: String = res.get_log_message()
	if not log_msg.contains("Decisive Victory"):
		failures.append("Log message missing outcome classification")
	if not log_msg.contains("85.0%"):
		failures.append("Log message missing win probability percentage")
	if not log_msg.contains("2000"):
		failures.append("Log message missing attacker power")

static func _test_decisive_classification_check(failures: Array[String]) -> void:
	var res: BattleResult = BattleResult.new()
	res.outcome_classification = "Decisive Victory"
	if not res.is_decisive():
		failures.append("Decisive Victory should return true for is_decisive()")
		
	res.outcome_classification = "Heroic Victory"
	if not res.is_decisive():
		failures.append("Heroic Victory should return true for is_decisive()")
		
	res.outcome_classification = "Close Victory"
	if res.is_decisive():
		failures.append("Close Victory should return false for is_decisive()")
		
	res.outcome_classification = "Pyrrhic Victory"
	if res.is_decisive():
		failures.append("Pyrrhic Victory should return false for is_decisive()")

static func _test_validate_survivor_integrity_method(failures: Array[String]) -> void:
	var res: BattleResult = BattleResult.new()
	res.attacker_initial_models = 120
	res.attacker_casualties_count = 40
	res.attacker_remaining_models = 80
	res.defender_initial_models = 100
	res.defender_casualties_count = 50
	res.defender_remaining_models = 50
	
	if not res.validate_survivor_integrity():
		failures.append("validate_survivor_integrity() returned false when models are conserved")
		
	# Corrupt counts
	res.attacker_remaining_models = 70
	if res.validate_survivor_integrity():
		failures.append("validate_survivor_integrity() returned true when models were lost/corrupted")

static func _test_autoresolve_engine_resolve_battle_integration(failures: Array[String]) -> void:
	var att: ArmyData = ArmyData.new()
	var att_u: UnitData = UnitData.new()
	att_u.unit_id = "test_att"
	att_u.unit_count = 120
	att.add_unit(att_u)
	
	var def: ArmyData = ArmyData.new()
	var def_u: UnitData = UnitData.new()
	def_u.unit_id = "test_def"
	def_u.unit_count = 100
	def.add_unit(def_u)
	
	var res: BattleResult = AutoResolveEngine.resolve_battle(att, def, {}, 0.01)
	if res == null:
		failures.append("AutoResolveEngine.resolve_battle() returned null")
		return
	if not res.validate_survivor_integrity():
		failures.append("AutoResolveEngine.resolve_battle() result failed survivor integrity validation")
	if res.outcome_classification.is_empty():
		failures.append("AutoResolveEngine.resolve_battle() missing outcome classification")
