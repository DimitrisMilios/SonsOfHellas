class_name TestArmyData
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_army_defaults(failures)
	_test_raiding_stance_activation_and_upkeep(failures)
	_test_forced_march_ap_lifecycle(failures)
	_test_forced_march_exploit_prevention(failures)
	_test_retreat_rule_enforcement(failures)
	_test_army_clone_independence(failures)
	_test_army_serialization_round_trip(failures)
	return failures

static func _test_army_defaults(failures: Array[String]) -> void:
	var army: ArmyData = ArmyData.new()
	if army.stance != ArmyData.Stance.NORMAL:
		failures.append("Expected default stance to be NORMAL")
	if army.has_retreated_this_turn:
		failures.append("Expected has_retreated_this_turn to start false")
	if army.current_action_points != 100.0 or army.max_action_points != 100.0:
		failures.append("Expected default action points to be 100.0")

static func _test_raiding_stance_activation_and_upkeep(failures: Array[String]) -> void:
	var army: ArmyData = ArmyData.new()
	var unit: UnitData = UnitData.new()
	unit.upkeep_cost = 100
	unit.turn_upkeep = 100
	army.add_unit(unit)
	
	# Normal upkeep = 100
	if army.calculate_total_upkeep() != 100:
		failures.append("Expected base upkeep 100, got: " + str(army.calculate_total_upkeep()))
		
	# Spend 60 AP (only 40 left -> cannot activate raiding because AP spent > 50%)
	army.current_action_points = 40.0
	var activated_late: bool = army.set_stance(ArmyData.Stance.RAIDING)
	if activated_late:
		failures.append("Raiding stance activated when AP spent > 50%")
		
	# Reset AP and spend only 30 AP (70 left -> can activate)
	army.current_action_points = 70.0
	var activated: bool = army.set_stance(ArmyData.Stance.RAIDING)
	if not activated:
		failures.append("Raiding stance failed to activate when AP remaining >= 50%")
	if army.stance != ArmyData.Stance.RAIDING:
		failures.append("Stance was not set to RAIDING")
	if army.calculate_total_upkeep() != 50:
		failures.append("Expected raiding upkeep to be 50% (50 gold), got: " + str(army.calculate_total_upkeep()))
	if army.max_action_points != 50.0:
		failures.append("Expected max AP in raiding to be 50.0, got: " + str(army.max_action_points))
	if army.current_action_points != 20.0:
		failures.append("Expected remaining AP after raiding cost to be 20.0, got: " + str(army.current_action_points))

static func _test_forced_march_ap_lifecycle(failures: Array[String]) -> void:
	var army: ArmyData = ArmyData.new()
	army.set_stance(ArmyData.Stance.FORCED_MARCH)
	army.reset_action_points()
	
	# Forced march grants 1.5x AP
	if army.current_action_points < 140.0:
		failures.append("Expected Forced March to grant extended AP (>140), got: " + str(army.current_action_points))

static func _test_forced_march_exploit_prevention(failures: Array[String]) -> void:
	var army: ArmyData = ArmyData.new()
	# Default: 100 AP, Normal stance
	# Toggle between Normal and Forced March 10 times
	for i in range(10):
		army.set_stance(ArmyData.Stance.FORCED_MARCH)
		if army.current_action_points > 150.0:
			failures.append("AP grew beyond 150.0 during stance toggle: " + str(army.current_action_points))
			break
		army.set_stance(ArmyData.Stance.NORMAL)
		if army.current_action_points > 100.0:
			failures.append("AP exceeded 100.0 when returning to Normal: " + str(army.current_action_points))
			break
			
	if army.current_action_points != 100.0:
		failures.append("Expected AP to remain 100.0 after toggles, got: " + str(army.current_action_points))

static func _test_retreat_rule_enforcement(failures: Array[String]) -> void:
	var army: ArmyData = ArmyData.new()
	army.current_action_points = 80.0
	
	# First retreat succeeds and zeros AP
	var first_retreat: bool = army.mark_retreated()
	if not first_retreat:
		failures.append("First retreat should succeed")
	if not army.has_retreated_this_turn:
		failures.append("has_retreated_this_turn should be true after first retreat")
	if army.current_action_points != 0.0:
		failures.append("AP should be 0 after retreat")
		
	# Second retreat in same turn fails (triggers wipeout)
	var second_retreat: bool = army.mark_retreated()
	if second_retreat:
		failures.append("Second retreat in same turn should fail (violates wipeout rule)")
		
	# Turn reset clears retreat flag
	army.reset_action_points()
	if army.has_retreated_this_turn:
		failures.append("has_retreated_this_turn should reset to false on turn reset")

static func _test_army_clone_independence(failures: Array[String]) -> void:
	var army: ArmyData = ArmyData.new()
	var unit: UnitData = UnitData.new()
	unit.unit_id = "test_unit"
	unit.unit_count = 120
	army.add_unit(unit)
	
	var clone_army: ArmyData = army.clone()
	if clone_army.units.size() != 1:
		failures.append("Clone units array size mismatch")
		return
	if clone_army.units[0] == unit:
		failures.append("Clone army shared identical unit instance reference")
		
	clone_army.units[0].unit_count = 50
	if army.units[0].unit_count != 120:
		failures.append("Mutating clone army unit mutated original army unit")

static func _test_army_serialization_round_trip(failures: Array[String]) -> void:
	var army: ArmyData = ArmyData.new()
	army.army_id = "army_sparta_main"
	army.army_name = "Royal Spartan Army"
	army.owner_faction_id = "faction_sparta"
	army.current_province_id = "prov_laconia"
	army.general_name = "Leonidas"
	army.general_command_stars = 6
	army.general_traits_bonus = 0.10
	army.current_action_points = 65.0
	army.max_action_points = 100.0
	army.set_stance(ArmyData.Stance.ENCAMPMENT)
	army.has_retreated_this_turn = false
	
	var unit: UnitData = UnitData.new()
	unit.unit_id = "unit_spartan_royal_guard"
	unit.unit_count = 100
	army.add_unit(unit)
	
	var dict: Dictionary = army.to_dict()
	var restored: ArmyData = ArmyData.from_dict(dict)
	
	if restored == null:
		failures.append("from_dict returned null")
		return
	if restored.army_id != army.army_id:
		failures.append("Restored army_id mismatch")
	if restored.general_command_stars != 6:
		failures.append("Restored command stars mismatch")
	if restored.stance != ArmyData.Stance.ENCAMPMENT:
		failures.append("Restored stance mismatch")
	if absf(restored.current_action_points - 65.0) > 0.1:
		failures.append("Restored current AP mismatch")
	if restored.units.size() != 1 or restored.units[0].unit_id != "unit_spartan_royal_guard":
		failures.append("Restored units mismatch")
