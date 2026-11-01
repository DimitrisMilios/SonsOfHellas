class_name TestTurnPipeline
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	
	test_pipeline_context_init(failures)
	test_step_1_revenue(failures)
	test_step_3_construction(failures)
	test_step_5_conflict_pairwise(failures)
	test_step_6_bankruptcy_desertion(failures)
	test_step_7_rebellion_and_cooldown(failures)
	test_step_7_alternating_tax_exploit_fix(failures)
	test_step_7_ap_reset_and_turn_advance(failures)
	test_full_7_step_execution_sequence(failures)
	
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func _create_sample_unit(id: String, tier: int = 1, count: int = 120, upkeep: int = 30) -> UnitData:
	var u: UnitData = UnitData.new()
	u.unit_id = id
	u.display_name = "Unit " + id
	u.tier = tier
	u.unit_count = count
	u.turn_upkeep = upkeep
	u.upkeep_cost = upkeep
	u.melee_attack = 10
	u.melee_defense = 10
	u.armor = 20
	u.morale = 10
	u.role_tags = [UnitData.RoleTag.INFANTRY_SPEAR]
	return u

static func _create_sample_province(id: String, owner: String) -> ProvinceData:
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = id
	prov.province_name = id.capitalize()
	prov.owner_faction_id = owner
	prov.settlement_level = 2
	prov.region_wealth = 1000.0
	prov.public_order = 50.0
	prov.growth_rate = 10.0
	prov.calm_margin = 10.0
	return prov

static func _create_sample_faction(id: String, is_player: bool = false, treasury: int = 1000) -> FactionData:
	var f: FactionData = FactionData.new()
	f.faction_id = id
	f.faction_name = id.capitalize()
	f.is_player = is_player
	f.treasury = treasury
	f.base_purse = 500
	return f

static func _create_sample_army(id: String, owner: String, prov_id: String) -> ArmyData:
	var army: ArmyData = ArmyData.new()
	army.army_id = id
	army.army_name = id.capitalize()
	army.owner_faction_id = owner
	army.current_province_id = prov_id
	army.current_action_points = 100.0
	army.max_action_points = 100.0
	army.stance = ArmyData.Stance.NORMAL
	return army

static func test_pipeline_context_init(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	_assert(ctx.current_turn == 1, "Context initial turn should be 1", failures)
	_assert(ctx.factions.is_empty(), "Context factions should start empty", failures)
	_assert(ctx.provinces.is_empty(), "Context provinces should start empty", failures)
	_assert(ctx.armies.is_empty(), "Context armies should start empty", failures)

static func test_step_1_revenue(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	var fac: FactionData = _create_sample_faction("sparta", true, 500)
	var prov: ProvinceData = _create_sample_province("prov_sparta", "sparta")
	prov.region_wealth = 1000.0
	prov.tax_level_upper = 3
	prov.tax_level_lower = 3
	
	ctx.add_faction(fac)
	ctx.add_province(prov)
	
	TurnPipeline.step_1_revenue(ctx)
	
	_assert(fac.treasury > 500, "Treasury should increase after Step 1 revenue collection", failures)
	_assert(prov.region_wealth >= 100.0, "Region wealth should respect subsistence floor", failures)
	_assert(ctx.event_log.size() >= 1, "Event log should record revenue collected event", failures)

static func test_step_3_construction(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	var prov: ProvinceData = _create_sample_province("prov_sparta", "sparta")
	
	var bld: BuildingData = BuildingData.new()
	bld.building_id = "bld_barracks_1"
	bld.display_name = "Spartan Barracks"
	bld.turns_to_build = 2
	
	var slot: BuildingSlotData = prov.get_empty_slot()
	_assert(slot != null, "Province must have empty slot", failures)
	slot.queue_construction(bld)
	_assert(slot.is_under_construction, "Slot should be under construction", failures)
	_assert(slot.remaining_construction_turns == 2, "Remaining turns should start at 2", failures)
	
	ctx.add_province(prov)
	
	# Turn 1 Step 3
	TurnPipeline.step_3_construction(ctx)
	_assert(slot.remaining_construction_turns == 1, "Remaining turns should decrement to 1", failures)
	_assert(slot.is_under_construction, "Slot should still be under construction at turn 1", failures)
	_assert(slot.building_data == null, "Building should not be active yet", failures)
	
	# Turn 2 Step 3
	TurnPipeline.step_3_construction(ctx)
	_assert(slot.remaining_construction_turns == 0, "Remaining turns should reach 0", failures)
	_assert(not slot.is_under_construction, "Slot should no longer be under construction", failures)
	_assert(slot.building_data != null, "Building data should now be active in slot", failures)
	_assert(slot.building_data.building_id == "bld_barracks_1", "Active building ID must match target", failures)

static func test_step_5_conflict_pairwise(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	var fac1: FactionData = _create_sample_faction("sparta", false, 1000)
	var fac2: FactionData = _create_sample_faction("athens", false, 1000)
	var prov: ProvinceData = _create_sample_province("prov_megara", "sparta")
	
	var army_sparta: ArmyData = _create_sample_army("army_sparta", "sparta", "prov_megara")
	for i in range(4):
		army_sparta.add_unit(_create_sample_unit("spartan_hop_%d" % i, 2, 120))
		
	var army_athens: ArmyData = _create_sample_army("army_athens", "athens", "prov_megara")
	for i in range(1):
		army_athens.add_unit(_create_sample_unit("athenian_militia_%d" % i, 1, 60))
		
	ctx.add_faction(fac1)
	ctx.add_faction(fac2)
	ctx.add_province(prov)
	ctx.add_army(army_sparta)
	ctx.add_army(army_athens)
	
	var conflict_result: Dictionary = TurnPipeline.step_5_conflict(ctx)
	_assert(conflict_result.has("battles_resolved"), "Step 5 should return battles resolved count", failures)
	_assert(conflict_result["battles_resolved"] == 1, "Exactly 1 battle should resolve in prov_megara", failures)
	_assert(army_sparta.units.size() > 0, "Sparta should win and retain survivors", failures)

static func test_step_6_bankruptcy_desertion(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	var fac: FactionData = _create_sample_faction("corinth", false, 0)
	var prov: ProvinceData = _create_sample_province("prov_corinth", "corinth")
	
	var army: ArmyData = _create_sample_army("army_corinth", "corinth", "prov_corinth")
	var u1: UnitData = _create_sample_unit("corinth_militia", 1, 100, 50)
	u1.veterancy_rank = 0
	var u2: UnitData = _create_sample_unit("corinth_elite", 3, 100, 100)
	u2.veterancy_rank = 3
	army.add_unit(u1)
	army.add_unit(u2)
	
	ctx.add_faction(fac)
	ctx.add_province(prov)
	ctx.add_army(army)
	
	TurnPipeline.step_6_upkeep(ctx)
	
	_assert(fac.is_bankrupt, "Faction should be flagged as bankrupt when unable to pay upkeep", failures)
	_assert(army.units.size() < 2, "Bankruptcy desertion should remove candidate units", failures)
	_assert(army.units.has(u2), "Elite high veterancy unit should be preserved over raw militia", failures)

static func test_step_7_rebellion_and_cooldown(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	var fac: FactionData = _create_sample_faction("sparta", false, 1000)
	var prov: ProvinceData = _create_sample_province("prov_messenia", "sparta")
	prov.tax_level_lower = 5 # 14 unrest, 0 positive PO -> PO = -14
	prov.unrest_pressure = 0
	prov.calm_margin = 10.0
	
	ctx.add_faction(fac)
	ctx.add_province(prov)
	
	# Turn 1: PO < 0 -> unrest_pressure = 1, no rebellion yet
	TurnPipeline.step_7_reset(ctx)
	_assert(prov.unrest_pressure == 1, "Unrest pressure should be 1 on first negative turn", failures)
	_assert(ctx.armies.is_empty(), "No rebel army should spawn on first negative turn", failures)
	
	# Turn 2: PO remains negative -> unrest_pressure reaches 2 -> spawns rebellion!
	TurnPipeline.step_7_reset(ctx)
	_assert(ctx.armies.size() == 1, "Rebel army should spawn when unrest_pressure reaches 2", failures)
	var rebel_army: ArmyData = ctx.armies[0]
	_assert(rebel_army.owner_faction_id == "faction_rebels", "Rebel army owner must be faction_rebels", failures)
	_assert(rebel_army.stance == ArmyData.Stance.SIEGE, "Rebel army should initiate siege stance", failures)
	_assert(prov.unrest_pressure == 0, "Unrest pressure must reset to 0 after spawning rebellion", failures)
	_assert(prov.rebellion_cooldown == 2, "Rebellion cooldown should be set to 2 turns", failures)

static func test_step_7_alternating_tax_exploit_fix(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	var fac: FactionData = _create_sample_faction("athens", true, 1000)
	var prov: ProvinceData = _create_sample_province("prov_attica", "athens")
	prov.calm_margin = 10.0
	
	ctx.add_faction(fac)
	ctx.add_province(prov)
	
	# Turn 1: High tax (L5) -> PO = -14 < 0 -> unrest_pressure = 1
	prov.tax_level_lower = 5
	TurnPipeline.step_7_reset(ctx)
	_assert(prov.unrest_pressure == 1, "Turn 1: unrest_pressure should be 1", failures)
	
	# Turn 2: Player lowers taxes to L3 (unrest 4) and adds a small garrison (repression 4) -> PO = 0
	# In the old exploit, any PO >= 0 wiped unrest to 0! With the fix, unrest_pressure stays 1 because PO < calm_margin (10.0).
	prov.tax_level_lower = 3
	var g_unit: UnitData = _create_sample_unit("town_watch", 1, 240) # 240 models / 60 = 4 repression
	prov.add_garrison_unit(g_unit)
	TurnPipeline.step_7_reset(ctx)
	_assert(prov.unrest_pressure == 1, "Turn 2: unrest_pressure should not decrease when 0 <= PO < calm_margin", failures)
	_assert(ctx.armies.is_empty(), "Turn 2: no rebels yet", failures)
	
	# Turn 3: Player raises taxes again to L5 without garrison, PO = -14 < 0 -> unrest_pressure reaches 2 -> Exploit prevented, rebels spawn!
	prov.remove_garrison_unit(g_unit)
	prov.tax_level_lower = 5
	TurnPipeline.step_7_reset(ctx)
	_assert(ctx.armies.size() == 1, "Turn 3: Rebels should spawn, preventing alternating tax exploit", failures)

static func test_step_7_ap_reset_and_turn_advance(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	var army: ArmyData = _create_sample_army("army_1", "sparta", "prov_1")
	army.current_action_points = 20.0
	army.has_retreated_this_turn = true
	
	ctx.add_army(army)
	ctx.current_turn = 5
	
	TurnPipeline.step_7_reset(ctx)
	_assert(army.current_action_points == army.max_action_points, "Armies should have AP reset in Step 7", failures)
	_assert(not army.has_retreated_this_turn, "has_retreated_this_turn should reset in Step 7", failures)
	_assert(ctx.current_turn == 6, "Turn counter should advance from 5 to 6 in Step 7", failures)

static func test_full_7_step_execution_sequence(failures: Array[String]) -> void:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	var fac: FactionData = _create_sample_faction("sparta", true, 2000)
	var prov: ProvinceData = _create_sample_province("prov_sparta", "sparta")
	var army: ArmyData = _create_sample_army("army_sparta", "sparta", "prov_sparta")
	army.add_unit(_create_sample_unit("hoplite_1", 2, 120, 40))
	army.current_action_points = 50.0
	
	ctx.add_faction(fac)
	ctx.add_province(prov)
	ctx.add_army(army)
	
	var report: Dictionary = TurnPipeline.execute_turn(ctx)
	_assert(report["success"], "execute_turn should return success", failures)
	_assert(report["new_turn"] == 2, "execute_turn should advance turn from 1 to 2", failures)
	_assert(army.current_action_points == 100.0, "Army AP should be restored to 100.0", failures)
