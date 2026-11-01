class_name TestSaveResilience
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_corrupt_main_fallback_to_tmp(failures)
	test_corrupt_main_and_tmp_fallback_to_bak(failures)
	test_missing_main_fallback_to_bak(failures)
	test_stale_tmp_cleanup_after_load(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func _create_valid_envelope_text(turn_val: int = 1) -> String:
	var env: Dictionary = {
		"save_version": 2,
		"game_version": "1.0.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"checksum": "valid_hash",
		"payload": {
			"current_turn": turn_val,
			"campaign_seed": 1337,
			"turn_committed": false,
			"factions": [{
				"faction_id": "sparta",
				"faction_name": "Sparta",
				"is_player": true,
				"treasury": 1000,
				"food_balance": 5
			}],
			"provinces": [{
				"province_id": "prov_sparta",
				"province_name": "Sparta",
				"owner_faction_id": "sparta",
				"settlement_level": 3,
				"region_wealth": 1500.0,
				"public_order": 50.0
			}],
			"armies": []
		}
	}
	return JSON.stringify(env, "  ")

static func test_corrupt_main_fallback_to_tmp(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/SaveManager.gd") as GDScript
	var mgr: Node = script.new()
	var slot: String = "test_slot_tmp_fallback"
	
	var main_path: String = mgr.get_save_file_path(slot)
	var tmp_path: String = mgr.get_save_tmp_path(slot)
	var bak_path: String = mgr.get_save_backup_path(slot)
	
	# Clean any old test artifacts
	for p: String in [main_path, tmp_path, bak_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# Write corrupted main
	var f_main: FileAccess = FileAccess.open(main_path, FileAccess.WRITE)
	f_main.store_string("{ corrupted JSON broken ...")
	f_main.close()
	
	# Write valid tmp
	var f_tmp: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	f_tmp.store_string(_create_valid_envelope_text(5))
	f_tmp.close()
	
	# Load envelope
	var envelope: Dictionary = mgr.read_save_envelope(slot)
	_assert(not envelope.is_empty(), "Should recover envelope from valid .tmp when main is corrupt", failures)
	if not envelope.is_empty():
		var payload: Dictionary = envelope.get("payload", {})
		_assert(payload.get("current_turn") == 5, "Should read turn 5 from .tmp, got: %s" % str(payload.get("current_turn")), failures)
	
	# Clean up
	for p: String in [main_path, tmp_path, bak_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	mgr.free()

static func test_corrupt_main_and_tmp_fallback_to_bak(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/SaveManager.gd") as GDScript
	var mgr: Node = script.new()
	var slot: String = "test_slot_bak_fallback"
	
	var main_path: String = mgr.get_save_file_path(slot)
	var tmp_path: String = mgr.get_save_tmp_path(slot)
	var bak_path: String = mgr.get_save_backup_path(slot)
	
	for p: String in [main_path, tmp_path, bak_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# Write corrupted main & corrupted tmp
	var f_main: FileAccess = FileAccess.open(main_path, FileAccess.WRITE)
	f_main.store_string("CORRUPT")
	f_main.close()
	
	var f_tmp: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	f_tmp.store_string("CORRUPT_TMP")
	f_tmp.close()
	
	# Write valid bak
	var f_bak: FileAccess = FileAccess.open(bak_path, FileAccess.WRITE)
	f_bak.store_string(_create_valid_envelope_text(4))
	f_bak.close()
	
	var envelope: Dictionary = mgr.read_save_envelope(slot)
	_assert(not envelope.is_empty(), "Should recover envelope from .bak when main and tmp are corrupt", failures)
	if not envelope.is_empty():
		var payload: Dictionary = envelope.get("payload", {})
		_assert(payload.get("current_turn") == 4, "Should read turn 4 from .bak", failures)
		
	for p: String in [main_path, tmp_path, bak_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	mgr.free()

static func test_missing_main_fallback_to_bak(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/SaveManager.gd") as GDScript
	var mgr: Node = script.new()
	var slot: String = "test_slot_missing_main"
	
	var main_path: String = mgr.get_save_file_path(slot)
	var tmp_path: String = mgr.get_save_tmp_path(slot)
	var bak_path: String = mgr.get_save_backup_path(slot)
	
	for p: String in [main_path, tmp_path, bak_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# No main file (missing), no tmp, valid bak exists
	var f_bak: FileAccess = FileAccess.open(bak_path, FileAccess.WRITE)
	f_bak.store_string(_create_valid_envelope_text(3))
	f_bak.close()
	
	var envelope: Dictionary = mgr.read_save_envelope(slot)
	_assert(not envelope.is_empty(), "Should recover from .bak when main file is missing", failures)
	if not envelope.is_empty():
		var payload: Dictionary = envelope.get("payload", {})
		_assert(payload.get("current_turn") == 3, "Should read turn 3 from .bak", failures)
		
	for p: String in [main_path, tmp_path, bak_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	mgr.free()

static func test_stale_tmp_cleanup_after_load(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/SaveManager.gd") as GDScript
	var mgr: Node = script.new()
	var slot: String = "test_slot_stale_tmp"
	
	var main_path: String = mgr.get_save_file_path(slot)
	var tmp_path: String = mgr.get_save_tmp_path(slot)
	
	var f_main: FileAccess = FileAccess.open(main_path, FileAccess.WRITE)
	f_main.store_string(_create_valid_envelope_text(2))
	f_main.close()
	
	var f_tmp: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	f_tmp.store_string("OLD_STALE_TEMP")
	f_tmp.close()
	
	# Performing load should clean up stale tmp
	mgr.load_game(slot)
	_assert(not FileAccess.file_exists(tmp_path), "Stale .tmp file should be pruned after load_game", failures)
	
	if FileAccess.file_exists(main_path):
		DirAccess.remove_absolute(main_path)
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	mgr.free()
