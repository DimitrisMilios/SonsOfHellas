extends Node

## Enumeration of high-level campaign progression states.
enum CampaignState {
	IDLE = 0,
	PROCESSING_TURN = 1,
	AWAITING_PLAYER_BATTLE = 2,
	PAUSED = 3
}

## Core lifecycle and state signals
signal turn_started(turn_number: int, active_faction: FactionData)
signal turn_ended(turn_number: int, ended_faction: FactionData)
signal faction_turn_changed(active_faction: FactionData)
signal player_gold_changed(new_gold: int, delta: int)
signal round_completed(new_turn_number: int)
signal turn_processing_started()
signal turn_processing_finished()
signal player_battle_triggered(result: BattleResult)
signal campaign_state_changed(new_state: CampaignState)

## Time budget for microsecond frame-slicing (6-8 ms)
const FRAME_BUDGET_USEC: int = 7000

@export var current_turn: int = 1
@export var registered_factions: Array[FactionData] = []
var active_faction_index: int = 0
var is_turn_in_progress: bool = false
var campaign_state: CampaignState = CampaignState.IDLE
var active_context: TurnPipeline.CampaignContext = null

func _ready() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button: ignore when turn processing or battle pending
		if campaign_state != CampaignState.IDLE:
			get_viewport().set_input_as_handled()

## Transition helper firing state change signal.
func set_campaign_state(new_state: CampaignState) -> void:
	if campaign_state != new_state:
		campaign_state = new_state
		is_turn_in_progress = (campaign_state == CampaignState.PROCESSING_TURN)
		campaign_state_changed.emit(campaign_state)

## Command gate validation.
func can_accept_input() -> bool:
	return campaign_state == CampaignState.IDLE

## Registers a faction into the campaign turn cycle.
func register_faction(faction: FactionData) -> void:
	if faction == null:
		return
	if not registered_factions.has(faction):
		registered_factions.append(faction)

## Initializes and kicks off the turn loop.
func start_campaign() -> void:
	if registered_factions.is_empty():
		push_warning("TurnManager: Cannot start campaign without registered factions.")
		return
	current_turn = 1
	active_faction_index = 0
	set_campaign_state(CampaignState.IDLE)
	_begin_current_faction_turn()

## Active player requests "End Turn". Validates through command gate.
func execute_end_turn() -> bool:
	if not can_accept_input():
		push_warning("TurnManager: Command rejected. Campaign state is not IDLE (%d)." % campaign_state)
		return false
	
	# Turn-commit autosave to capture player orders before AI processing
	if is_inside_tree():
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr != null and save_mgr.has_method("save_game"):
			save_mgr.save_game("campaign_autosave", true)
			
	process_turn_turnover()
	return true

## Legacy compatibility method.
func end_active_faction_turn() -> void:
	execute_end_turn()

## Asynchronous coroutine turn progression with microsecond frame-slicing.
func process_turn_turnover() -> void:
	set_campaign_state(CampaignState.PROCESSING_TURN)
	turn_processing_started.emit()

	var ctx: TurnPipeline.CampaignContext = _build_campaign_context()
	active_context = ctx

	# Step 1: Revenue Collection
	TurnPipeline.step_1_revenue(ctx)
	if is_inside_tree():
		await get_tree().process_frame

	# Step 2: AI Turns
	TurnPipeline.step_2_ai_turns(ctx, CampaignAIDecisionEngine)
	if is_inside_tree():
		await get_tree().process_frame

	# Step 3: Construction Progress Timers
	TurnPipeline.step_3_construction(ctx)

	# Step 4: AI Strategic Movement
	TurnPipeline.step_4_movement(ctx, CampaignAIDecisionEngine)
	if is_inside_tree():
		await get_tree().process_frame

	# Step 5: Conflict & Interceptions
	TurnPipeline.step_5_conflict(ctx)
	if ctx.is_player_battle_pending:
		set_campaign_state(CampaignState.AWAITING_PLAYER_BATTLE)
		player_battle_triggered.emit(ctx.awaiting_player_battle)
		return

	# Step 6: Upkeep Deductions & Bankruptcy Attrition
	TurnPipeline.step_6_upkeep(ctx)

	# Step 7: Public Order & Reset
	TurnPipeline.step_7_reset(ctx)

	_finalize_turn_completion()

## Synchronous execution helper for testing and headless runs.
func process_turn_turnover_sync() -> void:
	var ctx: TurnPipeline.CampaignContext = _build_campaign_context()
	process_turn_turnover_with_context_sync(ctx)

## Synchronous execution helper using an injected context.
func process_turn_turnover_with_context_sync(ctx: TurnPipeline.CampaignContext) -> void:
	set_campaign_state(CampaignState.PROCESSING_TURN)
	turn_processing_started.emit()
	active_context = ctx

	TurnPipeline.step_1_revenue(ctx)
	TurnPipeline.step_2_ai_turns(ctx, CampaignAIDecisionEngine)
	TurnPipeline.step_3_construction(ctx)
	TurnPipeline.step_4_movement(ctx, CampaignAIDecisionEngine)
	TurnPipeline.step_5_conflict(ctx)

	if ctx.is_player_battle_pending:
		set_campaign_state(CampaignState.AWAITING_PLAYER_BATTLE)
		player_battle_triggered.emit(ctx.awaiting_player_battle)
		return

	TurnPipeline.step_6_upkeep(ctx)
	TurnPipeline.step_7_reset(ctx)

	_finalize_turn_completion()

## Resumes turn pipeline after player battle is resolved in UI.
func resume_after_player_battle_sync(ctx: TurnPipeline.CampaignContext = null) -> void:
	var target_ctx: TurnPipeline.CampaignContext = ctx if ctx != null else active_context
	if target_ctx == null:
		set_campaign_state(CampaignState.IDLE)
		return

	target_ctx.is_player_battle_pending = false
	target_ctx.awaiting_player_battle = null

	TurnPipeline.step_6_upkeep(target_ctx)
	TurnPipeline.step_7_reset(target_ctx)

	_finalize_turn_completion()

func _finalize_turn_completion() -> void:
	if active_context != null:
		current_turn = active_context.current_turn
	else:
		current_turn += 1

	active_faction_index = 0
	set_campaign_state(CampaignState.IDLE)
	turn_processing_finished.emit()
	round_completed.emit(current_turn)

	var player_fac: FactionData = get_player_faction()
	if player_fac != null:
		player_gold_changed.emit(player_fac.treasury, 0)
		faction_turn_changed.emit(player_fac)
		turn_started.emit(current_turn, player_fac)

	# Turn-start mandatory autosave at turn boundary
	if is_inside_tree():
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr != null and save_mgr.has_method("save_game"):
			save_mgr.save_game("campaign_autosave", false)

func _build_campaign_context() -> TurnPipeline.CampaignContext:
	var ctx: TurnPipeline.CampaignContext = TurnPipeline.CampaignContext.new()
	ctx.current_turn = current_turn

	for f: FactionData in registered_factions:
		if f != null:
			ctx.add_faction(f)

	if is_inside_tree():
		var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
		if campaign_mgr != null:
			var prov_map: Dictionary = campaign_mgr.get("provinces")
			if prov_map != null:
				for pid: Variant in prov_map.keys():
					ctx.add_province(prov_map[pid])
			var army_list: Array = campaign_mgr.get("armies")
			if army_list != null:
				for a: Variant in army_list:
					if a is ArmyData:
						ctx.add_army(a)

	return ctx

## Handles per-turn resource generation, AP reset, and event triggers for legacy compatibility.
func _begin_current_faction_turn() -> void:
	var active_faction: FactionData = get_active_faction()
	if active_faction == null:
		return
	
	var net_delta: int = active_faction.process_turn_finances()
	if active_faction.is_player:
		player_gold_changed.emit(active_faction.treasury, net_delta)
	
	faction_turn_changed.emit(active_faction)
	turn_started.emit(current_turn, active_faction)

## Returns the currently acting faction.
func get_active_faction() -> FactionData:
	if registered_factions.is_empty():
		return null
	return registered_factions[active_faction_index]

## Returns the human player's faction if one exists.
func get_player_faction() -> FactionData:
	for faction: FactionData in registered_factions:
		if faction != null and faction.is_player:
			return faction
	return null

## Convenience check for UI input gating.
func is_player_turn() -> bool:
	return can_accept_input() and get_active_faction() != null and get_active_faction().is_player

## Adjusts player treasury and fires change notification.
func modify_player_gold(amount: int) -> void:
	var player: FactionData = get_player_faction()
	if player != null:
		if amount > 0:
			player.add_treasury(amount)
		else:
			player.deduct_treasury(-amount)
		player_gold_changed.emit(player.treasury, amount)

## Returns current player treasury balance.
func get_player_gold() -> int:
	var player: FactionData = get_player_faction()
	return player.treasury if player != null else 0
