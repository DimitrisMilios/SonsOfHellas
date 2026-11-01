class_name EconomyCalculator
extends RefCounted

## Constants from docs/design/settlement_economy.md and architecture guidelines
const SUBSISTENCE_WEALTH_FLOOR: float = 100.0
const MAX_EFFECTIVE_TAX_RATE: float = 0.70
const ADMIN_PENALTY_THRESHOLD: int = 4
const ADMIN_PENALTY_PER_REGION: float = 0.02
const FOOD_SHORTAGE_UNREST_MULT: int = 5
const GARRISON_MODELS_PER_REPRESSION: int = 60
const MAX_GARRISON_REPRESSION: int = 10
const TAX_EXEMPTION_RELIEF_BONUS: int = 10

## Calculates class tax rate for policy level L_tax in [1..5] (5% per level).
static func calculate_class_tax_rate(tax_level: int) -> float:
	var level: int = clampi(tax_level, 1, 5)
	return 0.05 * float(level)

## Calculates administrative penalty (C_admin): 0 when <= 4 regions, +2% per region above 4.
static func calculate_administrative_penalty(held_regions_count: int) -> float:
	if held_regions_count <= ADMIN_PENALTY_THRESHOLD:
		return 0.0
	return float(held_regions_count - ADMIN_PENALTY_THRESHOLD) * ADMIN_PENALTY_PER_REGION

## Calculates effective regional tax rate T_local with lower/upper policy levels, modifiers, and bounds [0.0, 0.70].
static func calculate_effective_tax_rate(
	tax_level_upper: int,
	tax_level_lower: int,
	gov_building_bonus: float = 0.0,
	minister_bonus: float = 0.0,
	held_regions_count: int = 1
) -> float:
	var t_upper: float = calculate_class_tax_rate(tax_level_upper)
	var t_lower: float = calculate_class_tax_rate(tax_level_lower)
	var c_admin: float = calculate_administrative_penalty(held_regions_count)
	var raw_tax: float = ((t_upper + t_lower) / 2.0) + gov_building_bonus + minister_bonus - c_admin
	return clampf(raw_tax, 0.0, MAX_EFFECTIVE_TAX_RATE)

## Calculates negative wealth decay (NWG) according to upper-class tax policy level.
static func calculate_negative_wealth_generation(tax_level_upper: int, pwg: float) -> float:
	var level: int = clampi(tax_level_upper, 1, 5)
	match level:
		1: return -2.0 - (0.10 * pwg)
		2: return -4.0 - (0.20 * pwg)
		3: return -8.0 - (0.40 * pwg)
		4: return -16.0 - (0.80 * pwg)
		5: return -32.0 - (1.20 * pwg)
		_: return -8.0 - (0.40 * pwg)

## Calculates net per-turn wealth growth (WG = PWG + NWG).
static func calculate_net_wealth_growth(pwg: float, nwg: float) -> float:
	return pwg + nwg

## Calculates updated region wealth clamped to subsistence floor (100.0).
static func calculate_new_region_wealth(current_wealth: float, net_wg: float) -> float:
	return maxf(SUBSISTENCE_WEALTH_FLOOR, current_wealth + net_wg)

## Calculates tax unrest from lower-class taxation level [1..5].
static func calculate_tax_unrest(tax_level_lower: int) -> int:
	var level: int = clampi(tax_level_lower, 1, 5)
	match level:
		1: return 0
		2: return 2
		3: return 4
		4: return 8
		5: return 14
		_: return 4

## Calculates empire-wide famine penalty: -5 PO per negative food point.
static func calculate_food_shortage_penalty(food_balance: int) -> int:
	if food_balance < 0:
		return absi(food_balance) * FOOD_SHORTAGE_UNREST_MULT
	return 0

## Calculates garrison public order repression: +1 PO per 60 soldiers (capped at +10).
static func calculate_garrison_repression(garrison_units: Array[UnitData]) -> int:
	var total_soldiers: int = 0
	for u: UnitData in garrison_units:
		if u != null:
			total_soldiers += u.unit_count
	return mini(MAX_GARRISON_REPRESSION, total_soldiers / GARRISON_MODELS_PER_REPRESSION)

## Generates full public order audit dictionary.
static func get_public_order_breakdown(province: ProvinceData, faction: FactionData) -> Dictionary:
	var repression: int = calculate_garrison_repression(province.garrison_units) if province != null else 0
	var gov_bonus: int = 0
	var cult_bonus: int = 0
	
	if province != null:
		for slot: BuildingSlotData in province.building_slots:
			if slot != null and slot.building_data != null and not slot.is_under_construction:
				gov_bonus += roundi(slot.building_data.public_order_bonus)
				
	var tax_relief: int = TAX_EXEMPTION_RELIEF_BONUS if (province != null and province.tax_exemption_status) else 0
	var tax_unrest: int = 0 if (province != null and province.tax_exemption_status) else calculate_tax_unrest(province.tax_level_lower if province != null else 3)
	var conquest_unrest: int = province.resistance_to_occupation_decay if province != null else 0
	var food_unrest: int = calculate_food_shortage_penalty(faction.food_balance if faction != null else 0)
	
	var positive: int = repression + gov_bonus + cult_bonus + tax_relief
	var negative: int = tax_unrest + conquest_unrest + food_unrest
	var net_po: int = clampi(positive - negative, -100, 100)
	
	return {
		"net_public_order": net_po,
		"garrison_repression": repression,
		"government_bonus": gov_bonus,
		"culture_bonus": cult_bonus,
		"tax_relief": tax_relief,
		"tax_unrest": tax_unrest,
		"conquest_unrest": conquest_unrest,
		"food_shortage_unrest": food_unrest,
		"total_positive": positive,
		"total_negative": negative
	}

## Calculates public order score in range [-100, 100].
static func calculate_public_order(province: ProvinceData, faction: FactionData) -> int:
	return get_public_order_breakdown(province, faction)["net_public_order"]

## Evaluates full provincial economy report without mutating input models.
static func calculate_province_economy(province: ProvinceData, faction: FactionData, held_regions_count: int) -> Dictionary:
	if province == null:
		return {}
		
	var pwg: float = 0.0
	var gov_tax_mod: float = 0.0
	for slot: BuildingSlotData in province.building_slots:
		if slot != null and slot.building_data != null and not slot.is_under_construction:
			pwg += slot.building_data.positive_wealth_generation
			gov_tax_mod += slot.building_data.tax_modifier_bonus
			
	var effective_tax_rate: float = 0.0
	var tax_income: int = 0
	if not province.tax_exemption_status:
		effective_tax_rate = calculate_effective_tax_rate(
			province.tax_level_upper,
			province.tax_level_lower,
			gov_tax_mod,
			0.0,
			held_regions_count
		)
		tax_income = roundi(province.region_wealth * effective_tax_rate)
		
	var nwg: float = calculate_negative_wealth_generation(province.tax_level_upper, pwg)
	var net_wg: float = calculate_net_wealth_growth(pwg, nwg)
	var new_wealth: float = calculate_new_region_wealth(province.region_wealth, net_wg)
	var po_breakdown: Dictionary = get_public_order_breakdown(province, faction)
	
	return {
		"province_id": province.province_id,
		"region_wealth": province.region_wealth,
		"effective_tax_rate": effective_tax_rate,
		"tax_income": tax_income,
		"positive_wealth_growth": pwg,
		"negative_wealth_growth": nwg,
		"net_wealth_growth": net_wg,
		"new_region_wealth": new_wealth,
		"public_order": po_breakdown["net_public_order"],
		"public_order_breakdown": po_breakdown
	}
