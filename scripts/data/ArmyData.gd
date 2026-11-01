class_name ArmyData
extends Resource

enum Stance {
	DEFAULT,
	FORCED_MARCH,
	ENCAMP,
	SIEGE
}

@export_group("Identity")
@export var army_id: String = ""
@export var army_name: String = "Spartan Cohort"
@export var owner_faction_id: String = ""
@export var current_province_id: String = ""

@export_group("Command & Composition")
@export_range(0.5, 3.0, 0.1) var general_leadership_rating: float = 1.0
@export var units: Array[UnitData] = []

@export_group("Campaign Movement")
@export_range(0.0, 100.0, 1.0) var current_action_points: float = 100.0
@export_range(0.0, 100.0, 1.0) var max_action_points: float = 100.0
@export var stance: Stance = Stance.DEFAULT

## Action Point movement cost under default conditions.
const BASE_MOVEMENT_AP_COST: float = 40.0

## Calculates total army upkeep per turn.
func calculate_total_upkeep() -> int:
	var total_upkeep: int = 0
	for unit: UnitData in units:
		if unit != null:
			total_upkeep += unit.turn_upkeep
	return total_upkeep

## Calculates sum of base combat values of all active units.
func calculate_total_strength() -> float:
	var total: float = 0.0
	for unit: UnitData in units:
		if unit != null:
			total += unit.get_combat_value()
	return total

## Consumes action points if sufficient AP is available.
func consume_action_points(amount: float) -> bool:
	if current_action_points >= amount:
		current_action_points = clampf(current_action_points - amount, 0.0, max_action_points)
		return true
	return false

## Resets action points at the start of faction turn.
func reset_action_points() -> void:
	if stance == Stance.FORCED_MARCH:
		current_action_points = max_action_points * 1.5
	else:
		current_action_points = max_action_points

## Changes tactical stance with validity checks.
func set_stance(new_stance: Stance) -> void:
	stance = new_stance

func get_stance_name() -> String:
	match stance:
		Stance.DEFAULT:
			return "Default"
		Stance.FORCED_MARCH:
			return "Forced March"
		Stance.ENCAMP:
			return "Encamp"
		Stance.SIEGE:
			return "Siege"
		_:
			return "Unknown"

func add_unit(unit: UnitData) -> void:
	if unit != null:
		units.append(unit)

func remove_unit_at(index: int) -> void:
	if index >= 0 and index < units.size():
		units.remove_at(index)
