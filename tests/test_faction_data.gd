class_name TestFactionData
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_faction_defaults(failures)
	_test_treasury_affordability_and_deductions(failures)
	_test_bankruptcy_state_lifecycle(failures)
	_test_faction_serialization_round_trip(failures)
	return failures

static func _test_faction_defaults(failures: Array[String]) -> void:
	var faction: FactionData = FactionData.new()
	if faction.base_purse != 3000:
		failures.append("Expected default base_purse to be 3000 (King's Purse), got: " + str(faction.base_purse))
	if faction.default_tax_level_upper != 3 or faction.default_tax_level_lower != 3:
		failures.append("Expected default tax policy levels to be 3 (15%)")
	if faction.is_bankrupt:
		failures.append("Expected faction to not start bankrupt")

static func _test_treasury_affordability_and_deductions(failures: Array[String]) -> void:
	var faction: FactionData = FactionData.new()
	faction.treasury = 500
	
	if not faction.can_afford(500):
		failures.append("can_afford(500) should be true when treasury is 500")
	if faction.can_afford(501):
		failures.append("can_afford(501) should be false when treasury is 500")
		
	var deducted_too_much: bool = faction.deduct_treasury(600)
	if deducted_too_much:
		failures.append("deduct_treasury(600) should return false on insufficient funds")
	if faction.treasury != 500:
		failures.append("Treasury mutated after failed deduction")
		
	var deducted: bool = faction.deduct_treasury(200)
	if not deducted or faction.treasury != 300:
		failures.append("deduct_treasury(200) failed to subtract funds correctly")
		
	faction.add_treasury(100)
	if faction.treasury != 400:
		failures.append("add_treasury(100) failed to increment treasury")

static func _test_bankruptcy_state_lifecycle(failures: Array[String]) -> void:
	var faction: FactionData = FactionData.new()
	faction.set_bankrupt(true)
	if not faction.is_bankrupt:
		failures.append("Failed to set bankruptcy flag")
	if faction.capital_stagnation_turns <= 0:
		failures.append("Expected positive capital stagnation turns upon bankruptcy")
		
	faction.set_bankrupt(false)
	if faction.is_bankrupt:
		failures.append("Failed to clear bankruptcy flag")

static func _test_faction_serialization_round_trip(failures: Array[String]) -> void:
	var faction: FactionData = FactionData.new()
	faction.faction_id = "faction_athens"
	faction.faction_name = "Athens"
	faction.faction_color = Color(0.2, 0.4, 0.8, 1.0)
	faction.is_player = true
	faction.treasury = 4500
	faction.base_purse = 3000
	faction.trade_income = 650
	faction.tribute_income = 200
	faction.raiding_income = 50
	faction.food_balance = 3
	faction.default_tax_level_upper = 2
	faction.default_tax_level_lower = 3
	faction.held_province_ids = ["prov_attica", "prov_euboea"]
	faction.is_bankrupt = false
	faction.capital_stagnation_turns = 0
	
	var dict: Dictionary = faction.to_dict()
	var restored: FactionData = FactionData.from_dict(dict)
	
	if restored == null:
		failures.append("from_dict returned null")
		return
	if restored.faction_id != faction.faction_id:
		failures.append("Restored faction_id mismatch")
	if restored.treasury != 4500:
		failures.append("Restored treasury mismatch")
	if restored.base_purse != 3000:
		failures.append("Restored base_purse mismatch")
	if restored.trade_income != 650:
		failures.append("Restored trade_income mismatch")
	if restored.food_balance != 3:
		failures.append("Restored food_balance mismatch")
	if restored.held_province_ids != faction.held_province_ids:
		failures.append("Restored held_province_ids mismatch")
