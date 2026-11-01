class_name TestTurnManager
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	
	test_state_initialization(failures)
	test_input_gating(failures)
	test_turn_execution_lifecycle(failures)
	test_player_battle_pause_and_resume(failures)
	
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func _create_mgr() -> Node:
	# Load TurnManager script directly without autoload collision
	var script: Script = load("res://scripts/core/TurnManager.gd")
	var mgr: Node = Node.new()
	mgr.set_script(script)
	return mgr

static func test_state_initialization(failures: Array[String]) -> void:
	var mgr: Node = _create_mgr()
	_assert(mgr.campaign_state == 0, "Initial campaign state should be IDLE (0)", failures)
	_assert(mgr.can_accept_input(), "TurnManager should accept input when IDLE", failures)
	mgr.free()

static func test_input_gating(failures: Array[String]) -> void:
	var mgr: Node = _create_mgr()
	mgr.campaign_state = 1 # PROCESSING_TURN
	_assert(not mgr.can_accept_input(), "TurnManager should reject input while PROCESSING_TURN", failures)
	
	var rejected: bool = not mgr.execute_end_turn()
	_assert(rejected, "execute_end_turn should reject when state is not IDLE", failures)
	mgr.free()

static func test_turn_execution_lifecycle(failures: Array[String]) -> void:
	var mgr: Node = _create_mgr()
	var f1: FactionData = FactionData.new()
	f1.faction_id = "sparta"
	f1.is_player = true
	f1.treasury = 1000
	
	var f2: FactionData = FactionData.new()
	f2.faction_id = "athens"
	f2.is_player = false
	f2.treasury = 1000
	
	mgr.register_faction(f1)
	mgr.register_faction(f2)
	mgr.current_turn = 1
	
	var flags: Dictionary = {"started": false, "finished": false}
	mgr.connect("turn_processing_started", func(): flags["started"] = true)
	mgr.connect("turn_processing_finished", func(): flags["finished"] = true)
	
	# Execute turn synchronously/directly
	mgr.process_turn_turnover_sync()
	
	_assert(flags["started"], "turn_processing_started should have emitted", failures)
	_assert(flags["finished"], "turn_processing_finished should have emitted", failures)
	_assert(mgr.current_turn == 2, "Turn number should advance to 2", failures)
	_assert(mgr.campaign_state == 0, "State should return to IDLE after turnover", failures)
	mgr.free()

static func _create_unit(id: String, count: int = 100) -> UnitData:
	var u: UnitData = UnitData.new()
	u.unit_id = id
	u.unit_count = count
	u.melee_attack = 12
	u.melee_defense = 10
	u.armor = 20
	u.morale = 10
	u.turn_upkeep = 30
	u.role_tags = [UnitData.RoleTag.INFANTRY_SPEAR]
	return u

static func test_player_battle_pause_and_resume(failures: Array[String]) -> void:
	var mgr: Node = _create_mgr()
	var f_player: FactionData = FactionData.new()
	f_player.faction_id = "sparta"
	f_player.is_player = true
	f_player.treasury = 1000
	
	var f_enemy: FactionData = FactionData.new()
	f_enemy.faction_id = "persia"
	f_enemy.is_player = false
	f_enemy.treasury = 1000
	
	mgr.register_faction(f_player)
	mgr.register_faction(f_enemy)
	
	var p_army: ArmyData = ArmyData.new()
	p_army.army_id = "spartan_army"
	p_army.owner_faction_id = "sparta"
	p_army.current_province_id = "prov_thermopylae"
	p_army.add_unit(_create_unit("spartan_hop", 100))
	
	var e_army: ArmyData = ArmyData.new()
	e_army.army_id = "persian_army"
	e_army.owner_faction_id = "persia"
	e_army.current_province_id = "prov_thermopylae"
	e_army.add_unit(_create_unit("persian_inf", 100))
	
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = "prov_thermopylae"
	prov.owner_faction_id = "sparta"
	
	# Inject into mgr context
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	ctx.add_faction(f_player)
	ctx.add_faction(f_enemy)
	ctx.add_province(prov)
	ctx.add_army(p_army)
	ctx.add_army(e_army)
	
	var battle_flags: Dictionary = {"emitted": false}
	mgr.connect("player_battle_triggered", func(_res): battle_flags["emitted"] = true)
	
	mgr.process_turn_turnover_with_context_sync(ctx)
	
	_assert(mgr.campaign_state == 2, "State should be AWAITING_PLAYER_BATTLE (2)", failures)
	_assert(battle_flags["emitted"], "player_battle_triggered should emit when player army engages in conflict", failures)
	
	# Resume after resolving battle
	mgr.resume_after_player_battle_sync(ctx)
	_assert(mgr.campaign_state == 0, "State should return to IDLE after player battle resume", failures)
	_assert(mgr.current_turn == 2, "Turn should advance to 2 after completing resumed turn", failures)
	mgr.free()
