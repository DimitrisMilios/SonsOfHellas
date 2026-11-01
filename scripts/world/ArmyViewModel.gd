class_name ArmyViewModel
extends RefCounted

var army_id: String = ""
var army_name: String = ""
var owner_faction_id: String = ""
var current_province_id: String = ""
var stance: ArmyData.Stance = ArmyData.Stance.NORMAL
var stance_name: String = "Normal"
var current_action_points: float = 100.0
var max_action_points: float = 100.0
var general_rating: float = 1.0
var total_combat_power: float = 0.0
var total_upkeep: int = 0
var unit_cards: Array[Dictionary] = []

## Factory constructor transforming domain model into an immutable presentation snapshot.
static func from_army_data(army: ArmyData) -> ArmyViewModel:
	var vm: ArmyViewModel = ArmyViewModel.new()
	if army == null:
		return vm

	vm.army_id = army.army_id
	vm.army_name = army.army_name
	vm.owner_faction_id = army.owner_faction_id
	vm.current_province_id = army.current_province_id
	vm.stance = army.stance
	vm.stance_name = army.get_stance_name()
	vm.current_action_points = army.current_action_points
	vm.max_action_points = army.max_action_points
	vm.general_rating = 1.0 + (0.04 * float(army.general_command_stars)) + army.general_traits_bonus
	vm.total_combat_power = army.calculate_total_strength()
	vm.total_upkeep = army.calculate_total_upkeep()

	for u: UnitData in army.units:
		if u != null:
			vm.unit_cards.append({
				"id": u.unit_id,
				"name": u.display_name,
				"count": u.unit_count,
				"tier": u.tier,
				"veterancy": u.veterancy_rank,
				"armor": u.armor,
				"upkeep": u.turn_upkeep,
				"combat_value": u.get_combat_value(),
				"role": u.get_role_name()
			})

	return vm
