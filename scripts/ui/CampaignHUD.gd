class_name CampaignHUD
extends CanvasLayer

@onready var top_bar: PanelContainer = $TopBar
@onready var top_margin_container: MarginContainer = $TopBar/MarginContainer
@onready var turn_label: Label = $TopBar/MarginContainer/HBoxContainer/TurnLabel
@onready var faction_label: Label = $TopBar/MarginContainer/HBoxContainer/FactionLabel
@onready var treasury_label: Label = $TopBar/MarginContainer/HBoxContainer/TreasuryLabel
@onready var end_turn_button: Button = $TopBar/MarginContainer/HBoxContainer/EndTurnButton

@onready var info_panel: PanelContainer = $SelectionPanel
@onready var title_label: Label = $SelectionPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var details_label: Label = $SelectionPanel/MarginContainer/VBoxContainer/DetailsLabel
@onready var stance_option_button: OptionButton = $SelectionPanel/MarginContainer/VBoxContainer/StanceContainer/StanceOptionButton
@onready var stance_container: HBoxContainer = $SelectionPanel/MarginContainer/VBoxContainer/StanceContainer

@onready var battle_dialog: AcceptDialog = $BattleDialog
@onready var notification_label: Label = $NotificationLabel

var _current_selected_army: ArmyData = null

func _ready() -> void:
	info_panel.visible = false
	notification_label.visible = false

	_apply_mobile_safe_area()
	get_viewport().size_changed.connect(_apply_mobile_safe_area)

	# Setup stance options
	if stance_option_button != null:
		stance_option_button.clear()
		stance_option_button.add_item("Default", ArmyData.Stance.DEFAULT)
		stance_option_button.add_item("Forced March", ArmyData.Stance.FORCED_MARCH)
		stance_option_button.add_item("Encamp", ArmyData.Stance.ENCAMP)
		stance_option_button.add_item("Siege", ArmyData.Stance.SIEGE)
		stance_option_button.item_selected.connect(_on_stance_selected)

	end_turn_button.pressed.connect(_on_end_turn_pressed)

	# Connect TurnManager
	var turn_mgr: TurnManager = get_node_or_null("/root/TurnManager")
	if turn_mgr != null:
		turn_mgr.turn_started.connect(_on_turn_started)
		turn_mgr.faction_turn_changed.connect(_on_faction_turn_changed)
		turn_mgr.player_gold_changed.connect(_on_player_gold_changed)
		_refresh_top_bar(turn_mgr.current_turn, turn_mgr.get_active_faction(), turn_mgr.get_player_gold())

	# Connect CampaignManager
	var campaign_mgr: CampaignManager = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null:
		campaign_mgr.province_selected.connect(_on_province_selected)
		campaign_mgr.army_selected.connect(_on_army_selected)
		campaign_mgr.selection_cleared.connect(_on_selection_cleared)
		campaign_mgr.battle_triggered.connect(_on_battle_triggered)
		campaign_mgr.move_rejected.connect(_show_notification)

	# Connect SaveManager
	var save_mgr: SaveManager = get_node_or_null("/root/SaveManager")
	if save_mgr != null:
		save_mgr.game_saved.connect(func(_slot: String) -> void:
			_show_notification("Campaign Autosaved (Offline)", 1.2)
		)

## Adjusts UI margins according to the mobile screen safe area (punch-holes, notches, dynamic island).
func _apply_mobile_safe_area() -> void:
	if top_margin_container == null:
		return
	
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()

	# If running on desktop window or testing, fallback gracefully
	if safe_rect.size.x == 0 or safe_rect.size.y == 0:
		return

	var left_pad: int = maxi(safe_rect.position.x, 15)
	var right_pad: int = maxi(window_size.x - (safe_rect.position.x + safe_rect.size.x), 15)
	var top_pad: int = maxi(safe_rect.position.y, 8)

	top_margin_container.add_theme_constant_override("margin_left", left_pad)
	top_margin_container.add_theme_constant_override("margin_right", right_pad)
	top_margin_container.add_theme_constant_override("margin_top", top_pad)

func _refresh_top_bar(turn_num: int, active_faction: FactionData, gold: int) -> void:
	if turn_label != null:
		turn_label.text = "Turn %d" % turn_num
	
	if faction_label != null and active_faction != null:
		var side_str: String = "Player" if active_faction.is_player else "AI"
		faction_label.text = "Active: %s (%s)" % [active_faction.faction_name, side_str]
	
	if treasury_label != null:
		treasury_label.text = "Treasury: %d Gold" % gold

func _on_end_turn_pressed() -> void:
	var turn_mgr: TurnManager = get_node_or_null("/root/TurnManager")
	if turn_mgr != null:
		turn_mgr.end_active_faction_turn()

func _on_turn_started(turn_number: int, active_faction: FactionData) -> void:
	var turn_mgr: TurnManager = get_node_or_null("/root/TurnManager")
	var gold: int = turn_mgr.get_player_gold() if turn_mgr != null else 0
	_refresh_top_bar(turn_number, active_faction, gold)

func _on_faction_turn_changed(active_faction: FactionData) -> void:
	var turn_mgr: TurnManager = get_node_or_null("/root/TurnManager")
	var gold: int = turn_mgr.get_player_gold() if turn_mgr != null else 0
	_refresh_top_bar(turn_mgr.current_turn if turn_mgr != null else 1, active_faction, gold)

func _on_player_gold_changed(new_gold: int, _delta: int) -> void:
	if treasury_label != null:
		treasury_label.text = "Treasury: %d Gold" % new_gold

func _on_province_selected(province: ProvinceData) -> void:
	_current_selected_army = null
	info_panel.visible = true
	stance_container.visible = false
	
	title_label.text = "Province: %s" % province.province_name
	
	var buildings_list: String = "None"
	if not province.building_slots.is_empty():
		var names: Array[String] = []
		for slot: BuildingSlotData in province.building_slots:
			if slot != null and slot.building_data != null:
				names.append(slot.building_data.display_name)
		buildings_list = ", ".join(names)

	details_label.text = """Owner: %s
Settlement Tier: %d
Public Order: %.1f
Base Tax: %.0f (Net: %.0f)
Growth Rate: +%.1f / turn
Garrison Size: %d units
Buildings (%d/%d): %s""" % [
		province.owner_faction_id.capitalize(),
		province.settlement_tier,
		province.public_order,
		province.base_tax,
		province.calculate_total_tax(),
		province.growth_rate,
		province.garrison_units.size(),
		province.building_slots.size(),
		province.max_building_slots,
		buildings_list
	]

func _on_army_selected(army: ArmyData) -> void:
	_current_selected_army = army
	info_panel.visible = true
	stance_container.visible = true
	
	if stance_option_button != null:
		stance_option_button.selected = int(army.stance)

	title_label.text = "Army: %s" % army.army_name
	
	var unit_summary: String = ""
	for u: UnitData in army.units:
		if u != null:
			unit_summary += "\n â€¢ %s (T%d, Str: %.0f, Arm: %.0f)" % [u.display_name, u.tier, u.base_strength, u.armor]

	details_label.text = """Owner: %s
Stationed in: %s
General Rating: %.1fx
Action Points: %.0f / %.0f
Stance: %s
Total Upkeep: %d Gold/turn
Combat Power: %.0f
Roster (%d units):%s""" % [
		army.owner_faction_id.capitalize(),
		army.current_province_id.capitalize(),
		army.general_leadership_rating,
		army.current_action_points,
		army.max_action_points,
		army.get_stance_name(),
		army.calculate_total_upkeep(),
		army.calculate_total_strength(),
		army.units.size(),
		unit_summary
	]

func _on_selection_cleared() -> void:
	_current_selected_army = null
	info_panel.visible = false

func _on_stance_selected(index: int) -> void:
	if _current_selected_army != null:
		_current_selected_army.set_stance(index as ArmyData.Stance)
		_on_army_selected(_current_selected_army)

func _on_battle_triggered(result: BattleResult) -> void:
	if battle_dialog != null:
		battle_dialog.title = "Battle Resolved - %s" % ("Victory!" if result.attacker_won else "Defeat!")
		battle_dialog.dialog_text = result.get_log_message()
		battle_dialog.popup_centered(Vector2i(520, 320))
	_on_selection_cleared()

func _show_notification(msg: String, duration: float = 2.0) -> void:
	if notification_label != null:
		notification_label.text = msg
		notification_label.visible = true
		var tween: Tween = create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(func() -> void: notification_label.visible = false)

