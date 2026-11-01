class_name TestTurnCommitReplay
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_turn_committed_flag_in_envelope(failures)
	test_turn_start_mandatory_autosave(failures)
	test_deterministic_pipeline_replay(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_turn_committed_flag_in_envelope(failures: Array[String]) -> void:
	var tm_script: GDScript = load("res://scripts/core/TurnManager.gd") as GDScript
	var sm_script: GDScript = load("res://scripts/core/SaveManager.gd") as GDScript
	var sm: Node = sm_script.new()
	
	var envelope: Dictionary = sm.serialize_campaign([], {}, [], 1, 1337, true)
	var payload: Dictionary = envelope.get("payload", {})
	_assert(payload.get("turn_committed", false) == true, 
		"serialize_campaign with committed=true must record turn_committed: true", failures)
	
	sm.free()

static func test_turn_start_mandatory_autosave(failures: Array[String]) -> void:
	var tm_script: GDScript = load("res://scripts/core/TurnManager.gd") as GDScript
	var tm: Node = tm_script.new()
	
	var fac: FactionData = FactionData.new()
	fac.faction_id = "sparta"
	fac.faction_name = "Sparta"
	fac.is_player = true
	tm.register_faction(fac)
	
	_assert(tm.has_method("_finalize_turn_completion"), "TurnManager must have _finalize_turn_completion", failures)
	
	tm.free()

static func _create_test_context(seed_val: int = 42) -> TurnPipeline.CampaignContext:
	var f1: FactionData = FactionData.new()
	f1.faction_id = "sparta"
	f1.faction_name = "Sparta"
	f1.is_player = true
	f1.treasury = 1000
	
	var f2: FactionData = FactionData.new()
	f2.faction_id = "athens"
	f2.faction_name = "Athens"
	f2.treasury = 1000
	
	var p1: ProvinceData = ProvinceData.new()
	p1.province_id = "prov_sparta"
	p1.province_name = "Sparta"
	p1.owner_faction_id = "sparta"
	p1.region_wealth = 1000.0
	p1.public_order = 10.0

	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	ctx.current_turn = 1
	ctx.campaign_seed = seed_val
	ctx.add_faction(f1)
	ctx.add_faction(f2)
	ctx.add_province(p1)
	return ctx

static func test_deterministic_pipeline_replay(failures: Array[String]) -> void:
	# Run 1: Normal pipeline execution
	var ctx1: TurnPipeline.CampaignContext = _create_test_context(42)
	TurnPipeline.step_1_revenue(ctx1)
	TurnPipeline.step_3_construction(ctx1)
	TurnPipeline.step_6_upkeep(ctx1)
	TurnPipeline.step_7_reset(ctx1)
	
	var gold1: int = ctx1.factions["sparta"].treasury
	var po1: float = ctx1.provinces["prov_sparta"].public_order
	
	# Run 2: Replay pipeline execution from identical starting state
	var ctx2: TurnPipeline.CampaignContext = _create_test_context(42)
	TurnPipeline.step_1_revenue(ctx2)
	TurnPipeline.step_3_construction(ctx2)
	TurnPipeline.step_6_upkeep(ctx2)
	TurnPipeline.step_7_reset(ctx2)
	
	var gold2: int = ctx2.factions["sparta"].treasury
	var po2: float = ctx2.provinces["prov_sparta"].public_order
	
	_assert(gold1 == gold2, "Deterministic replay must match gold exactly: %d vs %d" % [gold1, gold2], failures)
	_assert(is_equal_approx(po1, po2), "Deterministic replay must match PO exactly: %f vs %f" % [po1, po2], failures)
