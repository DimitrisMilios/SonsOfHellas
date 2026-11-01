class_name CampaignHUD
extends CanvasLayer

@onready var safe_area_container: SafeAreaContainer = $SafeAreaContainer
@onready var top_bar: PanelContainer = $SafeAreaContainer/HUDLayout/TopBar
@onready var turn_label: Label = $SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/TurnLabel
@onready var season_label: Label = $SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/SeasonLabel
@onready var faction_label: Label = $SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/FactionLabel
@onready var treasury_label: Label = $SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/TreasuryLabel
@onready var income_label: Label = $SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/IncomeLabel
@onready var food_label: Label = $SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/FoodLabel
@onready var end_turn_button: Button = $SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/EndTurnButton

@onready var info_panel: PanelContainer = $SafeAreaContainer/HUDLayout/SelectionPanel
@onready var title_label: Label = $SafeAreaContainer/HUDLayout/SelectionPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var details_label: Label = $SafeAreaContainer/HUDLayout/SelectionPanel/MarginContainer/VBoxContainer/DetailsLabel
@onready var stance_container: HBoxContainer = $SafeAreaContainer/HUDLayout/SelectionPanel/MarginContainer/VBoxContainer/StanceContainer
@onready var stance_option_button: OptionButton = $SafeAreaContainer/HUDLayout/SelectionPanel/MarginContainer/VBoxContainer/StanceContainer/StanceOptionButton

@onready var notification_label: Label = $SafeAreaContainer/HUDLayout/NotificationLabel
@onready var battle_dialog: AcceptDialog = $BattleDialog

var _current_selected_army_id: String = ""

## Calculates historical season and year string given campaign turn number.
static func format_season_year(turn_num: int) -> String:
	var safe_turn: int = maxi(1, turn_num)
	var seasons: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
	var season_idx: int = (safe_turn - 1) % 4
	var years_passed: int = (safe_turn - 1) / 4
	var year: int = 431 - years_passed
	return "%s, %d BC" % [seasons[season_idx], year]

func _ensure_references() -> void:
	if safe_area_container == null:
		safe_area_container = get_node_or_null("SafeAreaContainer") as SafeAreaContainer
	if top_bar == null:
		top_bar = get_node_or_null("SafeAreaContainer/HUDLayout/TopBar") as PanelContainer
	if turn_label == null:
		turn_label = get_node_or_null("SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/TurnLabel") as Label
	if season_label == null:
		season_label = get_node_or_null("SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/SeasonLabel") as Label
	if faction_label == null:
		faction_label = get_node_or_null("SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/FactionLabel") as Label
	if treasury_label == null:
		treasury_label = get_node_or_null("SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/TreasuryLabel") as Label
	if income_label == null:
		income_label = get_node_or_null("SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/IncomeLabel") as Label
	if food_label == null:
		food_label = get_node_or_null("SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/FoodLabel") as Label
	if end_turn_button == null:
		end_turn_button = get_node_or_null("SafeAreaContainer/HUDLayout/TopBar/MarginContainer/HBoxContainer/EndTurnButton") as Button
	if info_panel == null:
		info_panel = get_node_or_null("SafeAreaContainer/HUDLayout/SelectionPanel") as PanelContainer
	if title_label == null:
		title_label = get_node_or_null("SafeAreaContainer/HUDLayout/SelectionPanel/MarginContainer/VBoxContainer/TitleLabel") as Label
	if details_label == null:
		details_label = get_node_or_null("SafeAreaContainer/HUDLayout/SelectionPanel/MarginContainer/VBoxContainer/DetailsLabel") as Label
	if stance_container == null:
		stance_container = get_node_or_null("SafeAreaContainer/HUDLayout/SelectionPanel/MarginContainer/VBoxContainer/StanceContainer") as HBoxContainer
	if stance_option_button == null:
		stance_option_button = get_node_or_null("SafeAreaContainer/HUDLayout/SelectionPanel/MarginContainer/VBoxContainer/StanceContainer/StanceOptionButton") as OptionButton
	if notification_label == null:
		notification_label = get_node_or_null("SafeAreaContainer/HUDLayout/NotificationLabel") as Label
	if battle_dialog == null:
		battle_dialog = get_node_or_null("BattleDialog") as AcceptDialog
	if battle_dialog != null:
		var ok_btn: Button = battle_dialog.get_ok_button()
		if ok_btn != null:
			ok_btn.custom_minimum_size = Vector2(120, 48)

func _ready() -> void:
	_ensure_references()

	if info_panel != null:
		info_panel.visible = false
	if notification_label != null:
		notification_label.visible = false

	# Setup stance options
	if stance_option_button != null:
		stance_option_button.clear()
		stance_option_button.add_item("Normal", ArmyData.Stance.NORMAL)
		stance_option_button.add_item("Forced March", ArmyData.Stance.FORCED_MARCH)
		stance_option_button.add_item("Raiding", ArmyData.Stance.RAIDING)
		stance_option_button.add_item("Encampment", ArmyData.Stance.ENCAMPMENT)
		stance_option_button.add_item("Ambush", ArmyData.Stance.AMBUSH)
		stance_option_button.add_item("Siege", ArmyData.Stance.SIEGE)
		if not stance_option_button.item_selected.is_connected(_on_stance_selected):
			stance_option_button.item_selected.connect(_on_stance_selected)

	if end_turn_button != null:
		if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
			end_turn_button.pressed.connect(_on_end_turn_pressed)

	# Connect TurnManager
	if is_inside_tree():
		var turn_mgr: Node = get_node_or_null("/root/TurnManager")
		if turn_mgr != null:
			if turn_mgr.has_signal("turn_started"):
				turn_mgr.turn_started.connect(_on_turn_started)
			if turn_mgr.has_signal("faction_turn_changed"):
				turn_mgr.faction_turn_changed.connect(_on_faction_turn_changed)
			if turn_mgr.has_signal("player_gold_changed"):
				turn_mgr.player_gold_changed.connect(_on_player_gold_changed)
			if turn_mgr.has_signal("turn_processing_started"):
				turn_mgr.turn_processing_started.connect(on_turn_processing_started)
			if turn_mgr.has_signal("turn_processing_finished"):
				turn_mgr.turn_processing_finished.connect(on_turn_processing_finished)

			update_top_bar(
				turn_mgr.current_turn if "current_turn" in turn_mgr else 1,
				turn_mgr.get_active_faction() if turn_mgr.has_method("get_active_faction") else null,
				turn_mgr.get_player_gold() if turn_mgr.has_method("get_player_gold") else 0
			)

		# Connect CampaignManager
		var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
		if campaign_mgr != null:
			if campaign_mgr.has_signal("province_selected"):
				campaign_mgr.province_selected.connect(_on_province_selected)
			if campaign_mgr.has_signal("army_selected"):
				campaign_mgr.army_selected.connect(_on_army_selected)
			if campaign_mgr.has_signal("selection_cleared"):
				campaign_mgr.selection_cleared.connect(clear_selection)
			if campaign_mgr.has_signal("battle_triggered"):
				campaign_mgr.battle_triggered.connect(_on_battle_triggered)
			if campaign_mgr.has_signal("move_rejected"):
				campaign_mgr.move_rejected.connect(show_notification)

		# Connect SaveManager
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr != null and save_mgr.has_signal("game_saved"):
			save_mgr.game_saved.connect(func(_slot: String) -> void:
				show_notification("Campaign Autosaved (Offline)", 1.2)
			)

## Updates all metrics in the top HUD bar.
func update_top_bar(turn_num: int, active_faction: FactionData, gold: int, net_income: int = 0) -> void:
	_ensure_references()
	if turn_label != null:
		turn_label.text = "Turn %d" % turn_num
	if season_label != null:
		season_label.text = format_season_year(turn_num)
	if faction_label != null and active_faction != null:
		var side_str: String = "Player" if active_faction.is_player else "AI"
		faction_label.text = "Active: %s (%s)" % [active_faction.faction_name, side_str]
	if treasury_label != null:
		treasury_label.text = "Treasury: %d Gold" % gold
	if income_label != null:
		income_label.text = "Net: %+d/turn" % net_income
	if food_label != null and active_faction != null:
		food_label.text = "Food: %+d" % active_faction.food_balance

## Binds an immutable ProvinceViewModel snapshot directly to the inspection drawer.
func display_province_view_model(vm: ProvinceViewModel) -> void:
	_ensure_references()
	_current_selected_army_id = ""
	if info_panel != null:
		info_panel.visible = true
	if stance_container != null:
		stance_container.visible = false

	if title_label != null:
		title_label.text = "Province: %s" % vm.province_name

	if details_label != null:
		var buildings_list: Array[String] = []
		if not vm.building_slots_summary.is_empty():
			for slot_dict: Dictionary in vm.building_slots_summary:
				var b_name: String = slot_dict.get("name", "Slot")
				var is_bld: bool = slot_dict.get("is_building", false)
				var turns: int = slot_dict.get("turns_left", 0)
				if is_bld:
					buildings_list.append("%s (Building, %d turns)" % [b_name, turns])
				else:
					buildings_list.append(b_name)
		var buildings_str: String = ", ".join(buildings_list) if not buildings_list.is_empty() else "None"

		var order_status: String = "Stable" if vm.public_order >= 0.0 else "Unrest Alert"
		details_label.text = """🏛️ Owner: %s (Tier %d Settlement)
⚖️ Public Order: %.1f [%s]
🔥 Unrest Pressure: %d (Consecutive: %d)
💰 Regional Wealth: %.0f Gold
🪙 Tax Income: %d Gold (Upper L%d / Lower L%d)

🏛️ Infrastructure (%d Buildings):
%s""" % [
			vm.owner_faction_id.capitalize(),
			vm.settlement_tier,
			vm.public_order,
			order_status,
			vm.unrest_pressure,
			vm.consecutive_unrest_turns,
			vm.region_wealth,
			vm.tax_income,
			vm.tax_level_upper,
			vm.tax_level_lower,
			vm.building_slots_summary.size(),
			buildings_str
		]

## Binds an immutable ArmyViewModel snapshot directly to the inspection drawer.
func display_army_view_model(vm: ArmyViewModel) -> void:
	_ensure_references()
	_current_selected_army_id = vm.army_id
	if info_panel != null:
		info_panel.visible = true
	if stance_container != null:
		stance_container.visible = true

	if stance_option_button != null:
		stance_option_button.selected = int(vm.stance)

	if title_label != null:
		title_label.text = "Army: %s" % vm.army_name

	if details_label != null:
		var roster_str: String = ""
		for card: Dictionary in vm.unit_cards:
			roster_str += "\n - %s (T%d, Str: %.0f, Upkeep: %d)" % [
				card.get("name", "Unit"),
				card.get("tier", 1),
				card.get("combat_value", 0.0),
				card.get("upkeep", 0)
			]

		details_label.text = """🛡️ Faction: %s
⚡ Action Points: %.0f / %.0f
⚔️ Stance: %s
💰 Upkeep: %d Gold / turn
🏆 Combat Power: %.0f

📋 Regiments (%d Units):%s""" % [
			vm.owner_faction_id.capitalize(),
			vm.current_action_points,
			vm.max_action_points,
			vm.stance_name,
			vm.total_upkeep,
			vm.total_combat_power,
			vm.unit_cards.size(),
			roster_str
		]

func clear_selection() -> void:
	_ensure_references()
	_current_selected_army_id = ""
	if info_panel != null:
		info_panel.visible = false

func on_turn_processing_started() -> void:
	_ensure_references()
	if end_turn_button != null:
		end_turn_button.disabled = true
	show_notification("Processing Turn...", 1.0)

func on_turn_processing_finished() -> void:
	_ensure_references()
	if end_turn_button != null:
		end_turn_button.disabled = false

func _on_end_turn_pressed() -> void:
	if is_inside_tree():
		var turn_mgr: Node = get_node_or_null("/root/TurnManager")
		if turn_mgr != null and turn_mgr.has_method("execute_end_turn"):
			turn_mgr.execute_end_turn()

func _on_turn_started(turn_number: int, active_faction: FactionData) -> void:
	if is_inside_tree():
		var turn_mgr: Node = get_node_or_null("/root/TurnManager")
		var gold: int = turn_mgr.get_player_gold() if (turn_mgr != null and turn_mgr.has_method("get_player_gold")) else 0
		update_top_bar(turn_number, active_faction, gold)

func _on_faction_turn_changed(active_faction: FactionData) -> void:
	if is_inside_tree():
		var turn_mgr: Node = get_node_or_null("/root/TurnManager")
		var gold: int = turn_mgr.get_player_gold() if (turn_mgr != null and turn_mgr.has_method("get_player_gold")) else 0
		var current_turn: int = turn_mgr.current_turn if (turn_mgr != null and "current_turn" in turn_mgr) else 1
		update_top_bar(current_turn, active_faction, gold)

func _on_player_gold_changed(new_gold: int, _delta: int) -> void:
	_ensure_references()
	if treasury_label != null:
		treasury_label.text = "Treasury: %d Gold" % new_gold

func _on_province_selected(province: ProvinceData) -> void:
	if province != null:
		var vm: ProvinceViewModel = ProvinceViewModel.from_province_data(province)
		display_province_view_model(vm)

func _on_army_selected(army: ArmyData) -> void:
	if army != null:
		var vm: ArmyViewModel = ArmyViewModel.from_army_data(army)
		display_army_view_model(vm)

func _on_stance_selected(index: int) -> void:
	if _current_selected_army_id.is_empty():
		return
	if is_inside_tree():
		var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
		if campaign_mgr != null and campaign_mgr.has_method("set_army_stance"):
			campaign_mgr.set_army_stance(_current_selected_army_id, index as ArmyData.Stance)

func _on_battle_triggered(result: BattleResult) -> void:
	_ensure_references()
	if battle_dialog != null and result != null:
		battle_dialog.title = "Battle Resolved - %s" % ("Victory!" if result.attacker_won else "Defeat!")
		battle_dialog.dialog_text = result.get_log_message()
		if battle_dialog.is_inside_tree():
			battle_dialog.popup_centered(Vector2i(540, 320))
	clear_selection()

func show_notification(msg: String, duration: float = 2.0) -> void:
	_ensure_references()
	if notification_label != null:
		notification_label.text = msg
		notification_label.visible = true
		if is_inside_tree():
			var tween: Tween = create_tween()
			if tween != null:
				tween.tween_interval(duration)
				tween.tween_callback(func() -> void:
					if notification_label != null and is_instance_valid(notification_label):
						notification_label.visible = false
				)
