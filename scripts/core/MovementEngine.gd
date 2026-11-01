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

## Calculates trade route raiding income: I_raid = W_lane * alpha_raid.
static func calculate_raiding_income(lane_wealth: float, raid_fraction: float = 0.20) -> int:
	var safe_wealth: float = maxf(0.0, lane_wealth)
	var safe_alpha: float = clampf(raid_fraction, 0.0, 1.0)
	return roundi(safe_wealth * safe_alpha)

## Calculates 2D spatial retreat vector pointing away from attacking force.
static func calculate_retreat_vector(from_position: Vector2, away_from_position: Vector2) -> Vector2:
	var dir: Vector2 = from_position - away_from_position
	if dir.is_zero_approx():
		return Vector2.DOWN
	return dir.normalized()

## Finds the best eligible adjacent province for a retreating army.
## Trapped armies with no valid friendly or neutral path return "" (forcing stack destruction).
static func find_best_retreat_province(
	defeated_army: ArmyData,
	current_prov: ProvinceData,
	enemy_army: ArmyData,
	provinces_map: Dictionary
) -> String:
	if defeated_army == null or current_prov == null:
		return ""
		
	var enemy_pos: Vector2 = Vector2.ZERO
	if enemy_army != null and provinces_map.has(enemy_army.current_province_id):
		var ep: ProvinceData = provinces_map[enemy_army.current_province_id]
		if ep != null:
			enemy_pos = ep.map_position
			
	var retreat_vec: Vector2 = calculate_retreat_vector(current_prov.map_position, enemy_pos)
	var best_prov_id: String = ""
	var best_score: float = -999999.0
	
	for adj_id: String in current_prov.adjacent_province_ids:
		if not provinces_map.has(adj_id):
			continue
		var adj_prov: ProvinceData = provinces_map[adj_id]
		if adj_prov == null:
			continue
			
		# Cannot retreat into enemy faction's territory
		if enemy_army != null and adj_prov.owner_faction_id != "" and adj_prov.owner_faction_id == enemy_army.owner_faction_id:
			continue
			
		# Score based on alignment with retreat vector away from attacker
		var to_adj: Vector2 = (adj_prov.map_position - current_prov.map_position).normalized()
		var alignment: float = retreat_vec.dot(to_adj)
		
		# Bonus if already owned by friendly faction
		var friendly_bonus: float = 2.0 if adj_prov.owner_faction_id == defeated_army.owner_faction_id else 0.0
		var score: float = alignment + friendly_bonus
		
		if score > best_score:
			best_score = score
			best_prov_id = adj_id
			
	return best_prov_id

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
	if engagement:
		# Entering hostile Zone of Control halts campaign movement and consumes remaining AP
		remaining = 0.0
	
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
	if movement_result.get("triggers_engagement", false):
		army.current_action_points = 0.0
	army.current_province_id = destination_province_id
