class_name SaveManager
extends Node

signal game_saved(slot_name: String)
signal game_loaded(slot_name: String)
signal save_failed(reason: String)

const DEFAULT_SAVE_SLOT: String = "campaign_autosave"
const SAVE_DIR_PATH: String = "user://saves/"

@export var autosave_on_pause: bool = true
var is_loading: bool = false

func _ready() -> void:
	_ensure_save_directory_exists()

func _notification(what: int) -> void:
	# Crucial for mobile games: Save immediately when player backgrounds the app or locks phone
	if autosave_on_pause:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game(DEFAULT_SAVE_SLOT)
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android hardware back button
			save_game(DEFAULT_SAVE_SLOT)

func _ensure_save_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR_PATH):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)

func get_save_file_path(slot_name: String) -> String:
	return "%s%s.json" % [SAVE_DIR_PATH, slot_name]

func has_save_file(slot_name: String = DEFAULT_SAVE_SLOT) -> bool:
	return FileAccess.file_exists(get_save_file_path(slot_name))

## Saves complete campaign state to local device storage. 100% offline.
func save_game(slot_name: String = DEFAULT_SAVE_SLOT) -> bool:
	var turn_mgr: TurnManager = get_node_or_null("/root/TurnManager")
	var campaign_mgr: CampaignManager = get_node_or_null("/root/CampaignManager")
	
	if turn_mgr == null or campaign_mgr == null:
		save_failed.emit("Core managers not available for saving.")
		return false
	
	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"current_turn": turn_mgr.current_turn,
		"active_faction_index": turn_mgr.active_faction_index,
		"factions": [],
		"provinces": [],
		"armies": []
	}

	# Serialize factions
	for faction: FactionData in turn_mgr.registered_factions:
		if faction != null:
			save_data["factions"].append({
				"faction_id": faction.faction_id,
				"treasury": faction.treasury
			})

	# Serialize provinces
	for prov_id: String in campaign_mgr.provinces.keys():
		var prov: ProvinceData = campaign_mgr.provinces[prov_id]
		if prov != null:
			var building_ids: Array[String] = []
			for b: BuildingData in prov.building_slots:
				if b != null:
					building_ids.append(b.building_id)
			
			save_data["provinces"].append({
				"province_id": prov.province_id,
				"owner_faction_id": prov.owner_faction_id,
				"settlement_tier": prov.settlement_tier,
				"public_order": prov.public_order,
				"base_tax": prov.base_tax,
				"growth_rate": prov.growth_rate,
				"building_ids": building_ids
			})

	# Serialize armies
	for army: ArmyData in campaign_mgr.armies:
		if army != null:
			var unit_ids: Array[String] = []
			for u: UnitData in army.units:
				if u != null:
					unit_ids.append(u.unit_id)
			
			save_data["armies"].append({
				"army_id": army.army_id,
				"army_name": army.army_name,
				"owner_faction_id": army.owner_faction_id,
				"current_province_id": army.current_province_id,
				"general_leadership_rating": army.general_leadership_rating,
				"current_action_points": army.current_action_points,
				"max_action_points": army.max_action_points,
				"stance": int(army.stance),
				"unit_ids": unit_ids
			})

	# Write JSON safely
	_ensure_save_directory_exists()
	var file_path: String = get_save_file_path(slot_name)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var err_msg: String = "Failed to open save file '%s' for writing (Error: %s)" % [file_path, FileAccess.get_open_error()]
		push_error(err_msg)
		save_failed.emit(err_msg)
		return false

	var json_string: String = JSON.stringify(save_data, "  ")
	file.store_string(json_string)
	file.close()

	game_saved.emit(slot_name)
	return true

## Loads campaign state from local device storage.
func load_game(slot_name: String = DEFAULT_SAVE_SLOT) -> bool:
	var file_path: String = get_save_file_path(slot_name)
	if not FileAccess.file_exists(file_path):
		save_failed.emit("Save file does not exist.")
		return false

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		save_failed.emit("Failed to open save file for reading.")
		return false

	var content: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(content)
	if parse_result != OK:
		save_failed.emit("Corrupted JSON in save file.")
		return false

	var save_data: Dictionary = json.data as Dictionary
	if save_data.is_empty():
		save_failed.emit("Empty save file.")
		return false

	var turn_mgr: TurnManager = get_node_or_null("/root/TurnManager")
	var campaign_mgr: CampaignManager = get_node_or_null("/root/CampaignManager")
	if turn_mgr == null or campaign_mgr == null:
		save_failed.emit("Core managers not ready for loading.")
		return false

	is_loading = true

	# Restore turn state
	turn_mgr.current_turn = save_data.get("current_turn", 1)
	turn_mgr.active_faction_index = save_data.get("active_faction_index", 0)

	# Restore factions
	var factions_data: Array = save_data.get("factions", [])
	for f_dict: Dictionary in factions_data:
		var fid: String = f_dict.get("faction_id", "")
		for f: FactionData in turn_mgr.registered_factions:
			if f.faction_id == fid:
				f.treasury = f_dict.get("treasury", f.treasury)
				break

	# Restore provinces
	var provinces_data: Array = save_data.get("provinces", [])
	for p_dict: Dictionary in provinces_data:
		var pid: String = p_dict.get("province_id", "")
		if campaign_mgr.provinces.has(pid):
			var prov: ProvinceData = campaign_mgr.provinces[pid]
			prov.owner_faction_id = p_dict.get("owner_faction_id", prov.owner_faction_id)
			prov.settlement_tier = p_dict.get("settlement_tier", prov.settlement_tier)
			prov.public_order = p_dict.get("public_order", prov.public_order)
			prov.base_tax = p_dict.get("base_tax", prov.base_tax)
			prov.growth_rate = p_dict.get("growth_rate", prov.growth_rate)

	# Restore armies
	var armies_data: Array = save_data.get("armies", [])
	for a_dict: Dictionary in armies_data:
		var aid: String = a_dict.get("army_id", "")
		for army: ArmyData in campaign_mgr.armies:
			if army.army_id == aid:
				army.current_province_id = a_dict.get("current_province_id", army.current_province_id)
				army.current_action_points = a_dict.get("current_action_points", army.current_action_points)
				army.stance = a_dict.get("stance", army.stance) as ArmyData.Stance
				break

	is_loading = false
	game_loaded.emit(slot_name)
	return true
