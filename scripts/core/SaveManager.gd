extends Node

## Lifecycle & persistence signals
signal game_saved(slot_name: String)
signal game_loaded(slot_name: String)
signal save_failed(reason: String)
signal load_failed(slot_name: String, reason: String)

const CURRENT_SAVE_VERSION: int = 2
const GAME_VERSION: String = "1.0.0"
const DEFAULT_SAVE_SLOT: String = "campaign_autosave"
const SAVE_DIR_PATH: String = "user://saves/"

@export var autosave_on_pause: bool = true
var is_loading: bool = false

func _ready() -> void:
	_ensure_save_directory_exists()

func _notification(what: int) -> void:
	# Mobile lifecycle: Save only when game is in IDLE state at turn boundaries
	if autosave_on_pause:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_attempt_background_autosave()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
			_attempt_background_autosave()

func _attempt_background_autosave() -> void:
	var turn_mgr: Node = get_node_or_null("/root/TurnManager")
	if turn_mgr != null and turn_mgr.has_method("can_accept_input"):
		if turn_mgr.can_accept_input():
			save_game(DEFAULT_SAVE_SLOT)

func _ensure_save_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR_PATH):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)

func get_save_file_path(slot_name: String) -> String:
	return "%s%s.json" % [SAVE_DIR_PATH, slot_name]

func get_save_backup_path(slot_name: String) -> String:
	return "%s%s.json.bak" % [SAVE_DIR_PATH, slot_name]

func get_save_tmp_path(slot_name: String) -> String:
	return "%s%s.json.tmp" % [SAVE_DIR_PATH, slot_name]

func has_save_file(slot_name: String = DEFAULT_SAVE_SLOT) -> bool:
	return FileAccess.file_exists(get_save_file_path(slot_name)) or FileAccess.file_exists(get_save_backup_path(slot_name))

## Serializes campaign entities into a versioned envelope without mutating models.
func serialize_campaign(
	factions: Array,
	provinces: Dictionary,
	armies: Array,
	turn: int,
	seed_val: int = 1337
) -> Dictionary:
	var factions_data: Array[Dictionary] = []
	for f: Variant in factions:
		if f is FactionData:
			factions_data.append(f.to_dict())
			
	var provinces_data: Array[Dictionary] = []
	for p: Variant in provinces.values():
		if p is ProvinceData:
			provinces_data.append(p.to_dict())
			
	var armies_data: Array[Dictionary] = []
	for a: Variant in armies:
		if a is ArmyData:
			armies_data.append(a.to_dict())
			
	var payload: Dictionary = {
		"current_turn": turn,
		"campaign_seed": seed_val,
		"factions": factions_data,
		"provinces": provinces_data,
		"armies": armies_data
	}
	
	return {
		"save_version": CURRENT_SAVE_VERSION,
		"game_version": GAME_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"payload": payload
	}

## Performs atomic write to .tmp, verifies JSON integrity, rotates .bak, and renames.
func write_save_atomic(slot_name: String, envelope: Dictionary) -> bool:
	_ensure_save_directory_exists()
	
	var main_path: String = get_save_file_path(slot_name)
	var bak_path: String = get_save_backup_path(slot_name)
	var tmp_path: String = get_save_tmp_path(slot_name)
	
	# 1. Write to .tmp
	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		var err_msg: String = "Failed to open tmp save file for writing: %s" % tmp_path
		push_error(err_msg)
		save_failed.emit(err_msg)
		return false
		
	var json_string: String = JSON.stringify(envelope, "  ")
	tmp_file.store_string(json_string)
	tmp_file.flush()
	tmp_file.close()
	
	# 2. Verify tmp file integrity
	var verify_file: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	if verify_file == null:
		save_failed.emit("Tmp save file verification failed on reopen.")
		return false
	var read_back: String = verify_file.get_as_text()
	verify_file.close()
	
	var test_json: JSON = JSON.new()
	if test_json.parse(read_back) != OK:
		save_failed.emit("Tmp save file corrupted during write.")
		return false
		
	# 3. Rotate existing main file to .bak
	if FileAccess.file_exists(main_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var rotate_err: Error = DirAccess.rename_absolute(main_path, bak_path)
		if rotate_err != OK:
			push_warning("SaveManager: Failed to rotate old save to backup.")
			
	# 4. Atomically promote tmp file to main file
	var promote_err: Error = DirAccess.rename_absolute(tmp_path, main_path)
	if promote_err != OK:
		var err_msg2: String = "Atomic rename from tmp to main save failed (Error: %d)" % promote_err
		push_error(err_msg2)
		save_failed.emit(err_msg2)
		return false
		
	return true

## Reads save file with automatic corruption detection and fallback to .bak.
func read_save_envelope(slot_name: String) -> Dictionary:
	var main_path: String = get_save_file_path(slot_name)
	var bak_path: String = get_save_backup_path(slot_name)
	
	var candidate_paths: Array[String] = [main_path, bak_path]
	
	for path: String in candidate_paths:
		if not FileAccess.file_exists(path):
			continue
			
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
			
		var text: String = file.get_as_text()
		file.close()
		
		if text.strip_edges().is_empty():
			continue
			
		var json: JSON = JSON.new()
		if json.parse(text) != OK:
			push_warning("SaveManager: Corrupted JSON encountered in '%s', attempting backup." % path)
			continue
			
		var env: Dictionary = json.data as Dictionary
		if env.is_empty():
			continue
			
		var save_ver: int = int(env.get("save_version", 1))
		if save_ver > CURRENT_SAVE_VERSION:
			push_error("SaveManager: Save file version %d is newer than supported %d." % [save_ver, CURRENT_SAVE_VERSION])
			return {}
			
		# Run migrations if necessary
		if save_ver < CURRENT_SAVE_VERSION:
			env = _migrate_save_envelope(env, save_ver)
			
		return env
		
	return {}

func _migrate_save_envelope(old_env: Dictionary, from_version: int) -> Dictionary:
	var env: Dictionary = old_env.duplicate(true)
	if from_version == 1:
		# v1 to v2 migration
		env["save_version"] = 2
		var payload: Dictionary = env.get("payload", {})
		if payload.is_empty():
			# Wrap legacy root-level dictionary into payload
			payload = {
				"current_turn": int(old_env.get("current_turn", 1)),
				"factions": old_env.get("factions", []),
				"provinces": old_env.get("provinces", []),
				"armies": old_env.get("armies", [])
			}
			env["payload"] = payload
	return env

## Two-Phase Deserialization & Referential Integrity Validation.
func deserialize_campaign(payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return {"valid": false, "reason": "Empty payload"}
		
	# Phase 1: Build entities into isolated staging maps
	var staged_factions: Dictionary = {}
	var staged_provinces: Dictionary = {}
	var staged_armies: Array[ArmyData] = []
	
	var raw_factions: Array = payload.get("factions", [])
	for f_dict: Variant in raw_factions:
		if f_dict is Dictionary:
			var fac: FactionData = FactionData.from_dict(f_dict)
			staged_factions[fac.faction_id] = fac
			
	var raw_provinces: Array = payload.get("provinces", [])
	for p_dict: Variant in raw_provinces:
		if p_dict is Dictionary:
			var prov: ProvinceData = ProvinceData.from_dict(p_dict)
			staged_provinces[prov.province_id] = prov
			
	var raw_armies: Array = payload.get("armies", [])
	for a_dict: Variant in raw_armies:
		if a_dict is Dictionary:
			var army: ArmyData = ArmyData.from_dict(a_dict)
			staged_armies.append(army)
			
	# Phase 2: Link validation
	for army: ArmyData in staged_armies:
		if not staged_factions.has(army.owner_faction_id) and army.owner_faction_id != "faction_rebels":
			return {"valid": false, "reason": "Army %s references unknown faction %s" % [army.army_id, army.owner_faction_id]}
		if not staged_provinces.has(army.current_province_id):
			return {"valid": false, "reason": "Army %s stationed in unknown province %s" % [army.army_id, army.current_province_id]}
			
	for prov: ProvinceData in staged_provinces.values():
		if prov.owner_faction_id != "" and not staged_factions.has(prov.owner_faction_id) and prov.owner_faction_id != "faction_rebels":
			return {"valid": false, "reason": "Province %s owned by unknown faction %s" % [prov.province_id, prov.owner_faction_id]}
			
	return {
		"valid": true,
		"factions": staged_factions.values(),
		"provinces": staged_provinces,
		"armies": staged_armies,
		"current_turn": int(payload.get("current_turn", 1))
	}

## Saves game state atomically from live singletons.
func save_game(slot_name: String = DEFAULT_SAVE_SLOT) -> bool:
	var turn_mgr: Node = get_node_or_null("/root/TurnManager")
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	
	if turn_mgr == null or campaign_mgr == null:
		save_failed.emit("Core managers not available for saving.")
		return false
		
	if turn_mgr.has_method("can_accept_input") and not turn_mgr.can_accept_input():
		save_failed.emit("Cannot save while turn turnover is processing.")
		return false
		
	var factions_list: Array[FactionData] = []
	for f: Variant in turn_mgr.get("registered_factions"):
		if f is FactionData:
			factions_list.append(f)
			
	var provinces_map: Dictionary = campaign_mgr.get("provinces")
	var armies_list: Array[ArmyData] = []
	for a: Variant in campaign_mgr.get("armies"):
		if a is ArmyData:
			armies_list.append(a)
			
	var turn_val: int = int(turn_mgr.get("current_turn"))
	var envelope: Dictionary = serialize_campaign(factions_list, provinces_map, armies_list, turn_val)
	
	var write_ok: bool = write_save_atomic(slot_name, envelope)
	if write_ok:
		game_saved.emit(slot_name)
		return true
	return false

## Loads campaign state from local disk using two-phase staging validation.
func load_game(slot_name: String = DEFAULT_SAVE_SLOT) -> bool:
	var envelope: Dictionary = read_save_envelope(slot_name)
	if envelope.is_empty():
		load_failed.emit(slot_name, "Missing or unrecoverable save file.")
		return false
		
	var payload: Dictionary = envelope.get("payload", {})
	var result: Dictionary = deserialize_campaign(payload)
	if not result.get("valid", false):
		load_failed.emit(slot_name, result.get("reason", "Validation failure"))
		return false
		
	var turn_mgr: Node = get_node_or_null("/root/TurnManager")
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if turn_mgr == null or campaign_mgr == null:
		load_failed.emit(slot_name, "Core managers not present.")
		return false
		
	is_loading = true
	
	# Swap validated state
	turn_mgr.set("current_turn", result["current_turn"])
	turn_mgr.set("registered_factions", result["factions"])
	campaign_mgr.set("provinces", result["provinces"])
	campaign_mgr.set("armies", result["armies"])
	
	is_loading = false
	game_loaded.emit(slot_name)
	return true
