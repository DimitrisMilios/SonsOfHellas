class_name TestDataRegistry
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	_test_registry_registration_and_cloning(failures)
	_test_registry_missing_id_handling(failures)
	return failures

static func _test_registry_registration_and_cloning(failures: Array[String]) -> void:
	DataRegistry.clear()
	
	var prototype_unit: UnitData = UnitData.new()
	prototype_unit.unit_id = "test_spartan_guard"
	prototype_unit.display_name = "Spartan Guard"
	prototype_unit.unit_count = 100
	
	DataRegistry.register_unit(prototype_unit)
	if not DataRegistry.has_unit("test_spartan_guard"):
		failures.append("DataRegistry failed to register unit")
		
	# get_unit should return an isolated clone, not the original prototype reference
	var retrieved: UnitData = DataRegistry.get_unit("test_spartan_guard")
	if retrieved == null:
		failures.append("DataRegistry.get_unit returned null")
		return
	if retrieved == prototype_unit:
		failures.append("DataRegistry.get_unit returned original prototype reference instead of clone")
		
	retrieved.unit_count = 30
	if prototype_unit.unit_count != 100:
		failures.append("Mutating retrieved unit mutated prototype in registry")
		
	# Building registration
	var prototype_bld: BuildingData = BuildingData.new()
	prototype_bld.building_id = "test_agora"
	prototype_bld.display_name = "Agora"
	
	DataRegistry.register_building(prototype_bld)
	if not DataRegistry.has_building("test_agora"):
		failures.append("DataRegistry failed to register building")
		
	var retrieved_bld: BuildingData = DataRegistry.get_building("test_agora")
	if retrieved_bld == null or retrieved_bld == prototype_bld:
		failures.append("DataRegistry.get_building failed to return isolated clone")

static func _test_registry_missing_id_handling(failures: Array[String]) -> void:
	DataRegistry.clear()
	if DataRegistry.has_unit("non_existent_unit"):
		failures.append("DataRegistry.has_unit returned true for missing unit")
	if DataRegistry.get_unit("non_existent_unit") != null:
		failures.append("DataRegistry.get_unit should return null for missing unit")
