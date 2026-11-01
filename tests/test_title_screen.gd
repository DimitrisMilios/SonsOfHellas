class_name TestTitleScreen
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_title_screen_instantiation(failures)
	test_title_screen_disabled_when_no_save(failures)
	test_title_screen_metadata_display(failures)
	test_touch_target_dimensions(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_title_screen_instantiation(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/TitleScreen.tscn") as PackedScene
	_assert(scene != null, "TitleScreen.tscn must be loadable", failures)
	if scene == null:
		return
		
	var title_node: Node = scene.instantiate()
	_assert(title_node != null, "Instantiated node must not be null", failures)
	
	var safe_area: SafeAreaContainer = title_node.get_node_or_null("SafeAreaContainer") as SafeAreaContainer
	_assert(safe_area != null, "TitleScreen must wrap UI in SafeAreaContainer", failures)
	
	title_node.free()

static func test_title_screen_disabled_when_no_save(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/TitleScreen.tscn") as PackedScene
	if scene == null:
		return
	var title_node: Node = scene.instantiate()
	
	# Pass empty or non-existent slot
	title_node.call("setup_from_save_slot", "non_existent_slot_xyz")
	var continue_btn: Button = title_node.get_node_or_null("SafeAreaContainer/CenterContainer/VBoxContainer/ContinueButton") as Button
	_assert(continue_btn != null, "ContinueButton must exist", failures)
	if continue_btn != null:
		_assert(continue_btn.disabled, "ContinueButton must be disabled when no save exists", failures)
	
	title_node.free()

static func test_title_screen_metadata_display(failures: Array[String]) -> void:
	var sm_script: GDScript = load("res://scripts/core/SaveManager.gd") as GDScript
	var sm: Node = sm_script.new()
	var test_slot: String = "test_title_metadata"
	
	var f: FactionData = FactionData.new()
	f.faction_id = "sparta"
	f.faction_name = "Sparta"
	f.is_player = true
	
	var p: ProvinceData = ProvinceData.new()
	p.province_id = "prov_sparta"
	p.province_name = "Sparta"
	p.owner_faction_id = "sparta"
	
	var envelope: Dictionary = sm.serialize_campaign([f], {"prov_sparta": p}, [], 7, 42)
	sm.write_save_atomic(test_slot, envelope)
	
	var scene: PackedScene = load("res://scenes/TitleScreen.tscn") as PackedScene
	if scene != null:
		var title_node: Node = scene.instantiate()
		title_node.call("setup_from_save_slot", test_slot)
		var continue_btn: Button = title_node.get_node_or_null("SafeAreaContainer/CenterContainer/VBoxContainer/ContinueButton") as Button
		_assert(continue_btn != null and not continue_btn.disabled, "Continue button should be enabled when valid save exists", failures)
		if continue_btn != null:
			_assert(continue_btn.text.contains("Turn 7"), "Continue button text should display Turn 7, got: %s" % continue_btn.text, failures)
			_assert(continue_btn.text.contains("Sparta"), "Continue button text should display faction Sparta, got: %s" % continue_btn.text, failures)
		title_node.free()
		
	# Clean up test save files
	for path: String in [sm.get_save_file_path(test_slot), sm.get_save_backup_path(test_slot), sm.get_save_tmp_path(test_slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	sm.free()

static func test_touch_target_dimensions(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/TitleScreen.tscn") as PackedScene
	if scene == null:
		return
	var title_node: Node = scene.instantiate()
	
	var continue_btn: Button = title_node.get_node_or_null("SafeAreaContainer/CenterContainer/VBoxContainer/ContinueButton") as Button
	var new_btn: Button = title_node.get_node_or_null("SafeAreaContainer/CenterContainer/VBoxContainer/NewGameButton") as Button
	
	_assert(continue_btn != null and continue_btn.custom_minimum_size.y >= 44.0, 
		"ContinueButton height must be >= 44px", failures)
	_assert(new_btn != null and new_btn.custom_minimum_size.y >= 44.0, 
		"NewGameButton height must be >= 44px", failures)
	
	title_node.free()
