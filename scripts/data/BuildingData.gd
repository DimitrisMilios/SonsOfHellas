class_name BuildingData
extends Resource

enum BranchType {
	GOVERNMENT_PALACE,
	MILITARY_BARRACKS,
	INDUSTRY_WEAVING,
	INDUSTRY_METALWORK,
	FARMING,
	COMMERCIAL_PORT,
	FISHING_PORT,
	ACADEMY_SCHOOL,
	FORTIFICATION
}

## Legacy category enum for backward compatibility with existing .tres files.
enum Category {
	CIVIC,
	ECONOMIC,
	MILITARY,
	DEFENSIVE
}

@export_group("Identity")
@export var building_id: String = ""
@export var display_name: String = ""
@export var branch_type: BranchType = BranchType.GOVERNMENT_PALACE
@export_range(1, 5, 1) var upgrade_level: int = 1
@export var category: Category = Category.ECONOMIC # Legacy compatibility
@export_range(1, 5, 1) var tier: int = 1 # Legacy compatibility

@export_group("Construction Costs")
@export_range(0, 10000, 25) var construction_cost: int = 200
@export_range(1, 10, 1) var turns_to_build: int = 2
@export_range(0, 10000, 25) var build_cost: int = 200 # Legacy compatibility
@export_range(1, 20, 1) var build_time_turns: int = 2 # Legacy compatibility

@export_group("Economic Output")
@export_range(0.0, 2000.0, 10.0) var base_wealth: float = 0.0
@export_range(0.0, 50.0, 0.5) var positive_wealth_generation: float = 0.0
@export_range(-5.0, 0.0, 0.1) var negative_wealth_generation_penalty: float = 0.0
@export_range(0.0, 0.20, 0.01) var tax_modifier_bonus: float = 0.0
@export_range(-10, 20, 1) var food_production_delta: int = 0

@export_group("Legacy Province Bonuses")
@export_range(-500.0, 500.0, 5.0) var tax_bonus: float = 20.0
@export_range(-50.0, 50.0, 1.0) var growth_bonus: float = 2.0
@export_range(-20.0, 20.0, 1.0) var public_order_bonus: float = 4.0

@export_group("Garrison Granted")
@export var garrison_units_granted: Array[Dictionary] = [] # [{ "unit": UnitData, "quantity": int }]

@export_group("Unlock Requirements")
@export var required_technology_id: String = ""
@export var required_resource_type: String = "NONE" # HORSES, TIMBER, SILK, IRON, STONE, NONE
@export_range(1, 5, 1) var required_settlement_level: int = 1
@export var mutually_exclusive_branch_id: String = ""
@export var unlocked_units: Array[UnitData] = [] # Legacy compatibility

## Verifies whether building can be constructed based on empire resources and settlement tier.
func is_unlocked(available_resources: Array[String], current_settlement_level: int) -> bool:
	if current_settlement_level < required_settlement_level:
		return false
	if required_resource_type != "NONE" and required_resource_type != "":
		if not available_resources.has(required_resource_type):
			return false
	return true

## Net food balance contribution.
func get_net_food_delta() -> int:
	return food_production_delta

## Creates an isolated clone of this building definition.
func clone() -> BuildingData:
	var copy: BuildingData = BuildingData.new()
	copy.building_id = building_id
	copy.display_name = display_name
	copy.branch_type = branch_type
	copy.upgrade_level = upgrade_level
	copy.category = category
	copy.tier = tier
	copy.construction_cost = construction_cost
	copy.turns_to_build = turns_to_build
	copy.build_cost = build_cost
	copy.build_time_turns = build_time_turns
	copy.base_wealth = base_wealth
	copy.positive_wealth_generation = positive_wealth_generation
	copy.negative_wealth_generation_penalty = negative_wealth_generation_penalty
	copy.tax_modifier_bonus = tax_modifier_bonus
	copy.food_production_delta = food_production_delta
	copy.tax_bonus = tax_bonus
	copy.growth_bonus = growth_bonus
	copy.public_order_bonus = public_order_bonus
	copy.garrison_units_granted = garrison_units_granted.duplicate(true)
	copy.required_technology_id = required_technology_id
	copy.required_resource_type = required_resource_type
	copy.required_settlement_level = required_settlement_level
	copy.mutually_exclusive_branch_id = mutually_exclusive_branch_id
	copy.unlocked_units = unlocked_units.duplicate()
	return copy

## Serializes building to dictionary matching docs/design/data_schemas.md.
func to_dict() -> Dictionary:
	return {
		"id": building_id,
		"name": display_name,
		"branch_type": branch_type_to_string(branch_type),
		"upgrade_level": upgrade_level,
		"construction_cost": construction_cost,
		"turns_to_build": turns_to_build,
		"income_output": {
			"base_wealth": base_wealth,
			"positive_wealth_generation": positive_wealth_generation,
			"negative_wealth_generation_penalty": negative_wealth_generation_penalty,
			"tax_modifier_bonus": tax_modifier_bonus,
			"food_production_delta": food_production_delta
		},
		"unlock_requirements": {
			"required_technology_id": required_technology_id if required_technology_id != "" else null,
			"required_resource_type": required_resource_type,
			"required_settlement_level": required_settlement_level,
			"mutually_exclusive_branch_id": mutually_exclusive_branch_id if mutually_exclusive_branch_id != "" else null
		}
	}

## Deserializes dictionary to BuildingData instance.
static func from_dict(dict: Dictionary) -> BuildingData:
	var bld: BuildingData = BuildingData.new()
	bld.building_id = dict.get("id", "")
	bld.display_name = dict.get("name", "")
	bld.branch_type = string_to_branch_type(dict.get("branch_type", "GOVERNMENT_PALACE"))
	bld.upgrade_level = dict.get("upgrade_level", 1)
	bld.tier = bld.upgrade_level
	bld.construction_cost = dict.get("construction_cost", 200)
	bld.build_cost = bld.construction_cost
	bld.turns_to_build = dict.get("turns_to_build", 2)
	bld.build_time_turns = bld.turns_to_build
	
	var income: Dictionary = dict.get("income_output", {})
	if not income.is_empty():
		bld.base_wealth = float(income.get("base_wealth", 0.0))
		bld.positive_wealth_generation = float(income.get("positive_wealth_generation", 0.0))
		bld.negative_wealth_generation_penalty = float(income.get("negative_wealth_generation_penalty", 0.0))
		bld.tax_modifier_bonus = float(income.get("tax_modifier_bonus", 0.0))
		bld.food_production_delta = int(income.get("food_production_delta", 0))
		
	var reqs: Dictionary = dict.get("unlock_requirements", {})
	if not reqs.is_empty():
		bld.required_technology_id = str(reqs.get("required_technology_id", "")) if reqs.get("required_technology_id") != null else ""
		bld.required_resource_type = str(reqs.get("required_resource_type", "NONE"))
		bld.required_settlement_level = int(reqs.get("required_settlement_level", 1))
		bld.mutually_exclusive_branch_id = str(reqs.get("mutually_exclusive_branch_id", "")) if reqs.get("mutually_exclusive_branch_id") != null else ""
		
	return bld

static func branch_type_to_string(branch: BranchType) -> String:
	match branch:
		BranchType.GOVERNMENT_PALACE: return "GOVERNMENT_PALACE"
		BranchType.MILITARY_BARRACKS: return "MILITARY_BARRACKS"
		BranchType.INDUSTRY_WEAVING: return "INDUSTRY_WEAVING"
		BranchType.INDUSTRY_METALWORK: return "INDUSTRY_METALWORK"
		BranchType.FARMING: return "FARMING"
		BranchType.COMMERCIAL_PORT: return "COMMERCIAL_PORT"
		BranchType.FISHING_PORT: return "FISHING_PORT"
		BranchType.ACADEMY_SCHOOL: return "ACADEMY_SCHOOL"
		BranchType.FORTIFICATION: return "FORTIFICATION"
		_: return "GOVERNMENT_PALACE"

static func string_to_branch_type(s: String) -> BranchType:
	match s:
		"GOVERNMENT_PALACE": return BranchType.GOVERNMENT_PALACE
		"MILITARY_BARRACKS": return BranchType.MILITARY_BARRACKS
		"INDUSTRY_WEAVING": return BranchType.INDUSTRY_WEAVING
		"INDUSTRY_METALWORK": return BranchType.INDUSTRY_METALWORK
		"FARMING": return BranchType.FARMING
		"COMMERCIAL_PORT": return BranchType.COMMERCIAL_PORT
		"FISHING_PORT": return BranchType.FISHING_PORT
		"ACADEMY_SCHOOL": return BranchType.ACADEMY_SCHOOL
		"FORTIFICATION": return BranchType.FORTIFICATION
		_: return BranchType.GOVERNMENT_PALACE

func get_category_name() -> String:
	match branch_type:
		BranchType.GOVERNMENT_PALACE: return "Palace / Civic"
		BranchType.MILITARY_BARRACKS: return "Barracks / Military"
		BranchType.INDUSTRY_WEAVING, BranchType.INDUSTRY_METALWORK: return "Industry / Economy"
		BranchType.FARMING, BranchType.FISHING_PORT: return "Agriculture & Food"
		BranchType.COMMERCIAL_PORT: return "Commercial Port"
		BranchType.ACADEMY_SCHOOL: return "Academy / Research"
		BranchType.FORTIFICATION: return "Fortification / Defense"
		_: return "Structure"
