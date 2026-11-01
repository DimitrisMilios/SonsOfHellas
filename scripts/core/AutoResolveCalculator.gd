class_name AutoResolveCalculator
extends RefCounted

## Backward-compatibility bridge delegating to the comprehensive AutoResolveEngine.
static func calculate_effective_combat_power(army: ArmyData, opponent_army: ArmyData = null, is_defending: bool = false) -> float:
	return AutoResolveEngine.calculate_army_combat_power(army, opponent_army, is_defending)

static func calculate_win_probability(attacker_power: float, defender_power: float) -> float:
	return AutoResolveEngine.calculate_win_probability(attacker_power, defender_power)

static func resolve_battle(attacker: ArmyData, defender: ArmyData, forced_roll: float = -1.0) -> BattleResult:
	return AutoResolveEngine.simulate_battle(attacker, defender, {}, forced_roll)
