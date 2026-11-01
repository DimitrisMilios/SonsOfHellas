class_name TestUnitData
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_unit_defaults(failures)
	_test_unit_combat_value(failures)
	_test_unit_clone_deep_copy(failures)
	_test_unit_serialization_round_trip(failures)
	return failures

static func _test_unit_defaults(failures: Array[String]) -> void:
	var unit: UnitData = UnitData.new()
	if unit.unit_id != "":
		failures.append("Expected default unit_id to be empty, got: " + unit.unit_id)
	if unit.tier != 1:
		failures.append("Expected default tier to be 1, got: " + str(unit.tier))
	if unit.unit_count <= 0:
		failures.append("Expected positive default unit_count, got: " + str(unit.unit_count))
	if not unit.role_tags.has(UnitData.RoleTag.INFANTRY_SPEAR):
		failures.append("Expected default role_tags to contain INFANTRY_SPEAR")

static func _test_unit_combat_value(failures: Array[String]) -> void:
	var unit: UnitData = UnitData.new()
	unit.unit_count = 120
	unit.melee_attack = 14
	unit.melee_defense = 18
	unit.armor = 45
	unit.charge_bonus = 10
	unit.veterancy_rank = 3
	unit.missile_range = 0
	
	# S_melee = 14 + (0.6 * 18) + (0.5 * 45) + (0.4 * 10) = 51.3
	# V_rank = 1.0 + (0.05 * 3) = 1.15
	# CP = 120 * 51.3 * 1.15 = 7079.4
	var expected_cp: float = 7079.4
	var actual_cp: float = unit.get_combat_value()
	if absf(actual_cp - expected_cp) > 0.1:
		failures.append("Combat power mismatch: expected %.2f, got %.2f" % [expected_cp, actual_cp])

static func _test_unit_clone_deep_copy(failures: Array[String]) -> void:
	var unit: UnitData = UnitData.new()
	unit.unit_id = "test_hoplite"
	unit.unit_count = 120
	unit.role_tags = [UnitData.RoleTag.INFANTRY_SPEAR]
	
	var clone: UnitData = unit.clone()
	if clone == null:
		failures.append("clone() returned null")
		return
	if clone == unit:
		failures.append("clone() returned identical instance reference")
	if clone.unit_id != unit.unit_id or clone.unit_count != unit.unit_count:
		failures.append("clone() failed to copy basic properties")
	
	# Mutation independence
	clone.unit_count = 60
	if unit.unit_count != 120:
		failures.append("Mutating clone modified original unit_count")

static func _test_unit_serialization_round_trip(failures: Array[String]) -> void:
	var unit: UnitData = UnitData.new()
	unit.unit_id = "unit_cretan_archers"
	unit.display_name = "Cretan Archers"
	unit.tier = 2
	unit.unit_count = 80
	unit.melee_attack = 6
	unit.melee_defense = 8
	unit.armor = 15
	unit.charge_bonus = 3
	unit.missile_accuracy = 75
	unit.reload_speed = 60
	unit.missile_range = 150
	unit.ammo_capacity = 25
	unit.ammo_type = UnitData.AmmoType.STANDARD_ARROW
	unit.morale = 8
	unit.fatigue_max = 100
	unit.mass = 1.0
	unit.veterancy_rank = 2
	unit.role_tags = [UnitData.RoleTag.MISSILE_BOW]
	unit.recruitment_cost = 350
	unit.upkeep_cost = 80
	unit.recruitment_turn_time = 1
	
	var dict: Dictionary = unit.to_dict()
	var restored: UnitData = UnitData.from_dict(dict)
	
	if restored == null:
		failures.append("from_dict returned null")
		return
	if restored.unit_id != unit.unit_id:
		failures.append("Restored unit_id mismatch: " + restored.unit_id)
	if restored.unit_count != unit.unit_count:
		failures.append("Restored unit_count mismatch: " + str(restored.unit_count))
	if restored.ammo_type != unit.ammo_type:
		failures.append("Restored ammo_type mismatch")
	if restored.role_tags != unit.role_tags:
		failures.append("Restored role_tags mismatch")
