class_name FactionData
extends Resource

@export_group("Identity")
@export var faction_id: String = ""
@export var faction_name: String = ""
@export var faction_color: Color = Color(0.8, 0.2, 0.2, 1.0)
@export var is_player: bool = false

@export_group("Treasury & Revenue")
@export var treasury: int = 1000
@export var base_purse: int = 3000 # Default national King's Purse constant
@export var trade_income: int = 0
@export var tribute_income: int = 0
@export var raiding_income: int = 0
@export var total_income: int = 0
@export var total_upkeep: int = 0

@export_group("Empire Policy & Resources")
@export_range(1, 5, 1) var default_tax_level_upper: int = 3
@export_range(1, 5, 1) var default_tax_level_lower: int = 3
@export var held_province_ids: Array[String] = []
@export var food_balance: int = 0 # Global clan food balance (F_net)

@export_group("Bankruptcy State")
@export var is_bankrupt: bool = false
@export var capital_stagnation_turns: int = 0

func can_afford(cost: int) -> bool:
	return cost >= 0 and treasury >= cost

func deduct_treasury(cost: int, force_bankruptcy: bool = false) -> bool:
	if cost < 0:
		return false
	if can_afford(cost):
		treasury -= cost
		return true
	elif force_bankruptcy:
		treasury = 0
		set_bankrupt(true)
		return false
	return false

func add_treasury(amount: int) -> void:
	if amount > 0:
		treasury += amount

## Calculates total clan net food balance across all held provinces.
func calculate_net_food_balance(provinces: Array) -> int:
	var total_food: int = 0
	for p_variant: Variant in provinces:
		if p_variant is ProvinceData:
			var prov: ProvinceData = p_variant
			if prov.owner_faction_id == faction_id or held_province_ids.has(prov.province_id):
				for slot: BuildingSlotData in prov.building_slots:
					if slot != null and slot.building_data != null and not slot.is_under_construction:
						total_food += slot.building_data.get_net_food_delta()
	food_balance = total_food
	return food_balance

## Toggles bankruptcy state and sets/clears capital economic stagnation penalties.
func set_bankrupt(bankrupt: bool) -> void:
	is_bankrupt = bankrupt
	if is_bankrupt:
		capital_stagnation_turns = 12 # 10-15 turns penalty per spec
	else:
		capital_stagnation_turns = 0

func get_held_regions_count() -> int:
	return held_province_ids.size()

## Updates treasury based on current projected income and army upkeeps (Legacy compatibility).
func process_turn_finances() -> int:
	var net_gain: int = total_income - total_upkeep
	treasury = clampi(treasury + net_gain, 0, 9999999)
	return net_gain

## Creates an isolated clone of this faction.
func clone() -> FactionData:
	var copy: FactionData = FactionData.new()
	copy.faction_id = faction_id
	copy.faction_name = faction_name
	copy.faction_color = faction_color
	copy.is_player = is_player
	copy.treasury = treasury
	copy.base_purse = base_purse
	copy.trade_income = trade_income
	copy.tribute_income = tribute_income
	copy.raiding_income = raiding_income
	copy.total_income = total_income
	copy.total_upkeep = total_upkeep
	copy.default_tax_level_upper = default_tax_level_upper
	copy.default_tax_level_lower = default_tax_level_lower
	copy.held_province_ids = held_province_ids.duplicate()
	copy.food_balance = food_balance
	copy.is_bankrupt = is_bankrupt
	copy.capital_stagnation_turns = capital_stagnation_turns
	return copy

## Serializes faction to dictionary.
func to_dict() -> Dictionary:
	return {
		"faction_id": faction_id,
		"faction_name": faction_name,
		"faction_color": faction_color.to_html(),
		"is_player": is_player,
		"treasury": treasury,
		"base_purse": base_purse,
		"trade_income": trade_income,
		"tribute_income": tribute_income,
		"raiding_income": raiding_income,
		"total_income": total_income,
		"total_upkeep": total_upkeep,
		"default_tax_level_upper": default_tax_level_upper,
		"default_tax_level_lower": default_tax_level_lower,
		"held_province_ids": held_province_ids.duplicate(),
		"food_balance": food_balance,
		"is_bankrupt": is_bankrupt,
		"capital_stagnation_turns": capital_stagnation_turns
	}

## Deserializes dictionary to FactionData instance.
static func from_dict(dict: Dictionary) -> FactionData:
	var f: FactionData = FactionData.new()
	f.faction_id = dict.get("faction_id", "")
	f.faction_name = dict.get("faction_name", "")
	var color_str: String = dict.get("faction_color", "")
	if color_str != "":
		f.faction_color = Color.from_string(color_str, Color.RED)
	f.is_player = dict.get("is_player", false)
	f.treasury = dict.get("treasury", 1000)
	f.base_purse = dict.get("base_purse", 3000)
	f.trade_income = dict.get("trade_income", 0)
	f.tribute_income = dict.get("tribute_income", 0)
	f.raiding_income = dict.get("raiding_income", 0)
	f.total_income = dict.get("total_income", 0)
	f.total_upkeep = dict.get("total_upkeep", 0)
	f.default_tax_level_upper = dict.get("default_tax_level_upper", 3)
	f.default_tax_level_lower = dict.get("default_tax_level_lower", 3)
	f.food_balance = dict.get("food_balance", 0)
	f.is_bankrupt = dict.get("is_bankrupt", false)
	f.capital_stagnation_turns = dict.get("capital_stagnation_turns", 0)
	
	var prov_ids: Array = dict.get("held_province_ids", [])
	f.held_province_ids.clear()
	for pid: Variant in prov_ids:
		f.held_province_ids.append(str(pid))
		
	return f
