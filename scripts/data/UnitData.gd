class_name UnitData
extends Resource

enum RoleTag {
	INFANTRY_SPEAR,
	INFANTRY_SWORD,
	CAVALRY_LIGHT,
	CAVALRY_HEAVY,
	MISSILE_BOW,
	MISSILE_SKIRMISHER,
	ARTILLERY,
	HERO_UNIT
}

enum AmmoType {
	NONE,
	STANDARD_ARROW,
	FIRE_ARROW,
	JAVELIN,
	SLING_STONE,
	MATCHLOCK_BULLET,
	CANNON_BALL,
	SHRAPNEL
}

## Legacy role enum for backward compatibility with existing scenes.
enum Role {
	HOPLITE,
	CAVALRY,
	RANGED,
	SKIRMISHER
}

@export_group("Identity")
@export var unit_id: String = ""
@export var display_name: String = ""
@export_range(1, 5, 1) var tier: int = 1
@export var role_tags: Array[RoleTag] = [RoleTag.INFANTRY_SPEAR]
@export var role: Role = Role.HOPLITE

@export_group("Economy")
@export_range(0, 5000, 10) var recruitment_cost: int = 150
@export_range(0, 1000, 5) var upkeep_cost: int = 30
@export_range(0, 1000, 5) var turn_upkeep: int = 30 # Backward compatibility
@export_range(1, 5, 1) var recruitment_turn_time: int = 1

@export_group("Combat Stats")
@export_range(1, 300, 1) var unit_count: int = 120
@export_range(0, 100, 1) var melee_attack: int = 10
@export_range(0, 100, 1) var melee_defense: int = 10
@export_range(0, 100, 1) var armor: int = 20
@export_range(0, 100, 1) var charge_bonus: int = 5

@export_group("Ranged Stats")
@export_range(0, 100, 1) var missile_accuracy: int = 0
@export_range(0, 100, 1) var reload_speed: int = 0
@export_range(0, 300, 5) var missile_range: int = 0
@export var ammo_type: AmmoType = AmmoType.NONE
@export_range(0, 50, 1) var ammo_capacity: int = 0

@export_group("Morale & Physical")
@export_range(1, 50, 1) var morale: int = 10
@export_range(10, 200, 5) var fatigue_max: int = 100
@export_range(0.5, 5.0, 0.1) var mass: float = 1.0
@export_range(0, 9, 1) var veterancy_rank: int = 0

@export_group("Garrison State")
@export var is_building_garrison: bool = false
@export_range(10.0, 500.0, 5.0) var base_strength: float = 100.0 # Backward compatibility

## Calculates raw unit combat power using the comprehensive design formulas.
func get_combat_value() -> float:
	var s_melee: float = float(melee_attack) + (0.6 * float(melee_defense)) + (0.5 * float(armor)) + (0.4 * float(charge_bonus))
	
	var s_missile: float = 0.0
	if missile_range > 0 and ammo_capacity > 0:
		var ap_factor: float = 1.0 if ammo_type == AmmoType.MATCHLOCK_BULLET else 0.0
		var r_base: float = 100.0
		var base_dmg: float = 15.0 # Baseline projectile damage
		var ammo_mod: float = minf(1.0, float(ammo_capacity) / 15.0)
		s_missile = ((float(missile_accuracy) * float(reload_speed) * base_dmg * (1.0 + ap_factor)) / 100.0) * (float(missile_range) / r_base) * ammo_mod
	
	var v_rank: float = 1.0 + (0.05 * float(veterancy_rank))
	var total_power: float = float(unit_count) * (s_melee + s_missile) * v_rank
	return maxf(total_power, 1.0)

## Creates an isolated deep clone for instantiating unique units in armies/garrisons.
func clone() -> UnitData:
	var copy: UnitData = UnitData.new()
	copy.unit_id = unit_id
	copy.display_name = display_name
	copy.tier = tier
	copy.role_tags = role_tags.duplicate()
	copy.role = role
	copy.recruitment_cost = recruitment_cost
	copy.upkeep_cost = upkeep_cost
	copy.turn_upkeep = turn_upkeep
	copy.recruitment_turn_time = recruitment_turn_time
	copy.unit_count = unit_count
	copy.melee_attack = melee_attack
	copy.melee_defense = melee_defense
	copy.armor = armor
	copy.charge_bonus = charge_bonus
	copy.missile_accuracy = missile_accuracy
	copy.reload_speed = reload_speed
	copy.missile_range = missile_range
	copy.ammo_type = ammo_type
	copy.ammo_capacity = ammo_capacity
	copy.morale = morale
	copy.fatigue_max = fatigue_max
	copy.mass = mass
	copy.veterancy_rank = veterancy_rank
	copy.is_building_garrison = is_building_garrison
	copy.base_strength = base_strength
	return copy

## Deep clone alias for backward compatibility.
func duplicate_unit() -> UnitData:
	return clone()

## Serializes unit to dictionary matching docs/design/data_schemas.md.
func to_dict() -> Dictionary:
	var tag_strings: Array[String] = []
	for tag: RoleTag in role_tags:
		tag_strings.append(role_tag_to_string(tag))
		
	return {
		"id": unit_id,
		"name": display_name,
		"recruitment_cost": recruitment_cost,
		"upkeep_cost": upkeep_cost if upkeep_cost > 0 else turn_upkeep,
		"recruitment_turn_time": recruitment_turn_time,
		"tier": tier,
		"stats": {
			"unit_count": unit_count,
			"melee_attack": melee_attack,
			"melee_defense": melee_defense,
			"armor": armor,
			"charge_bonus": charge_bonus,
			"missile_accuracy": missile_accuracy,
			"reload_speed": reload_speed,
			"missile_range": missile_range,
			"ammo_type": ammo_type_to_string(ammo_type),
			"ammo_capacity": ammo_capacity,
			"morale": morale,
			"fatigue_max": fatigue_max,
			"mass": mass,
			"veterancy_rank": veterancy_rank
		},
		"role_tags": tag_strings,
		"is_building_garrison": is_building_garrison
	}

## Deserializes dictionary to UnitData instance.
static func from_dict(data: Dictionary) -> UnitData:
	var unit: UnitData = UnitData.new()
	unit.unit_id = data.get("id", "")
	unit.display_name = data.get("name", "")
	unit.recruitment_cost = data.get("recruitment_cost", 150)
	unit.upkeep_cost = data.get("upkeep_cost", 30)
	unit.turn_upkeep = unit.upkeep_cost
	unit.recruitment_turn_time = data.get("recruitment_turn_time", 1)
	unit.tier = data.get("tier", 1)
	unit.is_building_garrison = data.get("is_building_garrison", false)
	
	var stats: Dictionary = data.get("stats", {})
	if not stats.is_empty():
		unit.unit_count = stats.get("unit_count", 120)
		unit.melee_attack = stats.get("melee_attack", 10)
		unit.melee_defense = stats.get("melee_defense", 10)
		unit.armor = stats.get("armor", 20)
		unit.charge_bonus = stats.get("charge_bonus", 5)
		unit.missile_accuracy = stats.get("missile_accuracy", 0)
		unit.reload_speed = stats.get("reload_speed", 0)
		unit.missile_range = stats.get("missile_range", 0)
		unit.ammo_type = string_to_ammo_type(stats.get("ammo_type", "NONE"))
		unit.ammo_capacity = stats.get("ammo_capacity", 0)
		unit.morale = stats.get("morale", 10)
		unit.fatigue_max = stats.get("fatigue_max", 100)
		unit.mass = float(stats.get("mass", 1.0))
		unit.veterancy_rank = stats.get("veterancy_rank", 0)
		
	var tags_raw: Array = data.get("role_tags", [])
	unit.role_tags.clear()
	for tag_str: Variant in tags_raw:
		unit.role_tags.append(string_to_role_tag(str(tag_str)))
	if unit.role_tags.is_empty():
		unit.role_tags.append(RoleTag.INFANTRY_SPEAR)
		
	return unit

static func role_tag_to_string(tag: RoleTag) -> String:
	match tag:
		RoleTag.INFANTRY_SPEAR: return "INFANTRY_SPEAR"
		RoleTag.INFANTRY_SWORD: return "INFANTRY_KATANA" # Matching schema role
		RoleTag.CAVALRY_LIGHT: return "CAVALRY_LIGHT"
		RoleTag.CAVALRY_HEAVY: return "CAVALRY_HEAVY"
		RoleTag.MISSILE_BOW: return "MISSILE_BOW"
		RoleTag.MISSILE_SKIRMISHER: return "MISSILE_MATCHLOCK"
		RoleTag.ARTILLERY: return "ARTILLERY"
		RoleTag.HERO_UNIT: return "HERO_UNIT"
		_: return "INFANTRY_SPEAR"

static func string_to_role_tag(s: String) -> RoleTag:
	match s:
		"INFANTRY_SPEAR": return RoleTag.INFANTRY_SPEAR
		"INFANTRY_KATANA", "INFANTRY_SWORD": return RoleTag.INFANTRY_SWORD
		"CAVALRY_LIGHT": return RoleTag.CAVALRY_LIGHT
		"CAVALRY_HEAVY": return RoleTag.CAVALRY_HEAVY
		"MISSILE_BOW": return RoleTag.MISSILE_BOW
		"MISSILE_MATCHLOCK", "MISSILE_SKIRMISHER": return RoleTag.MISSILE_SKIRMISHER
		"ARTILLERY": return RoleTag.ARTILLERY
		"HERO_UNIT": return RoleTag.HERO_UNIT
		_: return RoleTag.INFANTRY_SPEAR

static func ammo_type_to_string(ammo: AmmoType) -> String:
	match ammo:
		AmmoType.STANDARD_ARROW: return "STANDARD_ARROW"
		AmmoType.FIRE_ARROW: return "FIRE_ARROW"
		AmmoType.JAVELIN: return "JAVELIN"
		AmmoType.SLING_STONE: return "SLING_STONE"
		AmmoType.MATCHLOCK_BULLET: return "MATCHLOCK_BULLET"
		AmmoType.CANNON_BALL: return "CANNON_BALL"
		AmmoType.SHRAPNEL: return "SHRAPNEL"
		_: return "NONE"

static func string_to_ammo_type(s: String) -> AmmoType:
	match s:
		"STANDARD_ARROW": return AmmoType.STANDARD_ARROW
		"FIRE_ARROW": return AmmoType.FIRE_ARROW
		"JAVELIN": return AmmoType.JAVELIN
		"SLING_STONE": return AmmoType.SLING_STONE
		"MATCHLOCK_BULLET": return AmmoType.MATCHLOCK_BULLET
		"CANNON_BALL": return AmmoType.CANNON_BALL
		"SHRAPNEL": return AmmoType.SHRAPNEL
		_: return AmmoType.NONE

func get_role_name() -> String:
	if not role_tags.is_empty():
		match role_tags[0]:
			RoleTag.INFANTRY_SPEAR: return "Spear Infantry"
			RoleTag.INFANTRY_SWORD: return "Sword Infantry"
			RoleTag.CAVALRY_LIGHT: return "Light Cavalry"
			RoleTag.CAVALRY_HEAVY: return "Heavy Cavalry"
			RoleTag.MISSILE_BOW: return "Bow / Missile"
			RoleTag.MISSILE_SKIRMISHER: return "Skirmisher"
			RoleTag.ARTILLERY: return "Artillery"
			RoleTag.HERO_UNIT: return "Hero Unit"
	return "Infantry"
