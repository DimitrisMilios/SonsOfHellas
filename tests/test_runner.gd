extends SceneTree

const TestUnitData = preload("res://tests/test_unit_data.gd")
const TestBuildingData = preload("res://tests/test_building_data.gd")
const TestProvinceData = preload("res://tests/test_province_data.gd")
const TestFactionData = preload("res://tests/test_faction_data.gd")
const TestArmyData = preload("res://tests/test_army_data.gd")
const TestDataRegistry = preload("res://tests/test_data_registry.gd")
const TestEconomyCalculator = preload("res://tests/test_economy_calculator.gd")
const TestBattleResult = preload("res://tests/test_battle_result.gd")
const TestAutoResolveEngine = preload("res://tests/test_autoresolve_engine.gd")
const TestMovementEngine = preload("res://tests/test_movement_engine.gd")
const TestTurnPipeline = preload("res://tests/test_turn_pipeline.gd")
const TestCampaignAI = preload("res://tests/test_campaign_ai.gd")
const TestTurnManager = preload("res://tests/test_turn_manager.gd")
const TestSaveManager = preload("res://tests/test_save_manager.gd")

func _init() -> void:
	print("\n==========================================")
	print("       SONS OF HELLAS - UNIT TEST RUNNER   ")
	print("==========================================\n")
	
	var total_failures: int = 0
	
	print("[RUNNING] TestUnitData...")
	var unit_failures: Array[String] = TestUnitData.run_all_tests()
	if unit_failures.is_empty():
		print("  -> PASSED: TestUnitData")
	else:
		total_failures += unit_failures.size()
		print("  -> FAILED: TestUnitData (%d errors)" % unit_failures.size())
		for f: String in unit_failures:
			print("     * " + f)

	print("[RUNNING] TestBuildingData...")
	var bld_failures: Array[String] = TestBuildingData.run_all_tests()
	if bld_failures.is_empty():
		print("  -> PASSED: TestBuildingData")
	else:
		total_failures += bld_failures.size()
		print("  -> FAILED: TestBuildingData (%d errors)" % bld_failures.size())
		for f: String in bld_failures:
			print("     * " + f)

	print("[RUNNING] TestProvinceData...")
	var prov_failures: Array[String] = TestProvinceData.run_all_tests()
	if prov_failures.is_empty():
		print("  -> PASSED: TestProvinceData")
	else:
		total_failures += prov_failures.size()
		print("  -> FAILED: TestProvinceData (%d errors)" % prov_failures.size())
		for f: String in prov_failures:
			print("     * " + f)

	print("[RUNNING] TestFactionData...")
	var fac_failures: Array[String] = TestFactionData.run_all_tests()
	if fac_failures.is_empty():
		print("  -> PASSED: TestFactionData")
	else:
		total_failures += fac_failures.size()
		print("  -> FAILED: TestFactionData (%d errors)" % fac_failures.size())
		for f: String in fac_failures:
			print("     * " + f)

	print("[RUNNING] TestArmyData...")
	var army_failures: Array[String] = TestArmyData.run_all_tests()
	if army_failures.is_empty():
		print("  -> PASSED: TestArmyData")
	else:
		total_failures += army_failures.size()
		print("  -> FAILED: TestArmyData (%d errors)" % army_failures.size())
		for f: String in army_failures:
			print("     * " + f)

	print("[RUNNING] TestDataRegistry...")
	var reg_failures: Array[String] = TestDataRegistry.run_all_tests()
	if reg_failures.is_empty():
		print("  -> PASSED: TestDataRegistry")
	else:
		total_failures += reg_failures.size()
		print("  -> FAILED: TestDataRegistry (%d errors)" % reg_failures.size())
		for f: String in reg_failures:
			print("     * " + f)

	print("[RUNNING] TestEconomyCalculator...")
	var econ_failures: Array[String] = TestEconomyCalculator.run_all_tests()
	if econ_failures.is_empty():
		print("  -> PASSED: TestEconomyCalculator")
	else:
		total_failures += econ_failures.size()
		print("  -> FAILED: TestEconomyCalculator (%d errors)" % econ_failures.size())
		for f: String in econ_failures:
			print("     * " + f)

	print("[RUNNING] TestBattleResult...")
	var battle_failures: Array[String] = TestBattleResult.run_all_tests()
	if battle_failures.is_empty():
		print("  -> PASSED: TestBattleResult")
	else:
		total_failures += battle_failures.size()
		print("  -> FAILED: TestBattleResult (%d errors)" % battle_failures.size())
		for f: String in battle_failures:
			print("     * " + f)

	print("[RUNNING] TestAutoResolveEngine...")
	var ar_failures: Array[String] = TestAutoResolveEngine.run_all_tests()
	if ar_failures.is_empty():
		print("  -> PASSED: TestAutoResolveEngine")
	else:
		total_failures += ar_failures.size()
		print("  -> FAILED: TestAutoResolveEngine (%d errors)" % ar_failures.size())
		for f: String in ar_failures:
			print("     * " + f)

	print("[RUNNING] TestMovementEngine...")
	var mov_failures: Array[String] = TestMovementEngine.run_all_tests()
	if mov_failures.is_empty():
		print("  -> PASSED: TestMovementEngine")
	else:
		total_failures += mov_failures.size()
		print("  -> FAILED: TestMovementEngine (%d errors)" % mov_failures.size())
		for f: String in mov_failures:
			print("     * " + f)

	print("[RUNNING] TestTurnPipeline...")
	var pipeline_failures: Array[String] = TestTurnPipeline.run_all_tests()
	if pipeline_failures.is_empty():
		print("  -> PASSED: TestTurnPipeline")
	else:
		total_failures += pipeline_failures.size()
		print("  -> FAILED: TestTurnPipeline (%d errors)" % pipeline_failures.size())
		for f: String in pipeline_failures:
			print("     * " + f)

	print("[RUNNING] TestCampaignAI...")
	var ai_failures: Array[String] = TestCampaignAI.run_all_tests()
	if ai_failures.is_empty():
		print("  -> PASSED: TestCampaignAI")
	else:
		total_failures += ai_failures.size()
		print("  -> FAILED: TestCampaignAI (%d errors)" % ai_failures.size())
		for f: String in ai_failures:
			print("     * " + f)

	print("[RUNNING] TestTurnManager...")
	var tm_failures: Array[String] = TestTurnManager.run_all_tests()
	if tm_failures.is_empty():
		print("  -> PASSED: TestTurnManager")
	else:
		total_failures += tm_failures.size()
		print("  -> FAILED: TestTurnManager (%d errors)" % tm_failures.size())
		for f: String in tm_failures:
			print("     * " + f)

	print("[RUNNING] TestSaveManager...")
	var sm_failures: Array[String] = TestSaveManager.run_all_tests()
	if sm_failures.is_empty():
		print("  -> PASSED: TestSaveManager")
	else:
		total_failures += sm_failures.size()
		print("  -> FAILED: TestSaveManager (%d errors)" % sm_failures.size())
		for f: String in sm_failures:
			print("     * " + f)
			
	print("\n------------------------------------------")
	if total_failures == 0:
		print("ALL TESTS PASSED!")
		quit(0)
	else:
		print("TEST SUITE FAILED with %d total errors." % total_failures)
		quit(1)
