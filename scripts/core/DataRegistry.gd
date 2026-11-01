class_name DataRegistry
extends RefCounted

static var _units: Dictionary = {}
static var _buildings: Dictionary = {}

## Registers a unit prototype in the registry.
static func register_unit(unit: UnitData) -> void:
	if unit != null and unit.unit_id != "":
		_units[unit.unit_id] = unit

## Retrieves an isolated clone of a registered unit prototype by ID.
static func get_unit(unit_id: String) -> UnitData:
	if _units.has(unit_id):
		var proto: UnitData = _units[unit_id]
		return proto.clone()
	return null

## Checks whether a unit prototype exists in the registry.
static func has_unit(unit_id: String) -> bool:
	return _units.has(unit_id)

## Registers a building prototype in the registry.
static func register_building(building: BuildingData) -> void:
	if building != null and building.building_id != "":
		_buildings[building.building_id] = building

## Retrieves an isolated clone of a registered building prototype by ID.
static func get_building(building_id: String) -> BuildingData:
	if _buildings.has(building_id):
		var proto: BuildingData = _buildings[building_id]
		return proto.clone()
	return null

## Checks whether a building prototype exists in the registry.
static func has_building(building_id: String) -> bool:
	return _buildings.has(building_id)

## Scans resources directory and registers all default .tres assets.
static func load_all_resources() -> void:
	_scan_and_load("res://resources/units/", func(res: Resource) -> void:
		if res is UnitData:
			register_unit(res as UnitData)
	)
	_scan_and_load("res://resources/buildings/", func(res: Resource) -> void:
		if res is BuildingData:
			register_building(res as BuildingData)
	)

static func _scan_and_load(dir_path: String, callback: Callable) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = dir_path + file_name
			var res: Resource = load(full_path)
			if res != null:
				callback.call(res)
		file_name = dir.get_next()
	dir.list_dir_end()

## Clears registry in-memory caches.
static func clear() -> void:
	_units.clear()
	_buildings.clear()
