class_name TestCampaignAI
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	
	test_budget_allocation_phases(failures)
	test_tactical_choice_thresholds(failures)
	test_target_priority_scoring(failures)
	test_target_selection_ranking(failures)
	test_rebel_tactical_evaluation(failures)
	
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_budget_allocation_phases(failures: Array[String]) -> void:
	var total_treasury: int = 2000
	
	# Early Phase: 25% infra, 60% recruit, 15% reserve
	var early: Dictionary = CampaignAIDecisionEngine.calculate_budget_allocation(
		total_treasury,
		CampaignAIDecisionEngine.CampaignPhase.EARLY
	)
	_assert(early["infra_budget"] == 500, "Early infra budget should be 500 (25% of 2000)", failures)
	_assert(early["recruit_budget"] == 1200, "Early recruit budget should be 1200 (60% of 2000)", failures)
	_assert(early["reserve_budget"] == 300, "Early reserve budget should be 300 (15% of 2000)", failures)
	
	# Mid Phase: 45% infra, 45% recruit, 10% reserve
	var mid: Dictionary = CampaignAIDecisionEngine.calculate_budget_allocation(
		total_treasury,
		CampaignAIDecisionEngine.CampaignPhase.MID
	)
	_assert(mid["infra_budget"] == 900, "Mid infra budget should be 900 (45% of 2000)", failures)
	_assert(mid["recruit_budget"] == 900, "Mid recruit budget should be 900 (45% of 2000)", failures)
	_assert(mid["reserve_budget"] == 200, "Mid reserve budget should be 200 (10% of 2000)", failures)
	
	# Late Phase: 15% infra, 75% recruit, 10% reserve
	var late: Dictionary = CampaignAIDecisionEngine.calculate_budget_allocation(
		total_treasury,
		CampaignAIDecisionEngine.CampaignPhase.LATE
	)
	_assert(late["infra_budget"] == 300, "Late infra budget should be 300 (15% of 2000)", failures)
	_assert(late["recruit_budget"] == 1500, "Late recruit budget should be 1500 (75% of 2000)", failures)
	_assert(late["reserve_budget"] == 200, "Late reserve budget should be 200 (10% of 2000)", failures)

static func test_tactical_choice_thresholds(failures: Array[String]) -> void:
	# Settlement level 1 -> fort multiplier = 1.25
	# Direct assault: R_power >= 1.5
	# Attacker = 3000, Defender = 1000, Fort = 1.25 -> Effective Def = 1250 -> R = 2.4
	var choice_assault: CampaignAIDecisionEngine.TacticalChoice = CampaignAIDecisionEngine.evaluate_tactical_choice(3000.0, 1000.0, 1)
	_assert(choice_assault == CampaignAIDecisionEngine.TacticalChoice.DIRECT_ASSAULT, "R = 2.4 should trigger DIRECT_ASSAULT", failures)
	
	# Lay siege: 0.9 <= R_power < 1.5
	# Attacker = 1500, Defender = 1000, Fort = 1.25 -> Effective Def = 1250 -> R = 1.2
	var choice_siege: CampaignAIDecisionEngine.TacticalChoice = CampaignAIDecisionEngine.evaluate_tactical_choice(1500.0, 1000.0, 1)
	_assert(choice_siege == CampaignAIDecisionEngine.TacticalChoice.LAY_SIEGE, "R = 1.2 should trigger LAY_SIEGE", failures)
	
	# Fall back / Retreat: R_power < 0.9
	# Attacker = 800, Defender = 1000, Fort = 1.25 -> Effective Def = 1250 -> R = 0.64
	var choice_retreat: CampaignAIDecisionEngine.TacticalChoice = CampaignAIDecisionEngine.evaluate_tactical_choice(800.0, 1000.0, 1)
	_assert(choice_retreat == CampaignAIDecisionEngine.TacticalChoice.FALL_BACK, "R = 0.64 should trigger FALL_BACK", failures)

static func test_target_priority_scoring(failures: Array[String]) -> void:
	# S_target = ((V_econ + V_strat) / D_turns) * M_diplomacy * (2.0 - R_power)
	var v_econ: float = 20.0
	var v_strat: float = 10.0
	var d_turns: float = 1.0
	var m_diplo: float = 1.5
	var r_power: float = 0.5
	
	var score: float = CampaignAIDecisionEngine.calculate_target_priority_score(
		v_econ,
		v_strat,
		d_turns,
		m_diplo,
		r_power
	)
	# Expected: ((20 + 10) / 1) * 1.5 * (2.0 - 0.5) = 30 * 1.5 * 1.5 = 67.5
	_assert(absf(score - 67.5) < 0.01, "Target priority score should match 67.5, got %f" % score, failures)

static func test_target_selection_ranking(failures: Array[String]) -> void:
	var prov1: ProvinceData = ProvinceData.new()
	prov1.province_id = "prov_rich"
	prov1.region_wealth = 2000.0
	prov1.settlement_level = 3
	
	var prov2: ProvinceData = ProvinceData.new()
	prov2.province_id = "prov_poor"
	prov2.region_wealth = 500.0
	prov2.settlement_level = 1
	
	var candidates: Array[ProvinceData] = [prov2, prov1]
	var best: ProvinceData = CampaignAIDecisionEngine.select_best_target(
		candidates,
		1000.0, # Attacker CP
		1.0     # Default distance turns
	)
	_assert(best != null and best.province_id == "prov_rich", "AI should select highest priority target", failures)

static func test_rebel_tactical_evaluation(failures: Array[String]) -> void:
	# Strong rebels CP = 2000 vs Garrison CP = 800 with fort 1.25 (1000 def CP) -> Ratio 2.0 >= 1.0 -> Assault
	var choice_strong: CampaignAIDecisionEngine.TacticalChoice = CampaignAIDecisionEngine.evaluate_rebel_tactics(2000.0, 800.0, 1)
	_assert(choice_strong == CampaignAIDecisionEngine.TacticalChoice.DIRECT_ASSAULT, "Strong rebels should assault", failures)
	
	# Weak rebels CP = 500 vs Garrison CP = 800 with fort 1.25 -> Ratio 0.5 < 1.0 -> Hold siege
	var choice_weak: CampaignAIDecisionEngine.TacticalChoice = CampaignAIDecisionEngine.evaluate_rebel_tactics(500.0, 800.0, 1)
	_assert(choice_weak == CampaignAIDecisionEngine.TacticalChoice.LAY_SIEGE, "Weak rebels should hold siege", failures)
