class_name MovementEngine
extends RefCounted

## Constants from docs/design/movement_stances.md and engineering specifications
const BASE_MOVEMENT_AP_COST: float = 40.0
const EPSILON_PRECISION: float = 0.001

## Road Infrastructure speed multipliers: 0: Baseline, 1: Paved (+33%), 2: Highway (+60%)
const ROAD_MODIFIERS: Dictionary = {
	0: 0.0,
	1: 0.33,
	2: 0.60
}

## Terrain movement difficulty coefficients
const TERRAIN_MODIFIERS: Dictionary = {
	"plains": 1.0,
	"forest": 1.25,
	"mountain": 1.50,
	"swamp": 1.40,
	"rough": 1.50
}

## Returns road speed multiplier M_road for road infrastructure tier.
static func get_road_modifier(road_tier: int) -> float:
	return ROAD_MODIFIERS.get(road_tier, 0.0)

## Returns terrain modifier coefficient.
static func get_terrain_modifier(terrain: String) -> float:
	return TERRAIN_MODIFIERS.get(terrain.to_lower(), 1.0)

## Calculates effective AP cost: (Base_Cost * Terrain_Mod) / (1.0 + M_road).
static func calculate_ap_cost(terrain: String = "plains", road_tier: int = 0) -> float:
	var m_road: float = get_road_modifier(road_tier)
	var t_mod: float = get_terrain_modifier(terrain)
	return (BASE_MOVEMENT_AP_COST * t_mod) / (1.0 + m_road)

## Validates whether an army can execute campaign movement to destination province.
static func can_move_to_province(
	army: ArmyData,
	from_prov: ProvinceData,
	to_prov: ProvinceData,
	terrain: String = "plains",
	road_tier: int = 0
) -> bool:
	if army == null or from_prov == null or to_prov == null:
		return false
		
	# Stationary stances cannot move
	if army.stance == ArmyData.Stance.SIEGE:
		return false
		
	# Armies that have already retreated cannot move again this turn
	if army.has_retreated_this_turn:
		return false
		
	# Must be topologically adjacent on the campaign province graph
	if not from_prov.adjacent_province_ids.has(to_prov.province_id):
		return false
		
	var ap_cost: float = calculate_ap_cost(terrain, road_tier)
	if (army.current_action_points + EPSILON_PRECISION) < ap_cost:
		return false
		
	return true

## Checks whether entering destination province violates Zone of Control or enters hostile territory.
static func is_hostile_intercept(army: ArmyData, to_prov: ProvinceData, stationed_armies: Array[ArmyData] = []) -> bool:
	if army == null or to_prov == null:
		return false
		
	# Hostile settlement control
	if to_prov.owner_faction_id != "" and to_prov.owner_faction_id != army.owner_faction_id:
		return true
		
	# Hostile stationed armies in target province
	for other: ArmyData in stationed_armies:
		if other != null and other.current_province_id == to_prov.province_id:
			if other.owner_faction_id != "" and other.owner_faction_id != army.owner_faction_id and not other.units.is_empty():
				return true
				
	return false

## Simulates movement path without mutating models. Returns calculation report.
static func calculate_movement_result(
	army: ArmyData,
	from_prov: ProvinceData,
	to_prov: ProvinceData,
	terrain: String = "plains",
	road_tier: int = 0,
	stationed_armies: Array[ArmyData] = []
) -> Dictionary:
	if army == null or from_prov == null or to_prov == null:
		return {
			"success": false,
			"ap_cost": 0.0,
			"remaining_ap": 0.0,
			"triggers_engagement": false,
			"reason": "Null parameters provided"
		}
		
	if army.stance == ArmyData.Stance.SIEGE:
		return {
			"success": false,
			"ap_cost": 0.0,
			"remaining_ap": army.current_action_points,
			"triggers_engagement": false,
			"reason": "Army is maintaining a siege and cannot move"
		}
		
	if army.has_retreated_this_turn:
		return {
			"success": false,
			"ap_cost": 0.0,
			"remaining_ap": army.current_action_points,
			"triggers_engagement": false,
			"reason": "Army has already retreated this turn"
		}
		
	if not from_prov.adjacent_province_ids.has(to_prov.province_id):
		return {
			"success": false,
			"ap_cost": 0.0,
			"remaining_ap": army.current_action_points,
			"triggers_engagement": false,
			"reason": "Destination province is not adjacent"
		}
		
	var ap_cost: float = calculate_ap_cost(terrain, road_tier)
	if (army.current_action_points + EPSILON_PRECISION) < ap_cost:
		return {
			"success": false,
			"ap_cost": ap_cost,
			"remaining_ap": army.current_action_points,
			"triggers_engagement": false,
			"reason": "Insufficient Action Points"
		}
		
	var remaining: float = maxf(0.0, army.current_action_points - ap_cost)
	var engagement: bool = is_hostile_intercept(army, to_prov, stationed_armies)
	
	return {
		"success": true,
		"ap_cost": ap_cost,
		"remaining_ap": remaining,
		"triggers_engagement": engagement,
		"reason": "OK"
	}

## Executes movement deduction and moves army to new province (Dedicated mutation phase).
static func apply_movement(army: ArmyData, movement_result: Dictionary, destination_province_id: String) -> void:
	if army == null or not movement_result.get("success", false):
		return
		
	var cost: float = movement_result.get("ap_cost", 0.0)
	army.consume_action_points(cost)
	army.current_province_id = destination_province_id
