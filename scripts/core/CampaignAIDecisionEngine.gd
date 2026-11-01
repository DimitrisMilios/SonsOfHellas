class_name CampaignAIDecisionEngine
extends RefCounted

## Campaign progression phase dictating resource investment philosophy.
enum CampaignPhase {
	EARLY,
	MID,
	LATE
}

## Tactical assault threshold options for settlements and armies.
enum TacticalChoice {
	DIRECT_ASSAULT,
	LAY_SIEGE,
	FALL_BACK
}

## Settlement fate decisions upon victorious occupation.
enum SettlementFate {
	PEACEFUL_OCCUPATION,
	SACK,
	VASSALIZE
}

## Mathematical threshold constants from docs/design/campaign_ai.md
const ASSAULT_POWER_THRESHOLD: float = 1.5
const SIEGE_POWER_THRESHOLD: float = 0.9
const REBEL_ASSAULT_THRESHOLD: float = 1.0

## Calculates capital distribution across financial buckets based on campaign phase.
static func calculate_budget_allocation(treasury_available: int, phase: CampaignPhase) -> Dictionary:
	var safe_treasury: int = maxi(0, treasury_available)
	var w_infra: float = 0.25
	var w_recruit: float = 0.60
	var w_reserve: float = 0.15
	
	match phase:
		CampaignPhase.EARLY:
			w_infra = 0.25
			w_recruit = 0.60
			w_reserve = 0.15
		CampaignPhase.MID:
			w_infra = 0.45
			w_recruit = 0.45
			w_reserve = 0.10
		CampaignPhase.LATE:
			w_infra = 0.15
			w_recruit = 0.75
			w_reserve = 0.10
			
	var b_infra: int = roundi(float(safe_treasury) * w_infra)
	var b_recruit: int = roundi(float(safe_treasury) * w_recruit)
	var b_reserve: int = safe_treasury - (b_infra + b_recruit)
	
	return {
		"infra_budget": b_infra,
		"recruit_budget": b_recruit,
		"reserve_budget": b_reserve
	}

## Evaluates whether an army should assault, lay siege, or retreat from a settlement.
static func evaluate_tactical_choice(attacker_cp: float, defender_cp: float, settlement_level: int = 1) -> TacticalChoice:
	var m_fort: float = 1.0 + float(clampi(settlement_level, 1, 5)) * 0.25
	var effective_defender_cp: float = maxf(1.0, defender_cp * m_fort)
	var r_power: float = attacker_cp / effective_defender_cp
	
	if r_power >= ASSAULT_POWER_THRESHOLD:
		return TacticalChoice.DIRECT_ASSAULT
	elif r_power >= SIEGE_POWER_THRESHOLD:
		return TacticalChoice.LAY_SIEGE
	return TacticalChoice.FALL_BACK

## Evaluates tactical behavior for rebel armies (assault if R >= 1.0, else hold siege).
static func evaluate_rebel_tactics(rebel_cp: float, garrison_cp: float, settlement_level: int = 1) -> TacticalChoice:
	var m_fort: float = 1.0 + float(clampi(settlement_level, 1, 5)) * 0.25
	var effective_garrison_cp: float = maxf(1.0, garrison_cp * m_fort)
	var r_power: float = rebel_cp / effective_garrison_cp
	
	if r_power >= REBEL_ASSAULT_THRESHOLD:
		return TacticalChoice.DIRECT_ASSAULT
	return TacticalChoice.LAY_SIEGE

## Calculates Target Priority Score (S_target) for campaign strategic vectoring.
## S_target = ((V_econ + V_strat) / D_turns) * M_diplomacy * (2.0 - R_power)
static func calculate_target_priority_score(
	v_econ: float,
	v_strat: float,
	d_turns: float,
	m_diplomacy: float,
	r_power: float
) -> float:
	var safe_d_turns: float = maxf(1.0, d_turns)
	var safe_m_diplo: float = clampf(m_diplomacy, 0.1, 3.0)
	var safe_r_mult: float = maxf(0.1, 2.0 - r_power)
	var base_value: float = (v_econ + v_strat) / safe_d_turns
	return base_value * safe_m_diplo * safe_r_mult

## Ranks candidates and returns the best strategic target province.
static func select_best_target(
	candidates: Array[ProvinceData],
	attacker_cp: float,
	default_distance_turns: float = 1.0,
	m_diplo: float = 1.5
) -> ProvinceData:
	if candidates.is_empty():
		return null
		
	var best_score: float = -INF
	var best_province: ProvinceData = null
	
	for prov: ProvinceData in candidates:
		if prov == null:
			continue
			
		var v_econ: float = prov.region_wealth / 100.0
		var v_strat: float = float(prov.settlement_level) * 10.0
		
		# Estimate defender CP (baseline militia if garrison array empty)
		var def_cp: float = float(prov.settlement_level) * 300.0
		for g: UnitData in prov.garrison_units:
			if g != null:
				def_cp += g.get_combat_value()
		var m_fort: float = 1.0 + float(clampi(prov.settlement_level, 1, 5)) * 0.25
		var r_power: float = attacker_cp / maxf(1.0, def_cp * m_fort)
		
		var score: float = calculate_target_priority_score(
			v_econ,
			v_strat,
			default_distance_turns,
			m_diplo,
			r_power
		)
		
		if score > best_score:
			best_score = score
			best_province = prov
			
	return best_province

## Pipeline Hook: AI Faction economic investment and recruitment.
static func process_faction_economy_and_recruitment(faction: FactionData, context: TurnPipeline.CampaignContext) -> void:
	if faction == null or context == null:
		return
		
	var budget: Dictionary = calculate_budget_allocation(faction.treasury, CampaignPhase.EARLY)
	var infra_funds: int = budget["infra_budget"]
	
	# Find candidate provinces for construction
	for pid: String in context.get_sorted_province_ids():
		if infra_funds <= 100:
			break
		var prov: ProvinceData = context.provinces[pid]
		if prov != null and prov.owner_faction_id == faction.faction_id and prov.can_add_building():
			# Check if there is an empty slot and funds
			var slot: BuildingSlotData = prov.get_empty_slot()
			if slot != null:
				var bld: BuildingData = BuildingData.new()
				bld.building_id = "bld_farm_basic"
				bld.display_name = "Basic Farm"
				bld.turns_to_build = 2
				bld.positive_wealth_generation = 10.0
				prov.queue_building_construction(bld)
				faction.treasury -= 100
				infra_funds -= 100

## Pipeline Hook: AI Strategic Movement & Action Phase.
static func process_faction_movement(faction: FactionData, context: TurnPipeline.CampaignContext) -> void:
	if faction == null or context == null:
		return
		
	# Find armies belonging to this faction
	for a: ArmyData in context.armies:
		if a != null and a.owner_faction_id == faction.faction_id and not a.units.is_empty():
			var cur_prov: ProvinceData = context.provinces.get(a.current_province_id)
			if cur_prov == null:
				continue
				
			# Look for adjacent hostile provinces
			var hostile_adjacent: Array[ProvinceData] = []
			for adj_id: String in cur_prov.adjacent_province_ids:
				var adj_p: ProvinceData = context.provinces.get(adj_id)
				if adj_p != null and adj_p.owner_faction_id != faction.faction_id:
					hostile_adjacent.append(adj_p)
					
			if not hostile_adjacent.is_empty():
				var target: ProvinceData = select_best_target(hostile_adjacent, a.get_total_combat_value(), 1.0)
				if target != null and a.current_action_points >= 40.0:
					a.current_province_id = target.province_id
					a.consume_action_points(40.0)
