class_name ProvinceViewModel
extends RefCounted

var province_id: String = ""
var province_name: String = ""
var owner_faction_id: String = ""
var map_position: Vector2 = Vector2.ZERO
var settlement_tier: int = 1
var public_order: float = 100.0
var unrest_pressure: int = 0
var consecutive_unrest_turns: int = 0
var region_wealth: float = 1000.0
var net_wealth_growth: float = 0.0
var positive_wealth_growth: float = 0.0
var negative_wealth_growth: float = 0.0
var tax_income: int = 0
var tax_level_upper: int = 3
var tax_level_lower: int = 3
var tax_exemption_status: bool = false
var garrison_count: int = 0
var building_slots_summary: Array[Dictionary] = []
var food_surplus_delta: int = 0

## Factory constructor transforming domain model into an immutable presentation snapshot.
static func from_province_data(
	prov: ProvinceData,
	faction: FactionData = null,
	held_regions_count: int = 1
) -> ProvinceViewModel:
	var vm: ProvinceViewModel = ProvinceViewModel.new()
	if prov == null:
		return vm

	vm.province_id = prov.province_id
	vm.province_name = prov.province_name
	vm.owner_faction_id = prov.owner_faction_id
	vm.map_position = prov.map_position
	vm.settlement_tier = prov.settlement_level
	vm.public_order = prov.public_order
	vm.unrest_pressure = prov.unrest_pressure
	vm.consecutive_unrest_turns = prov.consecutive_unrest_turns
	vm.region_wealth = prov.region_wealth
	vm.tax_level_upper = prov.tax_level_upper
	vm.tax_level_lower = prov.tax_level_lower
	vm.tax_exemption_status = prov.tax_exemption_status
	vm.garrison_count = prov.garrison_units.size()

	# Compute economic projection through EconomyCalculator
	var econ: Dictionary = EconomyCalculator.calculate_province_economy(prov, faction, held_regions_count)
	vm.tax_income = int(econ.get("tax_income", 0))
	vm.positive_wealth_growth = float(econ.get("positive_wealth_growth", 0.0))
	vm.negative_wealth_growth = float(econ.get("negative_wealth_growth", 0.0))
	vm.net_wealth_growth = float(econ.get("net_wealth_growth", 0.0))

	# Format building slots summary
	for slot: Variant in prov.building_slots:
		if slot is BuildingSlotData:
			var slot_dict: Dictionary = {
				"slot_index": slot.slot_index,
				"name": "Empty Slot",
				"is_building": slot.is_under_construction,
				"turns_left": slot.remaining_construction_turns,
				"tier": 0
			}
			if slot.is_under_construction and slot.target_building_to_construct != null:
				slot_dict["name"] = slot.target_building_to_construct.display_name
				slot_dict["tier"] = slot.target_building_to_construct.upgrade_level
			elif slot.building_data != null:
				slot_dict["name"] = slot.building_data.display_name
				slot_dict["tier"] = slot.building_data.upgrade_level
			vm.building_slots_summary.append(slot_dict)

	return vm
