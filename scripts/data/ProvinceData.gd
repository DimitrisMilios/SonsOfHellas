class_name ProvinceData
extends Resource

@export_group("Identity")
@export var province_id: String = ""
@export var province_name: String = ""
@export var owner_faction_id: String = ""
@export var map_position: Vector2 = Vector2.ZERO
@export var adjacent_province_ids: Array[String] = []

@export_group("Settlement & Infrastructure")
@export_range(1, 5, 1) var settlement_level: int = 1:
	set(value):
		settlement_level = clampi(value, 1, 5)
		settlement_tier = settlement_level
		_ensure_slot_capacity()
@export_range(1, 5, 1) var settlement_tier: int = 1 # Legacy compatibility
@export var building_slots: Array = []:
	set(value):
		building_slots.clear()
		for item in value:
			if item is BuildingSlotData:
				building_slots.append(item)
			elif item is BuildingData:
				var slot: BuildingSlotData = BuildingSlotData.new()
				slot.slot_index = building_slots.size()
				slot.building_data = item
				building_slots.append(slot)
		_ensure_slot_capacity()
@export var garrison_units: Array[UnitData] = []

@export_group("Economy & Wealth")
@export_range(0.0, 100000.0, 50.0) var region_wealth: float = 1000.0
@export_range(1, 5, 1) var tax_level_upper: int = 3
@export_range(1, 5, 1) var tax_level_lower: int = 3
@export var tax_exemption_status: bool = false
@export var population_surplus: int = 0
@export var base_tax: float = 100.0 # Legacy compatibility
@export var growth_rate: float = 5.0 # Legacy compatibility
@export var current_population: int = 1000 # Legacy compatibility
@export var growth_points_accumulated: float = 0.0 # Legacy compatibility
@export var growth_threshold_for_upgrade: float = 100.0 # Legacy compatibility
@export_range(1, 8, 1) var max_building_slots: int = 3 # Legacy compatibility

@export_group("Social & Public Order")
@export_range(-100.0, 100.0, 1.0) var public_order: float = 100.0
@export var consecutive_unrest_turns: int = 0
@export var resistance_to_occupation_decay: int = 0
@export_range(-20.0, 20.0, 0.5) var public_order_trend: float = 0.0 # Legacy compatibility

func _init() -> void:
	_ensure_slot_capacity()

## Ensures building slots array matches settlement level (Level 1 = 1 slot ... Level 5 = 5 slots).
func _ensure_slot_capacity() -> void:
	var target_slots: int = clampi(settlement_level, 1, 5)
	while building_slots.size() < target_slots:
		var slot: BuildingSlotData = BuildingSlotData.new()
		slot.slot_index = building_slots.size()
		building_slots.append(slot)
	while building_slots.size() > target_slots:
		building_slots.pop_back()

func set_settlement_level(new_level: int) -> void:
	settlement_level = new_level

func can_add_building() -> bool:
	for slot: BuildingSlotData in building_slots:
		if slot != null and slot.building_data == null and not slot.is_under_construction:
			return true
	return false

func get_empty_slot() -> BuildingSlotData:
	for slot: BuildingSlotData in building_slots:
		if slot != null and slot.building_data == null and not slot.is_under_construction:
			return slot
	return null

func add_building(building: BuildingData) -> bool:
	var slot: BuildingSlotData = get_empty_slot()
	if slot != null and building != null:
		slot.building_data = building
		return true
	return false

func queue_building_construction(building: BuildingData) -> bool:
	var slot: BuildingSlotData = get_empty_slot()
	if slot != null and building != null:
		slot.queue_construction(building)
		return true
	return false

func add_garrison_unit(unit: UnitData) -> void:
	if unit != null:
		garrison_units.append(unit)

func remove_garrison_unit(unit: UnitData) -> void:
	garrison_units.erase(unit)

func set_tax_levels(upper: int, lower: int) -> void:
	tax_level_upper = clampi(upper, 1, 5)
	tax_level_lower = clampi(lower, 1, 5)

func set_tax_exemption(exempt: bool) -> void:
	tax_exemption_status = exempt

## Updates consecutive unrest counter based on current public order.
## Rule: 2 consecutive turns of PO < 0 triggers armed rebellion.
func update_unrest_counter() -> void:
	if public_order < 0.0:
		consecutive_unrest_turns += 1
	else:
		consecutive_unrest_turns = 0

func is_adjacent_to(target_id: String) -> bool:
	return adjacent_province_ids.has(target_id)

## Legacy calculation helper
func calculate_total_tax() -> float:
	var total: float = base_tax
	for slot: BuildingSlotData in building_slots:
		if slot != null and slot.building_data != null:
			total += slot.building_data.tax_bonus
	return total

## Legacy calculation helper
func calculate_public_order_delta() -> float:
	var delta: float = public_order_trend
	for slot: BuildingSlotData in building_slots:
		if slot != null and slot.building_data != null:
			delta += slot.building_data.public_order_bonus
	return delta

## Legacy turn progression helper
func process_turn_progression() -> void:
	public_order = clampf(public_order + calculate_public_order_delta(), -100.0, 100.0)
	update_unrest_counter()
	var net_growth: float = growth_rate
	for slot: BuildingSlotData in building_slots:
		if slot != null and slot.building_data != null:
			net_growth += slot.building_data.growth_bonus
	growth_points_accumulated += net_growth

## Creates an isolated clone of this province.
func clone() -> ProvinceData:
	var copy: ProvinceData = ProvinceData.new()
	copy.province_id = province_id
	copy.province_name = province_name
	copy.owner_faction_id = owner_faction_id
	copy.map_position = map_position
	copy.adjacent_province_ids = adjacent_province_ids.duplicate()
	copy.settlement_level = settlement_level
	copy.settlement_tier = settlement_tier
	copy.region_wealth = region_wealth
	copy.tax_level_upper = tax_level_upper
	copy.tax_level_lower = tax_level_lower
	copy.tax_exemption_status = tax_exemption_status
	copy.population_surplus = population_surplus
	copy.public_order = public_order
	copy.consecutive_unrest_turns = consecutive_unrest_turns
	copy.resistance_to_occupation_decay = resistance_to_occupation_decay
	
	copy.building_slots.clear()
	for slot: BuildingSlotData in building_slots:
		if slot != null:
			var slot_copy: BuildingSlotData = BuildingSlotData.new()
			slot_copy.slot_index = slot.slot_index
			slot_copy.is_under_construction = slot.is_under_construction
			slot_copy.remaining_construction_turns = slot.remaining_construction_turns
			slot_copy.building_data = slot.building_data.clone() if slot.building_data != null else null
			slot_copy.target_building_to_construct = slot.target_building_to_construct.clone() if slot.target_building_to_construct != null else null
			copy.building_slots.append(slot_copy)
			
	copy.garrison_units.clear()
	for g_unit: UnitData in garrison_units:
		if g_unit != null:
			copy.garrison_units.append(g_unit.clone())
			
	return copy

## Serializes province to dictionary matching Settlement schema.
func to_dict() -> Dictionary:
	var slots_data: Array[Dictionary] = []
	for slot: BuildingSlotData in building_slots:
		if slot != null:
			slots_data.append(slot.to_dict())
			
	var garrisons_data: Array[Dictionary] = []
	for u: UnitData in garrison_units:
		if u != null:
			garrisons_data.append({
				"unit_card_id": u.unit_id,
				"current_unit_count": u.unit_count,
				"experience_chevrons": u.veterancy_rank,
				"is_building_garrison": u.is_building_garrison
			})
			
	return {
		"id": province_id,
		"name": province_name,
		"province_id": province_id,
		"owner_faction_id": owner_faction_id,
		"coordinates": {
			"x": map_position.x,
			"y": map_position.y
		},
		"level": settlement_level,
		"building_slots_array": slots_data,
		"active_garrison_array": garrisons_data,
		"public_order_value": roundi(public_order),
		"region_wealth": region_wealth,
		"population_surplus": population_surplus,
		"tax_exemption_status": tax_exemption_status,
		"consecutive_unrest_turns": consecutive_unrest_turns,
		"resistance_to_occupation_decay": resistance_to_occupation_decay,
		"tax_level_upper": tax_level_upper,
		"tax_level_lower": tax_level_lower,
		"adjacent_province_ids": adjacent_province_ids.duplicate()
	}

## Deserializes dictionary to ProvinceData instance.
static func from_dict(dict: Dictionary) -> ProvinceData:
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = dict.get("id", dict.get("province_id", ""))
	prov.province_name = dict.get("name", "")
	prov.owner_faction_id = dict.get("owner_faction_id", "")
	
	var coords: Dictionary = dict.get("coordinates", {})
	if not coords.is_empty():
		prov.map_position = Vector2(float(coords.get("x", 0.0)), float(coords.get("y", 0.0)))
		
	prov.settlement_level = dict.get("level", dict.get("settlement_tier", 1))
	prov.region_wealth = float(dict.get("region_wealth", 1000.0))
	prov.public_order = float(dict.get("public_order_value", dict.get("public_order", 100.0)))
	prov.population_surplus = dict.get("population_surplus", 0)
	prov.tax_exemption_status = dict.get("tax_exemption_status", false)
	prov.consecutive_unrest_turns = dict.get("consecutive_unrest_turns", 0)
	prov.resistance_to_occupation_decay = dict.get("resistance_to_occupation_decay", 0)
	prov.tax_level_upper = dict.get("tax_level_upper", 3)
	prov.tax_level_lower = dict.get("tax_level_lower", 3)
	
	var adj_ids: Array = dict.get("adjacent_province_ids", [])
	prov.adjacent_province_ids.clear()
	for aid: Variant in adj_ids:
		prov.adjacent_province_ids.append(str(aid))
		
	var slots_raw: Array = dict.get("building_slots_array", [])
	if not slots_raw.is_empty():
		prov.building_slots.clear()
		for s_dict: Variant in slots_raw:
			if s_dict is Dictionary:
				var slot: BuildingSlotData = BuildingSlotData.from_dict(s_dict)
				var bld_id: Variant = s_dict.get("building_node_id")
				if bld_id != null and str(bld_id) != "":
					var bld: BuildingData = BuildingData.new()
					bld.building_id = str(bld_id)
					if slot.is_under_construction:
						slot.target_building_to_construct = bld
					else:
						slot.building_data = bld
				prov.building_slots.append(slot)
				
	var garrisons_raw: Array = dict.get("active_garrison_array", [])
	prov.garrison_units.clear()
	for g_dict: Variant in garrisons_raw:
		if g_dict is Dictionary:
			var unit: UnitData = UnitData.new()
			unit.unit_id = str(g_dict.get("unit_card_id", ""))
			unit.unit_count = int(g_dict.get("current_unit_count", 0))
			unit.veterancy_rank = int(g_dict.get("experience_chevrons", 0))
			unit.is_building_garrison = bool(g_dict.get("is_building_garrison", false))
			prov.garrison_units.append(unit)
			
	return prov
