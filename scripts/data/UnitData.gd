class_name UnitData
extends Resource

enum Role {
	HOPLITE,
	CAVALRY,
	RANGED,
	SKIRMISHER
}

@export_group("Identity")
@export var unit_id: String = ""
@export var display_name: String = ""
@export_range(1, 5, 1) var tier: int = 1
@export var role: Role = Role.HOPLITE

@export_group("Combat Stats")
@export_range(10.0, 500.0, 5.0) var base_strength: float = 100.0
@export_range(0.0, 100.0, 1.0) var armor: float = 20.0

@export_group("Economy")
@export_range(0, 5000, 10) var recruitment_cost: int = 150
@export_range(0, 1000, 5) var turn_upkeep: int = 30

## Returns raw base combat rating factoring tier, strength, and armor mitigation.
func get_combat_value() -> float:
	var armor_multiplier: float = 1.0 + (armor / 100.0)
	var tier_multiplier: float = 1.0 + ((tier - 1) * 0.15)
	return base_strength * armor_multiplier * tier_multiplier

## Deep clone helper for instantiating unique unit instances in armies and garrisons.
func duplicate_unit() -> UnitData:
	var copy: UnitData = UnitData.new()
	copy.unit_id = unit_id
	copy.display_name = display_name
	copy.tier = tier
	copy.role = role
	copy.base_strength = base_strength
	copy.armor = armor
	copy.recruitment_cost = recruitment_cost
	copy.turn_upkeep = turn_upkeep
	return copy

func get_role_name() -> String:
	match role:
		Role.HOPLITE:
			return "Hoplite"
		Role.CAVALRY:
			return "Cavalry"
		Role.RANGED:
			return "Ranged"
		Role.SKIRMISHER:
			return "Skirmisher"
		_:
			return "Unknown"
