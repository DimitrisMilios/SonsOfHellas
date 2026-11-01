class_name ArmyData
extends Resource

enum Stance {
	NORMAL = 0,
	FORCED_MARCH = 1,
	RAIDING = 2,
	ENCAMPMENT = 3,
	AMBUSH = 4,
	SIEGE = 5,
	DEFAULT = 0, # Legacy compatibility
	ENCAMP = 3   # Legacy compatibility
}

@export_group("Identity")
@export var army_id: String = ""
@export var army_name: String = "Greek Cohort"
@export var owner_faction_id: String = ""
@export var current_province_id: String = ""

@export_group("Command & Leadership")
@export var general_name: String = "General"
@export_range(0, 10, 1) var general_command_stars: int = 1
@export_range(0.0, 1.0, 0.01) var general_traits_bonus: float = 0.0
@export_range(0.5, 3.0, 0.1) var general_leadership_rating: float = 1.0 # Legacy compatibility

@export_group("Campaign Movement")
@export var map_position: Vector2 = Vector2.ZERO
@export_range(0.0, 200.0, 1.0) var base_max_action_points: float = 100.0
@export_range(0.0, 200.0, 1.0) var current_action_points: float = 100.0
@export_range(0.0, 200.0, 1.0) var max_action_points: float = 100.0
@export var stance: Stance = Stance.NORMAL
@export var has_retreated_this_turn: bool = false

@export_group("Roster")
@export var units: Array[UnitData] = []

const BASE_MOVEMENT_AP_COST: float = 40.0

## Calculates total army upkeep per turn, halving costs under Raiding stance.
func calculate_total_upkeep() -> int:
	var total: int = 0
	for unit: UnitData in units:
		if unit != null:
			total += unit.upkeep_cost if unit.upkeep_cost > 0 else unit.turn_upkeep
	
	if stance == Stance.RAIDING:
		total = roundi(float(total) * 0.50)
	return total

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
		current_action_points = maxf(current_action_points - amount, 0.0)
		return true
	return false

## Resets action points at the start of faction turn and clears turn retreat flags.
func reset_action_points() -> void:
	has_retreated_this_turn = false
	if stance == Stance.FORCED_MARCH:
		max_action_points = base_max_action_points * 1.50
		current_action_points = max_action_points
	elif stance == Stance.RAIDING:
		max_action_points = base_max_action_points * 0.50
		current_action_points = max_action_points
	else:
		max_action_points = base_max_action_points
		current_action_points = max_action_points

## Changes tactical stance with validity checks according to movement_stances.md.
func set_stance(new_stance: Stance) -> bool:
	if stance == new_stance:
		return true

	# Validation
	if new_stance == Stance.RAIDING:
		# Activation condition: remaining AP >= 50% base max AP
		if current_action_points < (0.50 * base_max_action_points):
			return false

	# Exiting previous stance
	if stance == Stance.FORCED_MARCH:
		max_action_points = base_max_action_points
		current_action_points = maxf(0.0, current_action_points - (0.50 * base_max_action_points))
		current_action_points = minf(current_action_points, max_action_points)
	elif stance == Stance.RAIDING:
		max_action_points = base_max_action_points

	# Applying new stance
	if new_stance == Stance.RAIDING:
		# Raiding stance activation costs 50% base max AP
		current_action_points = maxf(0.0, current_action_points - (0.50 * base_max_action_points))
		max_action_points = base_max_action_points * 0.50
		current_action_points = minf(current_action_points, max_action_points)
		stance = Stance.RAIDING
		return true
	elif new_stance == Stance.FORCED_MARCH:
		max_action_points = base_max_action_points * 1.50
		current_action_points += (0.50 * base_max_action_points)
		stance = Stance.FORCED_MARCH
		return true
	else:
		stance = new_stance
		max_action_points = base_max_action_points
		current_action_points = minf(current_action_points, max_action_points)
		return true

## Marks army as having retreated this turn and expends all remaining AP.
## Rule: Cannot retreat twice in a single turn (returns false on second attempt).
func mark_retreated() -> bool:
	if has_retreated_this_turn:
		return false
	has_retreated_this_turn = true
	current_action_points = 0.0
	return true

func add_unit(unit: UnitData) -> void:
	if unit != null:
		units.append(unit)

func remove_unit(unit: UnitData) -> void:
	if unit != null:
		units.erase(unit)

func remove_unit_at(index: int) -> void:
	if index >= 0 and index < units.size():
		units.remove_at(index)

## Creates an isolated deep clone of this army with independent unit instances.
func clone() -> ArmyData:
	var copy: ArmyData = ArmyData.new()
	copy.army_id = army_id
	copy.army_name = army_name
	copy.owner_faction_id = owner_faction_id
	copy.current_province_id = current_province_id
	copy.general_name = general_name
	copy.general_command_stars = general_command_stars
	copy.general_traits_bonus = general_traits_bonus
	copy.general_leadership_rating = general_leadership_rating
	copy.base_max_action_points = base_max_action_points
	copy.current_action_points = current_action_points
	copy.max_action_points = max_action_points
	copy.stance = stance
	copy.has_retreated_this_turn = has_retreated_this_turn
	
	copy.units.clear()
	for u: UnitData in units:
		if u != null:
			copy.units.append(u.clone())
	return copy

## Serializes army to dictionary.
func to_dict() -> Dictionary:
	var unit_dicts: Array[Dictionary] = []
	for u: UnitData in units:
		if u != null:
			unit_dicts.append(u.to_dict())
			
	return {
		"army_id": army_id,
		"army_name": army_name,
		"owner_faction_id": owner_faction_id,
		"current_province_id": current_province_id,
		"general_name": general_name,
		"general_command_stars": general_command_stars,
		"general_traits_bonus": general_traits_bonus,
		"base_max_action_points": base_max_action_points,
		"current_action_points": current_action_points,
		"max_action_points": max_action_points,
		"stance": stance_to_string(stance),
		"has_retreated_this_turn": has_retreated_this_turn,
		"units": unit_dicts
	}

## Deserializes dictionary to ArmyData instance.
static func from_dict(dict: Dictionary) -> ArmyData:
	var army: ArmyData = ArmyData.new()
	army.army_id = dict.get("army_id", "")
	army.army_name = dict.get("army_name", "Greek Cohort")
	army.owner_faction_id = dict.get("owner_faction_id", "")
	army.current_province_id = dict.get("current_province_id", "")
	army.general_name = dict.get("general_name", "General")
	army.general_command_stars = dict.get("general_command_stars", 1)
	army.general_traits_bonus = float(dict.get("general_traits_bonus", 0.0))
	army.base_max_action_points = float(dict.get("base_max_action_points", 100.0))
	army.current_action_points = float(dict.get("current_action_points", 100.0))
	army.max_action_points = float(dict.get("max_action_points", 100.0))
	army.stance = string_to_stance(dict.get("stance", "NORMAL"))
	army.has_retreated_this_turn = dict.get("has_retreated_this_turn", false)
	
	var units_raw: Array = dict.get("units", [])
	army.units.clear()
	for u_dict: Variant in units_raw:
		if u_dict is Dictionary:
			army.units.append(UnitData.from_dict(u_dict))
			
	return army

static func stance_to_string(st: Stance) -> String:
	match st:
		Stance.NORMAL: return "NORMAL"
		Stance.FORCED_MARCH: return "FORCED_MARCH"
		Stance.RAIDING: return "RAIDING"
		Stance.ENCAMPMENT: return "ENCAMPMENT"
		Stance.AMBUSH: return "AMBUSH"
		Stance.SIEGE: return "SIEGE"
		_: return "NORMAL"

static func string_to_stance(s: String) -> Stance:
	match s:
		"NORMAL", "DEFAULT": return Stance.NORMAL
		"FORCED_MARCH": return Stance.FORCED_MARCH
		"RAIDING": return Stance.RAIDING
		"ENCAMPMENT", "ENCAMP": return Stance.ENCAMPMENT
		"AMBUSH": return Stance.AMBUSH
		"SIEGE": return Stance.SIEGE
		_: return Stance.NORMAL

func get_stance_name() -> String:
	match stance:
		Stance.NORMAL: return "Normal"
		Stance.FORCED_MARCH: return "Forced March"
		Stance.RAIDING: return "Raiding"
		Stance.ENCAMPMENT: return "Encampment"
		Stance.AMBUSH: return "Ambush"
		Stance.SIEGE: return "Siege"
		_: return "Normal"
