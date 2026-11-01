class_name TurnManager
extends Node

## Emitted when a new faction's turn begins.
signal turn_started(turn_number: int, active_faction: FactionData)

## Emitted when an active faction finishes its turn actions.
signal turn_ended(turn_number: int, ended_faction: FactionData)

## Emitted whenever the active faction index changes.
signal faction_turn_changed(active_faction: FactionData)

## Emitted whenever the human player's treasury changes.
signal player_gold_changed(new_gold: int, delta: int)

## Emitted when all factions have completed their turn and turn counter increments.
signal round_completed(new_turn_number: int)

@export var current_turn: int = 1
@export var registered_factions: Array[FactionData] = []
var active_faction_index: int = 0
var is_turn_in_progress: bool = false

func _ready() -> void:
	pass

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
	_begin_current_faction_turn()

## Concludes actions for the current active faction and advances cycle.
func end_active_faction_turn() -> void:
	if registered_factions.is_empty():
		return
	
	var current_faction: FactionData = get_active_faction()
	if current_faction != null:
		turn_ended.emit(current_turn, current_faction)
	
	advance_to_next_faction()

## Advances the active faction index, handling round turnover when cycling back to 0.
func advance_to_next_faction() -> void:
	active_faction_index += 1
	
	if active_faction_index >= registered_factions.size():
		# Completed full round across all factions
		active_faction_index = 0
		current_turn += 1
		round_completed.emit(current_turn)
	
	_begin_current_faction_turn()

## Handles per-turn resource generation, AP reset, and event triggers.
func _begin_current_faction_turn() -> void:
	var active_faction: FactionData = get_active_faction()
	if active_faction == null:
		return
	
	# Process economic income & upkeep
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
	var active_faction: FactionData = get_active_faction()
	return active_faction != null and active_faction.is_player

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
