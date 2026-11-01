class_name FactionData
extends Resource

@export_group("Identity")
@export var faction_id: String = ""
@export var faction_name: String = ""
@export var faction_color: Color = Color(0.8, 0.2, 0.2, 1.0)
@export var is_player: bool = false

@export_group("Economy & Treasury")
@export var treasury: int = 1000
@export var total_income: int = 0
@export var total_upkeep: int = 0

## Updates treasury based on current projected income and army upkeeps.
func process_turn_finances() -> int:
	var net_gain: int = total_income - total_upkeep
	treasury = clampi(treasury + net_gain, 0, 9999999)
	return net_gain

func can_afford(cost: int) -> bool:
	return treasury >= cost

func deduct_treasury(cost: int) -> bool:
	if can_afford(cost):
		treasury -= cost
		return true
	return false

func add_treasury(amount: int) -> void:
	treasury += maxi(amount, 0)
