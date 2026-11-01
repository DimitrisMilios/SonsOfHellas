class_name BattleResult
extends RefCounted

var attacker_army: ArmyData
var defender_army: ArmyData
var attacker_won: bool = false
var attacker_power: float = 0.0
var defender_power: float = 0.0
var attacker_win_probability: float = 0.5

var attacker_casualties_count: int = 0
var defender_casualties_count: int = 0

var attacker_survivors: Array[UnitData] = []
var defender_survivors: Array[UnitData] = []
var attacker_destroyed_units: Array[UnitData] = []
var defender_destroyed_units: Array[UnitData] = []

var battle_summary: String = ""

func get_log_message() -> String:
	var victor_side: String = "Attacker" if attacker_won else "Defender"
	var win_pct_str: String = "%.1f%%" % (attacker_win_probability * 100.0)
	return "[Battle Result] Victor: %s (Attacker Win Chance: %s)\nAttacker Power: %.0f | Defender Power: %.0f\nAttacker Lost Units: %d | Defender Lost Units: %d\nSummary: %s" % [
		victor_side,
		win_pct_str,
		attacker_power,
		defender_power,
		attacker_destroyed_units.size(),
		defender_destroyed_units.size(),
		battle_summary
	]
