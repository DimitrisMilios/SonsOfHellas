class_name BattleResult
extends RefCounted

## Attacking and Defending Armies
var attacker_army: ArmyData = null
var defender_army: ArmyData = null
var attacker_won: bool = false

## Combat Ratings & Odds
var attacker_power: float = 0.0
var defender_power: float = 0.0
var power_ratio: float = 1.0 # Winner Power / Loser Power
var attacker_win_probability: float = 0.50

## Outcome Classification (Heroic, Decisive, Close, Pyrrhic)
var outcome_classification: String = "Inconclusive"
var victor_casualty_ratio: float = 0.0
var loser_casualty_ratio: float = 0.0

## Casualty Metrics (Models)
var attacker_initial_models: int = 0
var attacker_remaining_models: int = 0
var attacker_casualties_count: int = 0

var defender_initial_models: int = 0
var defender_remaining_models: int = 0
var defender_casualties_count: int = 0

## Unit Collections
var attacker_survivors: Array[UnitData] = []
var defender_survivors: Array[UnitData] = []
var attacker_destroyed_units: Array[UnitData] = []
var defender_destroyed_units: Array[UnitData] = []

## Detailed unit casualty map
var unit_casualties: Dictionary = {}

## Post-Battle State Flags
var is_wipeout: bool = false
var is_siege_defense: bool = false
var battle_summary: String = ""

## Returns true if the battle outcome was classified as Decisive or Heroic.
func is_decisive() -> bool:
	return outcome_classification.begins_with("Decisive") or outcome_classification.begins_with("Heroic")

## Validates conservation of model counts across casualties and survivors.
func validate_survivor_integrity() -> bool:
	if attacker_initial_models != (attacker_casualties_count + attacker_remaining_models):
		return false
	if defender_initial_models != (defender_casualties_count + defender_remaining_models):
		return false
	return true

## Formulates structured combat telemetry log in Markdown for UI dialogs and battle reports.
func get_log_message() -> String:
	var victor_side: String = "Attacker" if attacker_won else "Defender"
	var win_pct_str: String = "%.1f%%" % (attacker_win_probability * 100.0)
	var wipeout_str: String = " **[STACK WIPED OUT]**" if is_wipeout else ""
	return """### Battle Result: %s
**Victor**: %s%s
* **Attacker Win Chance**: %s
* **Power Ratio**: %.2f:1
* **Attacker Power**: %.0f | **Defender Power**: %.0f
* **Attacker Losses**: %d / %d models (%d units eliminated)
* **Defender Losses**: %d / %d models (%d units eliminated)

> %s""" % [
		outcome_classification,
		victor_side,
		wipeout_str,
		win_pct_str,
		power_ratio,
		attacker_power,
		defender_power,
		attacker_casualties_count,
		attacker_initial_models,
		attacker_destroyed_units.size(),
		defender_casualties_count,
		defender_initial_models,
		defender_destroyed_units.size(),
		battle_summary
	]
