class_name TitleScreen
extends Control

@onready var continue_button: Button = $SafeAreaContainer/CenterContainer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $SafeAreaContainer/CenterContainer/VBoxContainer/NewGameButton

var _target_slot: String = "campaign_autosave"

func _ready() -> void:
	_ensure_references()
	setup_from_save_slot(_target_slot)
	
	if continue_button != null and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if new_game_button != null and not new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.connect(_on_new_game_pressed)

func _ensure_references() -> void:
	if continue_button == null:
		continue_button = get_node_or_null("SafeAreaContainer/CenterContainer/VBoxContainer/ContinueButton") as Button
	if new_game_button == null:
		new_game_button = get_node_or_null("SafeAreaContainer/CenterContainer/VBoxContainer/NewGameButton") as Button

## Configures the continue button based on available autosave metadata.
func setup_from_save_slot(slot_name: String) -> void:
	_ensure_references()
	_target_slot = slot_name
	
	var save_mgr: Node = get_node_or_null("/root/SaveManager") if is_inside_tree() else null
	if save_mgr == null:
		# Fallback direct script load for isolated tests
		var sm_script: GDScript = load("res://scripts/core/SaveManager.gd") as GDScript
		if sm_script != null:
			save_mgr = sm_script.new()
			
	if save_mgr == null:
		if continue_button != null:
			continue_button.disabled = true
			continue_button.text = "Continue Campaign (No Save)"
		return
		
	var has_save: bool = save_mgr.has_method("has_save_file") and save_mgr.has_save_file(slot_name)
	if not has_save:
		if continue_button != null:
			continue_button.disabled = true
			continue_button.text = "Continue Campaign (No Save)"
	else:
		var env: Dictionary = save_mgr.read_save_envelope(slot_name)
		if env.is_empty():
			if continue_button != null:
				continue_button.disabled = true
				continue_button.text = "Continue Campaign (Save Unreadable)"
		else:
			var payload: Dictionary = env.get("payload", {})
			var turn_num: int = int(payload.get("current_turn", 1))
			var faction_name: String = "Sparta"
			var factions_list: Array = payload.get("factions", [])
			for f_dict: Variant in factions_list:
				if f_dict is Dictionary and f_dict.get("is_player", false):
					faction_name = str(f_dict.get("faction_name", "Sparta"))
					break
					
			if continue_button != null:
				continue_button.disabled = false
				continue_button.text = "Continue (Turn %d - %s)" % [turn_num, faction_name]

	# Free temporary instance if created for test
	if not is_inside_tree() and save_mgr != null:
		save_mgr.free()

func _on_continue_pressed() -> void:
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("load_game"):
		save_mgr.load_game(_target_slot)
	
	if get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/MainCampaign.tscn")

func _on_new_game_pressed() -> void:
	if get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/MainCampaign.tscn")
