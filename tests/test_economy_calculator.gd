class_name TestEconomyCalculator
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_class_tax_rate_scaling(failures)
	_test_administrative_penalty_threshold(failures)
	_test_effective_tax_rate_calculation_and_clamping(failures)
	_test_wealth_decay_curves_and_tax_level_5_perpetual_decay(failures)
	_test_subsistence_wealth_floor(failures)
	_test_tax_exemption(failures)
	_test_public_order_breakdown_and_food_shortage_penalty(failures)
	_test_calculate_province_economy_report(failures)
	return failures

static func _test_class_tax_rate_scaling(failures: Array[String]) -> void:
	if not is_equal_approx(EconomyCalculator.calculate_class_tax_rate(1), 0.05):
		failures.append("Level 1 tax rate should be 0.05")
	if not is_equal_approx(EconomyCalculator.calculate_class_tax_rate(3), 0.15):
		failures.append("Level 3 tax rate should be 0.15")
	if not is_equal_approx(EconomyCalculator.calculate_class_tax_rate(5), 0.25):
		failures.append("Level 5 tax rate should be 0.25")
	if not is_equal_approx(EconomyCalculator.calculate_class_tax_rate(0), 0.05):
		failures.append("Level 0 tax rate should clamp to level 1 (0.05)")
	if not is_equal_approx(EconomyCalculator.calculate_class_tax_rate(7), 0.25):
		failures.append("Level 7 tax rate should clamp to level 5 (0.25)")

static func _test_administrative_penalty_threshold(failures: Array[String]) -> void:
	# 1 to 4 regions has 0 penalty
	for n: int in range(1, 5):
		var penalty: float = EconomyCalculator.calculate_administrative_penalty(n)
		if penalty != 0.0:
			failures.append("Administrative penalty for %d regions should be 0.0, got: %f" % [n, penalty])
			
	# 5 regions = 0.02
	if not is_equal_approx(EconomyCalculator.calculate_administrative_penalty(5), 0.02):
		failures.append("Administrative penalty for 5 regions should be 0.02")
		
	# 8 regions = (8 - 4) * 0.02 = 0.08
	if not is_equal_approx(EconomyCalculator.calculate_administrative_penalty(8), 0.08):
		failures.append("Administrative penalty for 8 regions should be 0.08")

static func _test_effective_tax_rate_calculation_and_clamping(failures: Array[String]) -> void:
	# Normal case: Upper=3, Lower=3, Gov=0.06, Min=0.0, Regions=6 (Admin=0.04)
	# Expected: 0.15 + 0.06 - 0.04 = 0.17
	var rate: float = EconomyCalculator.calculate_effective_tax_rate(3, 3, 0.06, 0.0, 6)
	if not is_equal_approx(rate, 0.17):
		failures.append("Expected effective tax rate 0.17, got: %f" % rate)
		
	# Negative clamp test: Admin penalty exceeds base taxes
	# Upper=1, Lower=1, Gov=0, Min=0, Regions=20 (Admin=0.32)
	# Raw: 0.05 - 0.32 = -0.27 -> must clamp to 0.0
	var clamped_low: float = EconomyCalculator.calculate_effective_tax_rate(1, 1, 0.0, 0.0, 20)
	if clamped_low != 0.0:
		failures.append("Effective tax rate must clamp to 0.0 when admin penalty exceeds tax, got: %f" % clamped_low)
		
	# Ceiling clamp test: high bonuses should clamp to 0.70
	var clamped_high: float = EconomyCalculator.calculate_effective_tax_rate(5, 5, 0.50, 0.20, 2)
	if clamped_high != 0.70:
		failures.append("Effective tax rate must clamp to 0.70 ceiling, got: %f" % clamped_high)

static func _test_wealth_decay_curves_and_tax_level_5_perpetual_decay(failures: Array[String]) -> void:
	# Level 1: NWG = -2 - 0.10 * PWG
	var nwg_1: float = EconomyCalculator.calculate_negative_wealth_generation(1, 20.0)
	if not is_equal_approx(nwg_1, -4.0):
		failures.append("Expected NWG for Level 1 with PWG=20 to be -4.0, got: %f" % nwg_1)
	var wg_1: float = EconomyCalculator.calculate_net_wealth_growth(20.0, nwg_1)
	if not is_equal_approx(wg_1, 16.0):
		failures.append("Expected Net WG for Level 1 with PWG=20 to be 16.0, got: %f" % wg_1)
		
	# Level 3: NWG = -8 - 0.40 * 20 = -16.0
	var nwg_3: float = EconomyCalculator.calculate_negative_wealth_generation(3, 20.0)
	if not is_equal_approx(nwg_3, -16.0):
		failures.append("Expected NWG for Level 3 with PWG=20 to be -16.0, got: %f" % nwg_3)
		
	# Level 5: NWG = -32 - 1.20 * 20 = -56.0 -> WG = -36.0
	var nwg_5: float = EconomyCalculator.calculate_negative_wealth_generation(5, 20.0)
	if not is_equal_approx(nwg_5, -56.0):
		failures.append("Expected NWG for Level 5 with PWG=20 to be -56.0, got: %f" % nwg_5)
	var wg_5: float = EconomyCalculator.calculate_net_wealth_growth(20.0, nwg_5)
	if not is_equal_approx(wg_5, -36.0):
		failures.append("Expected Net WG for Level 5 with PWG=20 to be -36.0, got: %f" % wg_5)
		
	# Verify perpetual decay for Level 5 across arbitrary PWG [0, 500]
	for pwg: float in [0.0, 10.0, 50.0, 100.0, 500.0]:
		var nwg: float = EconomyCalculator.calculate_negative_wealth_generation(5, pwg)
		var net_wg: float = EconomyCalculator.calculate_net_wealth_growth(pwg, nwg)
		if net_wg >= 0.0:
			failures.append("Tax Level 5 should guarantee net wealth decay, but got %f for PWG=%f" % [net_wg, pwg])

static func _test_subsistence_wealth_floor(failures: Array[String]) -> void:
	# Starting wealth 110, severe decay of -40 -> new wealth clamped to 100.0 floor
	var new_wealth: float = EconomyCalculator.calculate_new_region_wealth(110.0, -40.0)
	if new_wealth != 100.0:
		failures.append("Region wealth must not drop below subsistence floor 100.0, got: %f" % new_wealth)

static func _test_tax_exemption(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	prov.region_wealth = 2000.0
	prov.tax_level_upper = 4
	prov.tax_level_lower = 4
	prov.tax_exemption_status = true
	
	var faction: FactionData = FactionData.new()
	faction.held_province_ids = ["prov_test"]
	
	var report: Dictionary = EconomyCalculator.calculate_province_economy(prov, faction, 1)
	if report["effective_tax_rate"] != 0.0:
		failures.append("Tax-exempt province should have 0.0 effective tax rate")
	if report["tax_income"] != 0:
		failures.append("Tax-exempt province should generate 0 tax revenue")
	if report["public_order_breakdown"]["tax_unrest"] != 0:
		failures.append("Tax-exempt province should have 0 tax unrest")
	if report["public_order_breakdown"]["tax_relief"] != 10:
		failures.append("Tax-exempt province should grant +10 tax relief public order")

static func _test_public_order_breakdown_and_food_shortage_penalty(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	prov.tax_level_lower = 3 # 4 unrest
	prov.resistance_to_occupation_decay = 5 # 5 conquest unrest
	
	# Garrison 120 soldiers = +2 repression (120 / 60)
	var g_unit: UnitData = UnitData.new()
	g_unit.unit_count = 120
	prov.add_garrison_unit(g_unit)
	
	# Government palace building with +3 public order bonus
	prov.set_settlement_level(1)
	var bld: BuildingData = BuildingData.new()
	bld.public_order_bonus = 3.0
	prov.building_slots[0].building_data = bld
	
	var faction: FactionData = FactionData.new()
	faction.food_balance = -2 # Famine: -2 * 5 = -10 public order
	
	var po: int = EconomyCalculator.calculate_public_order(prov, faction)
	# Positive: Garrison(+2) + Gov(+3) = +5
	# Negative: Tax(4) + Conquest(5) + Food(10) = 19
	# Net: 5 - 19 = -14
	if po != -14:
		failures.append("Expected net public order -14, got: %d" % po)

static func _test_calculate_province_economy_report(failures: Array[String]) -> void:
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = "prov_attica"
	prov.region_wealth = 1500.0
	prov.tax_level_upper = 3
	prov.tax_level_lower = 3
	prov.set_settlement_level(2)
	
	var farm: BuildingData = BuildingData.new()
	farm.positive_wealth_generation = 15.0
	farm.food_production_delta = 4
	prov.building_slots[0].building_data = farm
	
	var faction: FactionData = FactionData.new()
	faction.held_province_ids = ["prov_attica", "prov_euboea"]
	faction.food_balance = 2
	
	var orig_wealth: float = prov.region_wealth
	var report: Dictionary = EconomyCalculator.calculate_province_economy(prov, faction, 2)
	
	# Ensure immutability / pure function
	if prov.region_wealth != orig_wealth:
		failures.append("calculate_province_economy mutated province region_wealth")
		
	if report["tax_income"] <= 0:
		failures.append("Expected positive tax income in report, got: %d" % report["tax_income"])
	if report["net_wealth_growth"] <= 0:
		failures.append("Expected positive net wealth growth with farm, got: %f" % report["net_wealth_growth"])
	if not report.has("public_order_breakdown"):
		failures.append("Report missing public_order_breakdown dictionary")
